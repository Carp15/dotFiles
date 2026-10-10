#!/usr/bin/env bash
# Read-only environment check for people and Codex. It never installs, repairs,
# or applies anything, and it does not print environment values, credentials,
# or config contents.
#
# Findings are reported as:
#   error  something declared is unusable. Two kinds are told apart:
#            "not installed"  the tool is absent; bootstrap or mise install it
#            "misconfigured"  the tool exists but this shell cannot use it
#   warn   worth fixing, but nothing declared is broken
# Exit status: 1 if there is any error, 0 otherwise (warnings do not fail).

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
commands_dir="$repo_root/packages/commands"
# shellcheck source=lib/platform.sh
. "$repo_root/scripts/lib/platform.sh"

# AstroNvim v6 requirement (config/nvim/README.md).
nvim_min_major=0
nvim_min_minor=11

platform="$(dotfiles_platform)"
errors=0
warnings=0

section() {
  printf '\n%s\n' "$1"
  printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

report_error() {
  printf '%-12s error    %s\n' "$1" "$2"
  errors=$((errors + 1))
}

report_warn() {
  printf '%-12s warn     %s\n' "$1" "$2"
  warnings=$((warnings + 1))
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

# Explain why a declared command is not usable: mise may have it installed
# while this shell has not activated mise, which is a configuration problem
# rather than a missing tool.
classify_missing() {
  local name="$1" mise_path
  if command -v mise >/dev/null 2>&1 &&
    mise_path="$(MISE_OFFLINE=1 mise which "$name" 2>/dev/null)" && [ -n "$mise_path" ]; then
    report_error "$name" "misconfigured: installed by mise ($mise_path) but not on PATH; open a new shell so mise activates"
  else
    report_error "$name" "not installed"
  fi
}

list_total=0

# Check that every command declared in a packages/commands list resolves on PATH.
# Only the lookup is done; the commands themselves are never executed.
check_commands() {
  local file="$1"
  local line name path

  if [ ! -f "$file" ]; then
    report_error "${file#"$repo_root"/}" "command list not found"
    return
  fi

  printf '%s\n' "${file#"$repo_root"/}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    name="${line%%[[:space:]]*}"
    [ -z "$name" ] && continue

    list_total=$((list_total + 1))
    if path="$(command -v "$name" 2>/dev/null)"; then
      case "$platform:$path" in
        wsl:/mnt/*)
          report_error "$name" "misconfigured: resolves to a Windows executable ($path); the Linux tool is not installed"
          ;;
        *)
          printf '%-12s present  %s\n' "$name" "$path"
          ;;
      esac
    else
      classify_missing "$name"
    fi
  done < "$file"
}

# ---------------------------------------------------------------------------

section "System"
printf '%-12s %s\n' "OS" "$(uname -s 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Release" "$(uname -r 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Architecture" "$(uname -m 2>/dev/null || printf unknown)"
printf '%-12s %s\n' "Shell" "${SHELL:-unknown}"
printf '%-12s %s\n' "Platform" "$platform"
case "$platform" in
  wsl)
    printf '%-12s WSL%s, %s %s\n' "Distribution" "$(dotfiles_wsl_version)" \
      "$(dotfiles_distro_id)" "$(dotfiles_distro_version)"
    if [ "$(dotfiles_wsl_version)" = "1" ]; then
      report_warn "WSL" "WSL1; WSL2 is the supported target"
    fi
    if [ "$(dotfiles_distro_id)" != "ubuntu" ]; then
      report_warn "Distribution" "only Ubuntu is supported by scripts/bootstrap.sh"
    fi
    ;;
  linux)
    report_warn "Platform" "Linux outside WSL is not a supported target; only common.txt is checked"
    ;;
esac

section "PATH"
if [ -n "${PATH:-}" ]; then
  path_list="$(printf '%s\n' "$PATH" | tr ':' '\n')"
  path_entries="$(printf '%s\n' "$path_list" | wc -l | tr -d ' ')"
  missing_entries=0
  windows_entries=0
  old_ifs=$IFS
  IFS=:
  set -f
  for entry in $PATH; do
    [ -n "$entry" ] && [ ! -d "$entry" ] && missing_entries=$((missing_entries + 1))
    case "$entry" in /mnt/*) windows_entries=$((windows_entries + 1)) ;; esac
  done
  set +f
  IFS=$old_ifs
  printf '%-12s %s entries; %s nonexistent directory entries\n' "PATH" "$path_entries" "$missing_entries"

  # An empty or relative entry makes command lookup depend on the current
  # directory, so a file in a cloned repository could shadow a real command.
  relative="$(printf '%s\n' "$path_list" | awk '!/^\// {print NR ": " ($0 == "" ? "(empty)" : $0)}')"
  if [ -n "$relative" ]; then
    report_error "PATH" "misconfigured: relative or empty entries (resolved against the current directory):"
    printf '%s\n' "$relative" | sed 's/^/             /'
  fi

  duplicates="$(printf '%s\n' "$path_list" | awk 'NF' | sort | uniq -d)"
  if [ -n "$duplicates" ]; then
    report_warn "PATH" "duplicate entries (the first occurrence wins):"
    printf '%s\n' "$duplicates" | sed 's/^/             /'
  fi

  if [ "$platform" = "wsl" ] && [ "$windows_entries" -gt 0 ]; then
    printf '%-12s %s Windows entries (/mnt/...); optional: appendWindowsPath=false (docs/wsl.md)\n' \
      "Interop" "$windows_entries"
  fi
else
  report_error "PATH" "misconfigured: PATH is unset"
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
    if [ "$(cd "$chezmoi_source" 2>/dev/null && pwd -P)" != "$(cd "$repo_root/home" && pwd -P)" ]; then
      report_warn "Source dir" "not this repository ($repo_root/home)"
    fi
  else
    report_warn "Source dir" "not configured (write sourceDir to ~/.config/chezmoi/chezmoi.toml)"
  fi

  if chezmoi_status="$(chezmoi status 2>/dev/null)"; then
    if [ -n "$chezmoi_status" ]; then
      report_warn "Status" "$(printf '%s\n' "$chezmoi_status" | wc -l | tr -d ' ') managed path(s) not applied:"
      printf '%s\n' "$chezmoi_status" | sed 's/^/             /'
      printf '%-12s review with "chezmoi diff" before applying anything\n' "Next"
    else
      printf '%-12s clean (managed paths match the source state)\n' "Status"
    fi
  else
    report_warn "Status" "unavailable"
  fi
else
  printf '%-12s missing  (see docs/chezmoi.md or docs/wsl.md)\n' "chezmoi"
fi

section "mise"
if command -v mise >/dev/null 2>&1; then
  printf '%-12s present  %s\n' "mise" "$(command -v mise)"
  if [ -n "${MISE_SHELL:-}" ]; then
    printf '%-12s active (%s)\n' "Activation" "$MISE_SHELL"
  else
    report_warn "Activation" "mise is not activated in the shell that ran doctor; runtimes may not be on PATH"
  fi
  if ! mise_listing="$(cd "$HOME" && MISE_OFFLINE=1 mise ls --current --missing --no-header 2>/dev/null)"; then
    report_warn "Tools" "could not list installed versions (mise ls failed)"
    mise_missing=""
  else
    mise_missing="$(printf '%s\n' "$mise_listing" | awk 'NF {printf "%s@%s ", $1, $2}')"
  fi
  if [ -n "$mise_missing" ]; then
    report_error "Tools" "not installed: ${mise_missing}(run: cd ~ && mise install)"
  else
    printf '%-12s all versions declared in the global configuration are installed\n' "Tools"
  fi
else
  # Counted once, under Required commands.
  printf '%-12s missing  (see Required commands)\n' "mise"
fi

section "Runtimes"
for runtime in java node go; do
  if ! path="$(command -v "$runtime" 2>/dev/null)"; then
    # Counted once, under Required commands, where the cause is classified.
    printf '%-12s missing  (see Required commands)\n' "$runtime"
    continue
  fi
  case "$runtime" in
    java) version="$(java -version 2>&1 | head -1)" ;;
    node) version="$(node --version 2>&1)" ;;
    go) version="$(go version 2>&1)" ;;
  esac
  # A command that exists but does not run (e.g. macOS's /usr/bin/java stub
  # without a JDK behind it) is a configuration problem, not a missing tool.
  runs=0
  case "$runtime" in
    java) java -version >/dev/null 2>&1 && runs=1 ;;
    node) node --version >/dev/null 2>&1 && runs=1 ;;
    go) go version >/dev/null 2>&1 && runs=1 ;;
  esac
  if [ "$runs" -eq 1 ]; then
    printf '%-12s ok       %s (%s)\n' "$runtime" "$version" "$path"
  elif mise_path="$(MISE_OFFLINE=1 mise which "$runtime" 2>/dev/null)" && [ -n "$mise_path" ]; then
    report_error "$runtime" "misconfigured: $path does not run; mise has $mise_path but is not active in this shell"
  else
    report_error "$runtime" "misconfigured: $path exists but does not run"
  fi
done

section "Editor"
present "Neovim" nvim --version
present "Vim" vim --version
if command -v nvim >/dev/null 2>&1; then
  nvim_version="$(nvim --version 2>/dev/null | head -1 | sed -n 's/^NVIM v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')"
  if [ -z "$nvim_version" ]; then
    report_warn "Neovim" "could not read the version"
  else
    major="${nvim_version% *}"
    minor="${nvim_version#* }"
    if [ "$major" -gt "$nvim_min_major" ] ||
      { [ "$major" -eq "$nvim_min_major" ] && [ "$minor" -ge "$nvim_min_minor" ]; }; then
      printf '%-12s ok       %s.%s >= %s.%s (AstroNvim v6)\n' "Version" "$major" "$minor" "$nvim_min_major" "$nvim_min_minor"
    else
      report_error "Neovim" "misconfigured: $major.$minor is older than $nvim_min_major.$nvim_min_minor required by AstroNvim v6 ($(command -v nvim))"
    fi
  fi
fi

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
printf '%-12s %s declared\n' "Declared" "$list_total"

printf '\nResult: %s error(s), %s warning(s). Diagnostic only: nothing was changed or applied.\n' \
  "$errors" "$warnings"

if [ "$errors" -gt 0 ]; then
  exit 1
fi
exit 0
