# PowerShell 7 settings shared across Windows machines, managed by chezmoi
# (Windows only; see home/.chezmoiignore). $PROFILE loads this file; see
# home/Documents/PowerShell/create_Microsoft.PowerShell_profile.ps1.
#
# Windows native is the GUI host and WSL is the development environment
# (docs/windows.md), so nothing here sets up mise or language runtimes.

# Windows PowerShell 5.1 has its own profile directory and never loads this
# file; the guard covers a manual dot-source from 5.1.
if ($PSVersionTable.PSVersion.Major -lt 7) { return }

# History: keep a long record without repeated entries. PSReadLine's default
# filter that keeps lines with password/token-like words out of the history
# file is left in place.
if (Get-Module -Name PSReadLine) {
  Set-PSReadLineOption -HistoryNoDuplicates -MaximumHistoryCount 100000
}

# Move into WSL: projects live in the Linux filesystem (docs/wsl.md).
#   wsl-home  shell in the Linux home of the default distribution
#   wsl-here  shell in the current Windows directory (/mnt/c/...)
function wsl-home { wsl.exe --cd '~' }
function wsl-here { wsl.exe --cd (Get-Location -PSProvider FileSystem).ProviderPath }
