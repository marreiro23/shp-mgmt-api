<#
.SYNOPSIS
Atualiza os escopos Microsoft Graph de uma App Registration usada pela API.

.DESCRIPTION
Lê o catálogo recomendado de permissões, gera o bloco RequiredResourceAccess e,
opcionalmente, cria as atribuições de app role para acelerar o consentimento administrativo.

.EXAMPLE
.\Update-GraphAppScopes.ps1 -ListRecommendedPermissions

.EXAMPLE
.\Update-GraphAppScopes.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -WhatIf -OutputJson

.EXAMPLE
.\Update-GraphAppScopes.ps1 -TenantId '<tenant-id>' -ClientId '<client-id>' -GrantAdminConsentAssignments -OutputJson

.OUTPUTS
PSCustomObject

.NOTES
Use apenas em contexto administrativo. O script não deve receber segredos; apenas IDs e permissões.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationObjectId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateThumbprint,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CertificatePath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$EnvFilePath = '..\api\.env',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$GraphApplicationPermissions,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PermissionCatalogPath = '..\config\graph-app-permissions.json',

    [Parameter()]
    [switch]$GrantAdminConsentAssignments,

    [Parameter()]
    [switch]$ListRecommendedPermissions,

    [Parameter()]
    [switch]$OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath $Path))
}

function Get-EnvSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = Resolve-RelativePath -Path $Path
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        return @{}
    }

    $settings = @{}
    $lines = Get-Content -LiteralPath $resolvedPath
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $trimmedLine = $line.Trim()
        if ($trimmedLine.StartsWith('#')) {
            continue
        }

        $separatorIndex = $trimmedLine.IndexOf('=')
        if ($separatorIndex -lt 1) {
            continue
        }

        $key = $trimmedLine.Substring(0, $separatorIndex).Trim()
        $value = $trimmedLine.Substring($separatorIndex + 1).Trim()
        $settings[$key] = $value
    }

    return $settings
}

function Get-EffectiveSetting {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$ExplicitValue,

        [Parameter(Mandatory)]
        [hashtable]$EnvSettings,

        [Parameter(Mandatory)]
        [string]$EnvKey
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitValue)) {
        return $ExplicitValue.Trim()
    }

    if ($EnvSettings.ContainsKey($EnvKey) -and -not [string]::IsNullOrWhiteSpace($EnvSettings[$EnvKey])) {
        return [string]$EnvSettings[$EnvKey]
    }

    return ''
}

function Normalize-Thumbprint {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Thumbprint
    )

    if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
        return ''
    }

    return ($Thumbprint -replace '[^a-fA-F0-9]', '').ToUpperInvariant()
}

function Get-CertificateFromPemFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedCertificatePath
    )

    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPemFile($ResolvedCertificatePath)
}

function Get-CertificateFromPfxFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedCertificatePath
    )

    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($ResolvedCertificatePath)
}

function Get-AppOnlyCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResolvedCertificatePath,

        [Parameter(Mandatory)]
        [string]$ExpectedThumbprint
    )

    if (-not (Test-Path -LiteralPath $ResolvedCertificatePath)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new("Certificado nao encontrado em '$ResolvedCertificatePath'."),
            'CertificateFileNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $ResolvedCertificatePath
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $extension = [System.IO.Path]::GetExtension($ResolvedCertificatePath)
    $certificate = if ($extension -ieq '.pem') {
        Get-CertificateFromPemFile -ResolvedCertificatePath $ResolvedCertificatePath
    }
    elseif ($extension -ieq '.pfx') {
        Get-CertificateFromPfxFile -ResolvedCertificatePath $ResolvedCertificatePath
    }
    else {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.NotSupportedException]::new("Formato de certificado nao suportado: '$extension'. Use .pem ou .pfx."),
            'UnsupportedCertificateFormat',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $ResolvedCertificatePath
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    if (-not $certificate.HasPrivateKey) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Security.Cryptography.CryptographicException]::new('O certificado carregado nao possui chave privada para autenticacao app-only.'),
            'CertificateWithoutPrivateKey',
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $ResolvedCertificatePath
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $actualThumbprint = Normalize-Thumbprint -Thumbprint $certificate.Thumbprint
    if ($ExpectedThumbprint -and $actualThumbprint -ne $ExpectedThumbprint) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Security.Cryptography.CryptographicException]::new("O thumbprint configurado nao corresponde ao certificado informado. Esperado '$ExpectedThumbprint' e encontrado '$actualThumbprint'."),
            'CertificateThumbprintMismatch',
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $ResolvedCertificatePath
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $certificate
}

