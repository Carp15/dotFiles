# Read-only environment check for Windows native; the counterpart of
# scripts/doctor.sh. It never installs, repairs, or applies anything, and it
# does not print environment values, credentials, or config contents.
#
# Findings are reported as in doctor.sh:
#   error  something declared is unusable. Two kinds are told apart:
#            "not installed"  the tool or package is absent; bootstrap.ps1 installs it
#            "misconfigured"  it exists but does not work as declared
#   warn   worth fixing, but nothing declared is broken
# Exit status: 1 if there is any error, 0 otherwise (warnings do not fail);
# 2 when run outside Windows native or with an unknown option.
#
# The base environment (packages/commands/windows.txt, packages/windows/winget.json)
# is required. Optional groups (windows-<group>.txt, winget-<group>.json, e.g.
# android) are reported for information only, unless selected with
# --with <group>, which makes them required.
#
# To see whether PowerShell 7 really loads the shared settings, doctor starts
# pwsh once with your profile, as opening a terminal would.
#
#   pwsh -File scripts\doctor.ps1 [--with android]
# Also runs on Windows PowerShell 5.1, before PowerShell 7 is installed.

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'windows.ps1')

$commandsFile = Join-Path $repoRoot 'packages/commands/windows.txt'
$wingetFile = Join-Path $repoRoot 'packages/windows/winget.json'
$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) { $localAppData = Join-Path (Join-Path $HOME 'AppData') 'Local' }

$groups = @(Get-DotfilesOptionalGroups $repoRoot)
$options = ConvertFrom-DotfilesArguments $args $groups $false
if ($options.Error -or $options.Help) {
  if ($options.Error) { Write-Output $options.Error; Write-Output '' }
  Write-Output 'Usage: doctor.ps1 [--with <group>]...'
  Write-Output "  --with <group>  require an optional group ($($groups -join ', ')) instead of only reporting it"
  if ($options.Error) { exit 2 }
  exit 0
}
$selected = $options.With

# How to get a command that no installer puts on PATH by itself.
$commandHints = @{
  adb = 'Android Studio > SDK Manager > SDK Tools > Android SDK Platform-Tools, then add <SDK>\platform-tools to PATH; docs/windows.md'
}

$script:errors = 0
$script:warnings = 0

function Write-Line([string]$Label, [string]$Text) { Write-Output ('{0,-12} {1}' -f $Label, $Text) }
function Report-Error([string]$Label, [string]$Text) {
  Write-Output ('{0,-12} error    {1}' -f $Label, $Text)
  $script:errors++
}
function Report-Warn([string]$Label, [string]$Text) {
  Write-Output ('{0,-12} warn     {1}' -f $Label, $Text)
  $script:warnings++
}
function Find-Application([string]$Name) {
  # ExternalScript too: a .ps1 on PATH is a command as well (and how tests stub winget).
  Get-Command $Name -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
}

# Commands from a list must resolve on PATH; they are never executed. Required
# lists report errors; optional ones only print. Missing items are counted in
# $script:missing (not returned: a function's printed lines are its output).
$script:missing = 0
function Test-CommandList([string]$Path, [bool]$Required) {
  foreach ($name in Read-DotfilesCommandList $Path) {
    $command = Find-Application $name
    $hint = ''
    if ($commandHints.ContainsKey($name)) { $hint = " ($($commandHints[$name]))" }
    if ($command) {
      Write-Output ('{0,-12} present  {1}' -f $name, $command.Source)
    } elseif ($Required) {
      Report-Error $name "not installed$hint"
      $script:missing++
    } else {
      Write-Output ('{0,-12} -        not installed{1}' -f $name, $hint)
      $script:missing++
    }
  }
}

