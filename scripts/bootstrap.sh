#!/usr/bin/env bash
# Guided, read-only bootstrap for a new machine.
#
# It reports which step of the chezmoi setup is missing and prints the exact
# command to run next. It installs nothing, writes nothing, and never runs
# "chezmoi apply": changing $HOME stays an explicit human decision.

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

section() {
  printf '\n%s\n' "$1"
  printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

step() {
  printf '  %-4s %-28s %s\n' "$1" "$2" "$3"
}

printf '%s\n' "dotfiles bootstrap (read-only guide)"
printf '%s\n' "No package is installed, no file is written, and no configuration is applied."

section "Bootstrap order"
printf '%s\n' "  Git -> chezmoi -> this repository -> chezmoi init -> chezmoi diff -> chezmoi apply"
printf '%s\n' "  The last step is manual. Review the diff on a new machine before touching \$HOME."

section "Current state"

if command -v git >/dev/null 2>&1; then
  step "ok" "1. Git" "$(command -v git)"
else
  step "todo" "1. Git" "install Git (macOS: xcode-select --install)"
fi

chezmoi_present=0
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi_present=1
  step "ok" "2. chezmoi" "$(chezmoi --version 2>/dev/null | head -1)"
else
  step "todo" "2. chezmoi" "macOS: brew install chezmoi | else: see docs/chezmoi.md"
fi

if [ -d "$repo_root/.git" ]; then
  step "ok" "3. repository" "$repo_root"
else
  step "todo" "3. repository" "clone this repository, then rerun this script from it"
fi

configured=0
if [ "$chezmoi_present" -eq 1 ] && chezmoi_source="$(chezmoi source-path 2>/dev/null)"; then
  if [ "$chezmoi_source" = "$repo_root/home" ]; then
    configured=1
    step "ok" "4. chezmoi init" "source dir is $chezmoi_source"
  else
    step "warn" "4. chezmoi init" "source dir is $chezmoi_source (not this repository)"
  fi
else
  step "todo" "4. chezmoi init" "chezmoi init --source=\"$repo_root\""
fi

if [ "$configured" -eq 1 ]; then
  if chezmoi_status="$(chezmoi status 2>/dev/null)" && [ -z "$chezmoi_status" ]; then
    step "ok" "5. chezmoi diff" "no pending changes"
    step "ok" "6. chezmoi apply" "nothing to apply"
  else
    step "todo" "5. chezmoi diff" "chezmoi diff   (read-only review)"
    step "todo" "6. chezmoi apply" "run it yourself, only after reading the diff"
  fi
else
  step "todo" "5. chezmoi diff" "available once step 4 is done"
  step "todo" "6. chezmoi apply" "available once step 5 has been reviewed"
fi

section "Notes"
printf '%s\n' "  - \"chezmoi init --source\" is not persisted by chezmoi; write sourceDir into"
printf '%s\n' "    ~/.config/chezmoi/chezmoi.toml on a new machine. See docs/chezmoi.md."
printf '%s\n' "  - .chezmoiroot points the source directory at home/, so the knowledge layer"
printf '%s\n' "    (AGENTS.md, docs/, cheatsheets/, scripts/) is never written into \$HOME."
printf '%s\n' "  - Package installation and provisioning are out of scope for this script."
printf '%s\n' "  - Secrets are not part of the source state; nothing here handles credentials."

printf '\nResult: guide printed (no changes made).\n'
exit 0
