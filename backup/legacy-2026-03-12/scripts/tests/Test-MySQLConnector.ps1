<#
.SYNOPSIS
    Testa query SQL para MySQL Connector no SCCM

.DESCRIPTION
    Script para testar a query SQL que busca MySQL Connector < 9.1.0
    diretamente no servidor SCCM.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-MySQLConnector.ps1
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
Write-Host "║     TESTE QUERY SQL - MySQL Connector UninstallString            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$connectionString = "Server=$($Config.SCCM.Server);Database=$($Config.SCCM.Database);Integrated Security=true"

Write-Host "Conectando ao SCCM..." -ForegroundColor Yellow
try {
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    Write-Host "✓ Conexão OK`n" -ForegroundColor Green
}
catch {
    Write-Host "✗ Erro: $_`n" -ForegroundColor Red
    exit 1
}

# Query SQL - Teste direto
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
    sys.NetbiosName0
"@

Write-Host "Executando query para MySQL Connector < 9.1.0..." -ForegroundColor Yellow
Write-Host ""

try {
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.CommandTimeout = $Config.SCCM.CommandTimeout

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $adapter.SelectCommand = $command

    $dataTable = New-Object System.Data.DataTable
    $adapter.Fill($dataTable) | Out-Null

    Write-Host "✓ Query executada - $($dataTable.Rows.Count) registros encontrados`n" -ForegroundColor Green

    if ($dataTable.Rows.Count -gt 0) {
        Write-Host "RESULTADOS:" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Gray

        foreach ($row in $dataTable.Rows) {
            Write-Host "🖥️  Sistema: $($row.NetbiosName0)" -ForegroundColor Cyan
            Write-Host "   📦 Produto: $($row.ProductName0)" -ForegroundColor Yellow
            Write-Host "   📌 Versão: $($row.ProductVersion0)" -ForegroundColor Yellow
            Write-Host "   🔧 UninstallString: $($row.UninstallString0)" -ForegroundColor Green
            Write-Host "   📂 Location: $($row.InstalledLocation0)" -ForegroundColor Green
            Write-Host ""
        }
    } else {
        Write-Host "⚠️  Nenhum MySQL Connector < 9.1.0 encontrado" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ ERRO: $_`n" -ForegroundColor Red
}
finally {
    $connection.Close()
}
