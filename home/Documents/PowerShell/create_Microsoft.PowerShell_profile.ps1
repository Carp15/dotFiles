# PowerShell 7 profile ($PROFILE). chezmoi creates this file only when it does
# not exist (create_ prefix) and never overwrites it afterwards, so an existing
# profile is kept and local additions below are yours. The shared settings are
# in ~/.config/powershell/dotfiles.ps1, which chezmoi keeps up to date.
$dotfilesProfile = Join-Path $HOME '.config/powershell/dotfiles.ps1'
if (Test-Path -LiteralPath $dotfilesProfile) { . $dotfilesProfile }
Remove-Variable -Name dotfilesProfile
