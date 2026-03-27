<#
.SYNOPSIS
    Executa inventario completo do ambiente SharePoint via API e salva na base PostgreSQL local.

.DESCRIPTION
    Dispara os endpoints de inventario/listagem com refresh=true para forcar consulta em tempo real
    no Microsoft Graph e persistir automaticamente nas tabelas shp.sharepoint_*.

.PARAMETER ApiBaseUrl
    URL base da API SharePoint. Ex: http://localhost:3001/api/v1/sharepoint

.PARAMETER Search
    Filtro de busca para sites. Default: *

.PARAMETER TopSites
    Quantidade de sites para varredura inicial. Default: 100

.PARAMETER TopItemsPerDrive
    Quantidade maxima de itens por drive para metadata. Default: 200

.PARAMETER TeamIds
    Lista opcional de Team IDs para inventario de canais/membros/conteudo.

.EXAMPLE
    .\scripts\Run-SharePoint-FullInventory.ps1

.EXAMPLE
    .\scripts\Run-SharePoint-FullInventory.ps1 -TopSites 200 -TeamIds @('team-1','team-2')
#>

[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://localhost:3001/api/v1/sharepoint',
    [string]$Search = '*',
    [int]$TopSites = 100,
    [int]$TopItemsPerDrive = 200,
    [string[]]$TeamIds = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Api {
    param(
        [ValidateSet('GET', 'POST')]
        [string]$Method,
        [string]$Url,
        [object]$Body
    )

    $headers = @{
        'x-client-surface' = 'inventory-script'
        'x-actor' = 'inventory-script'
    }

    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $Url -Headers $headers
    }

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method Post -Uri $Url -Headers $headers
    }

    return Invoke-RestMethod -Method Post -Uri $Url -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10)
}

function Get-Id {
    param([object]$obj)
    if ($null -eq $obj) { return '' }
    if ($obj.PSObject.Properties.Name -contains 'id') { return [string]$obj.id }
    return ''
}

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║      SHP-MGMT-API :: Inventario Completo SharePoint      ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

Write-Host '[1/8] Autenticando no Microsoft Graph...' -ForegroundColor Cyan
$auth = Invoke-Api -Method POST -Url "$ApiBaseUrl/authenticate" -Body $null
if (-not $auth.success) { throw 'Falha na autenticacao do Graph.' }
Write-Host '   ✅ Autenticado' -ForegroundColor Green

Write-Host '[2/8] Coletando sites (refresh=true)...' -ForegroundColor Cyan
$sitesResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/sites?search=$([uri]::EscapeDataString($Search))&top=$TopSites&refresh=true"
$sites = @($sitesResponse.data)
Write-Host "   ✅ Sites coletados: $($sites.Count)" -ForegroundColor Green

$driveCount = 0
$libraryCount = 0
$itemCount = 0
$permissionCount = 0

Write-Host '[3/8] Coletando drives e libraries por site...' -ForegroundColor Cyan
foreach ($site in $sites) {
    $siteId = Get-Id $site
    if ([string]::IsNullOrWhiteSpace($siteId)) { continue }

    $drivesResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/sites/$([uri]::EscapeDataString($siteId))/drives?refresh=true"
    $drives = @($drivesResponse.data)
    $driveCount += $drives.Count

    $libsResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/sites/$([uri]::EscapeDataString($siteId))/libraries?refresh=true"
    $libraries = @($libsResponse.data)
    $libraryCount += $libraries.Count

    foreach ($drive in $drives) {
        $driveId = Get-Id $drive
        if ([string]::IsNullOrWhiteSpace($driveId)) { continue }

        $itemsResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/drives/$([uri]::EscapeDataString($driveId))/files-metadata?path=&top=$TopItemsPerDrive&refresh=true"
        $items = @($itemsResponse.data)
        $itemCount += $items.Count

        foreach ($item in $items | Select-Object -First 30) {
            $itemId = Get-Id $item
            if ([string]::IsNullOrWhiteSpace($itemId)) { continue }
            try {
                $permResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/drives/$([uri]::EscapeDataString($driveId))/items/$([uri]::EscapeDataString($itemId))/permissions?refresh=true"
                $permissionCount += @($permResponse.data).Count
            } catch {
                # Algumas entidades podem nao suportar listagem de permissoes no contexto atual.
            }
        }
    }
}
Write-Host "   ✅ Drives: $driveCount | Libraries: $libraryCount | Itens: $itemCount | Permissoes: $permissionCount" -ForegroundColor Green

