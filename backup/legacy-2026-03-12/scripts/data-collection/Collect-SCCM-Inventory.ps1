<#
.SYNOPSIS
    Coleta inventário completo de dispositivos do SCCM

.DESCRIPTION
    Script para coleta de inventário completo de todos os dispositivos ativos no SCCM
    Executa query SQL via API e exporta para CSV
    IMPACTO: ZERO - Apenas leitura (SELECT)

.PARAMETER ExportPath
    Caminho para exportar o CSV resultante

.PARAMETER APIBaseUrl
    URL base da CVE API (padrão: http://localhost:3001)

.EXAMPLE
    .\Collect-SCCM-Inventory.ps1
    .\Collect-SCCM-Inventory.ps1 -ExportPath "C:\Reports" -Verbose

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
    [string]$APIBaseUrl = "http://localhost:3001"
)

# Garantir que o diretório de export existe
if (-not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputFile = Join-Path $ExportPath "SCCM-Inventory-Full-$timestamp.csv"

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "📊 COLETA DE INVENTÁRIO SCCM" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""

# Query SQL para inventário completo
$query = @"
SELECT DISTINCT
    sys.ResourceID,
    sys.Netbios_Name0 AS DeviceName,
    sys.Resource_Domain_OR_Workgr0 AS Domain,
    sys.Operating_System_Name_and0 AS OS,
    sys.Build01 AS OSBuild,
    sys.Client_Version0 AS SCCMClientVersion,
    sys.Last_Logon_Timestamp0 AS LastLogon,
    sys.AD_Site_Name0 AS ADSite,
    sys.User_Name0 AS PrimaryUser,
    cs.UserName0 AS LastUser,
    cs.Manufacturer0 AS Manufacturer,
    cs.Model0 AS Model,
    cs.TotalPhysicalMemory0 AS RAMKb,
    cs.NumberOfProcessors0 AS CPUCount,
    ws.LastHWScan AS LastHardwareScan,
    sys.Client0 AS HasSCCMClient,
    sys.Obsolete0 AS IsObsolete,
    sys.Active0 AS IsActive
FROM v_R_System sys
LEFT JOIN v_GS_COMPUTER_SYSTEM cs ON sys.ResourceID = cs.ResourceID
LEFT JOIN v_GS_WORKSTATION_STATUS ws ON sys.ResourceID = ws.ResourceID
WHERE sys.Client0 = 1           -- Tem cliente SCCM
  AND sys.Obsolete0 = 0         -- Não está obsoleto
  AND sys.Operating_System_Name_and0 LIKE '%Windows%'
ORDER BY sys.Netbios_Name0
"@

Write-Verbose "Query SQL preparada: $(($query -split "`n").Count) linhas"

# Preparar body da requisição
$body = @{
    query = $query
    queryType = "discovery"
} | ConvertTo-Json -Depth 10

Write-Host "🔍 Executando query no SCCM..." -ForegroundColor Yellow

try {
    # Executar query via API
    $response = Invoke-RestMethod -Uri "$APIBaseUrl/api/v1/sccm/query" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body `
        -ErrorAction Stop

    if ($response.success -and $response.data) {
        $deviceCount = $response.data.Count

        Write-Host "✅ Query executada com sucesso!" -ForegroundColor Green
        Write-Host "   Dispositivos encontrados: $deviceCount" -ForegroundColor White

        # Exportar para CSV
        Write-Host "`n📁 Exportando para CSV..." -ForegroundColor Yellow

        $response.data | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

        Write-Host "✅ Arquivo exportado: $outputFile" -ForegroundColor Green

        # Estatísticas
        Write-Host "`n📊 ESTATÍSTICAS:" -ForegroundColor Cyan

        $stats = @{
            Total = $deviceCount
            PorFabricante = $response.data | Group-Object Manufacturer | Sort-Object Count -Descending | Select-Object -First 5
            PorModelo = $response.data | Group-Object Model | Sort-Object Count -Descending | Select-Object -First 5
            PorOS = $response.data | Group-Object OS | Sort-Object Count -Descending
            PorADSite = $response.data | Group-Object ADSite | Sort-Object Count -Descending | Select-Object -First 10
        }

        Write-Host "`n   Top 5 Fabricantes:" -ForegroundColor White
        $stats.PorFabricante | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        Write-Host "`n   Top 5 Modelos:" -ForegroundColor White
        $stats.PorModelo | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        Write-Host "`n   Sistemas Operacionais:" -ForegroundColor White
        $stats.PorOS | ForEach-Object {
            Write-Host "      - $($_.Name): $($_.Count) dispositivos"
        }

        Write-Host "`n   Top 10 AD Sites:" -ForegroundColor White
        $stats.PorADSite | ForEach-Object {
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
        Write-Warning "⚠️  Query retornou sem dados ou falhou"
        Write-Warning "Response: $($response | ConvertTo-Json -Depth 2)"

        [PSCustomObject]@{
            Success = $false
            Error = "No data returned"
        }
    }
}
catch {
    Write-Error "❌ Erro ao executar query: $_"
    Write-Error "StackTrace: $($_.ScriptStackTrace)"

    [PSCustomObject]@{
        Success = $false
        Error = $_.Exception.Message
    }
}

Write-Host "`n" + ("="*80) -ForegroundColor Cyan
Write-Host "FIM DA COLETA" -ForegroundColor Cyan
Write-Host ("="*80) -ForegroundColor Cyan
Write-Host ""
