# Install a Windows 11 machine's packages with winget. The Windows counterpart
# of scripts/bootstrap.sh.
#
# The base environment is packages/windows/winget.json. Optional development
# tools (packages/windows/winget-<group>.json, e.g. android) are installed only
# when selected with --with <group>; without it they are only reported.
#
# The default is a dry run: it reports which declared packages are installed
# and prints the winget commands --apply would run. It installs nothing and
# writes nothing.
#
# With --apply it installs only the missing packages, one at a time, logs every
# command, and stops at the first failure. Re-running is safe: installed
# packages are skipped, and nothing is upgraded (--no-upgrade) or removed. It
# never passes --accept-package-agreements / --accept-source-agreements: winget
# asks, and you answer. It never runs `chezmoi apply` (see AGENTS.md).
#
# Runs on Windows PowerShell 5.1 (a fresh Windows 11 has no PowerShell 7 yet):
#   powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 [--apply] [--with android]
# The -ExecutionPolicy flag applies to that one process only.

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'windows.ps1')

$wingetFile = Join-Path (Join-Path (Join-Path $repoRoot 'packages') 'windows') 'winget.json'
$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) { $localAppData = Join-Path (Join-Path $HOME 'AppData') 'Local' }
$stateDir = Join-Path (Join-Path $localAppData 'dotfiles') 'bootstrap'

$groups = @(Get-DotfilesOptionalGroups $repoRoot)

function Show-Usage {
  Write-Output 'Usage: bootstrap.ps1 [--apply] [--with <group>]...'
  Write-Output ''
  Write-Output '  (no option)     dry run: show each package''s state and the commands --apply would run'
  Write-Output "  --apply         install what is missing; logs to $stateDir"
  Write-Output "  --with <group>  also include an optional group ($($groups -join ', ')); repeatable"
  Write-Output ''
  Write-Output 'Without --with, only the base environment (packages/windows/winget.json) is installed.'
  Write-Output 'Supported: Windows 10/11 native. macOS and WSL use scripts/bootstrap.sh.'
}

$options = ConvertFrom-DotfilesArguments $args $groups $true
if ($options.Error) { Write-Output $options.Error; Write-Output ''; Show-Usage; exit 2 }
if ($options.Help) { Show-Usage; exit 0 }
$apply = $options.Apply
$selected = $options.With

$mode = 'dry run'
if ($apply) { $mode = 'apply' }
if ($selected.Count -gt 0) { $mode += ', with ' + ($selected -join ', ') }
Write-Output "dotfiles bootstrap for Windows ($mode)"

# ---------------------------------------------------------------------------
# Platform

