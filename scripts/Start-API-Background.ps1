# Script para iniciar a shp-mgmt-api em background

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          INICIANDO SHP-MGMT-API (BACKGROUND)                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$apiPath = Join-Path (Split-Path -Parent $PSScriptRoot) "api"

# Verificar se Node.js esta instalado
try {
    $nodeVersion = node --version 2>$null
    Write-Host "✅ Node.js detectado: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale Node.js de: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Verificar se dependencias estao instaladas
if (-not (Test-Path (Join-Path $apiPath "node_modules"))) {
    Write-Host "📦 Instalando dependências..." -ForegroundColor Yellow
    Push-Location $apiPath
    npm install --silent
    Pop-Location
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao instalar dependências" -ForegroundColor Red
        exit 1
    }
}

# Parar servidor existente (se houver)
Get-Job | Where-Object { $_.Name -like "*SHP-MGMT-API*" } | ForEach-Object {
    Write-Host "🛑 Parando servidor anterior (Job ID: $($_.Id))..." -ForegroundColor Yellow
    Stop-Job $_.Id -ErrorAction SilentlyContinue
    Remove-Job $_.Id -ErrorAction SilentlyContinue
}

# Verificar se porta 3001 está em uso
$portInUse = Get-NetTCPConnection -LocalPort 3001 -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    Write-Host "⚠️  Porta 3001 já está em uso!" -ForegroundColor Yellow
    $process = Get-Process -Id $portInUse.OwningProcess -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "   Processo: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
        Write-Host "❌ Libere a porta 3001 antes de iniciar a API." -ForegroundColor Red
        exit 1
    }
}

# Iniciar servidor em background
Write-Host ""
Write-Host "🚀 Iniciando servidor em background..." -ForegroundColor Cyan

$job = Start-Job -Name "SHP-MGMT-API-Server" -ScriptBlock {
    param($apiPath)
    Set-Location $apiPath
    npm run start:lts
} -ArgumentList $apiPath

Start-Sleep -Seconds 3

# Verificar se servidor iniciou corretamente
$jobState = Get-Job -Id $job.Id
if ($jobState.State -eq "Running") {
    Write-Host "✅ Servidor iniciado com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Informações do Servidor:" -ForegroundColor Cyan
    Write-Host "   • Job ID: $($job.Id)" -ForegroundColor White
    Write-Host "   • URL: http://localhost:3001" -ForegroundColor White
    Write-Host "   • Dashboard: http://localhost:3001/web/index.html" -ForegroundColor White
    Write-Host ""

    # Testar conectividade
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 5 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Health check: OK" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️  Health check falhou (servidor pode ainda estar iniciando)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "📋 Comandos úteis:" -ForegroundColor Cyan
    Write-Host "   • Ver logs:    Receive-Job -Id $($job.Id) -Keep" -ForegroundColor Gray
    Write-Host "   • Parar:       Stop-Job -Id $($job.Id); Remove-Job -Id $($job.Id)" -ForegroundColor Gray
    Write-Host "   • Listar jobs: Get-Job" -ForegroundColor Gray
    Write-Host ""

    Start-Process "http://localhost:3001/web/index.html"
    Write-Host "✅ Navegador aberto!" -ForegroundColor Green

} else {
    Write-Host "❌ Erro ao iniciar servidor!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Logs do erro:" -ForegroundColor Yellow
    Receive-Job -Id $job.Id
    Remove-Job -Id $job.Id
    exit 1
}

Write-Host ""
Write-Host "💡 Dica: O servidor continuará rodando em background mesmo se você fechar este terminal." -ForegroundColor Cyan
Write-Host ""
