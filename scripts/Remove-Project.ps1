<#
.SYNOPSIS
    Removes the shp-mgmt-api project and its dependencies from the local machine.

.DESCRIPTION
    Stops the API background jobs, frees port 3001, optionally drops the PostgreSQL
    database and application role, removes generated data files and node_modules, and
    optionally uninstalls PostgreSQL via winget.

    All destructive steps are skipped when the corresponding -Keep* switch is supplied.
    Use -WhatIf to preview what would happen without making any changes.

.PARAMETER KeepDatabase
    Skip dropping the PostgreSQL database and application role.

.PARAMETER KeepNodeModules
    Skip deleting api/node_modules.

.PARAMETER KeepData
    Skip deleting the generated api/data/ JSON stores.

.PARAMETER KeepEnv
    Skip deleting api/.env and the .setup-complete marker file.

.PARAMETER KeepPostgreSQL
    Skip uninstalling PostgreSQL via winget (also implies -KeepDatabase).

.PARAMETER PgHost
    PostgreSQL host used to connect for the DROP operations. Default: localhost

.PARAMETER PgAdminUser
    PostgreSQL superuser used to drop the DB and role. Default: postgres

.PARAMETER PgAdminPassword
    Password for the PostgreSQL superuser.

.PARAMETER AppDbName
    Name of the application database to drop. Default: shp_mgmt_db

.PARAMETER AppDbUser
    Name of the application role to drop. Default: shp_app_user

.PARAMETER Force
    Suppress all confirmation prompts.

.EXAMPLE
    .\Remove-Project.ps1
    # Interactive removal of everything (prompts for confirmation).

.EXAMPLE
    .\Remove-Project.ps1 -KeepDatabase -KeepPostgreSQL -Force
    # Remove only node_modules, data files, and .env without touching PostgreSQL.

.EXAMPLE
    .\Remove-Project.ps1 -PgAdminPassword "secret" -Force
    # Full removal including database drop; no prompts.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$KeepDatabase,
    [switch]$KeepNodeModules,
    [switch]$KeepData,
    [switch]$KeepEnv,
    [switch]$KeepPostgreSQL,
    [string]$PgHost          = 'localhost',
    [string]$PgAdminUser     = 'postgres',
    [string]$PgAdminPassword = '',
    [string]$AppDbName       = 'shp_mgmt_db',
    [string]$AppDbUser       = 'shp_app_user',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── helpers ────────────────────────────────────────────────────────────────────

function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  – $msg" -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

function Confirm-Action([string]$Message) {
    if ($Force) { return $true }
    $answer = Read-Host "$Message [y/N]"
    return $answer -match '^[yY]'
}

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir          # …/shp-mgmt-api
$ApiDir     = Join-Path $ProjectDir 'api'

Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host   "║        shp-mgmt-api — Remove Project                 ║" -ForegroundColor Red
Write-Host   "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Red
Write-Host "Project dir : $ProjectDir"
Write-Host "API dir     : $ApiDir"
Write-Host ""

if (-not $Force -and -not (Confirm-Action "This will PERMANENTLY remove project artifacts. Continue?")) {
    Write-Host "`nAborted." -ForegroundColor Yellow
    exit 0
}

# ── 1. Stop PowerShell background jobs ────────────────────────────────────────
Write-Step "Stopping SHP-MGMT-API background jobs"

$jobs = Get-Job -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'SHP-MGMT-API*' }
if ($jobs) {
    foreach ($job in $jobs) {
        if ($PSCmdlet.ShouldProcess("Job '$($job.Name)'", 'Stop and Remove')) {
            Stop-Job  -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Write-OK "Removed job: $($job.Name)"
        }
    }
} else {
    Write-Skip "No SHP-MGMT-API jobs found."
}

# ── 2. Free port 3001 ─────────────────────────────────────────────────────────
Write-Step "Freeing port 3001"

$portProcs = netstat -ano 2>$null |
    Select-String ':3001\s' |
    ForEach-Object {
        if ($_ -match '\s(\d+)$') { $Matches[1] }
    } |
    Sort-Object -Unique

if ($portProcs) {
    foreach ($pid in $portProcs) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                if ($PSCmdlet.ShouldProcess("PID $pid ($($proc.ProcessName))", 'Kill process on port 3001')) {
                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                    Write-OK "Killed PID $pid ($($proc.ProcessName))"
                }
            }
        } catch {
            Write-Warn "Could not kill PID $pid : $_"
        }
    }
} else {
    Write-Skip "No process found on port 3001."
}