Write-DotfilesSection 'Platform'
$platform = Get-DotfilesPlatform
if ($platform -ne 'windows') {
  Write-Output "Unsupported platform: $platform. On macOS and WSL use scripts/bootstrap.sh. Nothing was changed."
  exit 2
}
Write-Output ("  Windows {0}, PowerShell {1} ({2})" -f [Environment]::OSVersion.Version, $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
if (Test-DotfilesElevated) {
  Write-Output 'Run this from a normal (non-administrator) terminal: winget asks for elevation per package when an installer needs it.'
  exit 2
}

# ---------------------------------------------------------------------------
# Packages. Each gets a state: ok | todo | blocked.

$packages = @(Read-DotfilesWingetPackages $wingetFile)
foreach ($group in $selected) {
  $files = Get-DotfilesGroupFiles $repoRoot $group
  if ($files.Winget) { $packages += @(Read-DotfilesWingetPackages $files.Winget) }
}
$haveWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

function Get-PackageState($Package) {
  if (-not $haveWinget) {
    return @{ State = 'blocked'; Detail = 'winget not found: install or update "App Installer" from the Microsoft Store' }
  }
  switch (Test-WingetPackage $Package.Id $Package.Source) {
    'installed' { return @{ State = 'ok'; Detail = 'installed' } }
    'missing' { return @{ State = 'todo'; Detail = 'not installed' } }
  }
  $detail = "winget list failed ($(Format-WingetCode $script:WingetLastCode)); run 'winget list --id $($Package.Id) --exact' yourself to see why"
  return @{ State = 'blocked'; Detail = $detail }
}

function Get-InstallArguments($Package) {
  return @('install', '--id', $Package.Id, '--exact', '--source', $Package.Source, '--no-upgrade')
}

function Write-PackageLine($Package, $Result) {
  Write-Output ('  {0,-8} {1,-28} {2}' -f $Result.State, $Package.Id, $Result.Detail)
}

$planTitle = 'Plan (packages/windows/winget.json'
foreach ($group in $selected) { $planTitle += ", winget-$group.json" }
Write-DotfilesSection ($planTitle + ')')
$todo = 0
$blocked = 0
foreach ($package in $packages) {
  $result = Get-PackageState $package
  Write-PackageLine $package $result
  switch ($result.State) {
    'todo' {
      $todo++
      Write-Output ('        > winget ' + ((Get-InstallArguments $package) -join ' '))
    }
    'blocked' { $blocked++ }
  }
}

# Optional groups that were not selected: reported, never installed.
foreach ($group in $groups) {
  if ($selected -contains $group) { continue }
  $files = Get-DotfilesGroupFiles $repoRoot $group
  if (-not $files.Winget) { continue }
  Write-DotfilesSection "Optional, not selected: $group (packages/windows/winget-$group.json)"
  foreach ($package in Read-DotfilesWingetPackages $files.Winget) {
    $result = Get-PackageState $package
    Write-Output ('  {0,-8} {1,-28} {2}' -f '-', $package.Id, $result.Detail)
  }
  Write-Output "  Not installed by this run. To include it: --with $group"
}

# ---------------------------------------------------------------------------
# chezmoi is reported, not acted on: bootstrap never applies configuration.

function Write-NextSteps {
  Write-DotfilesSection 'Next steps (manual)'
  Write-Output '  Open a new Windows Terminal tab with PowerShell 7, so that PATH includes newly installed commands.'
  Get-DotfilesChezmoiState $repoRoot
  switch ($script:ChezmoiState) {
    'missing' { Write-Output '  chezmoi is not on PATH yet (installed by this bootstrap as twpayne.chezmoi).' }
    'other-source' {
      Write-Output '  Point chezmoi at this repository (a TOML literal string, so backslashes stay as they are):'
      Write-Output '    New-Item -ItemType Directory -Force "$HOME\.config\chezmoi" | Out-Null'
      Write-Output ("    Set-Content -Encoding utf8 ""`$HOME\.config\chezmoi\chezmoi.toml"" ""sourceDir = '{0}'""" -f $repoRoot)
    }
    'failed' { Write-Output '  ''chezmoi status'' failed: run it yourself to see the error.' }
    'unapplied' { Write-Output '  chezmoi has unapplied changes: review ''chezmoi diff'', then run ''chezmoi apply'' yourself.' }
    'clean' { Write-Output '  chezmoi: source state is applied.' }
  }
  # chezmoi creates the $PROFILE loader under ~\Documents. When PowerShell 7
  # reads its profile elsewhere (OneDrive), nothing is changed automatically.
  $pwshProfile = Get-DotfilesPwshProfilePath
  if (-not (Test-DotfilesSamePath $pwshProfile (Get-DotfilesChezmoiProfilePath))) {
    Write-Output "  PowerShell 7 reads its profile from $pwshProfile, not ~\Documents (OneDrive?)."
    Write-Output '  Before chezmoi apply, follow docs/windows.md (OneDrive): nothing is changed for you.'
  }
  Write-Output '  Windows Terminal: Settings > Startup > Default profile = PowerShell (7); "WSL (home)" opens WSL in ~.'
  Write-Output '  pwsh -File scripts\doctor.ps1      # verify'
}

if (-not $apply) {
  Write-Output ''
  Write-Output "Dry run: nothing was installed or written. $todo package(s) to install, $blocked blocked."
  if ($todo -gt 0) { Write-Output 'Re-run with --apply to install them; winget shows each installer and asks before accepting any agreement.' }
  Write-NextSteps
  exit 0
}

# ---------------------------------------------------------------------------
# Apply

if ($todo -eq 0) {
  Write-Output ''
  Write-Output "Nothing to install. $blocked blocked."
  if ($blocked -gt 0) { exit 1 }
  exit 0
}

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$logFile = Join-Path $stateDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
function Write-Log([string]$Text) { Add-Content -LiteralPath $logFile -Value $Text -Encoding UTF8 }
Write-Output ''
Write-Output "Logging to $logFile"
Write-Log ("bootstrap --apply on Windows {0}, PowerShell {1}" -f [Environment]::OSVersion.Version, $PSVersionTable.PSVersion)

# Configuration files that installers must not touch. Compared before and after
# each package so that an unexpected edit is reported instead of going unnoticed.
$protectedFiles = @(
  (Get-DotfilesPwshProfilePath),
  (Get-DotfilesChezmoiProfilePath),
  (Join-Path $HOME 'Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1'),
  (Join-Path $HOME '.config/powershell/dotfiles.ps1'),
  (Join-Path $localAppData 'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'),
  (Join-Path $HOME '.gitconfig')
)
function Get-ProtectedSnapshot {
  foreach ($file in $protectedFiles) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      '{0} {1}' -f $file, (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    } else {
      '{0} absent' -f $file
    }
  }
}