function Write-ScriptOutput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Data
    )

    if ($OutputJson.IsPresent) {
        Write-Output ($Data | ConvertTo-Json -Depth 8 -Compress)
        return
    }

    Write-Output $Data
}

function Get-PermissionCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CatalogPath
    )

    $resolvedCatalogPath = Resolve-RelativePath -Path $CatalogPath
    if (-not (Test-Path -LiteralPath $resolvedCatalogPath)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.IO.FileNotFoundException]::new("Catalogo de permissoes nao encontrado em '$resolvedCatalogPath'."),
            'PermissionCatalogNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $resolvedCatalogPath
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return Get-Content -LiteralPath $resolvedCatalogPath -Raw | ConvertFrom-Json
}

function Get-RecommendedPermissionValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Catalog
    )

    return @($Catalog.recommendedApplicationPermissions | ForEach-Object { $_.name })
}

function Assert-RequiredInput {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [string]$ClientId,

        [Parameter()]
        [string]$CertificateThumbprint,

        [Parameter()]
        [string]$CertificatePath,

        [Parameter()]
        [string]$ApplicationObjectId
    )

    $missing = @()
    if (-not $TenantId) {
        $missing += 'TenantId'
    }

    if (-not $ClientId -and -not $ApplicationObjectId) {
        $missing += 'ClientId ou ApplicationObjectId'
    }

    if (-not $CertificateThumbprint) {
        $missing += 'CertificateThumbprint'
    }

    if (-not $CertificatePath) {
        $missing += 'CertificatePath'
    }

    if ($missing.Count -eq 0) {
        return
    }

    $message = @(
        "Parametros obrigatorios ausentes: $($missing -join ', ').",
        'Exemplo de preview:',
        '.\Update-GraphAppScopes.ps1 -TenantId "<tenant-id>" -ClientId "<client-id>" -CertificateThumbprint "<thumbprint>" -CertificatePath "..\certs\shp-mgmt-api.pem" -WhatIf -OutputJson',
        'Use -ListRecommendedPermissions para inspecionar a matriz de escopos recomendada.'
    ) -join [Environment]::NewLine

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.ArgumentException]::new($message),
        'MissingRequiredInput',
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $ClientId
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

function Ensure-GraphModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Verbose "Installing module $ModuleName"
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module -Name $ModuleName -Force
}

function Resolve-Application {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ApplicationObjectId,

        [Parameter()]
        [string]$ClientId
    )

    if ($ApplicationObjectId) {
        return Get-MgApplication -ApplicationId $ApplicationObjectId
    }

    if ($ClientId) {
        $apps = Get-MgApplication -Filter "appId eq '$ClientId'"
        if (-not $apps) {
            throw "Nao foi possivel encontrar app registration com ClientId '$ClientId'."
        }
        return $apps | Select-Object -First 1
    }

    throw 'Informe ApplicationObjectId ou ClientId.'
}

function Get-GraphAppRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$GraphServicePrincipal,

        [Parameter(Mandatory)]
        [string[]]$PermissionValues
    )

    $roles = @()
    foreach ($permission in $PermissionValues) {
        $match = $GraphServicePrincipal.AppRoles |
            Where-Object {
                $_.Value -eq $permission -and $_.AllowedMemberTypes -contains 'Application'
            }

        if (-not $match) {
            $valid = $GraphServicePrincipal.AppRoles |
                Where-Object { $_.AllowedMemberTypes -contains 'Application' } |
                Select-Object -ExpandProperty Value
            throw "Permissao de aplicativo '$permission' nao encontrada no Microsoft Graph. Permissoes validas: $($valid -join ', ')"
        }

        $roles += $match
    }

    return $roles
}

