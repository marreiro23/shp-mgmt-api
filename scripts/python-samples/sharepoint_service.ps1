Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GraphBaseUrl = 'https://graph.microsoft.com/v1.0'
$script:DefaultGraphScope = 'https://graph.microsoft.com/.default'

function Get-RequiredSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value.Trim()
    }

    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        [System.ArgumentException]::new("Parametro obrigatorio ausente: $Name"),
        'MissingRequiredSetting',
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $Name
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

function ConvertTo-GraphPath {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return ($Path.Trim('/') -split '/' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join '/'
}

function Get-GraphAccessToken {
    [CmdletBinding()]
    param(
        [string]$TenantId = $env:TENANT_ID,
        [string]$ClientId = $env:CLIENT_ID,
        [string]$ClientSecret = $env:CLIENT_SECRET,
        [string]$Scope = $script:DefaultGraphScope,
        [int]$TimeoutSeconds = 30
    )

    $tenant = Get-RequiredSetting -Name 'TENANT_ID' -Value $TenantId
    $client = Get-RequiredSetting -Name 'CLIENT_ID' -Value $ClientId
    $secret = Get-RequiredSetting -Name 'CLIENT_SECRET' -Value $ClientSecret
    $tokenScope = Get-RequiredSetting -Name 'GRAPH_SCOPE' -Value $Scope

    $tokenUri = "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token"
    $body = @{
        client_id = $client
        client_secret = $secret
        scope = $tokenScope
        grant_type = 'client_credentials'
    }

    try {
        $response = Invoke-RestMethod -Method POST -Uri $tokenUri -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec $TimeoutSeconds
    } catch {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('Falha ao obter token de acesso do Microsoft Graph.', $_.Exception),
            'GraphTokenAcquisitionFailed',
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $tenant
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    if ([string]::IsNullOrWhiteSpace($response.access_token)) {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('Resposta de token sem access_token.'),
            'GraphTokenMissing',
            [System.Management.Automation.ErrorCategory]::AuthenticationError,
            $tenant
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    return $response.access_token
}

function Invoke-GraphRequestRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        [string]$AccessToken,
        [AllowNull()][object]$Body,
        [AllowNull()][byte[]]$BinaryContent,
        [hashtable]$Headers,
        [int]$TimeoutSeconds = 30,
        [int]$MaxRetries = 2,
        [int]$BackoffBaseMs = 500
    )

    $token = if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        Get-GraphAccessToken -TimeoutSeconds $TimeoutSeconds
    } else {
        $AccessToken
    }

    $requestHeaders = @{
        Authorization = "Bearer $token"
        Accept = 'application/json'
    }

    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $requestHeaders[$key] = $Headers[$key]
        }
    }

    $uri = "$script:GraphBaseUrl$Endpoint"

    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        try {
            $params = @{
                Method = $Method
                Uri = $uri
                Headers = $requestHeaders
                TimeoutSec = $TimeoutSeconds
                SkipHttpErrorCheck = $true
            }

            if ($null -ne $Body) {
                $params['Body'] = ($Body | ConvertTo-Json -Depth 20)
                if (-not $requestHeaders.ContainsKey('Content-Type')) {
                    $requestHeaders['Content-Type'] = 'application/json'
                }
            }

            if ($null -ne $BinaryContent) {
                $params['Body'] = $BinaryContent
            }

            $response = Invoke-WebRequest @params
            $statusCode = [int]$response.StatusCode

            if ($statusCode -ge 400) {
                $isTransient = ($statusCode -eq 429) -or ($statusCode -ge 500 -and $statusCode -le 599)
                if ($isTransient -and $attempt -lt $MaxRetries) {
                    $delay = [Math]::Min($BackoffBaseMs * [Math]::Pow(2, $attempt), 5000)
                    Start-Sleep -Milliseconds ([int]$delay)
                    continue
                }

                $errorBody = if ([string]::IsNullOrWhiteSpace($response.Content)) { '' } else { $response.Content }
                throw "Graph request failed ($statusCode): $errorBody"
            }

            return $response
        } catch {
            if ($attempt -lt $MaxRetries) {
                $statusCode = $_.Exception.Response.StatusCode.value__
                $isTransient = ($statusCode -eq 429) -or ($statusCode -ge 500 -and $statusCode -le 599)
                if ($isTransient) {
                    $delay = [Math]::Min($BackoffBaseMs * [Math]::Pow(2, $attempt), 5000)
                    Start-Sleep -Milliseconds ([int]$delay)
                    continue
                }
            }

            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Falha na requisicao ao Microsoft Graph.', $_.Exception),
                'GraphRequestFailed',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $uri
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
}