# Packages from a winget file must be installed; counted like Test-CommandList.
function Test-WingetList([string]$Path, [bool]$Required) {
  if (-not (Find-Application 'winget')) {
    Write-Line 'winget' 'missing  (see Required commands); packages not checked'
    return
  }
  foreach ($package in Read-DotfilesWingetPackages $Path) {
    switch (Test-WingetPackage $package.Id $package.Source) {
      'installed' { Write-Output ('{0,-28} installed' -f $package.Id) }
      'missing' {
        $script:missing++
        if ($Required) {
          Report-Error $package.Id 'not installed (scripts\bootstrap.ps1 --apply)'
        } else {
          Write-Output ('{0,-28} -        not installed' -f $package.Id)
        }
      }
      default {
        Report-Warn $package.Id "could not check: winget list failed ($(Format-WingetCode $script:WingetLastCode))"
      }
    }
  }
}

# ---------------------------------------------------------------------------

Write-DotfilesSection 'System'
$platform = Get-DotfilesPlatform
Write-Line 'OS' ([Environment]::OSVersion.VersionString)
Write-Line 'PowerShell' ('{0} ({1})' -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)
Write-Line 'Platform' $platform
if ($platform -ne 'windows') {
  Write-Output ''
  Write-Output "Not Windows native: on macOS and WSL run scripts/doctor.sh. Nothing was checked."
  exit 2
}
if ($PSVersionTable.PSVersion.Major -lt 7) {
  Report-Warn 'PowerShell' 'running in Windows PowerShell 5.1; PowerShell 7 (pwsh) is the main shell'
}
if ($selected.Count -gt 0) { Write-Line 'Required' ('base + ' + ($selected -join ', ')) } else { Write-Line 'Required' 'base environment' }

# --- Base environment -----------------------------------------------------------

Write-DotfilesSection 'Required commands (packages/commands/windows.txt)'
Test-CommandList $commandsFile $true

Write-DotfilesSection 'Packages (packages/windows/winget.json)'
if (Find-Application 'winget') { Write-Line 'winget' ("$(& winget --version 2>$null)".Trim()) }
Test-WingetList $wingetFile $true

# --- Optional groups ---------------------------------------------------------------

foreach ($group in $groups) {
  $files = Get-DotfilesGroupFiles $repoRoot $group
  $required = $selected -contains $group
  if ($required) {
    Write-DotfilesSection "Optional group: $group (required by --with $group)"
  } else {
    Write-DotfilesSection "Optional group: $group (information only)"
  }
  $script:missing = 0
  if ($files.Commands) { Test-CommandList $files.Commands $required }
  if ($files.Winget) { Test-WingetList $files.Winget $required }
  if (-not $required) {
    if ($script:missing -gt 0) {
      Write-Line 'Status' "not set up ($($script:missing) item(s) missing); not required. To require it: doctor.ps1 --with $group"
    } else {
      Write-Line 'Status' 'set up'
    }
  }
}

# --- PowerShell 7 -----------------------------------------------------------------

Write-DotfilesSection 'PowerShell 7'
$havePwsh = [bool](Find-Application 'pwsh')
if ($havePwsh) {
  $pwshVersion = "$(& pwsh -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>$null)".Trim()
  if ($pwshVersion -match '^(\d+)\.') {
    if ([int]$Matches[1] -ge 7) {
      Write-Line 'Version' "ok       $pwshVersion"
    } else {
      Report-Error 'pwsh' "misconfigured: version $pwshVersion is older than 7"
    }
  } else {
    Report-Error 'pwsh' 'misconfigured: pwsh is on PATH but did not report a version'
  }
} else {
  # Counted once, under Required commands.
  Write-Line 'pwsh' 'missing  (see Required commands)'
}

# --- Git ----------------------------------------------------------------------

Write-DotfilesSection 'Git'
if (Find-Application 'git') {
  Write-Line 'Version' ("$(& git --version 2>$null)".Trim())
} else {
  Write-Line 'Git' 'missing  (see Required commands)'
}

# --- chezmoi ----------------------------------------------------------------------

