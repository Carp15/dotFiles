# scripts/bootstrap.sh: dry run, --apply against stubs, and the safety stops.
# Every system-changing command is a stub that appends to $W/calls; --apply is
# only ever run inside a fake machine directory.
# shellcheck shell=bash

# bs_machine DIR [macos]: a fake machine. Stubs find their state through
# $HOME/.. ($W), so they work under `env -i`. Control files in $W/ctl turn on
# failures.
bs_machine() {
  local W="$1"
  mkdir -p "$W/bin" "$W/home/.local/bin" "$W/home/.config/mise/conf.d" "$W/ctl" "$W/tmp" "$W/src"
  : >"$W/calls"
  : >"$W/installed"
  echo "$REPO/home" >"$W/source-path"
  printf 'zshrc\n' >"$W/home/.zshrc"
  : >"$W/home/.config/mise/config.toml"
  : >"$W/home/.config/mise/conf.d/wsl.toml"
  if [ "${2:-}" = macos ]; then
    cp "$TEST_TMP/uname-darwin/uname" "$W/bin/uname"
  else
    cp "$TEST_TMP/uname-linux/uname" "$W/bin/uname"
  fi
  stub "$W/bin/getent" 'echo "u:x:1000:1000::/home/u:/usr/bin/zsh"'
  stub "$W/bin/sudo" 'echo "sudo $*" >>"$HOME/../calls"; exec "$@"'
  stub "$W/bin/apt-get" 'W="$HOME/.."; echo "apt-get $*" >>"$W/calls"
case "$1" in
  update) [ -e "$W/ctl/fail-apt-update" ] && exit 100 ;;
  install) shift; for p in "$@"; do case "$p" in -*) ;; *) echo "$p" >>"$W/installed" ;; esac; done ;;
esac
exit 0'
  stub "$W/bin/dpkg-query" 'for a in "$@"; do pkg="$a"; done
grep -qx "$pkg" "$HOME/../installed" && printf "install ok installed" || exit 1'
  stub "$W/bin/chezmoi" 'W="$HOME/.."
case "$1" in
  source-path) cat "$W/source-path" ;;
  status)
    [ -e "$W/ctl/chezmoi-fails" ] && { echo "chezmoi: template error" >&2; exit 1; }
    # Lines of $W/chezmoi-status are what `chezmoi status` reports as pending.
    [ -e "$W/chezmoi-status" ] && cat "$W/chezmoi-status"
    exit 0 ;;
  *) echo "chezmoi $*" >>"$W/calls"; exit 99 ;;
esac'
  stub "$W/bin/curl" 'W="$HOME/.."; echo "curl $*" >>"$W/calls"
out=""; prev=""; url=""
for a in "$@"; do [ "$prev" = -o ] && out="$a"; prev="$a"; url="$a"; done
case "$url" in
  https://mise.run) name=mise ;;
  https://claude.ai/install.sh) name=claude ;;
  https://chatgpt.com/codex/install.sh) name=codex ;;
  *) echo "unexpected URL $url" >&2; exit 2 ;;
esac
[ -e "$W/ctl/fail-curl-$name" ] && { echo "curl: (6) Could not resolve host" >&2; exit 6; }
[ -e "$W/ctl/html-$name" ] && { echo "<html>proxy</html>" >"$out"; exit 0; }
cp "$W/src/$name" "$out"'
  # What the fake installers install.
  stub "$W/src/mise-bin" 'W="$HOME/.."
case "$1" in
  ls) [ -e "$W/mise-installed" ] || echo "java  temurin-21 (missing)  cfg  temurin-21" ;;
  install)
    [ "$(pwd)" = "$HOME" ] && where=home || where="$(pwd)"
    echo "mise install (cwd=$where)" >>"$W/calls"
    [ -e "$W/ctl/fail-mise-install" ] && exit 1
    touch "$W/mise-installed" ;;
esac
exit 0'
  stub "$W/src/mise" 'echo "run mise installer" >>"$HOME/../calls"; cp "$HOME/../src/mise-bin" "$HOME/.local/bin/mise"'
  stub "$W/src/claude" 'echo "run claude installer" >>"$HOME/../calls"
[ -e "$HOME/../ctl/fail-run-claude" ] && exit 1
printf "#!/bin/sh\n" >"$HOME/.local/bin/claude"; chmod +x "$HOME/.local/bin/claude"'
  stub "$W/src/codex" 'echo "run codex installer CODEX_NON_INTERACTIVE=${CODEX_NON_INTERACTIVE:-unset}" >>"$HOME/../calls"
printf "#!/bin/sh\n" >"$HOME/.local/bin/codex"; chmod +x "$HOME/.local/bin/codex"'
}

