<#
.SYNOPSIS
    Testa todas as queries de descoberta SQL contra o banco SCCM

.DESCRIPTION
    Script para validar sistema two-phase de queries contra SCCM
    - Etapa 1: Query de descoberta (busca ampla por aplicação)
    - Etapa 2: Query de filtro (valida versões contra Tenable)

.PARAMETER None
    Usa configuração de cves/config/config.json

.EXAMPLE
    .\Test-AllQueries.ps1

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
# VARIÁVEIS DO SISTEMA
# ============================================================================

$sccmServer = $Config.SCCM.Server
$sccmDatabase = $Config.SCCM.Database
$sccmPort = $Config.SCCM.Port
$jsonPath = Join-Path $Config.Paths.Json "*.json"

Write-Host "=== TESTE DE QUERIES SQL - PSADT CVE Management ===" -ForegroundColor Cyan
Write-Host "Servidor: $sccmServer" -ForegroundColor Gray
Write-Host "Database: $sccmDatabase" -ForegroundColor Gray
Write-Host ""

# Conectar ao SQL Server
$connectionString = "Server=$sccmServer,$sccmPort;Database=$sccmDatabase;Integrated Security=True;Connection Timeout=$($Config.SCCM.ConnectionTimeout);"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

try {
    Write-Host "Conectando ao SQL Server..." -ForegroundColor Yellow
    $connection.Open()
    Write-Host "Conectado com sucesso!" -ForegroundColor Green
    Write-Host ""

    # Ler todas as aplicacoes JSON
    $jsonFiles = Get-ChildItem -Path $Config.Paths.Json -Filter "*.json"
    $apps = $jsonFiles | ForEach-Object {
        Get-Content $_.FullName -Raw | ConvertFrom-Json
    }

    Write-Host "Total de aplicacoes carregadas: $($apps.Count)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Testando queries (amostra de 100)..." -ForegroundColor Yellow
    Write-Host ""

    $sucessos = 0
    $falhas = 0
    $semResultados = 0
    $descobertaSucesso = 0
    $testeCount = 0
    $maxTestes = $apps.Count # Testar TODAS as aplicações

    foreach ($app in $apps) {
        if ($testeCount -ge $maxTestes) { break }
        $testeCount++

        $appName = $app.applicationName -replace '<[^>]*>', '' -replace '\s+', ' '
        $appName = $appName.Trim()

        # Extrair Publisher/Product do Tenable
        $publishers = $app.affectedDevices | ForEach-Object {
            if ($_.pluginOutput.product) { $_.pluginOutput.product }
            elseif ($_.vulnerability.product) { $_.vulnerability.product }
        } | Where-Object { $_ } | Select-Object -Unique

        # Remover versoes e codigos da extração de keywords
        $cleanName = $appName -replace '\d+[\.\d]*\s*x?', '' -replace 'KB\d+:', '' -replace '<|>', '' -replace '\(.*?\)', '' -replace '/.*', ''
        $cleanName = $cleanName.Trim()

        $keywords = ($cleanName -split '\s+' | Where-Object { $_ -match '^[A-Za-z]+$' -and $_.Length -gt 3 }) | Select-Object -First 3

        # Se temos publisher, adicionar como palavra-chave prioritária
        if ($publishers.Count -gt 0) {
            $publisherKeyword = $publishers[0]
            # Remover palavras comuns de publisher
            $publisherKeyword = $publisherKeyword -replace 'Corporation|Inc\.|Ltd\.|LLC|Technologies|Software', '' -replace '\s+', ' '
            $publisherKeyword = $publisherKeyword.Trim()
            if ($publisherKeyword.Length -gt 3) {
                # Adicionar publisher como primeira palavra-chave
                $keywords = @($publisherKeyword) + ($keywords | Where-Object { $_ -ne $publisherKeyword })
                $keywords = $keywords | Select-Object -First 3
            }
        }

        if ($keywords.Count -lt 1) {
            Write-Host "⊘ $appName → Pulado (poucas palavras-chave)" -ForegroundColor DarkGray
            continue
        }

        $keywordsStr = "[$($keywords -join ', ')]"
        if ($publishers.Count -gt 0) {
            $keywordsStr += " {Pub: $($publishers[0])}"
        }

        # ETAPA 1: Query de DESCOBERTA (busca ampla)
        # Construir condições: DisplayName OU Publisher
        $displayNameConditions = ($keywords | ForEach-Object { "v_GS_ADD_REMOVE_PROGRAMS.DisplayName0 LIKE '%$_%'" }) -join ' AND '

        # Se temos publisher, adicionar busca alternativa por Publisher
        if ($publishers.Count -gt 0) {
            $publisherConditions = ($publishers | ForEach-Object { "v_GS_ADD_REMOVE_PROGRAMS.Publisher0 LIKE '%$_%'" }) -join ' OR '
            $likeConditions = "($displayNameConditions) OR ($publisherConditions)"
        } else {
            $likeConditions = $displayNameConditions
        }

        $discoveryQuery = @"
SELECT DISTINCT
    v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,
    v_GS_ADD_REMOVE_PROGRAMS.Version0,
    v_GS_ADD_REMOVE_PROGRAMS.Publisher0,
    v_GS_ADD_REMOVE_PROGRAMS.ProdID0,
    v_GS_ADD_REMOVE_PROGRAMS.UninstallString0,
    v_GS_ADD_REMOVE_PROGRAMS.InstallLocation0,
    v_GS_ADD_REMOVE_PROGRAMS.InstallSource0,
    COUNT(v_R_System.ResourceID) as DeviceCount
FROM v_R_System
INNER JOIN v_GS_ADD_REMOVE_PROGRAMS ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS.ResourceID
WHERE ($likeConditions)
    AND v_R_System.Client0 = 1
    AND v_R_System.Obsolete0 = 0
GROUP BY
    v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,
    v_GS_ADD_REMOVE_PROGRAMS.Version0,
    v_GS_ADD_REMOVE_PROGRAMS.Publisher0,
    v_GS_ADD_REMOVE_PROGRAMS.ProdID0,
    v_GS_ADD_REMOVE_PROGRAMS.UninstallString0,
    v_GS_ADD_REMOVE_PROGRAMS.InstallLocation0,
    v_GS_ADD_REMOVE_PROGRAMS.InstallSource0
"@

        try {
            # Tentar query de descoberta primeiro
            $command = $connection.CreateCommand()
            $command.CommandText = $discoveryQuery
            $command.CommandTimeout = 10
            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
            $dataset = New-Object System.Data.DataSet
            $discoveryCount = $adapter.Fill($dataset)

            if ($discoveryCount -gt 0) {
                $descobertaSucesso++
                $versionsFound = $dataset.Tables[0] | Select-Object -ExpandProperty Version0 -Unique

                # ETAPA 2: Query FILTRADA (versões do Tenable)
                $tenableVersions = $app.affectedDevices | ForEach-Object {
                    if ($_.pluginOutput) { $_.pluginOutput.installedVersion }
                    elseif ($_.vulnerability) { $_.vulnerability.installedVersion }
                } | Where-Object { $_ } | Select-Object -Unique

                if ($tenableVersions.Count -gt 0) {
                    # Verificar se alguma versão encontrada está na lista Tenable
                    $vulnerableVersions = $versionsFound | Where-Object { $tenableVersions -contains $_ }

                    if ($vulnerableVersions.Count -gt 0) {
                        Write-Host "✓✓ $appName $keywordsStr → Descoberta: $discoveryCount versões | Vulneráveis: $($vulnerableVersions.Count)" -ForegroundColor Green
                        $sucessos++
                    } else {
                        Write-Host "○+ $appName $keywordsStr → Descoberta: $discoveryCount versões | Vulneráveis: 0 (versões não batem)" -ForegroundColor Cyan
                        $semResultados++
                    }
                } else {
                    Write-Host "○+ $appName $keywordsStr → Descoberta: $discoveryCount versões | Sem versões Tenable" -ForegroundColor Cyan
                    $semResultados++
                }
            } else {
                Write-Host "○ $appName $keywordsStr → Produto não encontrado no ambiente" -ForegroundColor Yellow
                $semResultados++
            }
        }
        catch {
            Write-Host "✗ $appName $keywordsStr → ERRO: $($_.Exception.Message.Split([Environment]::NewLine)[0])" -ForegroundColor Red
            $falhas++
        }
    }

    Write-Host ""
    Write-Host "=== RESUMO GERAL (total: $testeCount queries) ===" -ForegroundColor Cyan
    Write-Host "Produtos encontrados (descoberta): $descobertaSucesso" -ForegroundColor Cyan
    Write-Host "Versões vulneráveis confirmadas: $sucessos" -ForegroundColor Green
    Write-Host "Sem versões vulneráveis: $semResultados" -ForegroundColor Yellow
    Write-Host "Falhas: $falhas" -ForegroundColor Red
    Write-Host ""
    Write-Host "Taxa de descoberta: $([Math]::Round(($descobertaSucesso / ($descobertaSucesso + $semResultados + $falhas)) * 100, 2))%" -ForegroundColor Cyan
    Write-Host "Taxa de vulnerabilidade confirmada: $([Math]::Round(($sucessos / ($sucessos + $semResultados + $falhas)) * 100, 2))%" -ForegroundColor Green
}
catch {
    Write-Host "ERRO AO CONECTAR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
        Write-Host "Conexao fechada." -ForegroundColor Gray
    }
}
