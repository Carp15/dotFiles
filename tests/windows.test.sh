# scripts/bootstrap.ps1 and scripts/doctor.ps1, run by pwsh against stubs.
#
# These are mock tests, not Windows tests: pwsh runs on this (macOS / Linux)
# host with DOTFILES_TEST_PLATFORM=windows, and every Windows command (winget,
# whoami, chezmoi, wt, wsl, adb, ...) is a stub. Passing them says nothing about
# a real Windows machine; see docs/windows.md for the checks done there.
#
# Where PowerShell 7 reads $PROFILE is simulated with XDG_CONFIG_HOME, which
# Linux pwsh uses for its profile directory: $XDG_CONFIG_HOME/powershell/.
#   standard Documents  XDG_CONFIG_HOME=~/Documents, with ~/Documents/powershell
#                       a symlink to PowerShell (Linux paths are case-sensitive;
#                       the scripts compare paths case-insensitively, like NTFS)
#   OneDrive redirect   XDG_CONFIG_HOME=~/OneDrive/Documents (WIN_DOCS)
#
# pwsh is taken from DOTFILES_TEST_PWSH or PATH; without it the file is skipped.
# shellcheck shell=bash

PWSH="${DOTFILES_TEST_PWSH:-$(command -v pwsh 2>/dev/null)}"
if [ -z "$PWSH" ] || [ ! -x "$PWSH" ]; then
  skip "Windows scripts (pwsh not found; set DOTFILES_TEST_PWSH or put pwsh on PATH)"
  return 0 2>/dev/null || exit 0
fi

win_ids() { sed -n 's/.*"PackageIdentifier": "\([^"]*\)".*/\1/p' "$1"; }
win_packages="$(win_ids "$REPO/packages/windows/winget.json")"
win_android="$(win_ids "$REPO/packages/windows/winget-android.json")"
win_package_count="$(printf '%s\n' "$win_packages" | wc -l | tr -d ' ')"

# win_machine DIR: a fake Windows user. Stubs find their state through
# $HOME/.. ($W). winget is a PowerShell script so that it can return winget's
# real (negative, 32-bit) exit codes, which a /bin/sh stub cannot. adb is not
# on PATH: Android development is not set up.
win_machine() {
  local W="$1" name
  mkdir -p "$W/bin" "$W/home/AppData/Local" "$W/home/Documents/PowerShell" "$W/ctl" "$W/installed" "$W/tmp"
  ln -s PowerShell "$W/home/Documents/powershell"
  : >"$W/calls"
  : >"$W/lists"
  echo "$REPO/home" >"$W/source-path"
  printf '%s\n' '$W = Join-Path $HOME ".."
switch ($args[0]) {
  "--version" { "v1.12.350"; exit 0 }
  "list" {
    $id = $args[([array]::IndexOf($args, "--id")) + 1]
    Add-Content (Join-Path $W "lists") ($args -join " ")
    if (Test-Path (Join-Path $W "ctl/list-fails")) { exit -1978335162 }
    if (Test-Path (Join-Path $W "installed/$id")) { exit 0 }
    exit -1978335212
  }
  "install" {
    $id = $args[([array]::IndexOf($args, "--id")) + 1]
    Add-Content (Join-Path $W "calls") ("winget " + ($args -join " "))
    if (Test-Path (Join-Path $W "ctl/fail-$id")) { "Package agreements were not accepted."; exit -1978335167 }
    if (Test-Path (Join-Path $W "ctl/touch-profile-$id")) {
      Add-Content (Join-Path $HOME "Documents/PowerShell/Microsoft.PowerShell_profile.ps1") "# added by an installer"
    }
    if (-not (Test-Path (Join-Path $W "ctl/noop-$id"))) { New-Item -ItemType File (Join-Path $W "installed/$id") | Out-Null }
    exit 0
  }
}
exit 1' >"$W/bin/winget.ps1"
  stub "$W/bin/whoami" '[ -e "$HOME/../ctl/elevated" ] && echo "Mandatory Label\High Mandatory Level Label S-1-16-12288" || echo "Mandatory Label\Medium Mandatory Level Label S-1-16-8192"'
  stub "$W/bin/chezmoi" 'W="$HOME/.."
case "$1" in
  source-path) cat "$W/source-path" ;;
  status) [ -e "$W/ctl/chezmoi-unapplied" ] && echo " A .config/powershell/dotfiles.ps1"; exit 0 ;;
  managed)
    printf "%s\n" .config .config/git .config/git/ignore .config/powershell .config/powershell/dotfiles.ps1
    [ -e "$W/ctl/skip-profile" ] || printf "%s\n" Documents Documents/PowerShell Documents/PowerShell/Microsoft.PowerShell_profile.ps1
    [ -e "$W/ctl/chezmoi-foreign" ] && printf "%s\n" .zshrc .config/mise .config/mise/config.toml
    exit 0 ;;
  *) echo "chezmoi $*" >>"$W/calls"; exit 99 ;;