bs_run() { # DIR [ARGS...]
  local W="$1"
  shift
  env -i HOME="$W/home" USER=u TMPDIR="$W/tmp" PATH="$W/bin:$TOOLS" \
    DOTFILES_OSRELEASE_FILE="${BS_OSRELEASE:-$FX/wsl2}" DOTFILES_OS_RELEASE_FILE="${BS_OS_RELEASE:-$FX/ubuntu}" \
    bash "$REPO/scripts/bootstrap.sh" "$@" 2>&1
}

# Calls in order; curl reduced to its URL.
bs_calls() {
  awk '$1 == "curl" { print "curl " $NF; next } { print }' "$1/calls" | tr '\n' ';'
}

apt_packages="$(sed 's/#.*//' "$REPO/packages/wsl/apt.txt" | awk 'NF {printf "%s%s", sep, $1; sep=" "}')"
mark_done() { # DIR STEP...: pretend steps are already satisfied
  local W="$1" step
  shift
  for step in "$@"; do
    case "$step" in
      apt) printf '%s\n' $apt_packages >"$W/installed" ;;
      mise) cp "$W/src/mise-bin" "$W/home/.local/bin/mise" ;;
      mise-tools) touch "$W/mise-installed" ;;
      claude | codex) printf '#!/bin/sh\n' >"$W/home/.local/bin/$step" && chmod +x "$W/home/.local/bin/$step" ;;
    esac
  done
}

# --- dry run -----------------------------------------------------------------

W="$TEST_TMP/bs-dry"
bs_machine "$W"
chmod -R a-w "$W/home" "$W/tmp"
out="$(bs_run "$W")"
rc=$?
chmod -R u+w "$W/home" "$W/tmp"
check "bootstrap dry run (fresh WSL, read-only HOME and TMPDIR): plan only" 0 "$rc" "$out" \
  '5 step\(s\) to run' "sudo apt-get install -y $apt_packages" 'https://mise.run' 'https://claude.ai/install.sh' \
  'CODEX_NON_INTERACTIVE=1 sh'
[ ! -s "$W/calls" ] && ! printf '%s\n' "$out" | grep -qiE 'permission denied|not permitted|cannot create' &&
  [ ! -e "$W/home/.local/state" ] && ok "bootstrap dry run: no commands run, nothing written" ||
  ng "bootstrap dry run changed something" "$(cat "$W/calls")
$out"

W="$TEST_TMP/bs-dry-macos"
bs_machine "$W" macos
stub "$W/bin/brew" 'echo "brew $*" >>"$HOME/../calls.brew"; [ "$2" = check ]'
mark_done "$W" mise mise-tools claude codex
out="$(bs_run "$W")"
rc=$?
check "bootstrap dry run (macOS, everything installed): all ok" 0 "$rc" "$out" \
  '^  ok +Brewfile' '^  ok +Claude Code' '0 step\(s\) to run'
[ ! -s "$W/calls" ] && ok "bootstrap dry run (macOS): no commands run" || ng "macOS dry run ran commands" "$(cat "$W/calls")"
# Codex CLI is a Brewfile cask on macOS: no separate step, no official installer.
printf '%s\n' "$out" | grep -q 'Codex CLI' && ng "macOS plan still lists a Codex CLI step" "$out" ||
  ok "bootstrap (macOS): Codex CLI is left to the Brewfile, no separate step"

# macOS without Codex: brew bundle (which declares cask "codex") installs it,
# and the official Codex installer is never downloaded.
W="$TEST_TMP/bs-macos-no-codex"
bs_machine "$W" macos
stub "$W/bin/brew" 'W="$HOME/.."
case "$2" in
  check) [ -e "$W/brew-done" ] ;;
  install) echo "brew $*" >>"$W/calls"; touch "$W/brew-done"; printf "#!/bin/sh\n" >"$HOME/.local/bin/codex"; chmod +x "$HOME/.local/bin/codex" ;;
esac'
mark_done "$W" mise mise-tools claude
out="$(bs_run "$W" --apply)"
rc=$?
got="$(bs_calls "$W")"
[ "$rc" = 0 ] && [ "$got" = "brew bundle install --file $REPO/packages/macos/Brewfile --no-upgrade;" ] &&
  ! printf '%s' "$got" | grep -q 'chatgpt.com/codex' &&
  ok "bootstrap --apply (macOS, no Codex): brew bundle installs it, no official installer" ||
  ng "macOS without Codex (exit $rc)" "$got
$out"
grep -q '^cask "codex"$' "$REPO/packages/macos/Brewfile" && ok "Brewfile declares cask \"codex\"" ||
  ng "Brewfile does not declare cask \"codex\""

