<#
.SYNOPSIS
    Testa a Configuração Consolidada do CVE Management System

.DESCRIPTION
    Script de validação que testa:
    - Endpoint /api/v1/config está respondendo
    - Estrutura da configuração consolidada
    - Valores corretos de APPLICATION, WEB, FEATURES
    - Metadata presente

.EXAMPLE
    .\Test-ConsolidatedConfig.ps1

.NOTES
    Nome do arquivo: Test-ConsolidatedConfig.ps1
    Versão: 1.0.0
    Data: 10 de Janeiro de 2026
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ApiUrl = "http://localhost:3000/api/v1"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    $symbol = if ($Passed) { "✅" } else { "❌" }
    $color = if ($Passed) { "Green" } else { "Red" }
    $status = if ($Passed) { "PASS" } else { "FAIL" }

    Write-Host "  [$status] $symbol $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "        $Message" -ForegroundColor Gray
    }
}

function Test-ConfigEndpoint {
    try {
        $response = Invoke-RestMethod -Uri "$ApiUrl/config" -Method Get -TimeoutSec 5
        return @{
            Success = $true
            Data = $response
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# TESTES
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     TESTE DE CONFIGURAÇÃO CONSOLIDADA - CVE MANAGEMENT        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$totalTests = 0
$passedTests = 0

# Teste 1: Endpoint acessível
Write-Host "🔍 Teste 1: Conectividade do Endpoint" -ForegroundColor Yellow
$totalTests++

$result = Test-ConfigEndpoint
if ($result.Success) {
    Write-TestResult -TestName "Endpoint /api/v1/config respondendo" -Passed $true
    $passedTests++
    $config = $result.Data
}
else {
    Write-TestResult -TestName "Endpoint /api/v1/config respondendo" -Passed $false -Message $result.Error
    Write-Host "`n❌ Servidor não está respondendo! Execute Start-CVEManagementAPI.ps1 primeiro." -ForegroundColor Red
    exit 1
}

# Teste 2: Estrutura APPLICATION
Write-Host "`n🔍 Teste 2: Seção APPLICATION" -ForegroundColor Yellow
$totalTests += 4

if ($config.APPLICATION) {
    Write-TestResult -TestName "Seção APPLICATION presente" -Passed $true
    $passedTests++

    if ($config.APPLICATION.name -eq "CVE Management System") {
        Write-TestResult -TestName "APPLICATION.name correto" -Passed $true -Message $config.APPLICATION.name
        $passedTests++
    }
    else {
        Write-TestResult -TestName "APPLICATION.name correto" -Passed $false -Message $config.APPLICATION.name
    }

    if ($config.APPLICATION.version) {
        Write-TestResult -TestName "APPLICATION.version presente" -Passed $true -Message $config.APPLICATION.version
        $passedTests++
    }
    else {
        Write-TestResult -TestName "APPLICATION.version presente" -Passed $false
    }

    if ($config.APPLICATION.releaseDate) {
        Write-TestResult -TestName "APPLICATION.releaseDate presente" -Passed $true -Message $config.APPLICATION.releaseDate
        $passedTests++
    }
    else {
        Write-TestResult -TestName "APPLICATION.releaseDate presente" -Passed $false
    }
}
else {
    Write-TestResult -TestName "Seção APPLICATION presente" -Passed $false
}

# Teste 3: Estrutura WEB
Write-Host "`n🔍 Teste 3: Seção WEB" -ForegroundColor Yellow
$totalTests += 4

if ($config.WEB) {
    Write-TestResult -TestName "Seção WEB presente" -Passed $true
    $passedTests++

    if ($config.WEB.api) {
        Write-TestResult -TestName "WEB.api presente" -Passed $true
        $passedTests++

        if ($config.WEB.api.host -and $config.WEB.api.port -and $config.WEB.api.prefix) {
            Write-TestResult -TestName "WEB.api configuração completa" -Passed $true -Message "Host: $($config.WEB.api.host), Port: $($config.WEB.api.port)"
            $passedTests++
        }
        else {
            Write-TestResult -TestName "WEB.api configuração completa" -Passed $false
        }
    }
    else {
        Write-TestResult -TestName "WEB.api presente" -Passed $false
    }

    if ($config.WEB.connections) {
        Write-TestResult -TestName "WEB.connections presente" -Passed $true
        $passedTests++

        # Validar SCCM
        if ($config.WEB.connections.sccm.server -eq "thanos.isp.corp") {
            Write-Host "        ✓ SCCM Server: $($config.WEB.connections.sccm.server)" -ForegroundColor Gray
        }
        if ($config.WEB.connections.sccm.database -eq "CM_RJO") {
            Write-Host "        ✓ SCCM Database: $($config.WEB.connections.sccm.database)" -ForegroundColor Gray
        }
    }
    else {
        Write-TestResult -TestName "WEB.connections presente" -Passed $false
    }
}
else {
    Write-TestResult -TestName "Seção WEB presente" -Passed $false
}

# Teste 4: Seção FEATURES
Write-Host "`n🔍 Teste 4: Seção FEATURES" -ForegroundColor Yellow
$totalTests += 3

if ($config.FEATURES) {
    Write-TestResult -TestName "Seção FEATURES presente" -Passed $true
    $passedTests++

    $expectedFeatures = @('sccmIntegration', 'intuneIntegration', 'psadtPackageGeneration')
    $missingFeatures = $expectedFeatures | Where-Object { -not $config.FEATURES.$_ }

    if ($missingFeatures.Count -eq 0) {
        Write-TestResult -TestName "Features principais presentes" -Passed $true
        $passedTests++
    }
    else {
        Write-TestResult -TestName "Features principais presentes" -Passed $false -Message "Faltando: $($missingFeatures -join ', ')"
    }

    $enabledFeatures = $config.FEATURES.PSObject.Properties | Where-Object { $_.Value -eq $true } | Measure-Object
    if ($enabledFeatures.Count -gt 0) {
        Write-TestResult -TestName "Ao menos uma feature habilitada" -Passed $true -Message "$($enabledFeatures.Count) features ativas"
        $passedTests++
    }
    else {
        Write-TestResult -TestName "Ao menos uma feature habilitada" -Passed $false
    }
}
else {
    Write-TestResult -TestName "Seção FEATURES presente" -Passed $false
}

# Teste 5: Metadata
Write-Host "`n🔍 Teste 5: Metadata" -ForegroundColor Yellow
$totalTests += 3

if ($config._meta) {
    Write-TestResult -TestName "Metadata (_meta) presente" -Passed $true
    $passedTests++

    if ($config._meta.source -eq "config.js (consolidated)") {
        Write-TestResult -TestName "Source correto" -Passed $true -Message $config._meta.source
        $passedTests++
    }
    else {
        Write-TestResult -TestName "Source correto" -Passed $false -Message $config._meta.source
    }

    if ($config._meta.timestamp) {
        Write-TestResult -TestName "Timestamp presente" -Passed $true -Message $config._meta.timestamp
        $passedTests++
    }
    else {
        Write-TestResult -TestName "Timestamp presente" -Passed $false
    }
}
else {
    Write-TestResult -TestName "Metadata (_meta) presente" -Passed $false
}

# Teste 6: Validação de valores específicos
Write-Host "`n🔍 Teste 6: Valores Específicos" -ForegroundColor Yellow
$totalTests += 3

if ($config.WEB.connections.sccm.server -eq "thanos.isp.corp") {
    Write-TestResult -TestName "SCCM Server = thanos.isp.corp" -Passed $true
    $passedTests++
}
else {
    Write-TestResult -TestName "SCCM Server = thanos.isp.corp" -Passed $false -Message $config.WEB.connections.sccm.server
}

if ($config.WEB.connections.sccm.database -eq "CM_RJO") {
    Write-TestResult -TestName "SCCM Database = CM_RJO" -Passed $true
    $passedTests++
}
else {
    Write-TestResult -TestName "SCCM Database = CM_RJO" -Passed $false -Message $config.WEB.connections.sccm.database
}

if ($config.WEB.api.prefix -eq "/api/v1") {
    Write-TestResult -TestName "API Prefix = /api/v1" -Passed $true
    $passedTests++
}
else {
    Write-TestResult -TestName "API Prefix = /api/v1" -Passed $false -Message $config.WEB.api.prefix
}

# ============================================================================
# RESUMO
# ============================================================================

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      RESUMO DOS TESTES                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$percentage = [math]::Round(($passedTests / $totalTests) * 100, 2)
$color = if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 80) { "Yellow" } else { "Red" }

Write-Host "  Total de Testes:    $totalTests" -ForegroundColor White
Write-Host "  Testes Passados:    $passedTests" -ForegroundColor Green
Write-Host "  Testes Falhados:    $($totalTests - $passedTests)" -ForegroundColor $(if ($totalTests -eq $passedTests) { "White" } else { "Red" })
Write-Host "  Taxa de Sucesso:    $percentage%" -ForegroundColor $color
Write-Host ""

if ($passedTests -eq $totalTests) {
    Write-Host "✅ TODOS OS TESTES PASSARAM!" -ForegroundColor Green
    Write-Host "   A configuração consolidada está funcionando perfeitamente!" -ForegroundColor White
    exit 0
}
else {
    Write-Host "⚠️  ALGUNS TESTES FALHARAM" -ForegroundColor Yellow
    Write-Host "   Revise as falhas acima e corrija os problemas." -ForegroundColor White
    exit 1
}
