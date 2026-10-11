# Shared helpers for scripts/bootstrap.ps1 and scripts/doctor.ps1. Dot-sourced,
# not executed; defines functions only and has no side effects.
#
# Runs on Windows PowerShell 5.1 as well as PowerShell 7: a fresh Windows 11
# has only 5.1 until bootstrap installs PowerShell 7. Keep to 5.1 syntax (no
# ternary, no ??, no &&) and ASCII text (5.1 reads BOM-less files as ANSI).
#
# Test hook (tests/windows.test.sh): DOTFILES_TEST_PLATFORM replaces the
# platform answer so that the scripts can be exercised by pwsh on Linux.

$DotfilesLibDir = $PSScriptRoot

# Prints windows | macos | wsl | linux | unknown. Windows is answered here;
# anything else is decided by scripts/lib/platform.sh, the single source of
# truth for macOS / WSL / Linux, so pwsh inside WSL reports wsl, not windows.
function Get-DotfilesPlatform {
  if ($env:DOTFILES_TEST_PLATFORM) { return $env:DOTFILES_TEST_PLATFORM }
  # Windows PowerShell 5.1 (Desktop) exists only on Windows and has no $IsWindows.
  if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) { return 'windows' }
  $answer = & sh -c '. "$1" && dotfiles_platform' sh (Join-Path $DotfilesLibDir 'platform.sh') 2>$null
  if ($LASTEXITCODE -eq 0 -and $answer) { return "$answer".Trim() }
  return 'unknown'
}

# True when this session runs elevated (High mandatory level). whoami.exe is
# used instead of the .NET identity API so that tests can stub it.
function Test-DotfilesElevated {
  $groups = & whoami /groups 2>$null
  return [bool]($groups | Select-String -SimpleMatch 'S-1-16-12288')
}

function Write-DotfilesSection([string]$Title) {
  Write-Output ''
  Write-Output $Title
  Write-Output ('-' * $Title.Length)
}

# Names from a packages/commands/*.txt list: one per line, "#" starts a comment.
function Read-DotfilesCommandList([string]$Path) {
  foreach ($line in Get-Content -LiteralPath $Path) {
    $name = (($line -replace '#.*', '').Trim() -split '\s+')[0]
    if ($name) { $name }
  }
}

# Packages declared in packages/windows/winget.json, in file order, as objects
# with Id and Source (the winget source name, e.g. "winget").
function Read-DotfilesWingetPackages([string]$Path) {
  $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  foreach ($source in $json.Sources) {
    foreach ($package in $source.Packages) {
      [pscustomobject]@{ Id = $package.PackageIdentifier; Source = $source.SourceDetails.Name }
    }
  }
}

# winget return codes used here (github.com/microsoft/winget-cli,
# doc/windows/package-manager/winget/returnCodes.md).
$WingetNoApplicationsFound = -1978335212       # 0x8A150014
$WingetCodeNames = @{
  -1978335212 = 'no matching package installed'
  -1978335162 = 'source agreements were not accepted'
  -1978335167 = 'package agreements were not accepted'
  -1978335166 = 'a prompt could not read input'
  -1978335135 = 'a version is already installed'
  -1978334967 = 'a restart is needed to finish the installation'
  -1978334966 = 'a restart is needed before retrying'
  -1978334964 = 'cancelled by the user'
}

function Format-WingetCode([int]$Code) {
  $text = '0x{0:X8}' -f $Code
  if ($WingetCodeNames.ContainsKey($Code)) { $text += ': ' + $WingetCodeNames[$Code] }
  return $text
}

# Whether winget sees the package as installed: returns installed | missing |
# error, and sets $script:WingetLastCode. --disable-interactivity makes winget
# fail instead of prompting, so this check never accepts an agreement and
# never waits for input.
function Test-WingetPackage([string]$Id, [string]$Source) {
  & winget list --id $Id --exact --source $Source --disable-interactivity *> $null
  $script:WingetLastCode = $LASTEXITCODE
  if ($LASTEXITCODE -eq 0) { return 'installed' }
  if ($LASTEXITCODE -eq $WingetNoApplicationsFound) { return 'missing' }
  return 'error'
}