try {
    $envSettings = Get-EnvSettings -Path $EnvFilePath
    $permissionCatalog = Get-PermissionCatalog -CatalogPath $PermissionCatalogPath

    $TenantId = Get-EffectiveSetting -ExplicitValue $TenantId -EnvSettings $envSettings -EnvKey 'TENANT_ID'
    $ClientId = Get-EffectiveSetting -ExplicitValue $ClientId -EnvSettings $envSettings -EnvKey 'CLIENT_ID'
    $CertificateThumbprint = Normalize-Thumbprint -Thumbprint (Get-EffectiveSetting -ExplicitValue $CertificateThumbprint -EnvSettings $envSettings -EnvKey 'CERT_THUMBPRINT')
    $CertificatePath = Get-EffectiveSetting -ExplicitValue $CertificatePath -EnvSettings $envSettings -EnvKey 'CERT_PRIVATE_KEY_PATH'

    if ($ListRecommendedPermissions.IsPresent) {
        Write-ScriptOutput -Data ([PSCustomObject]@{
            CatalogPath = (Resolve-RelativePath -Path $PermissionCatalogPath)
            EnvFilePath = (Resolve-RelativePath -Path $EnvFilePath)
            RecommendedApplicationPermissions = $permissionCatalog.recommendedApplicationPermissions
            OptionalApplicationPermissions = $permissionCatalog.optionalApplicationPermissions
            LeastPrivilegeGuidance = $permissionCatalog.leastPrivilegeGuidance
            ExecutionExamples = $permissionCatalog.executionExamples
        })
        return
    }

    if (-not $GraphApplicationPermissions -or $GraphApplicationPermissions.Count -eq 0) {
        $GraphApplicationPermissions = Get-RecommendedPermissionValues -Catalog $permissionCatalog
    }

    Assert-RequiredInput -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -CertificatePath $CertificatePath -ApplicationObjectId $ApplicationObjectId

    Ensure-GraphModule -ModuleName 'Microsoft.Graph.Authentication'
    Ensure-GraphModule -ModuleName 'Microsoft.Graph.Applications'

    $resolvedCertificatePath = Resolve-RelativePath -Path $CertificatePath
    $certificate = Get-AppOnlyCertificate -ResolvedCertificatePath $resolvedCertificatePath -ExpectedThumbprint $CertificateThumbprint

    Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -Certificate $certificate -NoWelcome

    $application = Resolve-Application -ApplicationObjectId $ApplicationObjectId -ClientId $ClientId
    $graphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

    if (-not $graphServicePrincipal) {
        throw 'Service principal do Microsoft Graph nao encontrado no tenant.'
    }

    $selectedRoles = Get-GraphAppRoles -GraphServicePrincipal $graphServicePrincipal -PermissionValues $GraphApplicationPermissions

    $requiredResourceAccess = @(
        @{
            resourceAppId = '00000003-0000-0000-c000-000000000000'
            resourceAccess = @(
                foreach ($role in $selectedRoles) {
                    @{
                        id = $role.Id
                        type = 'Role'
                    }
                }
            )
        }
    )

    if ($PSCmdlet.ShouldProcess($application.DisplayName, 'Atualizar RequiredResourceAccess com escopos Graph')) {
        Update-MgApplication -ApplicationId $application.Id -RequiredResourceAccess $requiredResourceAccess | Out-Null
    }

    $assignmentResult = @()
    if ($GrantAdminConsentAssignments.IsPresent) {
        $appServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$($application.AppId)'"
        if (-not $appServicePrincipal) {
            $appServicePrincipal = New-MgServicePrincipal -AppId $application.AppId
        }

        $currentAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $appServicePrincipal.Id

        foreach ($role in $selectedRoles) {
            $exists = $currentAssignments |
                Where-Object {
                    $_.ResourceId -eq $graphServicePrincipal.Id -and
                    $_.AppRoleId -eq $role.Id
                }

            if (-not $exists) {
                if ($PSCmdlet.ShouldProcess($application.DisplayName, "Atribuir app role $($role.Value)")) {
                    New-MgServicePrincipalAppRoleAssignment `
                        -ServicePrincipalId $appServicePrincipal.Id `
                        -PrincipalId $appServicePrincipal.Id `
                        -ResourceId $graphServicePrincipal.Id `
                        -AppRoleId $role.Id | Out-Null
                }

                $assignmentResult += "assigned:$($role.Value)"
            } else {
                $assignmentResult += "already-assigned:$($role.Value)"
            }
        }
    }

    Write-ScriptOutput -Data ([PSCustomObject]@{
        TenantId = $TenantId
        ApplicationObjectId = $application.Id
        ClientId = $application.AppId
        DisplayName = $application.DisplayName
        CertificateThumbprint = $CertificateThumbprint
        CertificatePath = $resolvedCertificatePath
        UpdatedGraphAppPermissions = $GraphApplicationPermissions
        AdminConsentAssignments = if ($assignmentResult.Count -gt 0) { $assignmentResult -join ';' } else { 'not-requested' }
        WhatIf = $WhatIfPreference
        AuthType = 'AppOnlyCertificate'
        EnvFilePath = (Resolve-RelativePath -Path $EnvFilePath)
        PermissionCatalogPath = (Resolve-RelativePath -Path $PermissionCatalogPath)
        Notes = 'Revise as permissoes pelo principio do menor privilegio antes de producao.'
    })
}
catch {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $_.Exception,
        'UpdateGraphAppScopesFailed',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $ClientId
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
