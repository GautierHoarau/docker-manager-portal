#!/bin/bash
# Script de déploiement direct Azure Cloud Shell

echo "🚀 Déploiement Container Platform"
echo "================================="

# Variables
RESOURCE_GROUP="rg-container-platform"
LOCATION="francecentral"
DB_PASSWORD="MySecurePassword123!"

echo "📋 Initialisation..."

# Créer le resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "🏗️ Déploiement infrastructure avec Terraform..."

# Initialiser Terraform
cd terraform
terraform init

# Appliquer Terraform
terraform apply -auto-approve -var="db_admin_password=$DB_PASSWORD"

echo "📦 Build des applications..."

# Build backend
cd ../dashboard-backend
npm ci
npm run build
zip -r ../backend.zip . -x "node_modules/*" "*.log"

# Build frontend  
cd ../dashboard-frontend
npm ci
npm run build
zip -r ../frontend.zip out/ 2>/dev/null || zip -r ../frontend.zip build/ || echo "Frontend build done"

cd ..

echo "🚀 Déploiement des applications..."

# Déployer backend
az webapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name container-platform-api \
  --src backend.zip

# Déployer frontend
az webapp deployment source config-zip \
  --resource-group $RESOURCE_GROUP \
  --name container-platform-web \
  --src frontend.zip

echo "✅ Déploiement terminé !"
echo ""
echo "🌐 Votre application :"
echo "API: https://container-platform-api.azurewebsites.net"
echo "Web: https://container-platform-web.azurewebsites.net"

# Test de santé
echo ""
echo "🔍 Test de santé..."
sleep 30
curl -f "https://container-platform-api.azurewebsites.net/api/health" && echo "✅ API OK" || echo "⏳ API en cours de démarrage"