# ── 3. Drop PostgreSQL database and role ──────────────────────────────────────
if ($KeepPostgreSQL -or $KeepDatabase) {
    Write-Skip "Skipping database removal (-KeepDatabase or -KeepPostgreSQL)."
} else {
    Write-Step "Dropping PostgreSQL database '$AppDbName' and role '$AppDbUser'"

    $psqlExe = Get-Command psql -ErrorAction SilentlyContinue
    if (-not $psqlExe) {
        Write-Warn "psql not found in PATH — skipping database removal."
    } else {
        if ($Force -or (Confirm-Action "Drop database '$AppDbName' and role '$AppDbUser' on $PgHost?")) {
            $env:PGPASSWORD = $PgAdminPassword

            $dropDb = @"
SELECT pg_terminate_backend(pid)
FROM   pg_stat_activity
WHERE  datname = '$AppDbName' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS $AppDbName;
"@
            $dropRole = "DROP ROLE IF EXISTS $AppDbUser;"

            try {
                if ($PSCmdlet.ShouldProcess("$AppDbName on $PgHost", 'Drop database')) {
                    $dropDb  | psql -h $PgHost -U $PgAdminUser -d postgres 2>&1 | ForEach-Object { Write-Host "  psql> $_" }
                    $dropRole | psql -h $PgHost -U $PgAdminUser -d postgres 2>&1 | ForEach-Object { Write-Host "  psql> $_" }
                    Write-OK "Database '$AppDbName' and role '$AppDbUser' removed."
                }
            } catch {
                Write-Warn "Database removal failed: $_"
            } finally {
                Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
            }
        } else {
            Write-Skip "Database removal skipped by user."
        }
    }
}

# ── 4. Remove api/node_modules ────────────────────────────────────────────────
if ($KeepNodeModules) {
    Write-Skip "Skipping node_modules removal (-KeepNodeModules)."
} else {
    $nmDir = Join-Path $ApiDir 'node_modules'
    if (Test-Path $nmDir) {
        if ($PSCmdlet.ShouldProcess($nmDir, 'Remove node_modules')) {
            Write-Step "Removing api/node_modules (~may take a moment)"
            Remove-Item -Recurse -Force $nmDir
            Write-OK "Removed $nmDir"
        }
    } else {
        Write-Skip "$nmDir does not exist."
    }
}

# ── 5. Remove generated data files ────────────────────────────────────────────
if ($KeepData) {
    Write-Skip "Skipping api/data removal (-KeepData)."
} else {
    $dataDir = Join-Path $ApiDir 'data'
    if (Test-Path $dataDir) {
        if ($PSCmdlet.ShouldProcess($dataDir, 'Remove generated data directory')) {
            Write-Step "Removing api/data (JSON stores)"
            Remove-Item -Recurse -Force $dataDir
            Write-OK "Removed $dataDir"
        }
    } else {
        Write-Skip "$dataDir does not exist."
    }
}

# ── 6. Remove .env and .setup-complete ────────────────────────────────────────
if ($KeepEnv) {
    Write-Skip "Skipping .env and .setup-complete removal (-KeepEnv)."
} else {
    Write-Step "Removing .env and first-run marker"

    $envFile     = Join-Path $ApiDir '.env'
    $setupMarker = Join-Path $ProjectDir '.setup-complete'

    foreach ($f in @($envFile, $setupMarker)) {
        if (Test-Path $f) {
            if ($PSCmdlet.ShouldProcess($f, 'Delete file')) {
                Remove-Item -Force $f
                Write-OK "Deleted $f"
            }
        } else {
            Write-Skip "$f not found."
        }
    }
}

# ── 7. Remove logs ────────────────────────────────────────────────────────────
$logsDir = Join-Path $ProjectDir 'logs'
if (Test-Path $logsDir) {
    if ($Force -or (Confirm-Action "Remove log files at '$logsDir'?")) {
        if ($PSCmdlet.ShouldProcess($logsDir, 'Remove logs directory')) {
            Remove-Item -Recurse -Force $logsDir
            Write-OK "Removed $logsDir"
        }
    } else {
        Write-Skip "Log removal skipped."
    }
}

# ── 8. Optionally uninstall PostgreSQL via winget ─────────────────────────────
if ($KeepPostgreSQL) {
    Write-Skip "Skipping PostgreSQL uninstall (-KeepPostgreSQL)."
} else {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        if (Confirm-Action "Uninstall PostgreSQL via winget? (WARNING: removes all PostgreSQL data)") {
            Write-Step "Uninstalling PostgreSQL via winget"

            # Find any installed PostgreSQL packages
            $pgPkgs = winget list --id PostgreSQL 2>$null | Select-String 'PostgreSQL'
            if ($pgPkgs) {
                if ($PSCmdlet.ShouldProcess('PostgreSQL', 'winget uninstall')) {
                    winget uninstall --id PostgreSQL.PostgreSQL --silent 2>&1 |
                        ForEach-Object { Write-Host "  winget> $_" }
                    Write-OK "PostgreSQL uninstall initiated."
                }
            } else {
                Write-Skip "PostgreSQL package not found in winget — skipping."
            }
        } else {
            Write-Skip "PostgreSQL uninstall skipped by user."
        }
    } else {
        Write-Skip "winget not available — skipping PostgreSQL uninstall."
    }
}

# ── summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Remove-Project completed successfully               ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "To reinstall, run: .\scripts\Start-API-Background.ps1 -Setup" -ForegroundColor DarkGray