function Stop-Failed([string]$Text) {
  Write-Output "FAILED: $Text"
  Write-Log "FAILED: $Text"
  Write-Output "Log: $logFile"
  Write-Output 'Fix the cause and re-run; installed packages are skipped.'
  exit 1
}

Write-DotfilesSection 'Apply'
foreach ($package in $packages) {
  # Re-check: an earlier installer may have brought this package in as well.
  $result = Get-PackageState $package
  if ($result.State -eq 'ok') { continue }
  if ($result.State -ne 'todo') {
    Write-Output "==> skip $($package.Id): $($result.Detail)"
    Write-Log "skip $($package.Id): $($result.Detail)"
    continue
  }
  $wingetArgs = Get-InstallArguments $package
  Write-Output "==> install $($package.Id)"
  Write-Output ('    > winget ' + ($wingetArgs -join ' '))
  Write-Log ''
  Write-Log ('[{0}] winget {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), ($wingetArgs -join ' '))
  $before = Get-ProtectedSnapshot
  # Not piped or redirected: winget's progress and any agreement prompt must
  # reach the terminal. winget keeps its own detailed log (DiagOutputDir).
  & winget @wingetArgs
  $code = $LASTEXITCODE
  Write-Log "exit $(Format-WingetCode $code)"
  $after = Get-ProtectedSnapshot
  $changed = @($after | Where-Object { $before -notcontains $_ })
  if ($changed.Count -gt 0) {
    Write-Output "WARNING: installing $($package.Id) changed configuration files. Review them (chezmoi diff / git diff):"
    Write-Log "WARNING: $($package.Id) changed configuration files"
    foreach ($line in $changed) {
      $name = ($line -replace ' (absent|[0-9A-F]{64})$', '')
      Write-Output "  $name"
      Write-Log "  $name"
    }
  }
  if ($code -ne 0) { Stop-Failed "winget install $($package.Id) (exit $(Format-WingetCode $code))" }
  if ((Test-WingetPackage $package.Id $package.Source) -ne 'installed') {
    Stop-Failed "winget reported success, but $($package.Id) is not listed as installed"
  }
}

Write-DotfilesSection 'Result'
$remaining = 0
foreach ($package in $packages) {
  $result = Get-PackageState $package
  Write-PackageLine $package $result
  Write-Log ('{0} {1} {2}' -f $result.State, $package.Id, $result.Detail)
  if ($result.State -ne 'ok') { $remaining++ }
}
Write-Output ''
Write-Output "Log: $logFile"
Write-NextSteps
if ($remaining -gt 0) { exit 1 }
exit 0
