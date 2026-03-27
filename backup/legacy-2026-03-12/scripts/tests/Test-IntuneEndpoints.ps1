<#
.SYNOPSIS
    Testa endpoints do Microsoft Graph / Intune

.DESCRIPTION
    Script para testar endpoints de Intune/Microsoft Graph
    incluindo autenticação, dispositivos e grupos.

.NOTES
    Autor: CVE Management Team
    Data: 2026-01-10
    Versão: 2.0
    Configuração: cves/config/config.json
    Repositório: PSAppDeployToolkit/cves

.EXAMPLE
    .\Test-IntuneEndpoints.ps1
#>

# Carregar configuração centralizada
try {
    $Config = & (Join-Path $PSScriptRoot '..\common\Get-ProjectConfig.ps1')
}
catch {
    Write-Error "Falha ao carregar configuração: $_"
    exit 1
}

$ErrorActionPreference = 'Stop'
$baseUrl = "http://$($Config.Api.Host):$($Config.Api.Port)$($Config.Api.Prefix)"

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TESTE DOS ENDPOINTS MICROSOFT INTUNE / GRAPH API" -ForegroundColor Cyan
Write-Host "  Servidor: $baseUrl" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ====================================================================
# TESTE 1: Verificar configuração do Intune
# ====================================================================
Write-Host "🧪 TESTE 1: Verificar Configuração Intune" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

try {
    $config = Invoke-RestMethod -Uri "$baseUrl/intune/config" -Method Get -ErrorAction Stop

    if ($config.success) {
        Write-Host "✓ Configuração carregada com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Tenant ID:         $($config.data.tenantId)" -ForegroundColor White
        Write-Host "  Client ID:         $($config.data.clientId)" -ForegroundColor White
        Write-Host "  Autenticado:       $($config.data.isAuthenticated)" -ForegroundColor $(if($config.data.isAuthenticated){'Green'}else{'Red'})
        Write-Host "  Environment:       $($config.data.environment)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Features:" -ForegroundColor Cyan
        $config.data.features.PSObject.Properties | ForEach-Object {
            Write-Host "    • $($_.Name): $($_.Value)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "  Endpoints disponíveis:" -ForegroundColor Cyan
        $config.data.endpoints.PSObject.Properties | ForEach-Object {
            Write-Host "    • $($_.Value)" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        Write-Host "✗ Falha ao carregar configuração" -ForegroundColor Red
        Write-Host "  Erro: $($config.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Erro ao testar endpoint: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Start-Sleep -Seconds 1

# ====================================================================
# TESTE 2: Autenticar no Azure AD
# ====================================================================
Write-Host "🧪 TESTE 2: Autenticar no Azure AD" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

try {
    $auth = Invoke-RestMethod -Uri "$baseUrl/intune/authenticate" -Method Post -ErrorAction Stop

    if ($auth.success) {
        Write-Host "✓ Autenticação realizada com sucesso!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Tenant ID:         $($auth.data.tenantId)" -ForegroundColor White
        Write-Host "  Client ID:         $($auth.data.clientId)" -ForegroundColor White
        Write-Host "  Status:            Autenticado" -ForegroundColor Green
        Write-Host "  Timestamp:         $($auth.data.lastAuthTime)" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "✗ Falha na autenticação" -ForegroundColor Red
        Write-Host "  Erro: $($auth.error)" -ForegroundColor Red
        Write-Host "  Detalhes: $($auth.details)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Erro ao autenticar: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Verifique as credenciais na configuração" -ForegroundColor Yellow
}

Write-Host ""
Start-Sleep -Seconds 2

# ====================================================================
# TESTE 3: Buscar dispositivos gerenciados (primeiros 5)
# ====================================================================
Write-Host "🧪 TESTE 3: Buscar Dispositivos Gerenciados" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

try {
    $devices = Invoke-RestMethod -Uri "$baseUrl/intune/devices?top=5" -Method Get -ErrorAction Stop

    if ($devices.success) {
        Write-Host "✓ Dispositivos encontrados: $($devices.count)" -ForegroundColor Green
        Write-Host ""

        if ($devices.count -gt 0) {
            Write-Host "  Primeiros 5 dispositivos:" -ForegroundColor Cyan
            Write-Host ""

            foreach ($device in $devices.data) {
                Write-Host "  • $($device.displayName)" -ForegroundColor White
                Write-Host "    ID: $($device.id)" -ForegroundColor Gray
                Write-Host "    OS: $($device.operatingSystem)" -ForegroundColor Gray
                Write-Host "    Status: $($device.deviceEnrollmentType)" -ForegroundColor Gray
                Write-Host ""
            }
        } else {
            Write-Host "  ⚠️ Nenhum dispositivo encontrado" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Falha ao buscar dispositivos" -ForegroundColor Red
        Write-Host "  Erro: $($devices.error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Erro ao buscar dispositivos: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  TESTES CONCLUÍDOS" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
