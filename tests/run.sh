#!/usr/bin/env bash
# Regression tests for platform detection, the chezmoi templates, bootstrap and
# doctor, including the Windows PowerShell scripts. Usage: tests/run.sh
#
# The Windows scripts are exercised by pwsh on this host against stubs
# (tests/windows.test.sh); they are skipped when pwsh is not found. Point
# DOTFILES_TEST_PWSH at a pwsh binary to use one that is not on PATH.
#
# The tests install nothing and use no network: every command that would change
# a system (sudo, apt-get, curl, brew, mise, installers) is a stub that records
# its arguments. All files are written under one temporary directory, which is
# removed afterwards. On macOS the whole run is additionally confined with
# sandbox-exec: no network, and no writes outside that directory.

set -u

tests_dir="$(cd "$(dirname "$0")" && pwd)"

if [ -z "${DOTFILES_TEST_TMP:-}" ]; then
  DOTFILES_TEST_TMP="$(cd "$(mktemp -d)" && pwd -P)"
  export DOTFILES_TEST_TMP
  trap 'chmod -R u+w "$DOTFILES_TEST_TMP" 2>/dev/null; rm -rf "$DOTFILES_TEST_TMP"' EXIT
  if command -v sandbox-exec >/dev/null 2>&1; then
    sandbox-exec -p "(version 1)(allow default)(deny network*)
      (deny file-write* (require-not (require-any (subpath \"$DOTFILES_TEST_TMP\") (subpath \"/dev\"))))" \
      bash "$0" "$@"
    exit $?
  fi
fi

REPO="$(cd "$tests_dir/.." && pwd)"
TEST_TMP="$DOTFILES_TEST_TMP"
export TMPDIR="$TEST_TMP/tmp"
mkdir -p "$TMPDIR"

# shellcheck source=helpers.sh
. "$tests_dir/helpers.sh"
make_fixtures

for test_file in "$tests_dir"/*.test.sh; do
  printf '\n# %s\n' "$(basename "$test_file")"
  # shellcheck disable=SC1090
  . "$test_file"
done

printf '\n%s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ]
