<#
.SYNOPSIS
    Consolida inventários de SCCM e Intune em uma única visão

.DESCRIPTION
    Cruza dados de dispositivos do SCCM e Intune para criar visão unificada
    Identifica dispositivos gerenciados por:
    - Somente SCCM
    - Somente Intune
    - Ambos (gerenciamento híbrido)
    IMPACTO: ZERO - Apenas processamento local

.PARAMETER SCCMInventoryPath
    Caminho para o CSV de inventário SCCM (mais recente se não especificado)

.PARAMETER IntuneInventoryPath
    Caminho para o CSV de inventário Intune (mais recente se não especificado)

.PARAMETER ExportPath
    Caminho para exportar o CSV consolidado

.EXAMPLE
    .\Consolidate-DeviceInventory.ps1
    .\Consolidate-DeviceInventory.ps1 -Verbose

.NOTES
    Autor: CVE Management System
    Data: 20/01/2026
    Versão: 1.0.0
    Impacto: ZERO (Processamento Local)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SCCMInventoryPath,

    [Parameter()]
    [string]$IntuneInventoryPath,

    [Parameter()]
    [string]$ExportPath = (Join-Path $PSScriptRoot "..\..\..\exports\data-collection")
)

# Garantir que o diretório de export existe
if (-not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $ExportPath "Consolidated-Inventory-$timestamp.csv"

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "🔗 CONSOLIDAÇÃO DE INVENTÁRIOS" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""

try {
    # Localizar arquivos mais recentes se não especificados
    if (-not $SCCMInventoryPath) {
        Write-Host "🔍 Buscando inventário SCCM mais recente..." -ForegroundColor Yellow
        $SCCMInventoryPath = Get-ChildItem -Path $ExportPath -Filter "SCCM-Inventory-Full-*.csv" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

        if (-not $SCCMInventoryPath) {
            throw "Nenhum arquivo de inventário SCCM encontrado em $ExportPath"
        }
        Write-Host "   Encontrado: $(Split-Path $SCCMInventoryPath -Leaf)" -ForegroundColor Green
    }

    if (-not $IntuneInventoryPath) {
        Write-Host "🔍 Buscando inventário Intune mais recente..." -ForegroundColor Yellow
        $IntuneInventoryPath = Get-ChildItem -Path $ExportPath -Filter "Intune-Inventory-Full-*.csv" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName

        if (-not $IntuneInventoryPath) {
            throw "Nenhum arquivo de inventário Intune encontrado em $ExportPath"
        }
        Write-Host "   Encontrado: $(Split-Path $IntuneInventoryPath -Leaf)" -ForegroundColor Green
    }

    # Importar dados
    Write-Host "`n📥 Importando dados..." -ForegroundColor Yellow

    $sccmDevices = Import-Csv $SCCMInventoryPath
    $intuneDevices = Import-Csv $IntuneInventoryPath

    Write-Host "   SCCM: $($sccmDevices.Count) dispositivos" -ForegroundColor White
    Write-Host "   Intune: $($intuneDevices.Count) dispositivos" -ForegroundColor White

    # Consolidar dados
    Write-Host "`n🔗 Consolidando dados (cross-reference)..." -ForegroundColor Yellow

    $consolidated = @()
    $processedIntune = @()

    # Processar dispositivos SCCM
    foreach ($sccmDevice in $sccmDevices) {
        # Tentar matching por nome (case-insensitive)
        $intuneMatch = $intuneDevices | Where-Object {
            $_.DeviceName -eq $sccmDevice.DeviceName
        }

        if ($intuneMatch) {
            $processedIntune += $intuneMatch.DeviceName
        }

        $consolidated += [PSCustomObject]@{
            DeviceName = $sccmDevice.DeviceName
            InSCCM = $true
            InIntune = ($null -ne $intuneMatch)
            Manufacturer = $sccmDevice.Manufacturer ?? ($intuneMatch.Manufacturer ?? "N/A")
            Model = $sccmDevice.Model ?? ($intuneMatch.Model ?? "N/A")
            OS = $sccmDevice.OS ?? "N/A"
            OSBuild = $sccmDevice.OSBuild ?? "N/A"
            LastLogon = $sccmDevice.LastLogon ?? "N/A"
            ADSite = $sccmDevice.ADSite ?? "N/A"
            PrimaryUser = $sccmDevice.PrimaryUser ?? "N/A"
            Domain = $sccmDevice.Domain ?? "N/A"
            SCCMClientVersion = $sccmDevice.SCCMClientVersion ?? "N/A"
            IntuneEnrollmentState = if ($intuneMatch) { $intuneMatch.EnrollmentState } else { "N/A" }
            IntuneLastContact = if ($intuneMatch) { $intuneMatch.LastContactDateTime } else { "N/A" }
            SerialNumber = if ($intuneMatch) { $intuneMatch.SerialNumber } else { "N/A" }
            ManagementType = if ($intuneMatch) { "Hybrid (SCCM + Intune)" } else { "SCCM Only" }
        }
    }

    # Adicionar dispositivos que estão SOMENTE no Intune
    foreach ($intuneDevice in $intuneDevices) {
        if ($intuneDevice.DeviceName -notin $processedIntune) {
            $consolidated += [PSCustomObject]@{
                DeviceName = $intuneDevice.DeviceName
                InSCCM = $false
                InIntune = $true
                Manufacturer = $intuneDevice.Manufacturer ?? "N/A"
                Model = $intuneDevice.Model ?? "N/A"
                OS = $intuneDevice.OSVersion ?? "N/A"
                OSBuild = "N/A"
                LastLogon = "N/A"
                ADSite = "N/A"
                PrimaryUser = $intuneDevice.UserPrincipalName ?? "N/A"
                Domain = "N/A"
                SCCMClientVersion = "N/A"
                IntuneEnrollmentState = $intuneDevice.EnrollmentState
                IntuneLastContact = $intuneDevice.LastContactDateTime
                SerialNumber = $intuneDevice.SerialNumber ?? "N/A"
                ManagementType = "Intune Only"
            }
        }
    }

    # Exportar consolidado
    Write-Host "`n📁 Exportando dados consolidados..." -ForegroundColor Yellow

    $consolidated | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

    Write-Host "✅ Arquivo exportado: $outputFile" -ForegroundColor Green

    # Estatísticas
    Write-Host "`n📊 ESTATÍSTICAS CONSOLIDADAS:" -ForegroundColor Cyan

    $stats = @{
        Total = $consolidated.Count
        SomenteSCCM = ($consolidated | Where-Object { $_.InSCCM -and -not $_.InIntune }).Count
        SomenteIntune = ($consolidated | Where-Object { -not $_.InSCCM -and $_.InIntune }).Count
        Hibrido = ($consolidated | Where-Object { $_.InSCCM -and $_.InIntune }).Count
    }

    Write-Host "`n   Total de Dispositivos: $($stats.Total)" -ForegroundColor White
    Write-Host ""
    Write-Host "   📊 Distribuição por Gerenciamento:" -ForegroundColor Yellow
    Write-Host "      - Somente SCCM: $($stats.SomenteSCCM) ($([math]::Round($stats.SomenteSCCM / $stats.Total * 100, 1))%)" -ForegroundColor Cyan
    Write-Host "      - Somente Intune: $($stats.SomenteIntune) ($([math]::Round($stats.SomenteIntune / $stats.Total * 100, 1))%)" -ForegroundColor Magenta
    Write-Host "      - Híbrido (Ambos): $($stats.Hibrido) ($([math]::Round($stats.Hibrido / $stats.Total * 100, 1))%)" -ForegroundColor Green

    # Estatísticas por fabricante
    Write-Host "`n   📊 Top 5 Fabricantes:" -ForegroundColor Yellow
    $consolidated | Group-Object Manufacturer |
        Sort-Object Count -Descending |
        Select-Object -First 5 |
        ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

    # Estatísticas por tipo de gerenciamento
    Write-Host "`n   📊 Dispositivos por Tipo de Gerenciamento:" -ForegroundColor Yellow
    $consolidated | Group-Object ManagementType |
        Sort-Object Count -Descending |
        ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

    # Recomendações
    Write-Host "`n💡 RECOMENDAÇÕES:" -ForegroundColor Cyan

    if ($stats.SomenteSCCM -gt 0) {
        Write-Host "   ⚠️  $($stats.SomenteSCCM) dispositivos estão SOMENTE no SCCM" -ForegroundColor Yellow
        Write-Host "      Considere enrollar no Intune para gerenciamento moderno"
    }

    if ($stats.SomenteIntune -gt 0) {
        Write-Host "   ⚠️  $($stats.SomenteIntune) dispositivos estão SOMENTE no Intune" -ForegroundColor Yellow
        Write-Host "      Considere instalar cliente SCCM para inventário completo"
    }

    if ($stats.Hibrido -gt 0) {
        Write-Host "   ✅ $($stats.Hibrido) dispositivos com gerenciamento híbrido (ideal)" -ForegroundColor Green
    }

    # Retornar resultado
    [PSCustomObject]@{
        Success = $true
        TotalDevices = $stats.Total
        SCCMOnly = $stats.SomenteSCCM
        IntuneOnly = $stats.SomenteIntune
        Hybrid = $stats.Hibrido
        OutputFile = $outputFile
    }
}
catch {
    Write-Error "❌ Erro ao consolidar inventários: $_"
    Write-Error "StackTrace: $($_.ScriptStackTrace)"

    [PSCustomObject]@{
        Success = $false
        Error = $_.Exception.Message
    }
}

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "FIM DA CONSOLIDAÇÃO" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""