# --- Homebrew: check and install use the same criterion ----------------------
# bootstrap installs what is missing and never upgrades, so the Brewfile check
# must ignore updates (--no-upgrade) exactly like the install does. This brew
# parses its arguments in any order. `bundle check` succeeds when the Brewfile
# is installed; with $W/brew-outdated present it fails unless --no-upgrade is
# given, like Homebrew does for an outdated cask. Every check is recorded in
# $W/brew.check (read-only); `bundle install` and anything else go to $W/calls.
brew_mock() { # DIR
  stub "$1/bin/brew" 'W="$HOME/.."
nu=no file="" prev=""
for a in "$@"; do
  case "$a" in
    --no-upgrade) nu=yes ;;
    --file=*) file="${a#--file=}" ;;
  esac
  [ "$prev" = --file ] && file="$a"
  prev="$a"
done
case "$1:$2" in
  bundle:check)
    echo "check file=$file no_upgrade=$nu" >>"$W/brew.check"
    [ -e "$W/brew-installed" ] || exit 1
    [ -e "$W/brew-outdated" ] && [ "$nu" = no ] && exit 1
    exit 0 ;;
  bundle:install)
    echo "install file=$file no_upgrade=$nu" >>"$W/calls"
    touch "$W/brew-installed"
    exit 0 ;;
  *) echo "brew $*" >>"$W/calls"; exit 99 ;;
esac'
}
# brew_machine DIR STATE...: a Mac where everything but the Brewfile is done.
brew_machine() {
  local W="$1" state
  shift
  bs_machine "$W" macos
  brew_mock "$W"
  mark_done "$W" mise mise-tools claude
  : >"$W/brew.check"
  for state in "$@"; do touch "$W/brew-$state"; done
}
brewfile="$REPO/packages/macos/Brewfile"
brew_dirs=""

# Case A: everything installed and current.
W="$TEST_TMP/bs-brew-current"
brew_machine "$W" installed
brew_dirs="$brew_dirs $W"
out="$(bs_run "$W")"
rc=$?
check "Brewfile (all installed): dry run reports ok" 0 "$rc" "$out" '^  ok +Brewfile'
out="$(bs_run "$W" --apply)"
rc=$?
[ "$rc" = 0 ] && ! grep -q '^install' "$W/calls" && printf '%s\n' "$out" | grep -q 'Nothing to install' &&
  ok "Brewfile (all installed): --apply does not run brew bundle install" ||
  ng "Brewfile (all installed): --apply (exit $rc)" "$(cat "$W/calls")
$out"

# Case B: installed, but a cask is outdated.
W="$TEST_TMP/bs-brew-outdated"
brew_machine "$W" installed outdated
brew_dirs="$brew_dirs $W"
HOME="$W/home" "$W/bin/brew" bundle check --file "$brewfile" >/dev/null 2>&1
plain=$?
HOME="$W/home" "$W/bin/brew" bundle check --file "$brewfile" --no-upgrade >/dev/null 2>&1
noup=$?
: >"$W/brew.check"
[ "$plain" != 0 ] && [ "$noup" = 0 ] && ok "brew mock: outdated cask fails plain check, passes --no-upgrade" ||
  ng "brew mock: plain=$plain no-upgrade=$noup"
out="$(bs_run "$W")"
rc=$?
check "Brewfile (outdated cask): dry run reports ok, not todo" 0 "$rc" "$out" '^  ok +Brewfile' '0 step\(s\) to run'
out="$(bs_run "$W" --apply)"
rc=$?
[ "$rc" = 0 ] && ! grep -q '^install' "$W/calls" &&
  ok "Brewfile (outdated cask): --apply does not run brew bundle install, exit 0" ||
  ng "Brewfile (outdated cask): --apply (exit $rc)" "$(cat "$W/calls")
$out"

# Case C: something declared is not installed.
W="$TEST_TMP/bs-brew-missing"
brew_machine "$W"
brew_dirs="$brew_dirs $W"
out="$(bs_run "$W")"
rc=$?
check "Brewfile (missing package): dry run reports todo with the no-upgrade install" 0 "$rc" "$out" \
  '^  todo +Brewfile' 'brew bundle install --file packages/macos/Brewfile --no-upgrade'