function Invoke-GraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        [string]$AccessToken,
        [AllowNull()][object]$Body,
        [AllowNull()][byte[]]$BinaryContent,
        [hashtable]$Headers,
        [int]$TimeoutSeconds = 30,
        [int]$MaxRetries = 2,
        [int]$BackoffBaseMs = 500
    )

    $rawParams = @{
        Method = $Method
        Endpoint = $Endpoint
        AccessToken = $AccessToken
        Body = $Body
        BinaryContent = $BinaryContent
        Headers = $Headers
        TimeoutSeconds = $TimeoutSeconds
        MaxRetries = $MaxRetries
        BackoffBaseMs = $BackoffBaseMs
    }
    $response = Invoke-GraphRequestRaw @rawParams

    if ($response.StatusCode -eq 204) {
        return @{ status = 'no_content' }
    }

    if ([string]::IsNullOrWhiteSpace($response.Content)) {
        return @{ status = 'ok' }
    }

    return $response.Content | ConvertFrom-Json -Depth 20
}

function Get-SharePointItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [string]$SiteId = $env:SHAREPOINT_SITE_ID,
        [string]$DriveId = $env:SHAREPOINT_DRIVE_ID,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeSiteId = Get-RequiredSetting -Name 'SHAREPOINT_SITE_ID' -Value $SiteId
    $safeDriveId = Get-RequiredSetting -Name 'SHAREPOINT_DRIVE_ID' -Value $DriveId
    $encodedPath = ConvertTo-GraphPath -Path $FolderPath
    $endpoint = "/sites/$safeSiteId/drives/$safeDriveId/root:/$encodedPath`:/children"

    return Invoke-GraphRequest -Method GET -Endpoint $endpoint -AccessToken $AccessToken -TimeoutSeconds $TimeoutSeconds
}

function Get-SharePointSites {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Search,
        [int]$Top = 100,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeTop = [Math]::Max(1, [Math]::Min($Top, 999))
    $queryParts = @("`$top=$safeTop")

    if (-not [string]::IsNullOrWhiteSpace($Search)) {
        $queryParts += "search=$([System.Uri]::EscapeDataString($Search.Trim()))"
    }

    $endpoint = "/sites?$($queryParts -join '&')"
    return Invoke-GraphRequest -Method GET -Endpoint $endpoint -AccessToken $AccessToken -TimeoutSeconds $TimeoutSeconds
}

function New-SharePointFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ParentPath,
        [Parameter(Mandatory)][string]$FolderName,
        [string]$SiteId = $env:SHAREPOINT_SITE_ID,
        [string]$DriveId = $env:SHAREPOINT_DRIVE_ID,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeSiteId = Get-RequiredSetting -Name 'SHAREPOINT_SITE_ID' -Value $SiteId
    $safeDriveId = Get-RequiredSetting -Name 'SHAREPOINT_DRIVE_ID' -Value $DriveId
    $encodedParentPath = ConvertTo-GraphPath -Path $ParentPath

    $endpoint = "/sites/$safeSiteId/drives/$safeDriveId/root:/$encodedParentPath`:/children"
    $payload = @{
        name = $FolderName
        folder = @{}
        '@microsoft.graph.conflictBehavior' = 'rename'
    }

    return Invoke-GraphRequest -Method POST -Endpoint $endpoint -Body $payload -AccessToken $AccessToken -TimeoutSeconds $TimeoutSeconds
}

