#!/usr/bin/env bash
# Non-destructive environment summary for people and Codex.
# It intentionally does not print environment values, credentials, or config contents.

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
commands_dir="$repo_root/packages/commands"

# macos | wsl | linux | unknown. Selects which command list applies.
detect_platform() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf 'macos' ;;
    Linux)
      if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        printf 'wsl'
      else
        printf 'linux'
      fi
      ;;
    *) printf 'unknown' ;;
  esac
}

platform="$(detect_platform)"

section() {
  printf '\n%s\n' "$1"
  printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

present() {
  local label="$1"
  local command_name="$2"
  local path
  shift 2

  if path="$(command -v "$command_name" 2>/dev/null)"; then
    printf '%-12s present  %s' "$label" "$path"
    if "$command_name" "$@" >/dev/null 2>&1; then
      printf '  (version available)'
    fi
    printf '\n'
  else
    printf '%-12s missing\n' "$label"
  fi
}

required_total=0
required_missing=0
list_errors=0

# Check that every command declared in a packages/commands list resolves on PATH.
# Only the lookup is done; the commands themselves are never executed.
check_commands() {
  local file="$1"
  local line name path

  if [ ! -f "$file" ]; then
    printf '%s: not found\n' "${file#"$repo_root"/}"
    list_errors=$((list_errors + 1))
    return
  fi

  printf '%s\n' "${file#"$repo_root"/}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    read -r name _ <<< "$line"
    [ -z "${name:-}" ] && continue

    required_total=$((required_total + 1))
    if path="$(command -v "$name" 2>/dev/null)"; then
      printf '  %-12s present  %s\n' "$name" "$path"
    else
      printf '  %-12s missing\n' "$name"
      required_missing=$((required_missing + 1))
    fi
  done < "$file"
}

section "System"
printf '%-12s %s\n' "OS" "$(uname -s 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Release" "$(uname -r 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Architecture" "$(uname -m 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Shell" "${SHELL:-unknown}"
printf '%-12s %s\n' "Platform" "$platform"

section "PATH"
if [ -n "${PATH:-}" ]; then
  path_entries=0
  missing_entries=0
  old_ifs=$IFS
  IFS=:
  for entry in $PATH; do
    path_entries=$((path_entries + 1))
    [ -n "$entry" ] && [ ! -d "$entry" ] && missing_entries=$((missing_entries + 1))
  done
  IFS=$old_ifs
  printf '%-12s %s entries; %s nonexistent directory entries\n' "PATH" "$path_entries" "$missing_entries"
else
  printf '%-12s unset\n' "PATH"
fi

section "Version control and managers"
present "Git" git --version
present "mise" mise --version
present "Homebrew" brew --version
present "Nix" nix --version
present "Stow" stow --version

section "Dotfiles (chezmoi)"
if chezmoi_path="$(command -v chezmoi 2>/dev/null)"; then
  printf '%-12s present  %s\n' "chezmoi" "$chezmoi_path"
  printf '%-12s %s\n' "Version" "$(chezmoi --version 2>/dev/null | head -1 || printf unknown)"

  if chezmoi_source="$(chezmoi source-path 2>/dev/null)"; then
    printf '%-12s %s\n' "Source dir" "$chezmoi_source"
  else
    printf '%-12s not configured (no chezmoi config file or source directory)\n' "Source dir"
  fi

  if chezmoi_status="$(chezmoi status 2>/dev/null)"; then
    if [ -n "$chezmoi_status" ]; then
      printf '%-12s %s managed path(s) differ from the source state\n' "Status" \
        "$(printf '%s\n' "$chezmoi_status" | wc -l | tr -d ' ')"
      printf '%s\n' "$chezmoi_status" | sed 's/^/             /'
      printf '%-12s review with "chezmoi diff" before applying anything\n' "Next"
    else
      printf '%-12s clean (managed paths match the source state)\n' "Status"
    fi
  else
    printf '%-12s unavailable\n' "Status"
  fi
else
  printf '%-12s missing  (macOS: brew install chezmoi)\n' "chezmoi"
fi

section "Editor"
present "Neovim" nvim --version
present "Vim" vim --version

section "Terminal and CLI tools"
present "tmux" tmux -V
present "fzf" fzf --version
present "rg" rg --version
present "fd" fd --version
present "tree-sitter" tree-sitter --version
present "lazygit" lazygit --version
present "jq" jq --version
present "kubectl" kubectl version --client=true
present "Docker" docker --version
present "Podman" podman --version

section "Languages"
present "Node.js" node --version
present "Go" go version
present "Rust" rustc --version

section "Required commands (packages/commands)"
case "$platform" in
  macos | wsl)
    check_commands "$commands_dir/common.txt"
    check_commands "$commands_dir/$platform.txt"
    ;;
  linux)
    check_commands "$commands_dir/common.txt"
    ;;
  *)
    printf '%s\n' "No command list for this platform (Windows native is checked from PowerShell; see docs/packages.md)."
    ;;
esac
if [ "$required_total" -gt 0 ]; then
  printf '%-12s %s declared, %s missing\n' "Summary" "$required_total" "$required_missing"
fi

printf '\nResult: diagnostic complete (no changes made; no apply was run).\n'

# Non-zero only when a declared requirement is unmet, so callers can gate on it.
if [ "$required_missing" -gt 0 ] || [ "$list_errors" -gt 0 ]; then
  exit 1
fi
exit 0