esac'
  # pwsh puts its own $PSHOME first on PATH, so the scripts find the real pwsh
  # that runs the tests rather than a stub; its version check is not mocked.
  stub "$W/bin/git" 'echo "git version 2.55.0.windows.1"'
  for name in wt wsl; do stub "$W/bin/$name" 'exit 0'; done
}

win_install() { # DIR ID...: these packages are installed
  local W="$1" id
  shift
  for id in "$@"; do : >"$W/installed/$id"; done
}

win_apply_config() { # DIR: what `chezmoi apply` would have written on a fresh machine
  local h="$1/home"
  mkdir -p "$h/.config/powershell" "$h/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles"
  cp "$REPO/home/dot_config/powershell/dotfiles.ps1" "$h/.config/powershell/dotfiles.ps1"
  cp "$REPO/home/Documents/PowerShell/create_Microsoft.PowerShell_profile.ps1" \
    "$h/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  cp "$REPO/home/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json" \
    "$h/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json"
}

ps_run() { # DIR SCRIPT [ARGS...]
  local W="$1" script="$2"
  shift 2
  # XDG_CACHE_HOME: pwsh's own startup cache, kept out of the fake home that the
  # tests compare before and after. XDG_CONFIG_HOME: where $PROFILE is (above).
  env -i HOME="$W/home" LOCALAPPDATA="$W/home/AppData/Local" TMPDIR="$W/tmp" XDG_CACHE_HOME="$W/tmp/cache" \
    XDG_CONFIG_HOME="${WIN_DOCS:-$W/home/Documents}" PATH="$W/bin:$TOOLS" \
    DOTFILES_TEST_PLATFORM="${WIN_PLATFORM-windows}" DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
    POWERSHELL_TELEMETRY_OPTOUT=1 POWERSHELL_UPDATECHECK=Off \
    "$PWSH" -NoProfile -NonInteractive -File "$REPO/scripts/$script" "$@" 2>&1
}

win_calls() { tr '\n' ';' <"$1/calls"; }
install_line() { printf 'winget install --id %s --exact --source winget --no-upgrade' "$1"; }
install_lines() { # ID...: the calls --apply makes, in order
  local id
  for id in "$@"; do printf '%s;' "$(install_line "$id")"; done
}
home_snapshot() { # DIR: every file under the fake home except bootstrap's own logs
  (cd "$1/home" && find . -type f ! -path './AppData/Local/dotfiles/*' -exec cksum {} + | sort)
}

# --- platform (scripts/lib/windows.ps1) ----------------------------------------
# Off Windows the answer comes from scripts/lib/platform.sh, so pwsh inside WSL
# is never mistaken for Windows native.

for case_line in "uname-linux|wsl2|wsl" "uname-linux|plain|linux" "uname-darwin|plain|macos"; do
  split "$case_line"
  got="$(env -i PATH="$TEST_TMP/${split_fields[0]}:$TOOLS" DOTFILES_OSRELEASE_FILE="$FX/${split_fields[1]}" \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 POWERSHELL_TELEMETRY_OPTOUT=1 HOME="$TEST_TMP/tmp" \
    "$PWSH" -NoProfile -NonInteractive -Command ". '$REPO/scripts/lib/windows.ps1'; Get-DotfilesPlatform" 2>&1)"
  [ "$got" = "${split_fields[2]}" ] && ok "windows.ps1: pwsh on ${split_fields[2]} -> $got (via platform.sh)" ||
    ng "windows.ps1: pwsh on ${split_fields[2]} -> '$got'"
