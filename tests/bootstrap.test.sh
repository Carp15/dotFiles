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
    [ -e "$W/ctl/chezmoi-unapplied" ] && echo " M .zshrc"
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
  '^  ok +Brewfile' '^  ok +Codex CLI' '0 step\(s\) to run'
[ ! -s "$W/calls" ] && ok "bootstrap dry run (macOS): no commands run" || ng "macOS dry run ran commands" "$(cat "$W/calls")"

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

for case_line in "chezmoi-unapplied|unapplied changes" "chezmoi-fails|'chezmoi status' failed"; do
  ctl="${case_line%%|*}"
  reason="${case_line#*|}"
  W="$TEST_TMP/bs-$ctl"
  bs_machine "$W"
  touch "$W/ctl/$ctl"
  out="$(bs_run "$W" --apply)"
  rc=$?
  got="$(bs_calls "$W")"
  if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qF "$reason" &&
    printf '%s\n' "$out" | grep -qE '^  blocked +Claude Code +apply chezmoi first' &&
    ! printf '%s' "$got" | grep -qE 'mise install \(|claude|codex'; then
    ok "bootstrap --apply with $ctl: mise tools and installers blocked, exit 1"
  else
    ng "bootstrap --apply with $ctl (exit $rc)" "$got
$out"
  fi
done

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
