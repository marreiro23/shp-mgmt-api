param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [string]$From = "main",
  [switch]$Fetch,
  [switch]$TrackRemote
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

if ($Fetch.IsPresent) {
  Write-Host "[fetch] Updating local refs"
  Invoke-Git -Args @("fetch", "--all", "--prune")
}

$baseExists = (& git show-ref --verify --quiet "refs/heads/$From"; if ($LASTEXITCODE -eq 0) { "true" } else { "false" })
if ($baseExists -ne "true") {
  throw "Base branch '$From' does not exist locally."
}

Write-Host "[branch] Checking out base branch $From"
Invoke-Git -Args @("checkout", $From)

Write-Host "[branch] Creating and switching to $Name"
Invoke-Git -Args @("checkout", "-b", $Name)

if ($TrackRemote.IsPresent) {
  Write-Host "[push] Publishing and tracking origin/$Name"
  Invoke-Git -Args @("push", "-u", "origin", $Name)
}

Write-Host "[done] Branch ready: $Name"