done

# --- declarations ----------------------------------------------------------------

! grep -q 'Google.AndroidStudio' "$REPO/packages/windows/winget.json" &&
  [ "$win_android" = "Google.AndroidStudio" ] &&
  ! grep -qx 'adb' "$REPO/packages/commands/windows.txt" && grep -qx 'adb' "$REPO/packages/commands/windows-android.txt" &&
  ok "packages: Android Studio and adb are only in the optional android group" ||
  ng "packages: Android is still part of the base environment"

# --- bootstrap.ps1: dry run ------------------------------------------------------

W="$TEST_TMP/win-dry"
win_machine "$W"
printf 'existing profile\n' >"$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
before="$(home_snapshot "$W")"
out="$(ps_run "$W" bootstrap.ps1)"
rc=$?
after="$(home_snapshot "$W")"
check "bootstrap.ps1 dry run (fresh Windows): base plan only, android reported" 0 "$rc" "$out" \
  "$win_package_count package\(s\) to install" "> $(install_line Microsoft.PowerShell)" "> $(install_line twpayne.chezmoi)" \
  'Optional, not selected: android' '^  - +Google.AndroidStudio +not installed' 'To include it: --with android' \
  'Dry run: nothing was installed'
printf '%s\n' "$out" | grep -q "> $(install_line Google.AndroidStudio)" &&
  ng "bootstrap.ps1 dry run plans Android Studio without --with android" "$out" ||
  ok "bootstrap.ps1 dry run: Android Studio is not planned without --with android"
[ ! -s "$W/calls" ] && [ "$before" = "$after" ] && [ ! -e "$W/home/AppData/Local/dotfiles" ] &&
  ok "bootstrap.ps1 dry run: no install, no log, existing profile untouched" ||
  ng "bootstrap.ps1 dry run changed something" "$(cat "$W/calls")
$out"
grep -q -- '--disable-interactivity' "$W/lists" && ! grep -q -- '--accept' "$W/lists" &&
  ok "bootstrap.ps1: the installed check never prompts and never accepts agreements" ||
  ng "bootstrap.ps1: winget list arguments" "$(cat "$W/lists")"
printf '%s\n' "$out" | grep -q -- '--accept' && ng "bootstrap.ps1 plans to accept agreements" "$out" ||
  ok "bootstrap.ps1: no --accept-*-agreements in the plan"

out="$(ps_run "$W" bootstrap.ps1 --with android)"
rc=$?
check "bootstrap.ps1 dry run --with android: Android Studio planned after the base" 0 "$rc" "$out" \
  "$((win_package_count + 1)) package\(s\) to install" "> $(install_line Google.AndroidStudio)" 'dry run, with android'
[ ! -s "$W/calls" ] && [ ! -e "$W/home/AppData/Local/dotfiles" ] && ok "bootstrap.ps1 dry run --with android: no install" ||
  ng "bootstrap.ps1 dry run --with android installed" "$(win_calls "$W")"

W="$TEST_TMP/win-dry-done"
win_machine "$W"
# shellcheck disable=SC2086 # IDs are single words
win_install "$W" $win_packages
out="$(ps_run "$W" bootstrap.ps1 -Apply)"
rc=$?
check "bootstrap.ps1 -Apply (base installed, no android): nothing to install" 0 "$rc" "$out" \
  '^  ok +Microsoft.PowerShell' '^  ok +twpayne.chezmoi' 'Nothing to install'
[ ! -s "$W/calls" ] && ok "bootstrap.ps1 (base installed): no install, Android Studio not installed" ||
  ng "bootstrap.ps1 installed something" "$(win_calls "$W")"

# --- bootstrap.ps1: --apply ------------------------------------------------------

W="$TEST_TMP/win-apply"
win_machine "$W"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
# shellcheck disable=SC2086
want="$(install_lines $win_packages)"
got="$(win_calls "$W")"
[ "$rc" = 0 ] && [ "$got" = "$want" ] && ok "bootstrap.ps1 --apply (fresh): base packages only, in winget.json order" ||
  ng "bootstrap.ps1 --apply (exit $rc)" "got:  $got
