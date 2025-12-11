#!/usr/bin/env pwsh

# Script de validation pour l'intégration Azure Container Apps réelle
Write-Host "=== VALIDATION AZURE CONTAINER APPS INTEGRATION ===" -ForegroundColor Green
Write-Host ""

# Configuration
$BackendUrl = "https://backend-bastienr.delightfulflower-c37029b5.francecentral.azurecontainerapps.io"
$FrontendUrl = "https://frontend-bastienr.delightfulflower-c37029b5.francecentral.azurecontainerapps.io"

Write-Host "1. Testing Backend Health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "$BackendUrl/api/health" -Method Get -TimeoutSec 10
    if ($healthResponse.success) {
        Write-Host "   ✓ Backend is healthy" -ForegroundColor Green
        Write-Host "   Environment: $($healthResponse.data.environment)" -ForegroundColor Cyan
        Write-Host "   Uptime: $([math]::Round($healthResponse.data.uptime, 2)) seconds" -ForegroundColor Cyan
    } else {
        Write-Host "   ✗ Backend health check failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   ✗ Cannot connect to backend: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Testing Frontend Availability..." -ForegroundColor Yellow
try {
    $frontendResponse = Invoke-WebRequest -Uri $FrontendUrl -Method Head -TimeoutSec 10
    if ($frontendResponse.StatusCode -eq 200) {
        Write-Host "   ✓ Frontend is accessible" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Frontend returned status: $($frontendResponse.StatusCode)" -ForegroundColor Red
    }
} catch {
    Write-Host "   ✗ Cannot connect to frontend: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Testing Container API Endpoint..." -ForegroundColor Yellow
try {
    $containersResponse = Invoke-RestMethod -Uri "$BackendUrl/api/containers" -Method Get -TimeoutSec 10
    Write-Host "   ✓ Container API is responding" -ForegroundColor Green
    $responseMsg = if ($containersResponse.error) { $containersResponse.error } elseif ($containersResponse.message) { $containersResponse.message } else { "Success" }
    Write-Host "   Response: $responseMsg" -ForegroundColor Cyan
} catch {
    Write-Host "   ✗ Container API error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Application URLs:" -ForegroundColor Yellow
Write-Host "   Frontend: $FrontendUrl" -ForegroundColor Cyan
Write-Host "   Backend:  $BackendUrl" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Magenta
Write-Host "1. Configure Azure CLI authentication in the backend container"
Write-Host "2. Set up managed identity or service principal permissions"
Write-Host "3. Test container creation via the frontend dashboard"
Write-Host "4. Verify real Azure Container Apps are created in the resource group"

Write-Host ""
Write-Host "=== VALIDATION COMPLETE ===" -ForegroundColor Green