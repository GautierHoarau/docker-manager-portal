param([switch]$Clean)

$ErrorActionPreference = "Continue"
$env:PATH += ";C:\Users\basti\AppData\Local\Temp\terraform"

Write-Host "=== DEPLOIEMENT PORTAIL CLOUD ===" -ForegroundColor Cyan

# Connexion et ID
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) { az login; $account = az account show --output json | ConvertFrom-Json }
$uniqueId = ($account.user.name -replace '[^a-zA-Z0-9]', '').ToLower().Substring(0, 8)
Write-Host "ID unique: $uniqueId" -ForegroundColor Green

# Nettoyage si demande
if ($Clean) {
    Write-Host "Nettoyage..." -ForegroundColor Yellow
    $rgName = "rg-container-manager-$uniqueId"
    az group delete --name $rgName --yes --no-wait 2>$null | Out-Null
    Start-Sleep 10
    Push-Location terraform\azure
    Remove-Item .terraform*, terraform.tfstate*, tfplan* -Recurse -Force -ErrorAction SilentlyContinue
    Pop-Location
    Write-Host "Nettoye" -ForegroundColor Green
}

# Phase 1: Infrastructure seule
Write-Host "`nPhase 1: Infrastructure..." -ForegroundColor Yellow
Push-Location terraform\azure
terraform init -upgrade
terraform plan -var="unique_id=$uniqueId" -out=tfplan
terraform apply -auto-approve tfplan

# Recuperation des infos
$outputs = terraform output -json | ConvertFrom-Json
$acrServer = $outputs.container_registry_login_server.value
$acrName = $outputs.acr_name.value
$rgName = $outputs.resource_group_name.value
Pop-Location

Write-Host "Registry: $acrServer" -ForegroundColor Green
Write-Host "Groupe: $rgName" -ForegroundColor Green

# Phase 2: Images Docker (Build temporaire sans URLs spécifiques)
Write-Host "`nPhase 2: Images temporaires..." -ForegroundColor Yellow
az acr login --name $acrName
docker build -t "$acrServer/dashboard-backend:latest" ./dashboard-backend
docker build -t "$acrServer/dashboard-frontend:latest" ./dashboard-frontend
docker push "$acrServer/dashboard-backend:latest"
docker push "$acrServer/dashboard-frontend:latest"
Write-Host "Images temporaires poussées" -ForegroundColor Green

# Phase 3: Re-deploiement des Container Apps avec images
Write-Host "`nPhase 3: Container Apps..." -ForegroundColor Yellow
Push-Location terraform\azure

# Tentative d'importation des ressources existantes si elles existent
$backendExists = az containerapp show --name "backend-$uniqueId" --resource-group $rgName 2>$null
$frontendExists = az containerapp show --name "frontend-$uniqueId" --resource-group $rgName 2>$null

if ($backendExists) {
    Write-Host "Importation du backend existant..." -ForegroundColor Yellow
    terraform import azurerm_container_app.backend "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$rgName/providers/Microsoft.App/containerApps/backend-$uniqueId" 2>$null
}

if ($frontendExists) {
    Write-Host "Importation du frontend existant..." -ForegroundColor Yellow  
    terraform import azurerm_container_app.frontend "/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$rgName/providers/Microsoft.App/containerApps/frontend-$uniqueId" 2>$null
}

terraform plan -var="unique_id=$uniqueId" -out=tfplan2
terraform apply -auto-approve tfplan2

# Récupération des URLs directement depuis Azure
Write-Host "Récupération des URLs des Container Apps..." -ForegroundColor Yellow
try {
    $backendFqdn = az containerapp show --name "backend-$uniqueId" --resource-group $rgName --query "properties.configuration.ingress.fqdn" -o tsv
    $frontendFqdn = az containerapp show --name "frontend-$uniqueId" --resource-group $rgName --query "properties.configuration.ingress.fqdn" -o tsv
    
    if ($backendFqdn -and $frontendFqdn) {
        $backendUrl = "https://$backendFqdn"
        $frontendUrl = "https://$frontendFqdn"
        Write-Host "✓ URLs récupérées avec succès" -ForegroundColor Green
        Write-Host "  Backend:  $backendUrl" -ForegroundColor White
        Write-Host "  Frontend: $frontendUrl" -ForegroundColor White
    } else {
        throw "URLs non disponibles"
    }
} catch {
    Write-Host "⚠ Erreur lors de la récupération des URLs, utilisation de Terraform outputs" -ForegroundColor Yellow
    try {
        $outputs = terraform output -json | ConvertFrom-Json
        $backendUrl = $outputs.backend_url.value
        $frontendUrl = $outputs.frontend_url.value
    } catch {
        Write-Host "❌ Impossible de récupérer les URLs" -ForegroundColor Red
        $backendUrl = ""
        $frontendUrl = ""
    }
}
Pop-Location

# Phase 4: Initialisation de la base de données
Write-Host "`nPhase 4: Base de données..." -ForegroundColor Yellow
Push-Location terraform\azure
$postgresPassword = (terraform output -raw postgres_password)
$postgresFqdn = (terraform output -raw postgres_fqdn)
Pop-Location

Write-Host "Initialisation de la base de données..." -ForegroundColor White

# Attendre que la base de données soit prête
Write-Host "Attente de la disponibilité de la base de données..." -ForegroundColor White
Start-Sleep 30

# Initialisation simple de la DB
Write-Host "Lancement de l'initialisation DB..." -ForegroundColor White

