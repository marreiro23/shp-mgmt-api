<#
.SYNOPSIS
    Wrapper script to start shp-mgmt-api in background

.DESCRIPTION
    This is a convenience wrapper that calls the actual startup script in scripts/
    Starts the SharePoint management API in background as a PowerShell job

.EXAMPLE
    .\Start-API-Background.ps1

.NOTES
    Author: shp-mgmt-api
    Date: 2026-01-22
    Related: API-UPDATE-SUMMARY.md
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$startScript = Join-Path $PSScriptRoot 'scripts\Start-API-Background.ps1'

if (-not (Test-Path $startScript)) {
    Write-Error "Startup script not found at: $startScript"
    exit 1
}

Write-Host "Executing startup script: $startScript" -ForegroundColor Cyan
Write-Host ""

& $startScript
