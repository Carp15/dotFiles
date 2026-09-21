#!/usr/bin/env bash
# Create symlinks from the live environment into this repository's managed configuration.
# Default mode is a dry run: nothing is created, moved, or deleted without --apply.
# An existing real file or directory at a destination is never replaced; it is reported instead.

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
apply=0

usage() {
  printf '%s\n' "Usage: $(basename "$0") [--apply]"
  printf '%s\n' ""
  printf '%s\n' "  (no option)  show the planned links only (default)"
  printf '%s\n' "  --apply      create missing symlinks"
  printf '%s\n' ""
  printf '%s\n' "Destinations that already hold a real file or directory are skipped and reported."
}

case "${1:-}" in
  --apply) apply=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    printf 'Unknown option: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

# Managed links: "<path relative to repo root>|<absolute destination>".
# Only configuration that is intended to be edited in place belongs here. Everything
# under home/ is managed by chezmoi instead and must never be listed here.
links=(
  "config/nvim|$HOME/.config/nvim"
)

status=0
planned=0
created=0
skipped=0

for entry in "${links[@]}"; do
  source_relative="${entry%%|*}"
  destination="${entry##*|}"
  source_path="$repo_root/$source_relative"

  if [ ! -e "$source_path" ]; then
    printf 'missing source  %s\n' "$source_relative"
    status=1
    continue
  fi

  if [ -L "$destination" ]; then
    current="$(readlink "$destination")"
    if [ "$current" = "$source_path" ]; then
      printf 'ok              %s -> %s\n' "$destination" "$source_relative"
    else
      printf 'conflict        %s is a symlink to %s\n' "$destination" "$current"
      status=1
      skipped=$((skipped + 1))
    fi
    continue
  fi

  if [ -e "$destination" ]; then
    printf 'conflict        %s already exists and is not a symlink (left untouched)\n' "$destination"
    status=1
    skipped=$((skipped + 1))
    continue
  fi

  if [ "$apply" -eq 1 ]; then
    mkdir -p "$(dirname "$destination")"
    if ln -s "$source_path" "$destination"; then
      printf 'linked          %s -> %s\n' "$destination" "$source_relative"
      created=$((created + 1))
    else
      printf 'failed          %s\n' "$destination"
      status=1
    fi
  else
    printf 'would link      %s -> %s\n' "$destination" "$source_relative"
    planned=$((planned + 1))
  fi
done

printf '\n'
if [ "$apply" -eq 1 ]; then
  printf 'Result: %s link(s) created, %s conflict(s) skipped.\n' "$created" "$skipped"
else
  printf 'Result: dry run; %s link(s) would be created, %s conflict(s) skipped.\n' "$planned" "$skipped"
  printf 'Run with --apply to create them.\n'
fi

exit "$status"