function Send-SharePointSmallFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FolderPath,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][byte[]]$FileContent,
        [string]$SiteId = $env:SHAREPOINT_SITE_ID,
        [string]$DriveId = $env:SHAREPOINT_DRIVE_ID,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeSiteId = Get-RequiredSetting -Name 'SHAREPOINT_SITE_ID' -Value $SiteId
    $safeDriveId = Get-RequiredSetting -Name 'SHAREPOINT_DRIVE_ID' -Value $DriveId
    $encodedFolderPath = ConvertTo-GraphPath -Path $FolderPath
    $encodedFileName = [System.Uri]::EscapeDataString($FileName)
    $encodedFullPath = if ([string]::IsNullOrWhiteSpace($encodedFolderPath)) {
        $encodedFileName
    } else {
        "$encodedFolderPath/$encodedFileName"
    }

    $endpoint = "/sites/$safeSiteId/drives/$safeDriveId/root:/$encodedFullPath`:/content"
    $requestParams = @{
        Method = 'PUT'
        Endpoint = $endpoint
        BinaryContent = $FileContent
        Headers = @{ 'Content-Type' = 'application/octet-stream' }
        AccessToken = $AccessToken
        TimeoutSeconds = $TimeoutSeconds
    }
    return Invoke-GraphRequest @requestParams
}

function Get-SharePointFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string]$SiteId = $env:SHAREPOINT_SITE_ID,
        [string]$DriveId = $env:SHAREPOINT_DRIVE_ID,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeSiteId = Get-RequiredSetting -Name 'SHAREPOINT_SITE_ID' -Value $SiteId
    $safeDriveId = Get-RequiredSetting -Name 'SHAREPOINT_DRIVE_ID' -Value $DriveId
    $encodedPath = ConvertTo-GraphPath -Path $FilePath
    $endpoint = "/sites/$safeSiteId/drives/$safeDriveId/root:/$encodedPath`:/content"

    $response = Invoke-GraphRequestRaw -Method GET -Endpoint $endpoint -AccessToken $AccessToken -TimeoutSeconds $TimeoutSeconds
    $memoryStream = New-Object System.IO.MemoryStream
    try {
        $response.RawContentStream.CopyTo($memoryStream)
        return $memoryStream.ToArray()
    } finally {
        $memoryStream.Dispose()
    }
}

function Remove-SharePointItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ItemPath,
        [string]$SiteId = $env:SHAREPOINT_SITE_ID,
        [string]$DriveId = $env:SHAREPOINT_DRIVE_ID,
        [string]$AccessToken,
        [int]$TimeoutSeconds = 30
    )

    $safeSiteId = Get-RequiredSetting -Name 'SHAREPOINT_SITE_ID' -Value $SiteId
    $safeDriveId = Get-RequiredSetting -Name 'SHAREPOINT_DRIVE_ID' -Value $DriveId
    $encodedPath = ConvertTo-GraphPath -Path $ItemPath
    $endpoint = "/sites/$safeSiteId/drives/$safeDriveId/root:/$encodedPath"

    Invoke-GraphRequest -Method DELETE -Endpoint $endpoint -AccessToken $AccessToken -TimeoutSeconds $TimeoutSeconds | Out-Null
    return @{
        deleted = $true
        path = $ItemPath
    }
}

if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function @(
        'Get-GraphAccessToken',
        'Get-SharePointItems',
        'Get-SharePointSites',
        'New-SharePointFolder',
        'Send-SharePointSmallFile',
        'Get-SharePointFileContent',
        'Remove-SharePointItem'
    )
}