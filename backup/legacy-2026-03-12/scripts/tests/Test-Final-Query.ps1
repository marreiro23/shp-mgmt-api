<#
.SYNOPSIS
    Testa query final corrigida para MySQL Connector com UninstallString

.DESCRIPTION
    Script de teste que valida a query SQL para MySQL Connector < 9.1.0
    usando UninstallString a partir da view v_GS_INSTALLED_SOFTWARE no SCCM.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-Final-Query.ps1
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
Write-Host "║     QUERY FINAL: MySQL Connector < 9.1.0                         ║" -ForegroundColor Cyan
Write-Host "║     UninstallString: v_GS_INSTALLED_SOFTWARE.UninstallString0    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Construir string de conexão a partir da configuração
$connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=true"

Write-Host "Conectando a: $($Config.SCCM.Server)" -ForegroundColor Yellow
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()
Write-Host "✓ OK`n" -ForegroundColor Green

# Query CORRIGIDA
$query = @"
SELECT
    sys.Name0 as NetbiosName,
    sw.ProductName0,
    sw.ProductVersion0,
    sw.UninstallString0,
    sw.InstalledLocation0
FROM
    v_GS_SYSTEM sys
    INNER JOIN v_GS_INSTALLED_SOFTWARE sw
        ON sw.ResourceID = sys.ResourceID
WHERE
    sw.ProductName0 LIKE '%MySQL%Connector%'
    AND sw.ProductVersion0 < '9.1.0'
ORDER BY
    sys.Name0, sw.ProductVersion0 DESC
"@

Write-Host "SQL Query:" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host $query -ForegroundColor Gray
Write-Host ""

Write-Host "Executando..." -ForegroundColor Yellow
Write-Host ""

try {
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $command.CommandTimeout = $Config.SCCM.CommandTimeout

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $adapter.SelectCommand = $command

    $dataTable = New-Object System.Data.DataTable
    $adapter.Fill($dataTable) | Out-Null

    Write-Host "✓ SUCESSO - $($dataTable.Rows.Count) registros encontrados`n" -ForegroundColor Green

    if ($dataTable.Rows.Count -gt 0) {
        Write-Host "RESULTADOS:" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Gray

        foreach ($row in $dataTable.Rows) {
            Write-Host "🖥️  Sistema: $($row.NetbiosName)" -ForegroundColor Cyan
            Write-Host "   📦 Produto: $($row.ProductName0)" -ForegroundColor Yellow
            Write-Host "   📌 Versão: $($row.ProductVersion0)" -ForegroundColor Yellow
            Write-Host "   🔧 UninstallString:" -ForegroundColor Green
            Write-Host "      $($row.UninstallString0)" -ForegroundColor Green
            if ($row.InstalledLocation0) {
                Write-Host "   📂 Location: $($row.InstalledLocation0)" -ForegroundColor Green
            }
            Write-Host ""
        }

        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "✓ CONCLUSÃO:" -ForegroundColor Green
        Write-Host "  • UninstallString0 EXISTE em v_GS_INSTALLED_SOFTWARE" -ForegroundColor Green
        Write-Host "  • InstalledLocation0 EXISTE em v_GS_INSTALLED_SOFTWARE" -ForegroundColor Green
        Write-Host "  • Query funciona perfeitamente com MySQL Connector" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Green

    } else {
        Write-Host "⚠️  Nenhum MySQL Connector < 9.1.0 encontrado" -ForegroundColor Yellow
        Write-Host "   Testando query genérica...`n" -ForegroundColor Yellow

        $queryGen = @"
SELECT TOP 5
    sys.Name0 as NetbiosName,
    sw.ProductName0,
    sw.ProductVersion0,
    sw.UninstallString0
FROM
    v_GS_SYSTEM sys
    INNER JOIN v_GS_INSTALLED_SOFTWARE sw
        ON sw.ResourceID = sys.ResourceID
WHERE
    sw.UninstallString0 IS NOT NULL
    AND sw.ProductName0 IS NOT NULL
ORDER BY
    sys.Name0
"@

        $command.CommandText = $queryGen
        $adapter.SelectCommand = $command
        $dataTable = New-Object System.Data.DataTable
        $adapter.Fill($dataTable) | Out-Null

        Write-Host "✓ Exemplos de software com UninstallString:" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Gray

        if ($dataTable.Rows.Count -gt 0) {
            $dataTable | Format-Table -AutoSize
            Write-Host "✓ UninstallString0 EXISTE e TEM DADOS!" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "✗ ERRO: $_`n" -ForegroundColor Red
}
finally {
    $connection.Close()
}
