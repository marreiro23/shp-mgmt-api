<#
.SYNOPSIS
    Testa a query SQL para SCCM Installed Software

.DESCRIPTION
    Script para testar a query SQL que busca software instalado
    no SCCM, especificamente MySQL Connector < 9.1.0.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-WQLQuery.ps1
#>

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     TESTE DE QUERY SQL - SCCM INSTALLED SOFTWARE                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuração SCCM
$connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=true"

Write-Host "Conectando ao SCCM..." -ForegroundColor Yellow
Write-Host "  Server: $($Config.SCCM.Server)" -ForegroundColor Gray
Write-Host "  Database: $($Config.SCCM.Database)" -ForegroundColor Gray
Write-Host ""

try {
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    Write-Host "✓ Conexão estabelecida" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Erro ao conectar: $_" -ForegroundColor Red
    exit 1
}

# Query SQL convertida - usando nomes de tabelas e colunas corretos do SCCM
$query = @"
SELECT
    sys.NetbiosName0,
    sw.ProductName0,
    sw.ProductVersion0,
    sw.UninstallString0,
    sw.InstalledLocation0
FROM
    v_GS_SYSTEM sys
    INNER JOIN v_GS_INSTALLED_SOFTWARE sw
        ON sw.ResourceID = sys.ResourceID
WHERE
    sw.ProductName0 LIKE 'MySQL%Connector%'
    AND sw.ProductVersion0 < '9.1.0'
ORDER BY
    sys.NetbiosName0, sw.ProductName0
"@

Write-Host "Executando query SQL..." -ForegroundColor Yellow
Write-Host ""

try {
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.CommandTimeout = $Config.SCCM.CommandTimeout

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $adapter.SelectCommand = $command

    $dataTable = New-Object System.Data.DataTable
    $adapter.Fill($dataTable) | Out-Null

    Write-Host "✓ Query executada com sucesso" -ForegroundColor Green
    Write-Host "  Registros encontrados: $($dataTable.Rows.Count)" -ForegroundColor Green
    Write-Host ""

    if ($dataTable.Rows.Count -gt 0) {
        Write-Host "RESULTADOS:" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host ""

        $dataTable | Format-Table -AutoSize @(
            @{ Name = "NetbiosName"; Expression = { $_."NetbiosName0" } },
            @{ Name = "ProductName"; Expression = { $_."ProductName0" } },
            @{ Name = "Version"; Expression = { $_."ProductVersion0" } },
            @{ Name = "UninstallString"; Expression = { $_."UninstallString0" } },
            @{ Name = "Location"; Expression = { $_."InstalledLocation0" } }
        ) -Wrap

        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "✓ Query foi bem-sucedida!" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Nenhum MySQL Connector < 9.1.0 encontrado" -ForegroundColor Yellow
        Write-Host ""
    }
}
catch {
    Write-Host "✗ ERRO: $_`n" -ForegroundColor Red
}
finally {
    $connection.Close()
}