want: $want
$out"
ls "$W/home/AppData/Local/dotfiles/bootstrap/"*.log >/dev/null 2>&1 && ok "bootstrap.ps1 --apply: log written" ||
  ng "bootstrap.ps1 --apply: no log" "$out"
: >"$W/calls"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 --apply again: nothing to install" 0 "$rc" "$out" 'Nothing to install'
[ ! -s "$W/calls" ] && ok "bootstrap.ps1 --apply again: idempotent, no winget install" || ng "second run installed" "$(win_calls "$W")"

out="$(ps_run "$W" bootstrap.ps1 --apply --with android)"
rc=$?
got="$(win_calls "$W")"
[ "$rc" = 0 ] && [ "$got" = "$(install_lines Google.AndroidStudio)" ] &&
  ok "bootstrap.ps1 --apply --with android (base done): installs only Android Studio" ||
  ng "bootstrap.ps1 --with android (exit $rc)" "$got
$out"
: >"$W/calls"
out="$(ps_run "$W" bootstrap.ps1 --with android --apply)"
rc=$?
check "bootstrap.ps1 --with android --apply again: nothing to install" 0 "$rc" "$out" 'Nothing to install'
[ ! -s "$W/calls" ] && ok "bootstrap.ps1 --with android again: idempotent" || ng "android reinstalled" "$(win_calls "$W")"

W="$TEST_TMP/win-apply-android"
win_machine "$W"
out="$(ps_run "$W" bootstrap.ps1 --apply --with android)"
rc=$?
# shellcheck disable=SC2086
want="$(install_lines $win_packages Google.AndroidStudio)"
got="$(win_calls "$W")"
[ "$rc" = 0 ] && [ "$got" = "$want" ] && ok "bootstrap.ps1 --apply --with android (fresh): base first, then Android Studio" ||
  ng "bootstrap.ps1 --apply --with android (exit $rc)" "got:  $got
want: $want"

# --- bootstrap.ps1: failures stop ------------------------------------------------

W="$TEST_TMP/win-fail"
win_machine "$W"
touch "$W/ctl/fail-Git.Git"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
want="$(install_lines Microsoft.PowerShell Microsoft.WindowsTerminal Git.Git)"
got="$(win_calls "$W")"
[ "$rc" = 1 ] && [ "$got" = "$want" ] && printf '%s\n' "$out" | grep -q 'FAILED: winget install Git.Git (exit 0x8A150041: package agreements were not accepted)' &&
  ok "bootstrap.ps1 --apply: a failed install stops before the next package, exit 1" ||
  ng "bootstrap.ps1 failure (exit $rc)" "got:  $got
want: $want
$out"
rm "$W/ctl/fail-Git.Git"
: >"$W/calls"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
got="$(win_calls "$W")"
[ "$rc" = 0 ] && [ "${got%%;*}" = "$(install_line Git.Git)" ] &&
  ok "bootstrap.ps1 --apply after fixing: resumes at the failed package" || ng "resume (exit $rc)" "$got
$out"

W="$TEST_TMP/win-fail-android"
win_machine "$W"
# shellcheck disable=SC2086
win_install "$W" $win_packages
touch "$W/ctl/fail-Google.AndroidStudio"
out="$(ps_run "$W" bootstrap.ps1 --apply --with android)"
rc=$?
check "bootstrap.ps1 --with android: a failed optional install stops, exit 1" 1 "$rc" "$out" \
  'FAILED: winget install Google.AndroidStudio'

W="$TEST_TMP/win-noop"
win_machine "$W"
touch "$W/ctl/noop-Microsoft.PowerShell"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'FAILED: winget reported success, but Microsoft.PowerShell is not listed' &&
  [ "$(wc -l <"$W/calls" | tr -d ' ')" = 1 ] && ok "bootstrap.ps1 --apply: success without the package installed is a failure" ||
  ng "bootstrap.ps1 noop install (exit $rc)" "$out"

