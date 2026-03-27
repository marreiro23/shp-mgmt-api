<#
.SYNOPSIS
    Descobre colunas disponíveis na tabela SCCM

.DESCRIPTION
    Script para descobrir quais colunas estão disponíveis na tabela
    v_GS_ADD_REMOVE_PROGRAMS do SCCM.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Discover-Columns.ps1
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
Write-Host "║         DESCOBERTA DE COLUNAS - SCCM ADD_REMOVE_PROGRAMS         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Analisando Colunas Disponíveis..." -ForegroundColor Yellow
Write-Host ""

try {
    # Carregar módulo SQL se disponível
    Import-Module SqlServer -ErrorAction SilentlyContinue

    $connectionString = "Server=$($Config.SCCM.Server),$($Config.SCCM.Port);Database=$($Config.SCCM.Database);Integrated Security=True;"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()

    # Query para obter colunas
    $query = @"
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'v_GS_ADD_REMOVE_PROGRAMS'
ORDER BY COLUMN_NAME
"@

    $cmd = $connection.CreateCommand()
    $cmd.CommandText = $query
    $reader = $cmd.ExecuteReader()

    Write-Host "Colunas disponíveis na tabela v_GS_ADD_REMOVE_PROGRAMS:" -ForegroundColor Cyan
    Write-Host ""

    while ($reader.Read()) {
        $colName = $reader.GetString(0)
        $colType = $reader.GetString(1)
        Write-Host "  • $colName ($colType)" -ForegroundColor Gray
    }

    $reader.Close()

    # Teste de query real
    Write-Host ""
    Write-Host "Testando query real:" -ForegroundColor Cyan
    Write-Host ""

    $testQuery = @"
SELECT TOP 3
    ResourceID,
    DisplayName0,
    Version0,
    Publisher0,
    ProdID0
FROM v_GS_ADD_REMOVE_PROGRAMS
ORDER BY DisplayName0
"@

    $cmd.CommandText = $testQuery
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $adapter.SelectCommand = $cmd

    $dataSet = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $dataSet.Tables[0] | Format-Table -AutoSize | Out-Host

    Write-Host ""
    Write-Host "✓ Colunas descobertas com sucesso!" -ForegroundColor Green

    $connection.Close()
}
catch {
    Write-Host "✗ Erro ao descobrir colunas: $_" -ForegroundColor Red
}

Write-Host ""
