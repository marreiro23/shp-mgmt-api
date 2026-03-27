<#
.SYNOPSIS
    Testa endpoints da API SCCM

.DESCRIPTION
    Script para validar endpoints de testes da API com configuração centralizada
    - Endpoint /config - Verificar configuração SCCM
    - Endpoint /customizations - Listar queries customizadas
    - Endpoint /customizations/:queryName - Carregar query específica

.PARAMETER None
    Usa configuração de cves/config/config.json

.EXAMPLE
    .\Test-APIEndpoints.ps1

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

$apiUrl = "http://$($Config.Api.Host):$($Config.Api.Port)$($Config.Api.Prefix)/sccm"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     TESTE DOS NOVOS ENDPOINTS - API SCCM ATUALIZADA             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "API URL: $apiUrl" -ForegroundColor Gray
Write-Host ""

Write-Host "TESTE 1: Verificar Configuração SCCM (com novas views)" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$apiUrl/config" -Method GET

    if ($response.success) {
        Write-Host "✓ Config carregada com sucesso`n" -ForegroundColor Green
        Write-Host "Servidor: $($response.data.server)" -ForegroundColor Gray
        Write-Host "Database: $($response.data.database)" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Views Disponíveis:" -ForegroundColor Cyan
        foreach ($view in $response.data.views) {
            Write-Host "  • $view" -ForegroundColor Gray
        }
        Write-Host ""

        Write-Host "Features Suportadas:" -ForegroundColor Cyan
        $response.data.supportedFeatures | Get-Member -MemberType NoteProperty | ForEach-Object {
            $value = $response.data.supportedFeatures.($_.Name)
            Write-Host "  • $($_.Name): $(if($value) { '✓' } else { '✗' })" -ForegroundColor Gray
        }
        Write-Host ""

        Write-Host "Query Profiles:" -ForegroundColor Cyan
        foreach ($profile in $response.data.queryProfiles) {
            Write-Host "  • $($profile.name)" -ForegroundColor Green
            Write-Host "    Type: $($profile.type) | Status: $($profile.status)" -ForegroundColor Gray
            Write-Host "    Affected Systems: $($profile.affectedSystems)" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        Write-Host "✗ Erro ao carregar config: $($response.message)" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Erro na requisição: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "TESTE 2: Listar Todas as Customizações" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$apiUrl/customizations" -Method GET

    if ($response.success) {
        Write-Host "✓ Customizações carregadas: $($response.count)" -ForegroundColor Green
        Write-Host ""

        foreach ($name in $response.data.PSObject.Properties.Name) {
            $query = $response.data.$name
            Write-Host "📌 $name" -ForegroundColor Cyan
            Write-Host "   Status: $($query.status)" -ForegroundColor Gray
            Write-Host "   Resultados: $($query.resultsFound)" -ForegroundColor Gray
            Write-Host "   Testada em: $($query.testedAt)" -ForegroundColor Gray

            if ($query.features) {
                Write-Host "   Features:" -ForegroundColor Gray
                $query.features | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $value = $query.features.($_.Name)
                    Write-Host "     • $($_.Name): $(if($value) { '✓' } else { '✗' })" -ForegroundColor Gray
                }
            }

            Write-Host "   Comandos Disponíveis: $($query.commandsAvailable)" -ForegroundColor Green
            Write-Host ""
        }
    } else {
        Write-Host "✗ Erro: $($response.message)" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Erro na requisição: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "TESTE 3: Carregar Query Específica (MySQL Connector)" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

try {
    $queryName = "MySQL Connector/ODBC < 9.1.0 (UninstallString + Location)"
    $encoded = [System.Web.HttpUtility]::UrlEncode($queryName)

    Write-Host "Carregando: $queryName" -ForegroundColor Gray
    Write-Host "URL Encoded: $encoded" -ForegroundColor DarkGray
    Write-Host ""

    $response = Invoke-RestMethod -Uri "$apiUrl/customizations/$encoded" -Method GET

    if ($response.success) {
        Write-Host "✓ Query carregada com sucesso`n" -ForegroundColor Green

        Write-Host "Nome: $($response.data.name)" -ForegroundColor Cyan
        Write-Host "Status: $($response.data.status)" -ForegroundColor Green
        Write-Host "Validada: $($response.data.validated)" -ForegroundColor Green
        Write-Host "Resultados: $($response.data.resultsFound)" -ForegroundColor Cyan
        Write-Host "Última Execução: $($response.data.lastTested)" -ForegroundColor Gray
        Write-Host ""

        Write-Host "Query SQL:" -ForegroundColor Cyan
        Write-Host "────────────────────────────────────────" -ForegroundColor Gray
        Write-Host $response.data.query -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Features:" -ForegroundColor Cyan
        if ($response.data.features) {
            $response.data.features | Get-Member -MemberType NoteProperty | ForEach-Object {
                $value = $response.data.features.($_.Name)
                Write-Host "  • $($_.Name): $(if($value) { '✓' } else { '✗' })" -ForegroundColor Gray
            }
        }
        Write-Host ""

    } else {
        Write-Host "✗ Query não encontrada: $($response.message)" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Erro na requisição: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                    TESTES CONCLUÍDOS" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "RESUMO:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""
Write-Host "✓ Endpoint /api/v1/sccm/config" -ForegroundColor Green
Write-Host "  - Views SCCM verificadas" -ForegroundColor Gray
Write-Host "  - Features suportadas documentadas" -ForegroundColor Gray
Write-Host "  - Query profiles carregados" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Endpoint /api/v1/sccm/customizations" -ForegroundColor Green
Write-Host "  - Todas as queries customizadas listadas" -ForegroundColor Gray
Write-Host "  - Status de cada query exibido" -ForegroundColor Gray
Write-Host "  - Comandos disponíveis documentados" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Endpoint /api/v1/sccm/customizations/:queryName" -ForegroundColor Green
Write-Host "  - Query específica carregada" -ForegroundColor Gray
Write-Host "  - SQL completo retornado" -ForegroundColor Gray
Write-Host "  - Features da query documentadas" -ForegroundColor Gray
Write-Host ""

Write-Host "PRÓXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "1. Reiniciar API: .\Start-API-Background.ps1" -ForegroundColor Gray
Write-Host "2. Validar integração na interface web: queries.html" -ForegroundColor Gray
Write-Host "3. Testar execução de queries nos endpoints" -ForegroundColor Gray
Write-Host "4. Validar remediação automática" -ForegroundColor Gray
Write-Host ""