function Test-DotfilesSamePath([string]$Left, [string]$Right) {
  if (-not $Left -or -not $Right) { return $false }
  # NTFS paths are case-insensitive.
  return [IO.Path]::GetFullPath($Left).TrimEnd('\', '/') -ieq [IO.Path]::GetFullPath($Right).TrimEnd('\', '/')
}

# chezmoi readiness, shared by bootstrap (information) and doctor. Sets
# $script:ChezmoiState to missing | other-source | failed | unapplied | clean,
# $script:ChezmoiSource and $script:ChezmoiStatus.
function Get-DotfilesChezmoiState([string]$RepoRoot) {
  $script:ChezmoiSource = ''
  $script:ChezmoiStatus = @()
  if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) { $script:ChezmoiState = 'missing'; return }
  $script:ChezmoiSource = "$(& chezmoi source-path 2>$null)".Trim()
  if ($LASTEXITCODE -ne 0 -or -not (Test-DotfilesSamePath $script:ChezmoiSource (Join-Path $RepoRoot 'home'))) {
    $script:ChezmoiState = 'other-source'; return
  }
  $status = & chezmoi status 2>&1
  if ($LASTEXITCODE -ne 0) { $script:ChezmoiState = 'failed'; return }
  $script:ChezmoiStatus = @($status | Where-Object { "$_".Trim() })
  if ($script:ChezmoiStatus.Count -gt 0) { $script:ChezmoiState = 'unapplied' } else { $script:ChezmoiState = 'clean' }
}

# Where chezmoi puts the $PROFILE loader (home/Documents/PowerShell/...).
function Get-DotfilesChezmoiProfilePath {
  return Join-Path $HOME 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1'
}

# Where PowerShell 7 loads $PROFILE from, asked from pwsh itself (without
# running any profile). It is Documents\PowerShell under the Documents known
# folder, which OneDrive can redirect away from $HOME\Documents. Before pwsh is
# installed (or on PATH), the same known folder is asked from .NET.
function Get-DotfilesPwshProfilePath {
  if (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue) {
    $path = "$(& pwsh -NoLogo -NoProfile -NonInteractive -Command '$PROFILE.CurrentUserCurrentHost' 2>$null)".Trim()
    if ($path) { return $path }
  }
  $documents = [Environment]::GetFolderPath('MyDocuments')
  if (-not $documents) { $documents = Join-Path $HOME 'Documents' }
  return Join-Path (Join-Path $documents 'PowerShell') 'Microsoft.PowerShell_profile.ps1'
}

# Optional package groups (Android development, ...): a group <name> is
# packages/windows/winget-<name>.json and/or packages/commands/windows-<name>.txt.
# Neither bootstrap nor doctor treats a group as part of the base environment
# unless it is selected with --with <name>.
function Get-DotfilesOptionalGroups([string]$RepoRoot) {
  $names = @()
  $names += Get-ChildItem -Path (Join-Path $RepoRoot 'packages/windows') -Filter 'winget-*.json' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.BaseName -replace '^winget-', '' }
  $names += Get-ChildItem -Path (Join-Path $RepoRoot 'packages/commands') -Filter 'windows-*.txt' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.BaseName -replace '^windows-', '' }
  return @($names | Sort-Object -Unique)
}

function Get-DotfilesGroupFiles([string]$RepoRoot, [string]$Group) {
  $winget = Join-Path $RepoRoot "packages/windows/winget-$Group.json"
  $commands = Join-Path $RepoRoot "packages/commands/windows-$Group.txt"
  if (-not (Test-Path -LiteralPath $winget)) { $winget = $null }
  if (-not (Test-Path -LiteralPath $commands)) { $commands = $null }
  return @{ Winget = $winget; Commands = $commands }
}

# Parses [--apply] [--with <group>]... [--help]. Returns a hashtable with
# Apply, With (array), Help and Error (a message, or empty).
function ConvertFrom-DotfilesArguments([object[]]$Arguments, [string[]]$Groups, [bool]$AllowApply) {
  $result = @{ Apply = $false; With = @(); Help = $false; Error = '' }
  for ($i = 0; $i -lt $Arguments.Count; $i++) {
    $argument = "$($Arguments[$i])"
    if ($AllowApply -and $argument -match '^(--apply|-Apply)$') { $result.Apply = $true; continue }
    if ($argument -match '^(-h|--help|-\?|-Help)$') { $result.Help = $true; continue }
    if ($argument -match '^(--with|-With)$') {
      $i++
      if ($i -ge $Arguments.Count) { $result.Error = "$argument needs a group name"; return $result }
      $group = "$($Arguments[$i])"
      if ($Groups -notcontains $group) {
        $result.Error = "Unknown group: $group (available: $($Groups -join ', '))"
        return $result
      }
      if ($result.With -notcontains $group) { $result.With += $group }
      continue
    }
    $result.Error = "Unknown option: $argument"
    return $result
  }
  return $result
}
