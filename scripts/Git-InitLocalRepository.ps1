param(
  [string]$RepoPath = ".",
  [string]$InitialBranch = "main",
  [string]$CommitMessage = "chore: initial repository bootstrap",
  [string]$RemoteName = "origin",
  [string]$RemoteUrl,
  [switch]$Push
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

$resolvedRepoPath = Resolve-Path -LiteralPath $RepoPath
Push-Location $resolvedRepoPath

try {
  $insideWorkTree = (& git rev-parse --is-inside-work-tree 2>$null)
  if ($LASTEXITCODE -ne 0 -or $insideWorkTree -ne "true") {
    Write-Host "[init] Initializing new git repository in $resolvedRepoPath"
    Invoke-Git -Args @("init")
  } else {
    Write-Host "[init] Git repository already initialized in $resolvedRepoPath"
  }

  Invoke-Git -Args @("checkout", "-B", $InitialBranch)

  $hasStagedOrUnstagedChanges = (& git status --porcelain)
  if ($hasStagedOrUnstagedChanges) {
    Write-Host "[commit] Staging all changes"
    Invoke-Git -Args @("add", "--all")

    Write-Host "[commit] Creating commit: $CommitMessage"
    Invoke-Git -Args @("commit", "-m", $CommitMessage)
  } else {
    Write-Host "[commit] No changes detected. Nothing to commit."
  }

  if ($RemoteUrl) {
    $remoteUrlCurrent = (& git remote get-url $RemoteName 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remoteUrlCurrent) {
      if ($remoteUrlCurrent -ne $RemoteUrl) {
        Write-Host "[remote] Updating remote $RemoteName URL"
        Invoke-Git -Args @("remote", "set-url", $RemoteName, $RemoteUrl)
      } else {
        Write-Host "[remote] Remote $RemoteName already configured with same URL"
      }
    } else {
      Write-Host "[remote] Adding remote $RemoteName"
      Invoke-Git -Args @("remote", "add", $RemoteName, $RemoteUrl)
    }

    if ($Push.IsPresent) {
      Write-Host "[push] Pushing branch $InitialBranch to $RemoteName"
      Invoke-Git -Args @("push", "-u", $RemoteName, $InitialBranch)
    }
  } elseif ($Push.IsPresent) {
    throw "-Push requires -RemoteUrl (or configure remote manually first)."
  }

  Write-Host "[done] Repository bootstrap finished successfully."
}
finally {
  Pop-Location
}
