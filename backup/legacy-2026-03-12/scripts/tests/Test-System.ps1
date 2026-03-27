<#
.SYNOPSIS
    Script de teste do sistema CVE Management integrado

.DESCRIPTION
    Testa todas as funcionalidades do sistema incluindo:
    - Estrutura de arquivos
    - Servidor Node.js
    - Shutdown automático
    - Endpoints da API

    Usa configurações centralizadas de cves/config/config.json

.EXAMPLE
    .\Test-System.ps1

.NOTES
    Versão: 2.0
    Data: Janeiro 2026
    Configuração: cves/config/config.json
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# ============================================================================
# CARREGAR CONFIGURAÇÃO
# ============================================================================

try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

# ============================================================================
# FUNÇÕES
# ============================================================================

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Message = ""
    )

    $icon = if ($Passed) { "✅" } else { "❌" }
    $color = if ($Passed) { "Green" } else { "Red" }

    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$Test " -NoNewline

    if ($Message) {
        Write-Host "- $Message" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
}

# ============================================================================
# TESTES
# ============================================================================

Clear-Host

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           TESTES DO SISTEMA - CVE MANAGEMENT v2.0             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuração:" -ForegroundColor Cyan
Write-Host "  • API Host: $($Config.Api.Host)" -ForegroundColor Gray
Write-Host "  • API Port: $($Config.Api.Port)" -ForegroundColor Gray
Write-Host "  • SCCM Server: $($Config.SCCM.Server)" -ForegroundColor Gray
Write-Host "  • SCCM Database: $($Config.SCCM.Database)" -ForegroundColor Gray
Write-Host ""

Write-Host "TESTE 1: Estrutura de Arquivos" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

$testsPassed = 0
$testsFailed = 0

# Testes de pasta
$folders = @(
    @{ Path = $Config.Paths.Api; Name = "Diretório API" }
    @{ Path = $Config.Paths.Web; Name = "Diretório Web" }
    @{ Path = $Config.Paths.Scripts; Name = "Diretório Scripts" }
    @{ Path = $Config.Paths.Config; Name = "Diretório Config" }
)

foreach ($folder in $folders) {
    $exists = Test-Path $folder.Path
    Write-TestResult $folder.Name $exists $(if ($exists) { $folder.Path } else { "Não encontrado" })
    if ($exists) { $testsPassed++ } else { $testsFailed++ }
}

# Testes de arquivo
$files = @(
    @{ Path = (Join-Path $Config.Paths.Config "config.json"); Name = "config.json" }
    @{ Path = (Join-Path $Config.Paths.Api "server.js"); Name = "API server.js" }
    @{ Path = (Join-Path $Config.Paths.Api "package.json"); Name = "package.json" }
    @{ Path = (Join-Path $Config.Paths.Web "index.html"); Name = "Web index.html" }
)

foreach ($file in $files) {
    $exists = Test-Path $file.Path
    Write-TestResult $file.Name $exists
    if ($exists) { $testsPassed++ } else { $testsFailed++ }
}

Write-Host ""
Write-Host "Resultado: $testsPassed OK, $testsFailed FALHAS" -ForegroundColor Cyan
Write-Host ""

Write-Host "TESTE 2: Servidor Node.js" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

try {
    $nodeVersion = node --version
    Write-TestResult "Node.js instalado" $true $nodeVersion
    $testsPassed++
}
catch {
    Write-TestResult "Node.js instalado" $false "Não encontrado"
    $testsFailed++
}

try {
    $npmVersion = npm --version
    Write-TestResult "npm instalado" $true $npmVersion
    $testsPassed++
}
catch {
    Write-TestResult "npm instalado" $false "Não encontrado"
    $testsFailed++
}

$nodeModules = Join-Path $Config.Paths.Api "node_modules"
$hasModules = Test-Path $nodeModules
Write-TestResult "node_modules instalado" $hasModules
if ($hasModules) { $testsPassed++ } else { $testsFailed++ }

Write-Host ""

Write-Host "TESTE 3: Conectividade API" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

$apiUrl = "http://$($Config.Api.Host):$($Config.Api.Port)"

try {
    $health = Invoke-WebRequest -Uri "$apiUrl/health" -Method Get -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    Write-TestResult "API Health Check" $true "OK (HTTP 200)"
    $testsPassed++
}
catch {
    Write-TestResult "API Health Check" $false "Falha na conexão"
    $testsFailed++
    Write-Host ""
    Write-Host "  Dica: Inicie a API com .\cves\scripts\runtime\Start-IntegratedSystem.ps1" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "TESTE 4: Conexão SCCM" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

$sccmServer = $Config.SCCM.Server
$sccmDatabase = $Config.SCCM.Database
$sccmPort = $Config.SCCM.Port

try {
    $connectionString = "Server=$sccmServer,$sccmPort;Database=$sccmDatabase;Integrated Security=True;Connection Timeout=$($Config.SCCM.ConnectionTimeout);"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    Write-TestResult "Conexão SCCM" $true "Conectado a $sccmServer"
    $connection.Close()
    $testsPassed++
}
catch {
    Write-TestResult "Conexão SCCM" $false "Falha: $($_.Exception.Message)"
    $testsFailed++
    Write-Host ""
    Write-Host "  Dica: Verifique a configuração em cves/config/config.json" -ForegroundColor Yellow
    Write-Host "  Servidor: $sccmServer" -ForegroundColor Gray
    Write-Host "  Database: $sccmDatabase" -ForegroundColor Gray
    Write-Host "  Port: $sccmPort" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═" * 60 -ForegroundColor Gray
Write-Host "RESUMO:" -ForegroundColor Cyan
Write-Host "  ✅ Testes Passados: $testsPassed" -ForegroundColor Green
Write-Host "  ❌ Testes Falhados: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "Sistema pronto! Acesse: $apiUrl/web/index.html" -ForegroundColor Green
}
else {
    Write-Host "Alguns testes falharam. Verifique as dicas acima." -ForegroundColor Yellow
}

Write-Host ""
