# Shared helpers for tests/*.test.sh. Sourced by tests/run.sh, which sets REPO
# and TEST_TMP.
# shellcheck shell=bash

pass=0
fail=0
skipped=0

ok() {
  pass=$((pass + 1))
  printf 'PASS  %s\n' "$1"
}

ng() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" | sed 's/^/      | /' | head -40
  fi
}

skip() {
  skipped=$((skipped + 1))
  printf 'SKIP  %s\n' "$1"
}

# check NAME WANT_EXIT GOT_EXIT OUTPUT [extended regex that must match]...
check() {
  local name="$1" want="$2" got="$3" out="$4" pattern
  shift 4
  if [ "$want" != "$got" ]; then
    ng "$name (exit $got, want $want)" "$out"
    return
  fi
  for pattern in "$@"; do
    if ! printf '%s\n' "$out" | grep -qE -- "$pattern"; then
      ng "$name (no match for /$pattern/)" "$out"
      return
    fi
  done
  ok "$name"
}

# split 'a|b|c' -> array split_fields (empty fields kept). Used instead of
# `read <<EOF`, whose temporary file the sandbox would refuse.
split() {
  local old_ifs=$IFS
  IFS='|'
  set -f
  # shellcheck disable=SC2086 # splitting on | is the point
  set -- $1
  set +f
  IFS=$old_ifs
  split_fields=("$@")
}

# stub PATH BODY: an executable /bin/sh script.
stub() {
  printf '#!/bin/sh\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

# A PATH directory with only the host utilities the scripts use, so results do
# not depend on what else the host has installed (e.g. macOS's /usr/bin/java).
TOOLS="$TEST_TMP/tools"
make_toolbin() {
  local tool path
  mkdir -p "$TOOLS"
  for tool in bash sh env cat cp chmod touch mkdir rm id date tee cksum head awk sed \
    grep tr cut wc sort uniq dirname basename shasum sha256sum sw_vers; do
    path="$(command -v "$tool" 2>/dev/null)" && ln -sf "$path" "$TOOLS/$tool"
  done
}

# fake_uname DIR KERNEL_NAME: uname reporting KERNEL_NAME; `uname -r` reads
# DOTFILES_OSRELEASE_FILE, like platform.sh does.
fake_uname() {
  mkdir -p "$1"
  stub "$1/uname" "case \"\$1\" in
  -r) cat \"\${DOTFILES_OSRELEASE_FILE:-/dev/null}\" ;;
  -m) echo x86_64 ;;
  *) echo $2 ;;
esac"
}

# Kernel release strings and os-release files.
FX="$TEST_TMP/fixtures"
make_fixtures() {
  mkdir -p "$FX"
  echo '6.6.87.2-microsoft-standard-WSL2' >"$FX/wsl2"
  echo '4.4.0-19041-Microsoft' >"$FX/wsl1"
  echo '6.8.0-45-generic' >"$FX/plain"
  echo '6.6.36-custom' >"$FX/custom"
  printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$FX/ubuntu"
  printf 'ID=debian\nVERSION_ID="12"\n' >"$FX/debian"
  make_toolbin
  fake_uname "$TEST_TMP/uname-linux" Linux
  fake_uname "$TEST_TMP/uname-darwin" Darwin
  fake_uname "$TEST_TMP/uname-bsd" FreeBSD
}
