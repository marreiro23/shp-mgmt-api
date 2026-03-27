<#
.SYNOPSIS
    Carrega a configuração centralizada do shp-mgmt-api.

.DESCRIPTION
    Lê config.json e resolve caminhos absolutos para os scripts ativos do
    escopo SharePoint Online via Microsoft Graph.
#>

param(
    [string]$ConfigPath = $null
)

try {
    # Se ConfigPath não foi fornecido, procurar no diretório padrão
    if (-not $ConfigPath) {
        # Tentar encontrar config.json a partir do script atual
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

        # Subir para config/config.json na raiz do workspace
        $configJsonPath = Join-Path $scriptRoot '..\..\config\config.json'

        if (-not (Test-Path $configJsonPath)) {
            throw "config.json não encontrado em $configJsonPath"
        }

        $ConfigPath = $configJsonPath
    }

    $rawConfig = Get-Content $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $projectRoot = Split-Path -Parent (Split-Path -Parent $ConfigPath)

    $config = @{
        Application = $rawConfig.application
        Paths = @{}
        Api = $rawConfig.api
        Logging = $rawConfig.logging
        PowerShell = $rawConfig.powershell
        SharePoint = $rawConfig.sharepoint
        Features = $rawConfig.features
        Web = $rawConfig.web
        ProjectRoot = $projectRoot
    }

    foreach ($pathKey in $rawConfig.paths.PSObject.Properties.Name) {
        $relativePath = $rawConfig.paths.$pathKey

        if ($pathKey -eq 'root' -or [string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -eq '.') {
            $config.Paths.$pathKey = $projectRoot
        } else {
            $fullPath = Join-Path $projectRoot $relativePath
            $resolvedPath = [System.IO.Path]::GetFullPath($fullPath)
            $config.Paths.$pathKey = $resolvedPath
        }
    }

    return ([PSCustomObject]$config)
}
catch {
    Write-Error "Erro ao carregar configuração: $_"
    exit 1
}
