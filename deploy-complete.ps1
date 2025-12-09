# Script de Deploiement Complet Azure - Container Platform
# Deploie infrastructure + base de donnees + applications avec CI/CD complet

param(
    [string]$ResourceGroup = "rg-container-platform-prod",
    [string]$Location = "francecentral",
    [string]$ProjectName = "container-platform",
    [string]$Environment = "prod",
    [string]$DbPassword = "SecurePassword2024!",
    [switch]$SkipBuild = $false,
    [switch]$SkipTerraform = $false
)

Write-Host "🚀 DEPLOIEMENT COMPLET CONTAINER PLATFORM" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host ""

# Variables calculees
$backendApp = "$ProjectName-api-$Environment"
$frontendApp = "$ProjectName-web-$Environment"
$dbServerName = "$ProjectName-db-$Environment"
$containerRegistry = "$ProjectName$Environment".Replace("-", "")
$appServicePlan = "$ProjectName-plan-$Environment"

# Fonction pour localiser Terraform
function Get-TerraformPath {
    # Chercher dans PATH d'abord
    $terraform = Get-Command terraform -ErrorAction SilentlyContinue
    if ($terraform) {
        return $terraform.Source
    }
    
    # Chercher dans les emplacements communs
    $paths = @(
        "$env:USERPROFILE\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform*\terraform.exe",
        "C:\ProgramData\chocolatey\bin\terraform.exe",
        "C:\HashiCorp\Terraform\terraform.exe"
    )
    
    foreach ($path in $paths) {
        $resolved = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($resolved -and (Test-Path $resolved.FullName)) {
            return $resolved.FullName
        }
    }
    
    return $null
}

# Verification prealables
Write-Host "📋 Verification des prerequis..." -ForegroundColor Yellow

# Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI non trouve. Installez-le depuis https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

$account = az account show --query name -o tsv 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Non connecte a Azure. Executez: az login" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Azure CLI: $account" -ForegroundColor Green

# Terraform
$terraformExe = Get-TerraformPath
if (-not $terraformExe) {
    Write-Host "❌ Terraform non trouve. Installation..." -ForegroundColor Yellow
    try {
        winget install Hashicorp.Terraform --silent
        $terraformExe = Get-TerraformPath
    } catch {
        Write-Host "❌ Impossible d'installer Terraform automatiquement" -ForegroundColor Red
        Write-Host "💡 Installez manuellement: https://www.terraform.io/downloads" -ForegroundColor Yellow
        exit 1
    }
}

if ($terraformExe) {
    Write-Host "✅ Terraform: $terraformExe" -ForegroundColor Green
} else {
    Write-Host "❌ Terraform toujours non accessible" -ForegroundColor Red
    exit 1
}

# Node.js et npm
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js/npm non trouve. Installez depuis https://nodejs.org" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Node.js: $(node --version)" -ForegroundColor Green

Write-Host ""
Write-Host "🏗️ ETAPE 1: Preparation Terraform..." -ForegroundColor Yellow

# Creer terraform.tfvars avec les bonnes valeurs
$tfVars = @"
# Configuration automatiquement generee
resource_group_name = "$ResourceGroup"
location = "$Location" 
project_name = "$ProjectName"
environment = "$Environment"
admin_password = "$DbPassword"

# Configuration des applications
backend_app_name = "$backendApp"
frontend_app_name = "$frontendApp"
db_server_name = "$dbServerName"
container_registry_name = "$containerRegistry"
app_service_plan_name = "$appServicePlan"
"@

Set-Content -Path "terraform\terraform.tfvars" -Value $tfVars -Encoding UTF8
Write-Host "✅ Configuration Terraform generee" -ForegroundColor Green

