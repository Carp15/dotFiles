# scripts/doctor.sh: exit status for healthy and broken environments. Every
# declared command is a stub, so results do not depend on the host.
# shellcheck shell=bash

D="$TEST_TMP/doctor"
mkdir -p "$D/stubs" "$D/hidden" "$D/home"
for name in $(sed 's/#.*//' "$REPO/packages/commands/common.txt" "$REPO/packages/commands/wsl.txt" \
  "$REPO/packages/commands/macos.txt"); do
  stub "$D/stubs/$name" 'exit 0'
done
stub "$D/stubs/nvim" 'echo "NVIM v0.12.6"'
stub "$D/stubs/mise" 'case "$1" in which) [ -n "${MISE_HAS:-}" ] && [ "$2" = "$MISE_HAS" ] && echo "/m/installs/$2/bin/$2" || exit 1 ;; esac; exit 0'
stub "$D/stubs/chezmoi" "case \"\$1\" in source-path) echo $REPO/home ;; esac; exit 0"

# doctor_run PATH_PREFIX [VAR=value...]: doctor on a fake WSL2 Ubuntu machine.
doctor_run() {
  local prefix="$1"
  shift
  env -i HOME="$D/home" MISE_SHELL=zsh PATH="$prefix:$D/stubs:$TOOLS" \
    DOTFILES_OSRELEASE_FILE="$FX/wsl2" DOTFILES_OS_RELEASE_FILE="$FX/ubuntu" "$@" \
    bash "$REPO/scripts/doctor.sh" 2>&1
}
hide() { mv "$D/stubs/$1" "$D/hidden/$1"; }
unhide() { mv "$D/hidden/$1" "$D/stubs/$1"; }
linux="$TEST_TMP/uname-linux"

chmod -R a-w "$D/home"
out="$(doctor_run "$linux")"
rc=$?
chmod -R u+w "$D/home"
check "doctor (WSL2, everything present, read-only HOME): exit 0" 0 "$rc" "$out" \
  'Platform +wsl' 'WSL2, ubuntu 24.04' 'Version +ok +0\.12 >= 0\.11' 'Result: 0 error'
printf '%s\n' "$out" | grep -qiE 'permission denied|not permitted|cannot create' &&
  ng "doctor tried to write" "$out" || ok "doctor: no write attempts"

out="$(doctor_run "$linux" DOTFILES_OSRELEASE_FILE="$FX/plain")"
rc=$?
check "doctor (plain Linux): warning only, common list checked" 0 "$rc" "$out" \
  'Platform +linux' 'not a supported target'

out="$(doctor_run "$TEST_TMP/uname-darwin")"
rc=$?
check "doctor (macOS): common + macos lists, exit 0" 0 "$rc" "$out" 'Platform +macos' 'packages/commands/macos.txt'

hide helm
out="$(doctor_run "$linux")"
rc=$?
unhide helm
check "doctor: missing command is 'not installed', exit 1" 1 "$rc" "$out" 'helm +error +not installed'

hide node
out="$(doctor_run "$linux" MISE_HAS=node)"
rc=$?
unhide node
check "doctor: tool installed by mise but not on PATH is 'misconfigured', exit 1" 1 "$rc" "$out" \
  'node +error +misconfigured: installed by mise'

hide mise
out="$(doctor_run "$linux")"
rc=$?
unhide mise
check "doctor: mise not installed, exit 1" 1 "$rc" "$out" 'mise +error +not installed'
[ "$(printf '%s\n' "$out" | grep -cE '^mise +error')" = 1 ] && ok "doctor: a missing mise is counted once" ||
  ng "doctor: mise counted more than once" "$out"

for r in java node go; do hide "$r"; done
out="$(doctor_run "$linux")"
rc=$?
for r in java node go; do unhide "$r"; done
check "doctor: Java / Node / Go not installed, exit 1" 1 "$rc" "$out" \
  'java +error +not installed' 'node +error +not installed' 'go +error +not installed'

out="$(doctor_run "$linux:relative/bin::$D/stubs")"
rc=$?
check "doctor: relative / empty PATH entries are errors, duplicates warned" 1 "$rc" "$out" \
  'PATH +error +misconfigured: relative' 'relative/bin' '\(empty\)' 'PATH +warn +duplicate'

out="$(doctor_run "$linux:$D/stubs")"
rc=$?
check "doctor: duplicate PATH entries alone are a warning, exit 0" 0 "$rc" "$out" 'PATH +warn +duplicate' 'Result: 0 error'

for case_line in "NVIM v0.10.4|1|Neovim +error +misconfigured: 0\.10 is older" \
  "NVIM v0.11.0-dev-1234+g0123|0|Version +ok" "NVIM v1.0.0|0|Version +ok"; do
  version="${case_line%%|*}"
  rest="${case_line#*|}"
  stub "$D/stubs/nvim" "echo \"$version\""
  out="$(doctor_run "$linux")"
  rc=$?
  check "doctor: Neovim '$version'" "${rest%%|*}" "$rc" "$out" "${rest#*|}"
done
stub "$D/stubs/nvim" 'echo "NVIM v0.12.6"'
