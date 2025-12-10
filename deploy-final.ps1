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

# Phase 2: Images Docker
Write-Host "`nPhase 2: Images..." -ForegroundColor Yellow
az acr login --name $acrName
docker build -t "$acrServer/dashboard-backend:latest" ./dashboard-backend
docker build -t "$acrServer/dashboard-frontend:latest" ./dashboard-frontend
docker push "$acrServer/dashboard-backend:latest"
docker push "$acrServer/dashboard-frontend:latest"
Write-Host "Images OK" -ForegroundColor Green

# Phase 3: Re-deploiement des Container Apps avec images
Write-Host "`nPhase 3: Container Apps..." -ForegroundColor Yellow
Push-Location terraform\azure
terraform plan -var="unique_id=$uniqueId" -out=tfplan2
terraform apply -auto-approve tfplan2

$outputs = terraform output -json | ConvertFrom-Json
$backendUrl = $outputs.backend_url.value
$frontendUrl = $outputs.frontend_url.value
Pop-Location

# Configuration finale
Write-Host "`nConfiguration URLs..." -ForegroundColor Yellow
az containerapp update --name "backend-$uniqueId" --resource-group $rgName --set-env-vars "FRONTEND_URL=$frontendUrl"
az containerapp update --name "frontend-$uniqueId" --resource-group $rgName --set-env-vars "NEXT_PUBLIC_API_URL=$backendUrl"

Write-Host "`n=== DEPLOIEMENT TERMINE ===" -ForegroundColor Green
Write-Host "Frontend: $frontendUrl" -ForegroundColor White
Write-Host "Backend:  $backendUrl" -ForegroundColor White

$open = Read-Host "`nOuvrir? (O/n)"
if ($open -ne 'n') { Start-Process $frontendUrl }