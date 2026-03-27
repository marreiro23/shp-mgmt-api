<#
.SYNOPSIS
    Script mestre para execução completa da coleta de dados de produção

.DESCRIPTION
    Automatiza todo o processo de coleta de dados conforme PLANO_COLETA_DADOS_REMEDIACAO.md
    Executa em fases:
    - Fase 1: Inventário de dispositivos (SCCM + Intune)
    - Fase 2: Inventário de software (amostragem)
    - Fase 3: Matching com vulnerabilidades
    - Fase 4: Análise e relatórios

.PARAMETER Phase
    Fase específica para executar (1-4), ou "All" para todas

.PARAMETER SkipAPIsCheck
    Pula verificação de APIs (útil se já estão rodando)

.EXAMPLE
    .\Run-Complete-Data-Collection.ps1 -Phase 1
    .\Run-Complete-Data-Collection.ps1 -Phase All -Verbose

.NOTES
    Autor: CVE Management System
    Data: 20/01/2026
    Versão: 1.0.0
    Impacto: ZERO (Read-Only)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('1', '2', '3', '4', 'All')]
    [string]$Phase = 'All',

    [Parameter()]
    [switch]$SkipAPIsCheck
)

$ErrorActionPreference = 'Stop'

# Banner
Write-Host "`n" + ("="*100) -ForegroundColor Cyan
Write-Host " " -NoNewline
Write-Host "📊 COLETA COMPLETA DE DADOS DE PRODUÇÃO - CVE MANAGEMENT SYSTEM" -ForegroundColor White
Write-Host ("="*100) -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Objetivo:" -ForegroundColor Yellow -NoNewline
Write-Host " Coletar dados reais sem impacto no ambiente (Read-Only)"
Write-Host "📅 Data:" -ForegroundColor Yellow -NoNewline
Write-Host " $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
Write-Host "⚙️  Fase:" -ForegroundColor Yellow -NoNewline
Write-Host " $Phase"
Write-Host ("="*100) -ForegroundColor Cyan
Write-Host ""

# Verificar APIs (se não foi pulado)
if (-not $SkipAPIsCheck) {
    Write-Host "🔍 Verificando status das APIs..." -ForegroundColor Yellow

    $apis = @(
        @{ Name = "CVE API"; URL = "http://localhost:3001/health"; Required = $true }
        @{ Name = "Autopilot API"; URL = "http://localhost:3002/health"; Required = $true }
        @{ Name = "Gateway API"; URL = "http://localhost:3000/health"; Required = $false }
    )

    $allHealthy = $true

    foreach ($api in $apis) {
        try {
            $health = Invoke-RestMethod -Uri $api.URL -TimeoutSec 5 -ErrorAction Stop

            if ($health.status -eq "healthy") {
                Write-Host "   ✅ $($api.Name): Saudável" -ForegroundColor Green
            }
            else {
                Write-Host "   ⚠️  $($api.Name): $($health.status)" -ForegroundColor Yellow
                if ($api.Required) { $allHealthy = $false }
            }
        }
        catch {
            Write-Host "   ❌ $($api.Name): Não acessível" -ForegroundColor Red
            if ($api.Required) { $allHealthy = $false }
        }
    }

    if (-not $allHealthy) {
        Write-Host "`n⚠️  ATENÇÃO: Algumas APIs obrigatórias não estão rodando!" -ForegroundColor Red
        Write-Host "💡 Execute: .\Start-AllServices.ps1" -ForegroundColor Yellow
        Write-Host ""

        $continue = Read-Host "Deseja continuar mesmo assim? (S/N)"
        if ($continue -ne 'S') {
            Write-Host "❌ Execução cancelada pelo usuário" -ForegroundColor Red
            return
        }
    }

    Write-Host ""
}

# Resultados agregados
$results = @{
    StartTime = Get-Date
    Phase1 = $null
    Phase2 = $null
    Phase3 = $null
    Phase4 = $null
    Errors = @()
}

