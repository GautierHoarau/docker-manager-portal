# Container Management Platform - Fast Start
Write-Host "🚀 Container Management Platform" -ForegroundColor Green

# Démarrage rapide avec cache
Write-Host "Starting services (using cache)..." -ForegroundColor Yellow
docker-compose up -d

Write-Host "`n✅ Ready!" -ForegroundColor Green
Write-Host "📱 Web: http://localhost:3000" -ForegroundColor Cyan
Write-Host "🔧 API: http://localhost:5000" -ForegroundColor Cyan
Write-Host "`nLogin: admin/admin123 or client1/client123" -ForegroundColor White