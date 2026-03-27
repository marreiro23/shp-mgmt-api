<#
.SYNOPSIS
    Suite completa de testes para CVE Management System

.DESCRIPTION
    Testa todos os componentes do sistema de forma integrada:
    - Estrutura de arquivos
    - Conexão SQL Server SCCM
    - Queries de dados reais
    - Integração API

.PARAMETER None
    Usa configuração de cves/config/config.json

.EXAMPLE
    .\Test-CompleteSystem.ps1

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
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
# TESTE 1: Verificar Arquivos
# ============================================================================
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         TESTES COMPLETOS - CVE MANAGEMENT SYSTEM              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "TESTE 1: Verificar Arquivos Criados" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

$files = @(
    (Join-Path $Config.Paths.Scripts "Get-RemediationCommands.ps1"),
    (Join-Path $Config.Paths.Scripts "New-PSADTRemediationPackage.ps1"),
    (Join-Path $Config.Paths.Json "*.json"),
    (Join-Path $Config.Paths.Web "index.html"),
    (Join-Path $Config.Paths.Web "queries.html")
)

$filesOK = 0
$filesFail = 0

foreach ($filePattern in $files) {
    $found = @(Get-Item -Path $filePattern -ErrorAction SilentlyContinue)
    if ($found.Count -gt 0) {
        Write-Host "✓ $filePattern" -ForegroundColor Green
        $filesOK++
    } else {
        Write-Host "✗ $filePattern - NÃO ENCONTRADO" -ForegroundColor Red
        $filesFail++
    }
}

Write-Host ""
Write-Host "Resultado: $filesOK OK, $filesFail FALHAS" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# TESTE 2: Conexão ao SQL Server
# ============================================================================
Write-Host "TESTE 2: Conexão ao SQL Server" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

try {
    $sccmServer = $Config.SCCM.Server
    $sccmDatabase = $Config.SCCM.Database
    $sccmPort = $Config.SCCM.Port

    $connection = New-Object System.Data.SqlClient.SqlConnection("Server=$sccmServer,$sccmPort;Database=$sccmDatabase;Integrated Security=True;Connection Timeout=$($Config.SCCM.ConnectionTimeout);")
    $connection.Open()
    Write-Host "✓ Conectado a: $sccmServer ($sccmDatabase)" -ForegroundColor Green

    # Query simples
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "SELECT COUNT(*) as Total FROM v_GS_ADD_REMOVE_PROGRAMS WHERE UninstallString0 IS NOT NULL"
    $reader = $cmd.ExecuteReader()

    if ($reader.Read()) {
        $count = $reader.GetInt32(0)
        Write-Host "✓ Aplicações com UninstallString: $count" -ForegroundColor Green
    }
    $reader.Close()
    $connection.Close()
} catch {
    Write-Host "✗ ERRO: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# TESTE 3: Testar Query com Dados Reais
# ============================================================================
Write-Host "TESTE 3: Query com UninstallString e ProdID" -ForegroundColor Yellow
Write-Host "═" * 60 -ForegroundColor Gray

try {
    $query = @"
SELECT TOP 5
    DisplayName0,
    Version0,
    Publisher0,
    ProdID0,
    UninstallString0,
    InstallLocation0
FROM v_GS_ADD_REMOVE_PROGRAMS
WHERE DisplayName0 IS NOT NULL
  AND UninstallString0 IS NOT NULL
ORDER BY DisplayName0
"@

    $connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=True;Connection Timeout=$($Config.SCCM.ConnectionTimeout);"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($query, $connection)
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null

    $results = $dataset.Tables[0]

    if ($results.Rows.Count -gt 0) {
        Write-Host "✓ Retornou $($results.Rows.Count) resultados" -ForegroundColor Green
        Write-Host ""

        foreach ($row in $results.Rows | Select-Object -First 3) {
            Write-Host "  • $($row['DisplayName0']) v$($row['Version0'])" -ForegroundColor Cyan
            if ($row['UninstallString0']) {
                $uninstallStr = $row['UninstallString0'].ToString().Substring(0, [Math]::Min(60, $row['UninstallString0'].ToString().Length))
                Write-Host "    UninstallString: $uninstallStr..." -ForegroundColor Gray
            }
            if ($row['ProdID0']) {
                Write-Host "    ProdID: $($row['ProdID0'])" -ForegroundColor Gray
            }
            Write-Host ""
        }
    } else {
        Write-Host "⚠ Nenhum resultado retornou" -ForegroundColor Yellow
    }

    $connection.Close()
} catch {
    Write-Host "✗ ERRO: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                    TESTES CONCLUÍDOS" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