Write-DotfilesSection 'Dotfiles (chezmoi)'
Get-DotfilesChezmoiState $repoRoot
switch ($script:ChezmoiState) {
  'missing' { Write-Line 'chezmoi' 'missing  (see Required commands)' }
  'other-source' {
    if ($script:ChezmoiSource) {
      Report-Warn 'Source dir' "not this repository: $($script:ChezmoiSource)"
    } else {
      Report-Warn 'Source dir' 'not configured (write sourceDir to ~/.config/chezmoi/chezmoi.toml; docs/windows.md)'
    }
  }
  'failed' { Report-Warn 'Status' 'unavailable (chezmoi status failed)' }
  'unapplied' {
    Write-Line 'Source dir' $script:ChezmoiSource
    Report-Warn 'Status' "$($script:ChezmoiStatus.Count) managed path(s) not applied:"
    foreach ($line in $script:ChezmoiStatus) { Write-Output ('             ' + $line) }
    Write-Line 'Next' 'review with "chezmoi diff" before applying anything'
  }
  'clean' {
    Write-Line 'Source dir' $script:ChezmoiSource
    Write-Line 'Status' 'clean (managed paths match the source state)'
  }
}

# Platform separation: Windows must receive its own targets and none of the
# macOS / WSL ones (home/.chezmoiignore).
$loaderManaged = $null
if ($script:ChezmoiState -eq 'unapplied' -or $script:ChezmoiState -eq 'clean') {
  $managed = @(& chezmoi managed 2>$null | ForEach-Object { "$_".Trim() -replace '\\', '/' })
  $foreign = @($managed | Where-Object { $_ -in @('.zshrc', '.zprofile', '.config/mise') -or $_ -like '.config/mise/*' })
  if ($foreign.Count -gt 0) {
    Report-Error 'Targets' "misconfigured: macOS / WSL targets in the Windows target state: $($foreign -join ', ')"
  } elseif ($managed -notcontains '.config/powershell/dotfiles.ps1') {
    Report-Error 'Targets' 'misconfigured: .config/powershell/dotfiles.ps1 is missing from the Windows target state'
  } else {
    Write-Line 'Targets' 'Windows only (no zsh / mise targets)'
  }
  $loaderManaged = $managed -contains 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1'
  if (-not $loaderManaged) {
    Write-Line 'Loader' 'not managed on this machine (skipPowerShellProfile in chezmoi.toml)'
  }
}

# --- PowerShell profile --------------------------------------------------------
# PowerShell 7 is started once with the user's profile and asked which $PROFILE
# it read and which file defined wsl-home (a function of the shared settings).
# The command is passed encoded so that Windows PowerShell 5.1 does not mangle
# its quotes. Profile contents are never printed.

Write-DotfilesSection 'PowerShell profile'
$shared = Join-Path $HOME '.config/powershell/dotfiles.ps1'
$chezmoiProfile = Get-DotfilesChezmoiProfilePath
$pwshProfile = ''
$loadedFrom = $null
if ($havePwsh) {
  $probe = @'
"DOTFILES-PROFILE=$($PROFILE.CurrentUserCurrentHost)"
$command = Get-Command wsl-home -CommandType Function -ErrorAction SilentlyContinue
if ($command) { "DOTFILES-LOADED=$($command.ScriptBlock.File)" } else { 'DOTFILES-LOADED=' }
'@
  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($probe))
  foreach ($line in @(& pwsh -NoLogo -NonInteractive -EncodedCommand $encoded 2>$null)) {
    if ("$line" -like 'DOTFILES-PROFILE=*') { $pwshProfile = "$line".Substring(17) }
    if ("$line" -like 'DOTFILES-LOADED=*') { $loadedFrom = "$line".Substring(16) }
  }
}
if (-not $pwshProfile) { $pwshProfile = Get-DotfilesPwshProfilePath }
$redirected = -not (Test-DotfilesSamePath $pwshProfile $chezmoiProfile)

if (Test-Path -LiteralPath $shared -PathType Leaf) {
  Write-Line 'Shared' "present  $shared"
} else {
  Report-Warn 'Shared' 'not applied: ~/.config/powershell/dotfiles.ps1 (chezmoi diff, then chezmoi apply)'
}
Write-Line '$PROFILE' $pwshProfile

