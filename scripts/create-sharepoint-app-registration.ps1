[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId = 'a1c06ffc-77b3-4fb3-b57d-86eab41da4a2',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PrimaryDomain = 'M365DS694397.onmicrosoft.com',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName = 'shp-mgmt-api',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateSubject = 'CN=shp-mgmt-api',

    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$CertificateYearsValid = 2,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateOutputDirectory = '../certs',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string[]]$GraphApplicationPermissions = @(
        'Sites.ReadWrite.All',
        'Files.ReadWrite.All'
    ),

    [Parameter()]
    [switch]$ExportPfx,

    [Parameter()]
    [securestring]$PfxPassword,

    [Parameter()]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Get-GraphAppRoles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$GraphServicePrincipal,

        [Parameter(Mandatory)]
        [string[]]$PermissionValues
    )

    $appRoles = @()
    foreach ($permission in $PermissionValues) {
        $match = $GraphServicePrincipal.AppRoles |
            Where-Object {
                $_.Value -eq $permission -and $_.AllowedMemberTypes -contains 'Application'
            }

        if (-not $match) {
            $valid = $GraphServicePrincipal.AppRoles |
                Where-Object { $_.AllowedMemberTypes -contains 'Application' } |
                Select-Object -ExpandProperty Value
            throw "Graph application permission '$permission' not found. Valid application permissions include: $($valid -join ', ')"
        }

        $appRoles += $match
    }

    return $appRoles
}

