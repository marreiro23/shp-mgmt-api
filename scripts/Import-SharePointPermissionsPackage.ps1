<#
.SYNOPSIS
Importa pacote de configuracoes/permissoes SharePoint no tenant conectado via API local.

.DESCRIPTION
Consome um arquivo JSON exportado do Operations Center (source=tenant-permissions-standard)
ou um JSON manual com array permissions, e envia para:
POST /api/v1/sharepoint/admin-governance/import/permissions-package

A autenticacao com Graph e feita pela API usando o metodo configurado no ambiente atual:
- app registration com certificado (CERT_PRIVATE_KEY_PATH/CERT_THUMBPRINT)
- app registration com secret (CLIENT_SECRET)

.EXAMPLE
.\scripts\Import-SharePointPermissionsPackage.ps1 -PackagePath ".\raw\permissions-package.json" -DryRun

.EXAMPLE
.\scripts\Import-SharePointPermissionsPackage.ps1 -ApiBaseUrl "http://localhost:3001/api/v1" -PackagePath ".\raw\permissions-package.json" -Mode update
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApiBaseUrl = 'http://localhost:3001/api/v1',

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackagePath,

    [Parameter()]
    [ValidateSet('always', 'skip-if-exists', 'update', 'replace-safe')]
    [string]$Mode = 'update',

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$SkipAuthenticate,

    [Parameter()]
    [switch]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath {
    param([Parameter(Mandatory)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location) -ChildPath $Path))
}

function Read-PermissionsPackage {
    param([Parameter(Mandatory)][string]$Path)

    $resolvedPath = Resolve-AbsolutePath -Path $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "Arquivo de pacote nao encontrado: $resolvedPath"
    }

    $raw = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
    $json = $raw | ConvertFrom-Json -Depth 100

    if ($json.permissions) {
        return @($json.permissions)
    }

    if ($json.data -and $json.data.permissions) {
        return @($json.data.permissions)
    }

    throw 'Nao foi encontrado array permissions no arquivo informado.'
}

function Write-Result {
    param([Parameter(Mandatory)]$Data)

    if ($OutputJson.IsPresent) {
        $Data | ConvertTo-Json -Depth 10 -Compress | Write-Output
        return
    }

    Write-Output $Data
}

$permissions = Read-PermissionsPackage -Path $PackagePath

if (-not $SkipAuthenticate.IsPresent) {
    try {
        $authUrl = "$ApiBaseUrl/sharepoint/authenticate"
        Invoke-RestMethod -Uri $authUrl -Method Post -ContentType 'application/json' | Out-Null
        Write-Host "[auth] Graph authentication OK via API."
    }
    catch {
        Write-Warning "[auth] Falha na autenticacao inicial. Verifique CERT_PRIVATE_KEY_PATH/CERT_THUMBPRINT ou CLIENT_SECRET no ambiente da API."
        throw
    }
}

$payload = @{
    mode = $Mode
    dryRun = $DryRun.IsPresent
    permissions = $permissions
}

$importUrl = "$ApiBaseUrl/sharepoint/admin-governance/import/permissions-package"
$response = Invoke-RestMethod -Uri $importUrl -Method Post -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Depth 100)

Write-Result -Data $response