Write-Host '[4/8] Coletando grupos (refresh=true)...' -ForegroundColor Cyan
try {
    $groupsResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/groups?search=&top=200&refresh=true"
    $groups = @($groupsResponse.data)
    Write-Host "   ✅ Grupos: $($groups.Count)" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Nao foi possivel listar grupos: $($_.Exception.Message)" -ForegroundColor Yellow
    $groups = @()
}

Write-Host '[5/8] Coletando usuarios e licencas (refresh=true)...' -ForegroundColor Cyan
$userCount = 0
$licenseCount = 0
try {
    $usersResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/users?search=&top=200&refresh=true"
    $users = @($usersResponse.data)
    $userCount = $users.Count

    foreach ($user in $users) {
        $userId = Get-Id $user
        if ([string]::IsNullOrWhiteSpace($userId)) { continue }
        try {
            $licensesResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/users/$([uri]::EscapeDataString($userId))/licenses?refresh=true"
            $licenseCount += @($licensesResponse.data).Count
        } catch {
            # Nem todo usuario retorna licencas conforme permissao do app.
        }
    }

    Write-Host "   ✅ Usuarios: $userCount | Licencas: $licenseCount" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Nao foi possivel listar usuarios: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host '[6/8] Executando export consolidado tenant-sharepoint-inventory...' -ForegroundColor Cyan
$null = Invoke-Api -Method GET -Url "$ApiBaseUrl/export?source=tenant-sharepoint-inventory&format=json&search=$([uri]::EscapeDataString($Search))&topSites=$TopSites&topItemsPerDrive=$TopItemsPerDrive&includePermissions=true&includeChannelPermissions=true"
Write-Host '   ✅ Export consolidado executado e persistido' -ForegroundColor Green

if ($TeamIds.Count -gt 0) {
    Write-Host '[7/8] Coletando dados de Teams e canais...' -ForegroundColor Cyan
    foreach ($teamId in $TeamIds) {
        if ([string]::IsNullOrWhiteSpace($teamId)) { continue }

        try {
            $channelsResponse = Invoke-Api -Method GET -Url "$ApiBaseUrl/teams/$([uri]::EscapeDataString($teamId))/channels?refresh=true"
            $channels = @($channelsResponse.data)

            foreach ($channel in $channels) {
                $channelId = Get-Id $channel
                if ([string]::IsNullOrWhiteSpace($channelId)) { continue }

                try {
                    $null = Invoke-Api -Method GET -Url "$ApiBaseUrl/teams/$([uri]::EscapeDataString($teamId))/channels/$([uri]::EscapeDataString($channelId))/members?refresh=true"
                } catch {}

                try {
                    $null = Invoke-Api -Method GET -Url "$ApiBaseUrl/teams/$([uri]::EscapeDataString($teamId))/channels/$([uri]::EscapeDataString($channelId))/content?topMessages=50&refresh=true"
                } catch {}
            }
        } catch {
            Write-Host "   ⚠️  Falha no inventario do team '$teamId': $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host '   ✅ Inventario de Teams finalizado' -ForegroundColor Green
} else {
    Write-Host '[7/8] Sem TeamIds informados; etapa de canais ignorada.' -ForegroundColor DarkYellow
}

Write-Host '[8/8] Finalizado. Dados persistidos no PostgreSQL da API.' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Dica: use /api/v1/sharepoint/* sem refresh para listar primeiro da base local.' -ForegroundColor Gray
Write-Host 'Para forcar tempo real e atualizar cache: adicione ?refresh=true.' -ForegroundColor Gray
Write-Host ''
