<#
.SYNOPSIS
    Wrapper script to test API endpoints

.DESCRIPTION
    This is a convenience wrapper that calls the actual test script in scripts/tests/
    Validates the new SCCM endpoints added in API v2.0.1:
    - /api/v1/sccm/config (expanded with views and features)
    - /api/v1/sccm/customizations (list all custom queries)
    - /api/v1/sccm/customizations/:queryName (get specific query)

.EXAMPLE
    .\Test-APIEndpoints.ps1

.NOTES
    Author: CVE Management Team
    Date: 2026-01-22
    Related: API-UPDATE-SUMMARY.md
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$testScript = Join-Path $PSScriptRoot 'scripts\tests\Test-APIEndpoints.ps1'

if (-not (Test-Path $testScript)) {
    Write-Error "Test script not found at: $testScript"
    exit 1
}

Write-Host "Executing test script: $testScript" -ForegroundColor Cyan
Write-Host ""

& $testScript