W="$TEST_TMP/win-list-fails"
win_machine "$W"
touch "$W/ctl/list-fails"
out="$(ps_run "$W" bootstrap.ps1)"
rc=$?
check "bootstrap.ps1 dry run, winget list fails: blocked with the reason" 0 "$rc" "$out" \
  '^  blocked +Git.Git +winget list failed \(0x8A150046: source agreements were not accepted\)'
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 --apply, winget list fails: nothing installed, exit 1" 1 "$rc" "$out" \
  "Nothing to install. $win_package_count blocked"
[ ! -s "$W/calls" ] && ok "bootstrap.ps1 (winget list fails): no install" || ng "installed despite failing check" "$(win_calls "$W")"

W="$TEST_TMP/win-no-winget"
win_machine "$W"
rm "$W/bin/winget.ps1"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 without winget: blocked, exit 1" 1 "$rc" "$out" 'blocked +Microsoft.PowerShell +winget not found'

# --- bootstrap.ps1: existing configuration is protected --------------------------

W="$TEST_TMP/win-protect"
win_machine "$W"
mkdir -p "$W/home/Documents/WindowsPowerShell" "$W/home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
printf 'existing profile\n' >"$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
printf 'existing 5.1 profile\n' >"$W/home/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
printf '{"profiles":[]}\n' >"$W/home/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
printf '[user]\n' >"$W/home/.gitconfig"
before="$(home_snapshot "$W")"
out="$(ps_run "$W" bootstrap.ps1 --apply --with android)"
rc=$?
after="$(home_snapshot "$W")"
[ "$rc" = 0 ] && [ "$before" = "$after" ] && ! grep -q "^chezmoi " "$W/calls" && ! printf '%s\n' "$out" | grep -q WARNING &&
  ok "bootstrap.ps1 --apply: PowerShell 7 / 5.1 profiles, Terminal settings, .gitconfig untouched; chezmoi never run" ||
  ng "bootstrap.ps1 --apply touched configuration (exit $rc)" "$out"

W="$TEST_TMP/win-installer-edits"
win_machine "$W"
printf 'existing profile\n' >"$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
touch "$W/ctl/touch-profile-Git.Git"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 --apply: an installer editing \$PROFILE is reported" 0 "$rc" "$out" \
  'WARNING: installing Git.Git changed configuration files' 'Documents/PowerShell/Microsoft.PowerShell_profile.ps1'

W="$TEST_TMP/win-redirect-bootstrap"
win_machine "$W"
mkdir -p "$W/home/OneDrive/Documents"
before="$(home_snapshot "$W")"
out="$(WIN_DOCS="$W/home/OneDrive/Documents" ps_run "$W" bootstrap.ps1)"
rc=$?
after="$(home_snapshot "$W")"
check "bootstrap.ps1 with Documents redirected: tells you before chezmoi apply" 0 "$rc" "$out" \
  'PowerShell 7 reads its profile from .*OneDrive/Documents/powershell/Microsoft.PowerShell_profile.ps1' \
  'nothing is changed for you'
[ "$before" = "$after" ] && [ -z "$(ls -A "$W/home/OneDrive/Documents")" ] &&
  ok "bootstrap.ps1 with Documents redirected: no profile created anywhere" || ng "redirect: files changed" "$after"

# --- bootstrap.ps1: refusals -----------------------------------------------------

W="$TEST_TMP/win-refuse"
win_machine "$W"
touch "$W/ctl/elevated"
out="$(ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 elevated: refused, exit 2" 2 "$rc" "$out" 'non-administrator'
rm "$W/ctl/elevated"
out="$(WIN_PLATFORM=wsl ps_run "$W" bootstrap.ps1 --apply)"
rc=$?
check "bootstrap.ps1 on WSL: refused, exit 2" 2 "$rc" "$out" 'Unsupported platform: wsl.*scripts/bootstrap.sh'
for case_line in "--upgrade|Unknown option: --upgrade" "--with|--with needs a group name" \
  "--with intellij|Unknown group: intellij \(available: android\)"; do
  split "$case_line"
  # shellcheck disable=SC2086 # the option and its value are separate words
  out="$(ps_run "$W" bootstrap.ps1 --apply ${split_fields[0]})"
  rc=$?
  check "bootstrap.ps1 --apply ${split_fields[0]}: exit 2" 2 "$rc" "$out" "${split_fields[1]}"
