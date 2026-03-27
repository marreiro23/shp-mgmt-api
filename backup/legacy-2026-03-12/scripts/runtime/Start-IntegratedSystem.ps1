<#
.SYNOPSIS
    Inicializa o sistema integrado CVE Management (API + Interface Web)

.DESCRIPTION
    Script para iniciar o servidor da API Node.js e abrir o navegador com a interface web integrada.
    Verifica dependências, inicia o servidor e fornece URLs de acesso.

    Usa configurações centralizadas de cves/config/config.json via Get-ProjectConfig.ps1

.EXAMPLE
    .\Start-IntegratedSystem.ps1

.NOTES
    Autor: CVE Management System
    Versão: 2.1.0
    Data: Janeiro 2026
    Configuração: cves/config/config.json
#>

[CmdletBinding()]
param()

# ============================================================================
# INICIALIZAÇÃO - CARREGAR CONFIGURAÇÃO
# ============================================================================

$ErrorActionPreference = 'Stop'

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
    Write-Verbose "Configuração carregada de: $(Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')"
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

# ============================================================================
# VARIÁVEIS DO SISTEMA
# ============================================================================

$apiPath = $Config.Paths.Api
$apiPort = $Config.Api.Port
$apiHost = $Config.Api.Host
$apiUrl = "http://${apiHost}:${apiPort}"

Write-Verbose "API Path: $apiPath"
Write-Verbose "API URL: $apiUrl"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

function Write-ColoredMessage {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }

    $icons = @{
        'Info'    = 'ℹ️'
        'Success' = '✅'
        'Warning' = '⚠️'
        'Error'   = '❌'
    }

    Write-Host "$($icons[$Type]) " -NoNewline -ForegroundColor $colors[$Type]
    Write-Host $Message -ForegroundColor $colors[$Type]
}

