[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DriveId,
    [string]$ApiBaseUrl = 'http://localhost:3001/api/v1',
    [string]$FolderName = 'shp-mgmt-api-graph-test',
    [string]$FileName = 'shp-mgmt-api-sample.txt',
    [string]$FileContent = 'Arquivo criado via shp-mgmt-api para SharePoint Graph.'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Api {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body
    )

    if ($null -ne $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8)
    }

    Invoke-RestMethod -Method $Method -Uri $Uri
}

Write-Host "Autenticando em $ApiBaseUrl/sharepoint/authenticate" -ForegroundColor Cyan
Invoke-Api -Method POST -Uri "$ApiBaseUrl/sharepoint/authenticate" | Out-Null

Write-Host "Criando pasta '$FolderName'..." -ForegroundColor Cyan
$folderResult = Invoke-Api -Method POST -Uri "$ApiBaseUrl/sharepoint/drives/$([uri]::EscapeDataString($DriveId))/folders" -Body @{
    name = $FolderName
}

Write-Host "Pasta criada: $($folderResult.data.name)" -ForegroundColor Green

Write-Host "Enviando arquivo '$FileName'..." -ForegroundColor Cyan
$uploadResult = Invoke-Api -Method POST -Uri "$ApiBaseUrl/sharepoint/drives/$([uri]::EscapeDataString($DriveId))/files" -Body @{
    fileName = $FileName
    parentPath = $FolderName
    content = $FileContent
}

Write-Host "Arquivo criado: $($uploadResult.data.name)" -ForegroundColor Green
Write-Host "Operacao concluida com sucesso." -ForegroundColor Green
