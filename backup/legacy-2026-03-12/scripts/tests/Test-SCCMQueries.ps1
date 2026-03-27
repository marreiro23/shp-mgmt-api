<#
.SYNOPSIS
    Testa queries SQL diretamente no servidor SCCM

.DESCRIPTION
    Script interativo para executar e testar queries SQL no SCCM.
    Permite escolher entre queries predefinidas ou executar queries customizadas.

.PARAMETER Server
    Servidor SCCM (default: carregado de config.json)

.PARAMETER Database
    Database SCCM (default: carregado de config.json)

.PARAMETER QueryFile
    Arquivo .sql para executar

.PARAMETER InteractiveMode
    Modo interativo com menu de opcoes

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-SCCMQueries.ps1 -InteractiveMode

.EXAMPLE
    .\Test-SCCMQueries.ps1 -QueryFile ".\exports\CVE_SCCM_Queries.sql"

.EXAMPLE
    .\Test-SCCMQueries.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Server,

    [Parameter()]
    [string]$Database,

    [Parameter()]
    [string]$QueryFile,

    [Parameter()]
    [switch]$InteractiveMode
)

$ErrorActionPreference = 'Continue'

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

# Usar valores de parâmetros ou carregar da configuração
if ([string]::IsNullOrEmpty($Server)) {
    $Server = $Config.SCCM.Server
}
if ([string]::IsNullOrEmpty($Database)) {
    $Database = $Config.SCCM.Database
}

# ============================================================================
# FUNCOES AUXILIARES
# ============================================================================

function Write-Header {
    param([string]$Text)
    Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$('=' * 80)" -ForegroundColor Cyan
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host "`n$('-' * 80)" -ForegroundColor Gray
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "$('-' * 80)" -ForegroundColor Gray
}

function Test-SQLConnection {
    param(
        [string]$Server,
        [string]$Database
    )

    try {
        $connectionString = "Server=$Server,$($Config.SCCM.Port);Database=$Database;Integrated Security=True;Connection Timeout=$($Config.SCCM.ConnectionTimeout);"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()

        Write-Host "✓ Conectado a $Server\$Database" -ForegroundColor Green
        return $connection
    }
    catch {
        Write-Host "✗ Erro ao conectar: $_" -ForegroundColor Red
        return $null
    }
}

function Execute-Query {
    param(
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$Query,
        [int]$Timeout = 300
    )

    try {
        $command = $Connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = $Timeout

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $adapter.SelectCommand = $command

        $dataSet = New-Object System.Data.DataSet
        $adapter.Fill($dataSet) | Out-Null

        return $dataSet.Tables[0]
    }
    catch {
        Write-Host "✗ Erro ao executar query: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Header "CVE MANAGEMENT - TEST SCCM QUERIES"

Write-Host "`nServidor: $Server" -ForegroundColor Cyan
Write-Host "Database: $Database" -ForegroundColor Cyan

# Conectar
Write-Host ""
Write-Host "Conectando..." -ForegroundColor Yellow
$connection = Test-SQLConnection -Server $Server -Database $Database

if ($null -eq $connection) {
    exit 1
}

# Se QueryFile foi fornecido, executar
if (-not [string]::IsNullOrEmpty($QueryFile)) {
    Write-SubHeader "Executando arquivo de query: $QueryFile"

    if (Test-Path $QueryFile) {
        $queryContent = Get-Content $QueryFile -Raw
        $result = Execute-Query -Connection $connection -Query $queryContent

        if ($null -ne $result) {
            Write-Host "`n✓ Query executada com sucesso - $($result.Rows.Count) registros" -ForegroundColor Green
            $result | Format-Table -AutoSize | Out-Host
        }
    } else {
        Write-Host "✗ Arquivo não encontrado: $QueryFile" -ForegroundColor Red
    }

    $connection.Close()
    exit 0
}

# Modo interativo
if ($InteractiveMode -or -not $QueryFile) {
    Write-SubHeader "Modo Interativo"

    Write-Host ""
    Write-Host "1. Teste de Conectividade" -ForegroundColor Cyan
    Write-Host "2. Query: MySQL Connector < 9.1.0" -ForegroundColor Cyan
    Write-Host "3. Query: Aplicações com UninstallString" -ForegroundColor Cyan
    Write-Host "4. Query: Top 10 Aplicações" -ForegroundColor Cyan
    Write-Host "5. Query Customizada" -ForegroundColor Cyan
    Write-Host "6. Sair" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Escolha uma opção (1-6)"

    switch ($choice) {
        "1" {
            Write-SubHeader "Teste de Conectividade"
            Write-Host "✓ Conexão estabelecida com sucesso" -ForegroundColor Green
        }

        "2" {
            Write-SubHeader "Query: MySQL Connector < 9.1.0"
            $query = @"
SELECT
    sys.NetbiosName0,
    sw.ProductName0,
    sw.ProductVersion0,
    sw.UninstallString0
FROM
    v_GS_SYSTEM sys
    INNER JOIN v_GS_INSTALLED_SOFTWARE sw ON sw.ResourceID = sys.ResourceID
WHERE
    sw.ProductName0 LIKE 'MySQL%Connector%'
    AND sw.ProductVersion0 < '9.1.0'
ORDER BY
    sys.NetbiosName0
"@

            $result = Execute-Query -Connection $connection -Query $query
            if ($null -ne $result) {
                Write-Host "`n✓ $($result.Rows.Count) registros encontrados" -ForegroundColor Green
                $result | Format-Table -AutoSize | Out-Host
            }
        }

        "3" {
            Write-SubHeader "Query: Aplicações com UninstallString"
            $query = @"
SELECT TOP 20
    DisplayName0,
    Version0,
    Publisher0,
    UninstallString0
FROM v_GS_ADD_REMOVE_PROGRAMS
WHERE UninstallString0 IS NOT NULL
ORDER BY DisplayName0
"@

            $result = Execute-Query -Connection $connection -Query $query
            if ($null -ne $result) {
                Write-Host "`n✓ $($result.Rows.Count) registros encontrados" -ForegroundColor Green
                $result | Format-Table -AutoSize | Out-Host
            }
        }

        "4" {
            Write-SubHeader "Query: Top 10 Aplicações"
            $query = @"
SELECT TOP 10
    DisplayName0,
    Version0,
    Publisher0
FROM v_GS_ADD_REMOVE_PROGRAMS
ORDER BY DisplayName0
"@

            $result = Execute-Query -Connection $connection -Query $query
            if ($null -ne $result) {
                Write-Host "`n✓ $($result.Rows.Count) registros encontrados" -ForegroundColor Green
                $result | Format-Table -AutoSize | Out-Host
            }
        }

        "5" {
            Write-SubHeader "Query Customizada"
            Write-Host "Digite sua query SQL (termine com 'GO'):" -ForegroundColor Yellow
            Write-Host ""

            $customQuery = ""
            while ($true) {
                $line = Read-Host
                if ($line -eq "GO") { break }
                $customQuery += "$line`n"
            }

            $result = Execute-Query -Connection $connection -Query $customQuery
            if ($null -ne $result) {
                Write-Host "`n✓ Query executada - $($result.Rows.Count) registros" -ForegroundColor Green
                $result | Format-Table -AutoSize | Out-Host
            }
        }

        default {
            Write-Host "Saindo..." -ForegroundColor Yellow
        }
    }
}

$connection.Close()
Write-Host "`n✓ Conexão fechada" -ForegroundColor Green