function Test-NodeInstalled {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-ColoredMessage "Node.js detectado: $nodeVersion" -Type Success
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Test-ApiRunning {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -Uri "$Url/health" -Method Get -TimeoutSec 2 -UseBasicParsing
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================

Clear-Host

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     CVE MANAGEMENT SYSTEM - INICIALIZAÇÃO INTEGRADA            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar Node.js
Write-ColoredMessage "Verificando dependências..." -Type Info

if (-not (Test-NodeInstalled)) {
    Write-ColoredMessage "Node.js não está instalado!" -Type Error
    Write-Host ""
    Write-Host "Instale o Node.js em: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Verificar se o diretório da API existe
if (-not (Test-Path $apiPath)) {
    Write-ColoredMessage "Diretório da API não encontrado: $apiPath" -Type Error
    exit 1
}

# Verificar se package.json existe
$packageJsonPath = Join-Path $apiPath "package.json"
if (-not (Test-Path $packageJsonPath)) {
    Write-ColoredMessage "package.json não encontrado!" -Type Error
    exit 1
}

# Verificar se node_modules existe
$nodeModulesPath = Join-Path $apiPath "node_modules"
if (-not (Test-Path $nodeModulesPath)) {
    Write-ColoredMessage "Dependências não instaladas. Executando npm install..." -Type Warning
    Write-Host ""

    Push-Location $apiPath
    try {
        npm install
        Write-Host ""
        Write-ColoredMessage "Dependências instaladas com sucesso!" -Type Success
    }
    catch {
        Write-ColoredMessage "Erro ao instalar dependências: $_" -Type Error
        Pop-Location
        exit 1
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-ColoredMessage "Iniciando servidor da API..." -Type Info
Write-Host ""

# Verificar se a API já está rodando
if (Test-ApiRunning -Url $apiUrl) {
    Write-ColoredMessage "API já está rodando em $apiUrl" -Type Warning
    Write-Host ""

    $openBrowser = Read-Host "Deseja abrir o navegador mesmo assim? (S/N)"
    if ($openBrowser -eq 'S' -or $openBrowser -eq 's') {
        Start-Process "$apiUrl/web/index.html"
    }

    exit 0
}

# Iniciar a API em background
Push-Location $apiPath

Write-Host "Iniciando servidor Node.js..." -ForegroundColor Cyan
Write-Host "Porta: $apiPort" -ForegroundColor Cyan
Write-Host "Host: $apiHost" -ForegroundColor Cyan
Write-Host ""

# Criar job para iniciar o servidor
$job = Start-Job -ScriptBlock {
    param($ApiPath)
    Set-Location $ApiPath
    node server.js
} -ArgumentList $apiPath

Write-ColoredMessage "Servidor iniciado em background (Job ID: $($job.Id))" -Type Success

# Aguardar alguns segundos para o servidor inicializar
Write-Host ""
Write-Host "Aguardando inicialização do servidor..." -ForegroundColor Yellow

for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    Write-Host " ✓" -ForegroundColor Green
}

Write-Host ""

# Verificar se a API está respondendo
Write-ColoredMessage "Verificando conexão com a API..." -Type Info

$maxRetries = 5
$retryCount = 0
$apiOnline = $false

while ($retryCount -lt $maxRetries -and -not $apiOnline) {
    $apiOnline = Test-ApiRunning -Url $apiUrl

    if (-not $apiOnline) {
        Write-Host "  Tentativa $($retryCount + 1)/$maxRetries..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        $retryCount++
    }
}

Write-Host ""

if ($apiOnline) {
    Write-ColoredMessage "API está online e respondendo!" -Type Success
}
else {
    Write-ColoredMessage "API não está respondendo após $maxRetries tentativas" -Type Warning
    Write-ColoredMessage "Verifique os logs do Job ID: $($job.Id)" -Type Info
    Write-Host ""
    Write-Host "Para ver os logs: " -NoNewline
    Write-Host "Receive-Job -Id $($job.Id) -Keep" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    SISTEMA INICIALIZADO                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "🌐 URLs de Acesso:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Dashboard:        " -NoNewline
Write-Host "$apiUrl/web/index.html" -ForegroundColor Yellow
Write-Host "   Aplicações:       " -NoNewline
Write-Host "$apiUrl/web/applications.html" -ForegroundColor Yellow
Write-Host "   Dispositivos:     " -NoNewline
Write-Host "$apiUrl/web/devices.html" -ForegroundColor Yellow
Write-Host "   Queries SCCM:     " -NoNewline
Write-Host "$apiUrl/web/queries.html" -ForegroundColor Yellow
Write-Host "   Remediação PSADT: " -NoNewline
Write-Host "$apiUrl/web/remediation.html" -ForegroundColor Yellow
Write-Host "   Importar Tenable: " -NoNewline
Write-Host "$apiUrl/web/import-tenable.html" -ForegroundColor Yellow
Write-Host "   Relatórios:       " -NoNewline
Write-Host "$apiUrl/web/reports-integrated.html" -ForegroundColor Yellow
Write-Host "   Testar API:       " -NoNewline
Write-Host "$apiUrl/web/test-api.html" -ForegroundColor Yellow
Write-Host ""
Write-Host "   API Health:       " -NoNewline
Write-Host "$apiUrl/health" -ForegroundColor Yellow
Write-Host "   API Docs:         " -NoNewline
Write-Host "$apiUrl/" -ForegroundColor Yellow
Write-Host ""

Write-Host "⚙️  Recursos Automáticos:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   🔄 Auto-refresh a cada 5 minutos" -ForegroundColor Gray
Write-Host "   🛑 Shutdown automático ao fechar navegador" -ForegroundColor Gray
Write-Host "   📊 Dados carregados dinamicamente via API" -ForegroundColor Gray
Write-Host ""

Write-Host "🔧 Comandos Úteis:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Ver logs:         " -NoNewline
Write-Host "Receive-Job -Id $($job.Id) -Keep" -ForegroundColor Yellow
Write-Host "   Parar servidor:   " -NoNewline
Write-Host "Stop-Job -Id $($job.Id); Remove-Job -Id $($job.Id)" -ForegroundColor Yellow
Write-Host ""

# Abrir navegador automaticamente
$openBrowser = Read-Host "Deseja abrir o dashboard no navegador? (S/N)"

if ($openBrowser -eq 'S' -or $openBrowser -eq 's') {
    Write-ColoredMessage "Abrindo navegador..." -Type Info
    Start-Process "$apiUrl/web/index.html"
}

Write-Host ""
Write-Host "Pressione qualquer tecla para ver os logs da API (Ctrl+C para sair)..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                        LOGS DA API                             " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Mostrar logs em tempo real
try {
    while ($true) {
        $output = Receive-Job -Id $job.Id
        if ($output) {
            Write-Host $output
        }
        Start-Sleep -Milliseconds 500
    }
}
catch {
    Write-Host ""
    Write-ColoredMessage "Logs encerrados" -Type Info
}
finally {
    Pop-Location
}

Pop-Location