done
[ ! -s "$W/calls" ] && [ ! -s "$W/lists" ] && ok "bootstrap.ps1 refusals: winget never called" ||
  ng "refusal called winget" "$(cat "$W/calls" "$W/lists")"

# --- doctor.ps1: base environment and optional android ---------------------------

W="$TEST_TMP/win-doctor"
win_machine "$W"
# shellcheck disable=SC2086
win_install "$W" $win_packages
win_apply_config "$W"
before="$(home_snapshot "$W")"
out="$(ps_run "$W" doctor.ps1)"
rc=$?
after="$(home_snapshot "$W")"
check "doctor.ps1 (base Windows, no Android SDK): exit 0" 0 "$rc" "$out" 'Platform +windows' 'Version +ok +7\.' \
  'twpayne.chezmoi +installed' 'Status +clean' 'Targets +Windows only' \
  'Optional group: android \(information only\)' 'adb +- +not installed \(Android Studio' \
  'Google.AndroidStudio +- +not installed' 'Status +not set up \(2 item\(s\) missing\); not required' \
  'Loaded +ok +PowerShell 7 loads the shared settings' 'Fragment +present' 'Result: 0 error\(s\), 0 warning'
[ ! -s "$W/calls" ] && [ "$before" = "$after" ] && ok "doctor.ps1: read-only (no install, no apply, no file changed)" ||
  ng "doctor.ps1 changed something" "$(win_calls "$W")"

out="$(ps_run "$W" doctor.ps1 --with android)"
rc=$?
check "doctor.ps1 --with android, Android not set up: errors, exit 1" 1 "$rc" "$out" \
  'Optional group: android \(required by --with android\)' 'adb +error +not installed' 'Google.AndroidStudio +error +not installed'
stub "$W/bin/adb" 'exit 0'
win_install "$W" Google.AndroidStudio
out="$(ps_run "$W" doctor.ps1 --with android)"
rc=$?
check "doctor.ps1 --with android, Android set up: exit 0" 0 "$rc" "$out" 'adb +present' 'Google.AndroidStudio +installed' \
  'Result: 0 error'
out="$(ps_run "$W" doctor.ps1)"
check "doctor.ps1 without --with, Android set up: reported as set up" 0 $? "$out" 'Status +set up'
out="$(ps_run "$W" doctor.ps1 --with intellij)"
check "doctor.ps1 unknown group: exit 2" 2 $? "$out" 'Unknown group: intellij'

rm "$W/installed/Git.Git"
out="$(ps_run "$W" doctor.ps1)"
rc=$?
win_install "$W" Git.Git
check "doctor.ps1: a missing base package is 'not installed', exit 1" 1 "$rc" "$out" 'Git.Git +error +not installed'

touch "$W/ctl/chezmoi-foreign"
out="$(ps_run "$W" doctor.ps1)"
rc=$?
rm "$W/ctl/chezmoi-foreign"
check "doctor.ps1: zsh / mise targets on Windows are misconfigured, exit 1" 1 "$rc" "$out" \
  'Targets +error +misconfigured: macOS / WSL targets in the Windows target state: \.zshrc, \.config/mise'

touch "$W/ctl/chezmoi-unapplied"
out="$(ps_run "$W" doctor.ps1)"
rc=$?
rm "$W/ctl/chezmoi-unapplied"
check "doctor.ps1: unapplied chezmoi is a warning, exit 0" 0 "$rc" "$out" 'Status +warn +1 managed path' 'Result: 0 error'

out="$(WIN_PLATFORM=macos ps_run "$W" doctor.ps1)"
rc=$?
check "doctor.ps1 on macOS: refused, exit 2" 2 "$rc" "$out" 'scripts/doctor.sh'

# --- doctor.ps1: PowerShell profiles ---------------------------------------------
# Each case: what doctor reports, and that doctor changed no file.