# ==========================================
# FASE 1: INVENTÁRIO DE DISPOSITIVOS
# ==========================================
if ($Phase -eq 'All' -or $Phase -eq '1') {
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host "FASE 1: INVENTÁRIO DE DISPOSITIVOS" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""

    try {
        # 1.1 - SCCM Inventory
        Write-Host "📊 AÇÃO 1.1: Coletando inventário SCCM..." -ForegroundColor Yellow
        Write-Host ""

        $sccmResult = & (Join-Path $PSScriptRoot "Collect-SCCM-Inventory.ps1") -Verbose:$VerbosePreference

        if ($sccmResult.Success) {
            Write-Host "✅ Inventário SCCM concluído: $($sccmResult.DeviceCount) dispositivos" -ForegroundColor Green
            $results.Phase1 = @{ SCCM = $sccmResult }
        }
        else {
            throw "Falha na coleta SCCM: $($sccmResult.Error)"
        }

        Write-Host ""

        # 1.2 - Intune Inventory
        Write-Host "☁️  AÇÃO 1.2: Coletando inventário Intune..." -ForegroundColor Yellow
        Write-Host ""

        $intuneResult = & (Join-Path $PSScriptRoot "Collect-Intune-Inventory.ps1") -Verbose:$VerbosePreference

        if ($intuneResult.Success) {
            Write-Host "✅ Inventário Intune concluído: $($intuneResult.DeviceCount) dispositivos" -ForegroundColor Green
            $results.Phase1.Intune = $intuneResult
        }
        else {
            throw "Falha na coleta Intune: $($intuneResult.Error)"
        }

        Write-Host ""

        # 1.3 - Consolidação
        Write-Host "🔗 AÇÃO 1.3: Consolidando inventários..." -ForegroundColor Yellow
        Write-Host ""

        $consolidatedResult = & (Join-Path $PSScriptRoot "Consolidate-DeviceInventory.ps1") -Verbose:$VerbosePreference

        if ($consolidatedResult.Success) {
            Write-Host "✅ Consolidação concluída: $($consolidatedResult.TotalDevices) dispositivos únicos" -ForegroundColor Green
            $results.Phase1.Consolidated = $consolidatedResult
        }
        else {
            throw "Falha na consolidação: $($consolidatedResult.Error)"
        }

        Write-Host ""
        Write-Host ("="*100) -ForegroundColor Green
        Write-Host "✅ FASE 1 CONCLUÍDA COM SUCESSO" -ForegroundColor Green
        Write-Host ("="*100) -ForegroundColor Green
        Write-Host ""
    }
    catch {
        $results.Errors += "Fase 1: $_"
        Write-Error "❌ Erro na Fase 1: $_"
    }
}

# ==========================================
# FASE 2: INVENTÁRIO DE SOFTWARE (FUTURO)
# ==========================================
if ($Phase -eq 'All' -or $Phase -eq '2') {
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host "FASE 2: INVENTÁRIO DE SOFTWARE (Amostragem)" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "⚠️  Fase 2 ainda não implementada" -ForegroundColor Yellow
    Write-Host "📝 Scripts necessários:" -ForegroundColor White
    Write-Host "   - Collect-Software-Inventory-Sample.ps1"
    Write-Host "   - Analyze-Common-Applications.ps1"
    Write-Host ""
    Write-Host "💡 Consulte: docs\PLANO_COLETA_DADOS_REMEDIACAO.md (Ação 2)" -ForegroundColor Cyan
    Write-Host ""
}

# ==========================================
# FASE 3: MATCHING COM VULNERABILIDADES (FUTURO)
# ==========================================
if ($Phase -eq 'All' -or $Phase -eq '3') {
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host "FASE 3: MATCHING COM VULNERABILIDADES" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "⚠️  Fase 3 ainda não implementada" -ForegroundColor Yellow
    Write-Host "📝 Scripts necessários:" -ForegroundColor White
    Write-Host "   - Import-Tenable-Production.ps1"
    Write-Host "   - Match-Software-Vulnerabilities.ps1"
    Write-Host ""
    Write-Host "💡 Consulte: docs\PLANO_COLETA_DADOS_REMEDIACAO.md (Ação 3)" -ForegroundColor Cyan
    Write-Host ""
}

