[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://localhost:3001/api/v1',
    [string]$SiteSearch = '*'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ApiGet {
    param([Parameter(Mandatory)][string]$Url)
    Invoke-RestMethod -Method Get -Uri $Url -TimeoutSec 30
}

function Invoke-ApiPost {
    param(
        [Parameter(Mandatory)][string]$Url,
        [object]$Body
    )

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method Post -Uri $Url -TimeoutSec 30
    }

    Invoke-RestMethod -Method Post -Uri $Url -TimeoutSec 30 -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 6)
}

Write-Host '=== Teste SharePoint Graph API ===' -ForegroundColor Cyan
Write-Host "API: $ApiBaseUrl"

$health = Invoke-ApiGet -Url ($ApiBaseUrl -replace '/api/v1$', '/health')
Write-Host "Health: $($health.status)" -ForegroundColor Green

$config = Invoke-ApiGet -Url "$ApiBaseUrl/sharepoint/config"
Write-Host "Config carregada. Auth atual: $($config.data.isAuthenticated)"
Write-Host "Modo de auth: $($config.data.authMethod)"
Write-Host "Thumbprint carregado: $($config.data.certificateThumbprintConfigured)"

$auth = Invoke-ApiPost -Url "$ApiBaseUrl/sharepoint/authenticate"
Write-Host "Autenticacao: $($auth.success)" -ForegroundColor Green

$sites = Invoke-ApiGet -Url "$ApiBaseUrl/sharepoint/sites?search=$([uri]::EscapeDataString($SiteSearch))&top=5"
Write-Host "Sites encontrados: $($sites.count)" -ForegroundColor Yellow

if ($sites.count -gt 0) {
    $siteId = $sites.data[0].id
    Write-Host "Primeiro site: $($sites.data[0].displayName)"

    $drives = Invoke-ApiGet -Url "$ApiBaseUrl/sharepoint/sites/$([uri]::EscapeDataString($siteId))/drives"
    Write-Host "Bibliotecas encontradas: $($drives.count)" -ForegroundColor Yellow
}

Write-Host 'Teste concluido.' -ForegroundColor Cyan
