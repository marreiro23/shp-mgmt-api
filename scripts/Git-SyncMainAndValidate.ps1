param(
  [string]$MainBranch = "main",
  [string]$RemoteName = "origin",
  [switch]$FailIfDirty,
  [string]$ValidationCommand
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )

  & git @Args
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
  }
}

$insideWorkTree = (& git rev-parse --is-inside-work-tree 2>$null)
if ($LASTEXITCODE -ne 0 -or $insideWorkTree -ne "true") {
  throw "Current directory is not a git repository."
}

$status = (& git status --porcelain)
if ($FailIfDirty.IsPresent -and $status) {
  throw "Working tree has local changes. Commit/stash before sync."
}

Write-Host "[sync] Fetching from $RemoteName"
Invoke-Git -Args @("fetch", $RemoteName, "--prune")

Write-Host "[sync] Switching to $MainBranch"
Invoke-Git -Args @("checkout", $MainBranch)

Write-Host "[sync] Pulling latest $RemoteName/$MainBranch with ff-only"
Invoke-Git -Args @("pull", "--ff-only", $RemoteName, $MainBranch)

Write-Host "[validate] Computing ahead/behind"
$aheadBehind = (& git rev-list --left-right --count "$MainBranch...$RemoteName/$MainBranch")
if (-not $aheadBehind) {
  throw "Unable to compute synchronization state."
}

$parts = $aheadBehind -split "\s+"
$behind = [int]$parts[0]
$ahead = [int]$parts[1]

$syncState = [pscustomobject]@{
  branch = $MainBranch
  remote = "$RemoteName/$MainBranch"
  ahead = $ahead
  behind = $behind
  inSync = ($ahead -eq 0 -and $behind -eq 0)
  hasLocalChanges = [bool]$status
}

$syncState | ConvertTo-Json -Depth 5 | Write-Host

if ($ValidationCommand) {
  Write-Host "[validate] Running validation command: $ValidationCommand"
  Invoke-Expression $ValidationCommand
  if ($LASTEXITCODE -ne 0) {
    throw "Validation command failed with exit code $LASTEXITCODE"
  }
}

if (-not $syncState.inSync) {
  throw "Main branch is not synchronized with $RemoteName/$MainBranch."
}

Write-Host "[done] Main branch synchronized and validated."
