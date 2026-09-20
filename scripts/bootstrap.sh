#!/usr/bin/env bash
# Safe bootstrap placeholder. It intentionally makes no system or live-config changes.

set -u

printf '%s\n' "dotfiles bootstrap (safe stub)"
printf '%s\n' ""
printf '%s\n' "No packages are installed and no configuration is changed by this script."
printf '%s\n' ""
printf '%s\n' "Future bootstrap scope:"
printf '%s\n' "  - detect the operating system and selected package manager"
printf '%s\n' "  - install only an explicitly approved, documented tool set"
printf '%s\n' "  - preview and then apply the selected dotfiles manager"
printf '%s\n' "  - load optional machine-specific overrides without storing secrets"
printf '%s\n' ""
printf '%s\n' "Detected package-manager commands (availability only):"
for candidate in brew nix apt-get dnf pacman; do
  if command -v "$candidate" >/dev/null 2>&1; then
    printf '  - %s: available\n' "$candidate"
  else
    printf '  - %s: not found\n' "$candidate"
  fi
done
printf '%s\n' ""
printf '%s\n' "Before implementing bootstrap automation, select a dotfiles manager and document"
printf '%s\n' "the package list, OS conditions, dry-run behavior, and rollback plan."
exit 0