# ==========================================
# FASE 4: ANÁLISE E RELATÓRIOS (FUTURO)
# ==========================================
if ($Phase -eq 'All' -or $Phase -eq '4') {
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host "FASE 4: ANÁLISE E RELATÓRIOS" -ForegroundColor Cyan
    Write-Host ("="*100) -ForegroundColor Cyan
    Write-Host ""

    Write-Host "⚠️  Fase 4 ainda não implementada" -ForegroundColor Yellow
    Write-Host "📝 Scripts necessários:" -ForegroundColor White
    Write-Host "   - Generate-Production-Dashboard.ps1"
    Write-Host ""
    Write-Host "💡 Consulte: docs\PLANO_COLETA_DADOS_REMEDIACAO.md (Ação 4)" -ForegroundColor Cyan
    Write-Host ""
}

# ==========================================
# RESUMO FINAL
# ==========================================
$results.EndTime = Get-Date
$results.Duration = $results.EndTime - $results.StartTime

Write-Host ("="*100) -ForegroundColor Cyan
Write-Host "📊 RESUMO DA EXECUÇÃO" -ForegroundColor Cyan
Write-Host ("="*100) -ForegroundColor Cyan
Write-Host ""
Write-Host "⏱️  Duração Total:" -ForegroundColor Yellow -NoNewline
Write-Host " $([math]::Round($results.Duration.TotalMinutes, 2)) minutos"
Write-Host "📅 Início:" -ForegroundColor Yellow -NoNewline
Write-Host " $($results.StartTime.ToString('HH:mm:ss'))"
Write-Host "📅 Fim:" -ForegroundColor Yellow -NoNewline
Write-Host " $($results.EndTime.ToString('HH:mm:ss'))"
Write-Host ""

if ($results.Phase1) {
    Write-Host "✅ FASE 1 - Inventário de Dispositivos" -ForegroundColor Green
    Write-Host "   📊 SCCM: $($results.Phase1.SCCM.DeviceCount) dispositivos"
    Write-Host "   ☁️  Intune: $($results.Phase1.Intune.DeviceCount) dispositivos"
    Write-Host "   🔗 Consolidado: $($results.Phase1.Consolidated.TotalDevices) únicos"
    Write-Host "      - Somente SCCM: $($results.Phase1.Consolidated.SCCMOnly)"
    Write-Host "      - Somente Intune: $($results.Phase1.Consolidated.IntuneOnly)"
    Write-Host "      - Híbrido: $($results.Phase1.Consolidated.Hybrid)"
    Write-Host ""
}

if ($results.Errors.Count -gt 0) {
    Write-Host "❌ ERROS ENCONTRADOS:" -ForegroundColor Red
    $results.Errors | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "📁 ARQUIVOS GERADOS:" -ForegroundColor Yellow
$exportPath = Join-Path $PSScriptRoot "..\..\..\exports\data-collection"
Get-ChildItem $exportPath -Filter "*$(Get-Date -Format 'yyyyMMdd')*.csv" | ForEach-Object {
    Write-Host "   - $($_.Name)" -ForegroundColor White
}
Write-Host ""

Write-Host ("="*100) -ForegroundColor Cyan
Write-Host "🎉 COLETA DE DADOS CONCLUÍDA!" -ForegroundColor Green
Write-Host ("="*100) -ForegroundColor Cyan
Write-Host ""

Write-Host "💡 PRÓXIMOS PASSOS:" -ForegroundColor Cyan
Write-Host "   1. Revisar arquivos CSV gerados em: $exportPath"
Write-Host "   2. Executar Fase 2 (Inventário de Software) quando pronto"
Write-Host "   3. Consultar plano completo: docs\PLANO_COLETA_DADOS_REMEDIACAO.md"
Write-Host ""

# Retornar resultado
return $results