if (-not $havePwsh) {
  Write-Line 'Loaded' 'not checked (pwsh missing; see Required commands)'
} elseif ($loadedFrom -and (Test-DotfilesSamePath $loadedFrom $shared)) {
  Write-Line 'Loaded' 'ok       PowerShell 7 loads the shared settings'
} elseif ($loadedFrom) {
  Report-Warn 'Loaded' 'wsl-home is defined by another file, not ~/.config/powershell/dotfiles.ps1'
} elseif (-not (Test-Path -LiteralPath $shared -PathType Leaf)) {
  Report-Warn 'Loaded' 'no: the shared settings are not applied yet (see Shared)'
} elseif ($redirected -and -not (Test-Path -LiteralPath $pwshProfile -PathType Leaf)) {
  Report-Warn 'Loaded' "no: Documents is redirected (OneDrive?); PowerShell 7 reads $pwshProfile, which does not exist. chezmoi does not create it there: follow docs/windows.md (OneDrive)"
} elseif (Test-Path -LiteralPath $pwshProfile -PathType Leaf) {
  Report-Warn 'Loaded' "no: `$PROFILE does not load the shared settings; add this line to it yourself: . (Join-Path `$HOME '.config/powershell/dotfiles.ps1')"
} else {
  Report-Warn 'Loaded' 'no: $PROFILE does not exist yet (chezmoi diff, then chezmoi apply creates the loader)'
}
if ($redirected -and $loaderManaged -and (Test-Path -LiteralPath $chezmoiProfile -PathType Leaf)) {
  Write-Line 'Unused' "$chezmoiProfile is not read by PowerShell 7; skipPowerShellProfile stops chezmoi managing it (docs/windows.md)"
}

# Windows PowerShell 5.1 has its own profile next to PowerShell 7's. It is not
# managed; the shared settings are for PowerShell 7 and return early on 5.1.
$documents = Split-Path -Parent (Split-Path -Parent $pwshProfile)
$desktopProfile = Join-Path $documents 'WindowsPowerShell/Microsoft.PowerShell_profile.ps1'
if (Test-Path -LiteralPath $desktopProfile -PathType Leaf) {
  Write-Line '5.1 profile' "present  (not managed; dotfiles settings apply to PowerShell 7 only) $desktopProfile"
} else {
  Write-Line '5.1 profile' '-        (not managed; dotfiles settings apply to PowerShell 7 only)'
}

# --- Windows Terminal ---------------------------------------------------------

Write-DotfilesSection 'Windows Terminal'
$fragment = Join-Path $localAppData 'Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json'
if (-not (Test-DotfilesSamePath $localAppData (Join-Path $HOME 'AppData/Local'))) {
  Report-Warn 'Fragment' "LOCALAPPDATA is not ~\AppData\Local; chezmoi writes the fragment under ~\AppData\Local"
}
if (Test-Path -LiteralPath $fragment -PathType Leaf) {
  Write-Line 'Fragment' "present  (profile ""WSL (home)"")"
} else {
  Report-Warn 'Fragment' 'not applied: Fragments/dotfiles/dotfiles.json (chezmoi diff, then chezmoi apply)'
}
Write-Line 'Settings' 'settings.json is not managed (Terminal rewrites it); set the default profile in Settings'

# --- Runtimes (information) ------------------------------------------------------
# WSL owns Java / Node / Go (docs/packages.md). Listed for awareness only.

Write-DotfilesSection 'Runtimes on Windows (information; WSL owns them)'
foreach ($name in @('java', 'node', 'go', 'mise')) {
  $command = Find-Application $name
  if ($command) { Write-Output ('{0,-12} present  {1}' -f $name, $command.Source) } else { Write-Output ('{0,-12} -' -f $name) }
}

Write-Output ''
Write-Output "Result: $($script:errors) error(s), $($script:warnings) warning(s). Diagnostic only: nothing was changed or applied."
if ($script:errors -gt 0) { exit 1 }
exit 0
