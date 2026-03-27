<#
.SYNOPSIS
    Coleta inventário de dispositivos do Microsoft Intune

.DESCRIPTION
    Script para coleta de dispositivos gerenciados no Intune via API Autopilot
    Sincroniza com Intune e exporta dados para CSV
    IMPACTO: ZERO - Apenas leitura (GET)

.PARAMETER ExportPath
    Caminho para exportar o CSV resultante

.PARAMETER APIBaseUrl
    URL base da Autopilot API (padrão: http://localhost:3002)

.PARAMETER SyncFirst
    Se deve sincronizar com Intune antes de coletar (padrão: $true)

.EXAMPLE
    .\Collect-Intune-Inventory.ps1
    .\Collect-Intune-Inventory.ps1 -SyncFirst $false -Verbose

.NOTES
    Autor: CVE Management System
    Data: 20/01/2026
    Versão: 1.0.0
    Impacto: ZERO (Read-Only)
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ExportPath = (Join-Path $PSScriptRoot "..\..\..\exports\data-collection"),

    [Parameter()]
    [string]$APIBaseUrl = "http://localhost:3002",

    [Parameter()]
    [bool]$SyncFirst = $true
)

# Garantir que o diretório de export existe
if (-not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $ExportPath "Intune-Inventory-Full-$timestamp.csv"

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "☁️  COLETA DE INVENTÁRIO INTUNE" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""

try {
    # Verificar health da API
    Write-Host "🔍 Verificando API Autopilot..." -ForegroundColor Yellow

    $healthCheck = Invoke-RestMethod -Uri "$APIBaseUrl/health" -ErrorAction Stop

    if ($healthCheck.status -eq "healthy") {
        Write-Host "✅ API Autopilot está saudável" -ForegroundColor Green
    }
    else {
        Write-Warning "⚠️  API Autopilot retornou status: $($healthCheck.status)"
    }

    # Sincronizar com Intune primeiro (se solicitado)
    if ($SyncFirst) {
        Write-Host "`n🔄 Sincronizando com Microsoft Intune..." -ForegroundColor Yellow

        try {
            $syncResponse = Invoke-RestMethod -Uri "$APIBaseUrl/api/v1/autopilot/sync" `
                -Method Post `
                -ErrorAction Stop

            if ($syncResponse.success) {
                Write-Host "✅ Sincronização iniciada com sucesso" -ForegroundColor Green
                Write-Host "   Aguardando 30 segundos para conclusão..." -ForegroundColor White
                Start-Sleep -Seconds 30
            }
        }
        catch {
            Write-Warning "⚠️  Erro na sincronização: $($_.Exception.Message)"
            Write-Warning "   Continuando com dados existentes..."
        }
    }

    # Obter dispositivos do Intune
    Write-Host "`n📥 Obtendo dispositivos do Intune..." -ForegroundColor Yellow

    $devicesResponse = Invoke-RestMethod -Uri "$APIBaseUrl/api/v1/autopilot/devices?limit=10000" `
        -ErrorAction Stop

    if ($devicesResponse.success -and $devicesResponse.data) {
        $deviceCount = $devicesResponse.data.Count

        Write-Host "✅ Dispositivos obtidos com sucesso!" -ForegroundColor Green
        Write-Host "   Total de dispositivos: $deviceCount" -ForegroundColor White

        # Enriquecer dados com formatação
        $enrichedData = $devicesResponse.data | ForEach-Object {
            [PSCustomObject]@{
                DeviceName = $_.displayName
                SerialNumber = $_.serialNumber
                Manufacturer = $_.manufacturer
                Model = $_.model
                EnrollmentState = $_.enrollmentState
                LastContactDateTime = $_.lastContactDateTime
                OSVersion = $_.osVersion
                UserPrincipalName = $_.userPrincipalName ?? "N/A"
                AzureADDeviceId = $_.azureADDeviceId ?? "N/A"
                ManagedDeviceId = $_.managedDeviceId ?? "N/A"
                DeviceRegistrationState = $_.deviceRegistrationState ?? "N/A"
                ManagementState = $_.managementState ?? "N/A"
                EncryptionState = $_.encryptionState ?? "N/A"
            }
        }

        # Exportar para CSV
        Write-Host "`n📁 Exportando para CSV..." -ForegroundColor Yellow

        $enrichedData | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

        Write-Host "✅ Arquivo exportado: $outputFile" -ForegroundColor Green

        # Estatísticas
        Write-Host "`n📊 ESTATÍSTICAS:" -ForegroundColor Cyan

        $stats = @{
            Total = $deviceCount
            PorFabricante = $enrichedData | Group-Object Manufacturer | Sort-Object Count -Descending
            PorModelo = $enrichedData | Group-Object Model | Sort-Object Count -Descending | Select-Object -First 5
            PorEnrollmentState = $enrichedData | Group-Object EnrollmentState | Sort-Object Count -Descending
            PorOSVersion = $enrichedData | Group-Object OSVersion | Sort-Object Count -Descending | Select-Object -First 5
        }

        Write-Host "`n   Fabricantes:" -ForegroundColor White
        $stats.PorFabricante | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        Write-Host "`n   Top 5 Modelos:" -ForegroundColor White
        $stats.PorModelo | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        Write-Host "`n   Status de Enrollment:" -ForegroundColor White
        $stats.PorEnrollmentState | ForEach-Object {
            $color = switch ($_.Name) {
                'enrolled' { 'Green' }
                'pending' { 'Yellow' }
                default { 'White' }
            }
            Write-Host "      - $($_.Name): $($_.Count) dispositivos" -ForegroundColor $color
        }

        Write-Host "`n   Top 5 Versões de SO:" -ForegroundColor White
        $stats.PorOSVersion | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        # Retornar informações
        [PSCustomObject]@{
            Success = $true
            DeviceCount = $deviceCount
            OutputFile = $outputFile
            Statistics = $stats
        }
    }
    else {
        Write-Warning "⚠️  API retornou sem dados ou falhou"

        [PSCustomObject]@{
            Success = $false
            Error = "No data returned"
        }
    }
}
catch {
    Write-Error "❌ Erro ao coletar dispositivos Intune: $_"
    Write-Error "StackTrace: $($_.ScriptStackTrace)"

    # Verificar se a API está acessível
    Write-Host "`n💡 Dicas de troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Verifique se a API Autopilot está rodando: curl $APIBaseUrl/health"
    Write-Host "   2. Verifique credenciais Azure AD no .env"
    Write-Host "   3. Execute: .\Start-AllServices.ps1"

    [PSCustomObject]@{
        Success = $false
        Error = $_.Exception.Message
    }
}

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "FIM DA COLETA" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""
