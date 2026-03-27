[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://localhost:3001'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot 'api/.env'

if (-not (Test-Path $envFile)) {
    Write-Error "Arquivo .env não encontrado em $envFile"
}

$raw = Get-Content $envFile -Raw

function Get-EnvValueFromRaw {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Key
    )

    $pattern = "(?m)^$Key=(.*)$"
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) { return '' }
    return $match.Groups[1].Value.Trim()
}

function Test-IsConfiguredValue {
    param([AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

    $normalized = $Value.Trim().ToLowerInvariant()
    if ($normalized -in @('your-tenant-id', 'your-client-id', 'your-client-secret', '<tenant-id>', '<client-id>', '<client-secret>', 'path/to/cert.pem', '<cert-path>')) {
        return $false
    }

    return $true
}

$tenantValue = Get-EnvValueFromRaw -Content $raw -Key 'TENANT_ID'
$clientValue = Get-EnvValueFromRaw -Content $raw -Key 'CLIENT_ID'
$certPathValue = Get-EnvValueFromRaw -Content $raw -Key 'CERT_PRIVATE_KEY_PATH'
$thumbprintValue = Get-EnvValueFromRaw -Content $raw -Key 'CERT_THUMBPRINT'

$hasTenant = Test-IsConfiguredValue -Value $tenantValue
$hasClient = Test-IsConfiguredValue -Value $clientValue
$hasCertPath = Test-IsConfiguredValue -Value $certPathValue
$hasThumbprint = Test-IsConfiguredValue -Value $thumbprintValue
$hasCertificateAuth = $hasCertPath -and $hasThumbprint

Write-Host '=== Pré-validação de Credenciais Graph ===' -ForegroundColor Cyan
Write-Host "TENANT_ID configurado: $hasTenant"
Write-Host "CLIENT_ID configurado: $hasClient"
Write-Host "CERT_PRIVATE_KEY_PATH configurado: $hasCertPath"
Write-Host "CERT_THUMBPRINT configurado: $hasThumbprint"

Write-Host '=== Smoke Test API ===' -ForegroundColor Cyan
$health = Invoke-RestMethod -Uri "$ApiBaseUrl/health" -Method GET
Write-Host "Health: $($health.status)" -ForegroundColor Green

$spConfig = Invoke-RestMethod -Uri "$ApiBaseUrl/api/v1/sharepoint/config" -Method GET
Write-Host "Auth atual: $($spConfig.data.isAuthenticated)"
Write-Host "Runtime tenant configured: $($spConfig.data.tenantIdConfigured)"
Write-Host "Runtime client configured: $($spConfig.data.clientIdConfigured)"
Write-Host "Runtime certificate path configured: $($spConfig.data.certificatePathConfigured)"
Write-Host "Runtime certificate thumbprint configured: $($spConfig.data.certificateThumbprintConfigured)"
Write-Host "Runtime auth method: $($spConfig.data.authMethod)"

if (-not ($hasTenant -and $hasClient -and $hasCertificateAuth)) {
    Write-Warning 'Credenciais Graph ausentes no .env. Configure TENANT_ID, CLIENT_ID, CERT_PRIVATE_KEY_PATH e CERT_THUMBPRINT.' 
    exit 2
}

Write-Host 'Tentando autenticação Graph...' -ForegroundColor Cyan
$auth = Invoke-RestMethod -Uri "$ApiBaseUrl/api/v1/sharepoint/authenticate" -Method POST
Write-Host "Autenticação success: $($auth.success)" -ForegroundColor Green

Write-Host 'Validação SharePoint concluída.' -ForegroundColor Green