prof_case() { # LABEL WANT_EXIT REGEX...: doctor on $W (WIN_DOCS honoured), no file changed
  local label="$1" want="$2" before after out rc
  shift 2
  before="$(home_snapshot "$W")"
  out="$(ps_run "$W" doctor.ps1)"
  rc=$?
  after="$(home_snapshot "$W")"
  check "doctor.ps1 profile: $label" "$want" "$rc" "$out" "$@"
  [ "$before" = "$after" ] || ng "doctor.ps1 profile: $label: files changed" "$after"
}
prof_machine() { # DIR: base installed, shared settings and fragment applied, no $PROFILE
  win_machine "$1"
  # shellcheck disable=SC2086
  win_install "$1" $win_packages
  win_apply_config "$1"
  rm "$1/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
}
loader_line=". (Join-Path \$HOME '.config/powershell/dotfiles.ps1')"

W="$TEST_TMP/win-prof"
prof_machine "$W"
prof_case "standard Documents, no \$PROFILE yet: warned" 0 \
  '\$PROFILE +.*/Documents/powershell/Microsoft.PowerShell_profile.ps1' 'Loaded +warn +no: \$PROFILE does not exist yet'
win_apply_config "$W"
prof_case "standard Documents, chezmoi loader: loaded" 0 'Loaded +ok' 'Result: 0 error\(s\), 0 warning'
printf 'Set-Alias ll Get-ChildItem\n' >"$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
prof_case "existing \$PROFILE without the line: warned, not changed" 0 \
  'Loaded +warn +no: \$PROFILE does not load the shared settings; add this line' 'Result: 0 error'
printf '%s\n' "$loader_line" >>"$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
prof_case "existing \$PROFILE with the line added by hand: loaded" 0 'Loaded +ok'
mkdir -p "$W/home/Documents/WindowsPowerShell"
printf '%s\n' "$loader_line" >"$W/home/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
prof_case "5.1 profile present: information only, no warning" 0 \
  '5.1 profile +present +\(not managed' 'Result: 0 error\(s\), 0 warning'
rm "$W/home/.config/powershell/dotfiles.ps1"
prof_case "shared settings not applied: warned" 0 'Shared +warn +not applied' 'Loaded +warn +no: the shared settings are not applied yet'

W="$TEST_TMP/win-prof-onedrive"
prof_machine "$W"
win_apply_config "$W"
mkdir -p "$W/home/OneDrive/Documents"
export WIN_DOCS="$W/home/OneDrive/Documents"
prof_case "OneDrive redirect, chezmoi loader in ~/Documents: warned, unused loader shown" 0 \
  '\$PROFILE +.*/OneDrive/Documents/powershell/Microsoft.PowerShell_profile.ps1' \
  'Loaded +warn +no: Documents is redirected \(OneDrive\?\)' 'Unused +.*skipPowerShellProfile'
[ -z "$(ls -A "$W/home/OneDrive/Documents")" ] && ok "doctor.ps1 OneDrive redirect: nothing created in the redirected Documents" ||
  ng "doctor.ps1 OneDrive redirect created files"
touch "$W/ctl/skip-profile"
rm "$W/home/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
mkdir -p "$W/home/OneDrive/Documents/powershell"
printf '%s\n' "$loader_line" >"$W/home/OneDrive/Documents/powershell/Microsoft.PowerShell_profile.ps1"
prof_case "OneDrive redirect, line added to the real \$PROFILE, loader skipped: loaded" 0 \
  'Loader +not managed on this machine \(skipPowerShellProfile' 'Loaded +ok' 'Result: 0 error\(s\), 0 warning'
unset WIN_DOCS

# --- bash scripts under Git Bash (MINGW) ------------------------------------------

W="$TEST_TMP/win-gitbash"
mkdir -p "$W/bin" "$W/home"
cp "$TEST_TMP/uname-mingw/uname" "$W/bin/uname"
out="$(env -i HOME="$W/home" PATH="$W/bin:$TOOLS" bash "$REPO/scripts/bootstrap.sh" --apply 2>&1)"
rc=$?
check "bootstrap.sh under Git Bash: points to bootstrap.ps1, exit 2" 2 "$rc" "$out" 'scripts/bootstrap.ps1'
out="$(env -i HOME="$W/home" PATH="$W/bin:$TOOLS" bash "$REPO/scripts/doctor.sh" 2>&1)"
check "doctor.sh under Git Bash: warns and points to doctor.ps1" 0 0 "$out" \
  'Platform +windows' 'Platform +warn +Windows native \(Git Bash\): run scripts/doctor.ps1'
