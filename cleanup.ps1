param([switch]$Force)

$ErrorActionPreference = "Stop"

Write-Host "=== NETTOYAGE COMPLET PORTAIL CLOUD ===" -ForegroundColor Red

# Connexion et generation de l'ID unique
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Connexion a Azure requise..." -ForegroundColor Yellow
    az login
    $account = az account show --output json | ConvertFrom-Json
}

$uniqueId = ($account.user.name -replace '[^a-zA-Z0-9]', '').ToLower().Substring(0, 8)
Write-Host "ID unique detecte: $uniqueId" -ForegroundColor Green

# Noms des ressources bases sur l'ID unique
$rgName = "rg-container-manager-$uniqueId"
$acrName = "acr$uniqueId"

Write-Host "`nRessources a supprimer:" -ForegroundColor Yellow
Write-Host "- Resource Group: $rgName" -ForegroundColor White
Write-Host "- Container Registry: $acrName" -ForegroundColor White
Write-Host "- Tous les Container Apps associes" -ForegroundColor White
Write-Host "- Base de donnees PostgreSQL" -ForegroundColor White
Write-Host "- Images Docker locales" -ForegroundColor White
Write-Host "- Etat Terraform" -ForegroundColor White

if (-not $Force) {
    $confirm = Read-Host "`nEtes-vous sur de vouloir tout supprimer? (oui/non)"
    if ($confirm -ne "oui") {
        Write-Host "Annulation du nettoyage." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "`n=== DEBUT DU NETTOYAGE ===" -ForegroundColor Red

# 1. Suppression du Resource Group
Write-Host "`n1. Suppression du Resource Group..." -ForegroundColor Yellow
try {
    $rgExists = az group exists --name $rgName --output tsv
    if ($rgExists -eq "true") {
        Write-Host "Suppression en cours de $rgName..." -ForegroundColor White
        az group delete --name $rgName --yes --no-wait
        
        # Attendre la suppression complete
        Write-Host "Attente de la suppression complete (peut prendre plusieurs minutes)..." -ForegroundColor White
        do {
            Start-Sleep 30
            $rgExists = az group exists --name $rgName --output tsv 2>$null
            Write-Host "." -NoNewline -ForegroundColor Gray
        } while ($rgExists -eq "true")
        Write-Host ""
        Write-Host "Resource Group supprime avec succes." -ForegroundColor Green
    } else {
        Write-Host "Resource Group n'existe pas." -ForegroundColor Gray
    }
} catch {
    Write-Host "Erreur lors de la suppression du Resource Group: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Nettoyage des images Docker locales
Write-Host "`n2. Nettoyage des images Docker locales..." -ForegroundColor Yellow
try {
    # Supprimer les images specifiques du projet
    $images = @(
        "$acrName.azurecr.io/dashboard-backend:latest",
        "$acrName.azurecr.io/dashboard-frontend:latest",
        "dashboard-backend:latest",
        "dashboard-frontend:latest"
    )
    
    foreach ($image in $images) {
        try {
            docker rmi $image --force 2>$null | Out-Null
            Write-Host "Image supprimee: $image" -ForegroundColor Green
        } catch {
            Write-Host "Image non trouvee: $image" -ForegroundColor Gray
        }
    }
    
    # Nettoyage general Docker
    Write-Host "Nettoyage general Docker..." -ForegroundColor White
    docker system prune -f 2>$null | Out-Null
    Write-Host "Nettoyage Docker termine." -ForegroundColor Green
} catch {
    Write-Host "Erreur lors du nettoyage Docker: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Nettoyage de l'etat Terraform
Write-Host "`n3. Nettoyage de l'etat Terraform..." -ForegroundColor Yellow
try {
    Push-Location "terraform\azure"
    
    # Supprimer tous les fichiers d'etat et de cache Terraform
    $terraformFiles = @(
        ".terraform",
        ".terraform.lock.hcl",
        "terraform.tfstate",
        "terraform.tfstate.backup",
        "tfplan",
        "tfplan2"
    )
    
    foreach ($file in $terraformFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Supprime: $file" -ForegroundColor Green
        }
    }
    
    Pop-Location
    Write-Host "Etat Terraform nettoye." -ForegroundColor Green
} catch {
    Pop-Location
    Write-Host "Erreur lors du nettoyage Terraform: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Verification finale
Write-Host "`n4. Verification finale..." -ForegroundColor Yellow
try {
    $rgExists = az group exists --name $rgName --output tsv 2>$null
    if ($rgExists -eq "false") {
        Write-Host "Resource Group supprime" -ForegroundColor Green
    } else {
        Write-Host "Resource Group existe encore (suppression en cours)" -ForegroundColor Yellow
    }
    
    if (-not (Test-Path "terraform\azure\.terraform")) {
        Write-Host "Etat Terraform nettoye" -ForegroundColor Green
    }
    
    Write-Host "Nettoyage termine" -ForegroundColor Green
} catch {
    Write-Host "Erreur lors de la verification: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== NETTOYAGE TERMINE ===" -ForegroundColor Green
Write-Host "L'environnement est maintenant propre et pret pour un nouveau deploiement." -ForegroundColor White
Write-Host "`nPour redeployer, utilisez: .\deploy-final.ps1" -ForegroundColor Cyan