[ ! -s "$W/calls" ] && ok "Brewfile (missing package): dry run runs no install" || ng "dry run installed" "$(cat "$W/calls")"
: >"$W/brew.check"
out="$(bs_run "$W" --apply)"
rc=$?
installs="$(grep -c '^install' "$W/calls")"
checks_after="$(awk 'END {print NR}' "$W/brew.check")"
[ "$rc" = 0 ] && [ "$installs" = 1 ] && [ "$checks_after" -ge 2 ] &&
  printf '%s\n' "$out" | sed -n '/^Result/,$p' | grep -qE '^  ok +Brewfile' &&
  ok "Brewfile (missing package): --apply installs once, and the re-check passes" ||
  ng "Brewfile (missing package): --apply (exit $rc, installs=$installs, checks=$checks_after)" "$(cat "$W/calls")
$out"

# Case D: every check and install in A-C used the same Brewfile and --no-upgrade.
records="$(for d in $brew_dirs; do cat "$d/brew.check"; grep -E '^install' "$d/calls"; done)"
bad="$(printf '%s\n' "$records" | awk -v f="file=$brewfile" 'NF && ($2 != f || $3 != "no_upgrade=yes")')"
[ -n "$records" ] && [ -z "$bad" ] &&
  printf '%s\n' "$records" | grep -q '^check' && printf '%s\n' "$records" | grep -q '^install' &&
  ok "Brewfile: every check and install used the repository Brewfile with --no-upgrade" ||
  ng "Brewfile: inconsistent brew bundle arguments" "$bad"

# --- --apply against stubs ---------------------------------------------------

W="$TEST_TMP/bs-apply"
bs_machine "$W"
out="$(bs_run "$W" --apply)"
rc=$?
want="sudo apt-get update;apt-get update;sudo apt-get install -y $apt_packages;apt-get install -y $apt_packages;curl https://mise.run;run mise installer;mise install (cwd=home);curl https://claude.ai/install.sh;run claude installer;curl https://chatgpt.com/codex/install.sh;run codex installer CODEX_NON_INTERACTIVE=1;"
got="$(bs_calls "$W")"
[ "$rc" = 0 ] && [ "$got" = "$want" ] && ok "bootstrap --apply (fresh WSL): apt -> mise -> mise install -> claude -> codex" ||
  ng "bootstrap --apply order (exit $rc)" "got:  $got
want: $want
$out"
ls "$W/home/.local/state/dotfiles/bootstrap/"*.log >/dev/null 2>&1 &&
  printf '%s\n' "$out" | grep -qE 'sha256 [0-9a-f]{64}' && ok "bootstrap --apply: log written, installer sha256 recorded" ||
  ng "bootstrap --apply: no log or sha256" "$out"
: >"$W/calls"
out="$(bs_run "$W" --apply)"
rc=$?
check "bootstrap --apply again: nothing to install" 0 "$rc" "$out" 'Nothing to install'
[ ! -s "$W/calls" ] && ok "bootstrap --apply again: no commands run" || ng "second run ran commands" "$(cat "$W/calls")"

# --- safety stops ------------------------------------------------------------

# Only the targets a step needs block it: mise tools wait for the mise
# configuration, the official installers for the shell startup files, and an
# unrelated pending target (Git settings) blocks nothing.
# bs_pending NAME STATUS_LINES: a fresh machine whose chezmoi reports STATUS_LINES.
bs_pending() {
  W="$TEST_TMP/bs-pending-$1"
  bs_machine "$W"
  printf '%s\n' "$2" >"$W/chezmoi-status"
  out="$(bs_run "$W" --apply)"
  rc=$?
  got="$(bs_calls "$W")"
}

bs_pending git ' A .config/git/config'
[ "$rc" = 0 ] && printf '%s' "$got" | grep -q 'mise install (' && printf '%s' "$got" | grep -q 'run codex installer' &&
  printf '%s\n' "$out" | grep -qE '\.config/git/config +\(not needed by bootstrap\)' &&
  ok "bootstrap --apply with only Git settings pending: nothing blocked, exit 0" ||
  ng "unrelated pending target blocked bootstrap (exit $rc)" "$got
$out"

bs_pending zshrc ' M .zshrc'
[ "$rc" = 1 ] && printf '%s' "$got" | grep -q 'mise install (' && ! printf '%s' "$got" | grep -qE 'claude|codex' &&
  printf '%s\n' "$out" | grep -qE '^  blocked +Claude Code +~/\.zshrc is not applied yet' &&
  printf '%s\n' "$out" | grep -qE '\.zshrc +\(needed by bootstrap\)' &&
  ok "bootstrap --apply with ~/.zshrc pending: installers blocked, mise tools still run, exit 1" ||
  ng "shell target pending (exit $rc)" "$got
$out"

bs_pending zprofile ' M .zprofile'
[ "$rc" = 1 ] && ! printf '%s' "$got" | grep -qE 'claude|codex' &&
  ok "bootstrap --apply with ~/.zprofile pending: installers blocked, exit 1" || ng "zprofile pending (exit $rc)" "$got