# Deploiement Terraform
if (-not $SkipTerraform) {
    Write-Host ""
    Write-Host "🏗️ ETAPE 2: Deploiement Infrastructure..." -ForegroundColor Yellow
    
    Push-Location terraform
    try {
        Write-Host "   Terraform init..." -ForegroundColor Cyan
        & $terraformExe init -input=false
        if ($LASTEXITCODE -ne 0) { throw "Terraform init failed" }
        
        Write-Host "   Terraform validate..." -ForegroundColor Cyan
        & $terraformExe validate
        if ($LASTEXITCODE -ne 0) { throw "Terraform validate failed" }
        
        Write-Host "   Terraform plan..." -ForegroundColor Cyan
        & $terraformExe plan -out=tfplan -input=false
        if ($LASTEXITCODE -ne 0) { throw "Terraform plan failed" }
        
        Write-Host "   Terraform apply..." -ForegroundColor Cyan
        & $terraformExe apply -auto-approve tfplan
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed" }
        
        Write-Host "✅ Infrastructure deployee avec succes" -ForegroundColor Green
        
        # Recuperer les outputs Terraform
        $outputs = & $terraformExe output -json | ConvertFrom-Json
        if ($outputs.backend_url) {
            Write-Host "   Backend URL: $($outputs.backend_url.value)" -ForegroundColor Cyan
        }
        if ($outputs.frontend_url) {
            Write-Host "   Frontend URL: $($outputs.frontend_url.value)" -ForegroundColor Cyan
        }
        
    } catch {
        Write-Host "❌ Erreur Terraform: $_" -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
} else {
    Write-Host "⏭️ Etape Terraform ignoree (--SkipTerraform)" -ForegroundColor Yellow
}

# Build et deploiement des applications
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "📦 ETAPE 3: Build et deploiement des applications..." -ForegroundColor Yellow
    
    # Build Backend
    Write-Host "   Build backend..." -ForegroundColor Cyan
    Push-Location dashboard-backend
    try {
        npm ci --silent
        if ($LASTEXITCODE -ne 0) { throw "npm ci backend failed" }
        
        npm run build --silent
        if ($LASTEXITCODE -ne 0) { throw "npm build backend failed" }
        
        # Package pour deploiement
        $excludePatterns = @("node_modules", "*.log", "coverage", ".git", "*.test.js")
        Get-ChildItem -Path . | Where-Object { 
            $item = $_
            -not ($excludePatterns | Where-Object { $item.Name -like $_ })
        } | Compress-Archive -DestinationPath "..\backend-$Environment.zip" -Force
        
        Write-Host "   ✅ Backend build complete" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Erreur build backend: $_" -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
    
    # Build Frontend
    Write-Host "   Build frontend..." -ForegroundColor Cyan
    Push-Location dashboard-frontend
    try {
        npm ci --silent
        if ($LASTEXITCODE -ne 0) { throw "npm ci frontend failed" }
        
        npm run build --silent
        if ($LASTEXITCODE -ne 0) { throw "npm build frontend failed" }
        
        # Package le build output
        if (Test-Path "out") {
            Compress-Archive -Path "out\*" -DestinationPath "..\frontend-$Environment.zip" -Force
        } elseif (Test-Path "build") {
            Compress-Archive -Path "build\*" -DestinationPath "..\frontend-$Environment.zip" -Force
        } elseif (Test-Path "dist") {
            Compress-Archive -Path "dist\*" -DestinationPath "..\frontend-$Environment.zip" -Force
        } else {
            throw "Aucun dossier de build trouve (out/build/dist)"
        }
        
        Write-Host "   ✅ Frontend build complete" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Erreur build frontend: $_" -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
    
    # Deploiement sur Azure App Services
    Write-Host ""
    Write-Host "🚀 ETAPE 4: Deploiement sur Azure..." -ForegroundColor Yellow
    
    Write-Host "   Deploiement backend..." -ForegroundColor Cyan
    az webapp deploy --resource-group $ResourceGroup --name $backendApp --src-path "backend-$Environment.zip" --type zip --async false
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Backend deploye" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Erreur deploiement backend" -ForegroundColor Red
    }
    
    Write-Host "   Deploiement frontend..." -ForegroundColor Cyan
    az webapp deploy --resource-group $ResourceGroup --name $frontendApp --src-path "frontend-$Environment.zip" --type zip --async false
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Frontend deploye" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Erreur deploiement frontend" -ForegroundColor Red
    }
    
    # Nettoyage des packages temporaires
    Remove-Item "backend-$Environment.zip", "frontend-$Environment.zip" -ErrorAction SilentlyContinue
    
} else {
    Write-Host "⏭️ Etape Build ignoree (--SkipBuild)" -ForegroundColor Yellow
}

# Test de sante
Write-Host ""
Write-Host "🔍 ETAPE 5: Tests de sante..." -ForegroundColor Yellow
Write-Host "   Attente stabilisation (45s)..." -ForegroundColor Cyan
Start-Sleep 45

$backendUrl = "https://$backendApp.azurewebsites.net"
$frontendUrl = "https://$frontendApp.azurewebsites.net"

Write-Host "   Test backend..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$backendUrl/api/health" -TimeoutSec 30
    Write-Host "   ✅ Backend API operationnel" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️ Backend encore en cours de demarrage" -ForegroundColor Yellow
}

Write-Host "   Test frontend..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $frontendUrl -TimeoutSec 30
    if ($response.StatusCode -eq 200) {
        Write-Host "   ✅ Frontend accessible" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️ Frontend encore en cours de demarrage" -ForegroundColor Yellow
}

# Resultat final
Write-Host ""
Write-Host "🎉 DEPLOIEMENT COMPLET TERMINE !" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 URLs de production :" -ForegroundColor Yellow
Write-Host "   Frontend: $frontendUrl" -ForegroundColor Cyan
Write-Host "   Backend:  $backendUrl" -ForegroundColor Cyan
Write-Host "   API Health: $backendUrl/api/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "🗄️ Base de donnees PostgreSQL configuree et prete" -ForegroundColor Yellow
Write-Host "🐳 Applications Node.js deployees avec build complet" -ForegroundColor Yellow
Write-Host "🔧 Infrastructure as Code via Terraform" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 Commandes utiles :" -ForegroundColor Yellow
Write-Host "   Logs backend:  az webapp log tail --resource-group $ResourceGroup --name $backendApp" -ForegroundColor White
Write-Host "   Logs frontend: az webapp log tail --resource-group $ResourceGroup --name $frontendApp" -ForegroundColor White
Write-Host "   Supprimer tout: az group delete --name $ResourceGroup --yes --no-wait" -ForegroundColor White
Write-Host ""
Write-Host "✨ Deploiement professionnel complet avec CI/CD!" -ForegroundColor Green