function New-AppCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,

        [Parameter(Mandatory)]
        [int]$YearsValid,

        [Parameter(Mandatory)]
        [string]$OutputDirectory,

        [Parameter()]
        [switch]$ExportPfx,

        [Parameter()]
        [securestring]$PfxPassword
    )

    $resolvedOutputDirectory = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        $OutputDirectory
    } else {
        Join-Path -Path $PSScriptRoot -ChildPath $OutputDirectory
    }

    $resolvedOutputDirectory = [System.IO.Path]::GetFullPath($resolvedOutputDirectory)
    Write-Verbose "Resolved certificate output directory: $resolvedOutputDirectory"

    if (-not (Test-Path -LiteralPath $resolvedOutputDirectory)) {
        New-Item -Path $resolvedOutputDirectory -ItemType Directory -Force | Out-Null
    }

    $certificate = New-SelfSignedCertificate `
        -Subject $Subject `
        -CertStoreLocation 'Cert:\CurrentUser\My' `
        -KeyExportPolicy Exportable `
        -KeySpec Signature `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -NotAfter (Get-Date).AddYears($YearsValid)

    $baseName = ($Subject -replace '[^a-zA-Z0-9\-]', '_').Trim('_')
    $cerPath = Join-Path -Path $resolvedOutputDirectory -ChildPath "$baseName.cer"
    Export-Certificate -Cert $certificate -FilePath $cerPath -Force | Out-Null
    Write-Verbose "Exported public certificate path: $cerPath"

    if (-not (Test-Path -LiteralPath $cerPath)) {
        throw "Falha ao exportar certificado publico em '$cerPath'."
    }

    $pfxPath = $null
    if ($ExportPfx.IsPresent) {
        if (-not $PfxPassword) {
            throw 'PfxPassword is required when ExportPfx is specified.'
        }

        $pfxPath = Join-Path -Path $resolvedOutputDirectory -ChildPath "$baseName.pfx"
        Export-PfxCertificate `
            -Cert $certificate `
            -FilePath $pfxPath `
            -Password $PfxPassword `
            -Force | Out-Null
        Write-Verbose "Exported private certificate path: $pfxPath"

        if (-not (Test-Path -LiteralPath $pfxPath)) {
            throw "Falha ao exportar certificado privado em '$pfxPath'."
        }
    }

    return [PSCustomObject]@{
        Certificate = $certificate
        CerPath = $cerPath
        PfxPath = $pfxPath
    }
}

try {
    Ensure-GraphModule -ModuleName 'Microsoft.Graph.Authentication'
    Ensure-GraphModule -ModuleName 'Microsoft.Graph.Applications'

    $connectScopes = @(
        'Application.ReadWrite.All',
        'AppRoleAssignment.ReadWrite.All',
        'Directory.ReadWrite.All'
    )

    Write-Verbose 'Connecting to Microsoft Graph'
    Connect-MgGraph -TenantId $TenantId -Scopes $connectScopes -NoWelcome

    $graphContext = Get-MgContext
    if (-not $graphContext) {
        throw 'Unable to establish Microsoft Graph context.'
    }

    $certInfo = New-AppCertificate `
        -Subject $CertificateSubject `
        -YearsValid $CertificateYearsValid `
        -OutputDirectory $CertificateOutputDirectory `
        -ExportPfx:$ExportPfx `
        -PfxPassword $PfxPassword

    Write-Verbose "Reading certificate bytes from: $($certInfo.CerPath)"
    if (-not (Test-Path -LiteralPath $certInfo.CerPath)) {
        throw "Certificado publico nao encontrado em '$($certInfo.CerPath)'. Verifique CertificateOutputDirectory e permissoes de escrita."
    }

    $certBytes = [System.IO.File]::ReadAllBytes($certInfo.CerPath)

    if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Azure AD application registration')) {
        $application = New-MgApplication `
            -DisplayName $DisplayName `
            -SignInAudience 'AzureADMyOrg'

        $keyCredential = @{
            type = 'AsymmetricX509Cert'
            usage = 'Verify'
            key = $certBytes
            displayName = 'self-signed-auth-cert'
            startDateTime = $certInfo.Certificate.NotBefore.ToUniversalTime()
            endDateTime = $certInfo.Certificate.NotAfter.ToUniversalTime()
        }

        Update-MgApplication `
            -ApplicationId $application.Id `
            -KeyCredentials @($keyCredential) | Out-Null

        $graphServicePrincipal = Get-MgServicePrincipal `
            -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

        if (-not $graphServicePrincipal) {
            throw 'Microsoft Graph service principal not found in tenant.'
        }

        $selectedRoles = Get-GraphAppRoles `
            -GraphServicePrincipal $graphServicePrincipal `
            -PermissionValues $GraphApplicationPermissions

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

        Update-MgApplication `
            -ApplicationId $application.Id `
            -RequiredResourceAccess $requiredResourceAccess | Out-Null

        $appServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$($application.AppId)'"
        if (-not $appServicePrincipal) {
            $appServicePrincipal = New-MgServicePrincipal -AppId $application.AppId
        }

        foreach ($role in $selectedRoles) {
            $existingAssignment = Get-MgServicePrincipalAppRoleAssignment `
                -ServicePrincipalId $appServicePrincipal.Id |
                Where-Object {
                    $_.ResourceId -eq $graphServicePrincipal.Id -and
                    $_.AppRoleId -eq $role.Id
                }

            if (-not $existingAssignment) {
                New-MgServicePrincipalAppRoleAssignment `
                    -ServicePrincipalId $appServicePrincipal.Id `
                    -PrincipalId $appServicePrincipal.Id `
                    -ResourceId $graphServicePrincipal.Id `
                    -AppRoleId $role.Id | Out-Null
            }
        }

        $result = [PSCustomObject]@{
            TenantId = $TenantId
            PrimaryDomain = $PrimaryDomain
            DisplayName = $DisplayName
            ApplicationObjectId = $application.Id
            ClientId = $application.AppId
            ServicePrincipalId = $appServicePrincipal.Id
            CertificateThumbprint = $certInfo.Certificate.Thumbprint
            CertificatePublicPath = (Resolve-Path $certInfo.CerPath).Path
            CertificatePfxPath = if ($certInfo.PfxPath) { (Resolve-Path $certInfo.PfxPath).Path } else { $null }
            GraphPermissions = ($GraphApplicationPermissions -join ',')
            NextSteps = @(
                'Grant admin consent if your tenant requires interactive approval.',
                'Set CLIENT_ID and CERT_THUMBPRINT in your API .env files.',
                'Set CERT_PRIVATE_KEY_PATH to the private key path used by runtime.'
            )
        }

        Write-Output $result

        if ($PassThru.IsPresent) {
            return $result
        }
    }
}
catch {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        $_.Exception,
        'CreateSharePointAppRegistrationFailed',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $DisplayName
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
}