$out"

bs_pending mise ' M .config/mise/config.toml'
[ "$rc" = 1 ] && ! printf '%s' "$got" | grep -q 'mise install (' && printf '%s' "$got" | grep -q 'run codex installer' &&
  printf '%s\n' "$out" | grep -qE '^  blocked +mise tools .*~/\.config/mise/config\.toml is not applied yet' &&
  ok "bootstrap --apply with the mise config pending: mise tools blocked, installers still run, exit 1" ||
  ng "mise config pending (exit $rc)" "$got
$out"

bs_pending wsl-conf ' A .config/mise/conf.d
 A .config/mise/conf.d/wsl.toml'
[ "$rc" = 1 ] && ! printf '%s' "$got" | grep -q 'mise install (' &&
  ok "bootstrap --apply on WSL with conf.d/wsl.toml pending: mise tools blocked, exit 1" ||
  ng "wsl conf.d pending (exit $rc)" "$got
$out"

W="$TEST_TMP/bs-chezmoi-fails"
bs_machine "$W"
touch "$W/ctl/chezmoi-fails"
out="$(bs_run "$W" --apply)"
rc=$?
got="$(bs_calls "$W")"
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qF "'chezmoi status' failed" &&
  printf '%s\n' "$out" | grep -qE '^  blocked +Claude Code' && printf '%s\n' "$out" | grep -qE '^  blocked +mise tools' &&
  ! printf '%s' "$got" | grep -qE 'mise install \(|claude|codex' &&
  ok "bootstrap --apply when chezmoi status fails: mise tools and installers blocked, exit 1" ||
  ng "chezmoi status failure (exit $rc)" "$got
$out"

W="$TEST_TMP/bs-fetch-fails"
bs_machine "$W"
mark_done "$W" apt mise mise-tools
touch "$W/ctl/fail-curl-claude"
out="$(bs_run "$W" --apply)"
rc=$?
got="$(bs_calls "$W")"
[ "$rc" = 1 ] && [ "$got" = "curl https://claude.ai/install.sh;" ] &&
  printf '%s\n' "$out" | grep -q 'FAILED: download claude installer' && printf '%s\n' "$out" | grep -q 'Full log:' &&
  ok "bootstrap --apply: installer download failure stops before running it and before codex" ||
  ng "installer download failure (exit $rc)" "$got
$out"

W="$TEST_TMP/bs-html"
bs_machine "$W"
mark_done "$W" apt mise mise-tools
touch "$W/ctl/html-claude"
out="$(bs_run "$W" --apply)"
rc=$?
[ "$rc" = 1 ] && ! grep -q 'run claude installer' "$W/calls" && printf '%s\n' "$out" | grep -q 'not a shell script' &&
  ok "bootstrap --apply: a non-script download is never executed" || ng "html download (exit $rc)" "$out"

W="$TEST_TMP/bs-run-fails"
bs_machine "$W"
mark_done "$W" apt mise mise-tools
touch "$W/ctl/fail-run-claude"
out="$(bs_run "$W" --apply)"
rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'FAILED: run claude installer' && ! grep -q codex "$W/calls" &&
  ok "bootstrap --apply: installer failure stops before codex" || ng "installer failure (exit $rc)" "$out"

W="$TEST_TMP/bs-mise-fails"
bs_machine "$W"
mark_done "$W" apt mise
touch "$W/ctl/fail-mise-install"
out="$(bs_run "$W" --apply)"
rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q 'FAILED: mise install' && ! grep -q curl "$W/calls" &&
  ok "bootstrap --apply: mise install failure stops before the official installers" || ng "mise failure (exit $rc)" "$out"

W="$TEST_TMP/bs-unsupported"
bs_machine "$W"
out="$(BS_OSRELEASE="$FX/plain" bs_run "$W" --apply)"
rc=$?
check "bootstrap on plain Linux: unsupported, exit 2" 2 "$rc" "$out" 'Unsupported platform: linux'
out="$(BS_OS_RELEASE="$FX/debian" bs_run "$W" --apply)"
rc=$?
check "bootstrap on WSL Debian: unsupported, exit 2" 2 "$rc" "$out" 'only Ubuntu'
stub "$W/bin/id" 'echo 0'
out="$(bs_run "$W" --apply)"
rc=$?
check "bootstrap as root: refused, exit 2" 2 "$rc" "$out" 'not root'
[ ! -s "$W/calls" ] && ok "bootstrap unsupported / root: no commands run" || ng "unsupported ran commands" "$(cat "$W/calls")"