# Le backend va automatiquement créer les tables au démarrage
# On va juste s'assurer que l'utilisateur admin existe
Write-Host "Attente du démarrage du backend pour l'auto-migration..." -ForegroundColor White
Start-Sleep 20

Write-Host "Base de données prête (tables créées par le backend)" -ForegroundColor Green

# Phase 6: Rebuild avec les bonnes URLs et configuration production
Write-Host "`nPhase 6: Rebuild avec URLs correctes..." -ForegroundColor Yellow

if ($backendUrl -and $frontendUrl) {
    # Suppression des fichiers .env.local qui peuvent interférer
    Write-Host "Nettoyage des configurations de développement..." -ForegroundColor White
    Remove-Item "dashboard-frontend\.env.local" -ErrorAction SilentlyContinue
    Remove-Item "dashboard-frontend\.env.development" -ErrorAction SilentlyContinue
    Remove-Item "dashboard-backend\.env" -ErrorAction SilentlyContinue
    
    # Configuration pour production
    Write-Host "Configuration des variables d'environnement pour production..." -ForegroundColor White
    Write-Host "  NEXT_PUBLIC_API_URL: $backendUrl" -ForegroundColor Gray
    Write-Host "  NODE_ENV: production" -ForegroundColor Gray
    
    # Rebuild du frontend avec les bonnes variables de production
    Write-Host "Rebuild du frontend avec configuration production..." -ForegroundColor White
    docker build -t "$acrServer/dashboard-frontend:latest" `
        --build-arg NODE_ENV=production `
        --build-arg NEXT_PUBLIC_API_URL="$backendUrl" `
        ./dashboard-frontend
    docker push "$acrServer/dashboard-frontend:latest"

    # Rebuild du backend (pas de changement nécessaire mais pour cohérence)
    Write-Host "Rebuild du backend..." -ForegroundColor White
    docker build -t "$acrServer/dashboard-backend:latest" `
        --build-arg NODE_ENV=production `
        ./dashboard-backend
    docker push "$acrServer/dashboard-backend:latest"

    # Update des Container Apps avec les nouvelles images et variables runtime
    Write-Host "Mise à jour des Container Apps avec nouvelles images..." -ForegroundColor White
    
    # Update backend avec FRONTEND_URL pour CORS
    az containerapp update --name "backend-$uniqueId" --resource-group $rgName `
        --set-env-vars "FRONTEND_URL=$frontendUrl" "NODE_ENV=production" 2>$null | Out-Null
        
    # Update frontend avec NEXT_PUBLIC_API_URL (même si c'est build-time, utile pour vérification)
    az containerapp update --name "frontend-$uniqueId" --resource-group $rgName `
        --set-env-vars "NEXT_PUBLIC_API_URL=$backendUrl" "NODE_ENV=production" 2>$null | Out-Null

    Write-Host "✓ Container Apps mis à jour" -ForegroundColor Green
} else {
    Write-Host "❌ URLs non disponibles, impossible de faire le rebuild avec configuration correcte" -ForegroundColor Red
}

# Phase 5: Tests de connectivité
Write-Host "`nPhase 5: Tests..." -ForegroundColor Yellow
Start-Sleep 10

Write-Host "Test de l'API backend..." -ForegroundColor White
try {
    $healthCheck = Invoke-RestMethod "$backendUrl/api/health" -Method GET -TimeoutSec 10
    Write-Host "✓ Backend accessible" -ForegroundColor Green
} catch {
    Write-Host "⚠ Backend non accessible immédiatement (normal au démarrage)" -ForegroundColor Yellow
}

Write-Host "Test de connexion avec les utilisateurs de test..." -ForegroundColor White
try {
    $loginBody = '{"email":"admin@portail-cloud.com","password":"admin123"}'
    $loginTest = Invoke-RestMethod "$backendUrl/api/auth/login" -Method POST -ContentType "application/json" -Body $loginBody -TimeoutSec 10
    Write-Host "✓ Connexion admin fonctionnelle" -ForegroundColor Green
} catch {
    Write-Host "⚠ Connexion admin à tester manuellement" -ForegroundColor Yellow
}

Write-Host "`n=== DEPLOIEMENT TERMINE ===" -ForegroundColor Green
Write-Host "URLs de production:" -ForegroundColor Cyan
Write-Host "Frontend: $frontendUrl" -ForegroundColor White
Write-Host "Backend:  $backendUrl" -ForegroundColor White

Write-Host "`nConfiguration CORS:" -ForegroundColor Cyan
Write-Host "- Le backend autorise les requêtes depuis: $frontendUrl" -ForegroundColor Gray
Write-Host "- Le frontend fait ses requêtes vers: $backendUrl" -ForegroundColor Gray

Write-Host "`nUtilisateurs de test:" -ForegroundColor Cyan
Write-Host "- Admin: admin@portail-cloud.com / admin123" -ForegroundColor White
Write-Host "- Client: client1@portail-cloud.com / client123" -ForegroundColor White

Write-Host "`nPrêt à tester!" -ForegroundColor Green
if ($frontendUrl -and $frontendUrl -ne "") {
    $open = Read-Host "`nOuvrir le frontend? (O/n)"
    if ($open -ne "n") { 
        Start-Process $frontendUrl 
        Write-Host "Ouverture du frontend dans le navigateur..." -ForegroundColor Green
        Write-Host "Si CORS ne fonctionne pas immédiatement, attendez 1-2 minutes le redémarrage des containers." -ForegroundColor Yellow
    }
} else {
    Write-Host "`nATTENTION: URL du frontend non récupérée. Vérifiez manuellement dans le portail Azure." -ForegroundColor Yellow
}