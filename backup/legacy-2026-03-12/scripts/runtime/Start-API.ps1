<#
.SYNOPSIS
    Inicia a API CVE Management

.DESCRIPTION
    Carrega configuração, verifica dependências Node.js e inicia o servidor Express na porta configurada

.EXAMPLE
    & .\Start-API.ps1

.NOTES
    Versão: 2.0
    Data: Janeiro 2026
    Usa: cves/config/config.json
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CARREGAR CONFIGURAÇÃO
# ============================================================================

$Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')

$apiPath = $Config.Paths.Api
$apiPort = $Config.Api.Port
$apiHost = $Config.Api.Host

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

# ============================================================================
# MAIN
# ============================================================================

Clear-Host

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         INICIANDO CVE MANAGEMENT API                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar Node.js
Write-ColoredMessage "Verificando dependências..." -Type Info

try {
    $nodeVersion = node --version
    Write-ColoredMessage "Node.js detectado: $nodeVersion" -Type Success
} catch {
    Write-ColoredMessage "Node.js não encontrado!" -Type Error
    Write-Host ""
    Write-Host "Instale Node.js em: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Verificar se node_modules existe
$nodeModulesPath = Join-Path $apiPath "node_modules"
if (-not (Test-Path $nodeModulesPath)) {
    Write-ColoredMessage "Instalando dependências Node.js..." -Type Warning
    Write-Host ""

    Push-Location $apiPath
    try {
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-ColoredMessage "Erro ao instalar dependências" -Type Error
            exit 1
        }
    }
    finally {
        Pop-Location
    }

    Write-Host ""
}

# Criar arquivo .env se não existir
$envFile = Join-Path $apiPath ".env"
if (-not (Test-Path $envFile)) {
    Write-ColoredMessage "Criando arquivo .env..." -Type Warning
    $envExample = Join-Path $apiPath ".env.example"

    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
    } else {
        # Criar um mínimo
        @"
NODE_ENV=development
PORT=$($Config.Api.Port)
HOST=$($Config.Api.Host)
"@ | Set-Content $envFile
    }
}

# Iniciar servidor
Write-Host ""
Write-ColoredMessage "Iniciando servidor da API..." -Type Info
Write-Host ""
Write-Host "Host:       $apiHost" -ForegroundColor Gray
Write-Host "Porta:      $apiPort" -ForegroundColor Gray
Write-Host "URL:        http://$apiHost`:$apiPort" -ForegroundColor Gray
Write-Host "Diretório:  $apiPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Para parar o servidor, pressione Ctrl+C" -ForegroundColor Yellow
Write-Host ""

Push-Location $apiPath
try {
    npm start
}
finally {
    Pop-Location
}
