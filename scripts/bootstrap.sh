#!/usr/bin/env bash
# Install a new machine's packages: macOS (Homebrew) or WSL Ubuntu (apt).
#
# The default is a dry run: it reports the state of every step and prints the
# commands --apply would run. It installs nothing and writes nothing.
#
# With --apply it runs only the steps that are not yet satisfied, in order,
# logs every command, and stops at the first failure. Re-running is safe:
# satisfied steps are skipped, a command that already exists is never
# reinstalled or replaced, and nothing is upgraded or removed. It never runs
# `chezmoi apply` or `brew bundle cleanup` (see AGENTS.md, Package management).

set -u

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/platform.sh
. "$repo_root/scripts/lib/platform.sh"
# shellcheck source=install/official.sh
. "$repo_root/scripts/install/official.sh"

brewfile="$repo_root/packages/macos/Brewfile"
apt_list="$repo_root/packages/wsl/apt.txt"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/bootstrap"
local_bin="$HOME/.local/bin"
apply=0

usage() {
  printf '%s\n' "Usage: $(basename "$0") [--apply]"
  printf '%s\n' ""
  printf '%s\n' "  (no option)  dry run: show each step's state and the commands --apply would run"
  printf '%s\n' "  --apply      install what is missing; logs to $state_dir"
  printf '%s\n' ""
  printf '%s\n' "Supported: macOS, and Ubuntu on WSL. Other platforms exit with status 2;"
  printf '%s\n' "Windows native uses scripts/bootstrap.ps1 (docs/windows.md)."
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
if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

section() {
  printf '\n%s\n' "$1"
  printf '%*s\n' "${#1}" '' | tr ' ' '-'
}

# Installers find each other through ~/.local/bin, and the Codex installer only
# leaves shell profiles alone when that directory is already on PATH.
case ":$PATH:" in
  *":$local_bin:"*) ;;
  *) PATH="$local_bin:$PATH" && export PATH ;;
esac

# ---------------------------------------------------------------------------
# Platform

printf '%s\n' "dotfiles bootstrap ($([ "$apply" -eq 1 ] && echo apply || echo dry run))"

platform="$(dotfiles_platform)"
section "Platform"
case "$platform" in
  macos)
    printf '  macOS %s (%s)\n' "$(sw_vers -productVersion 2>/dev/null)" "$(uname -m)"
    # Codex CLI is a Brewfile cask on macOS, so brew_bundle installs it; the
    # official-installer step below is for WSL only.
    steps="homebrew brew_bundle mise_tools claude"
    ;;
  wsl)
    distro="$(dotfiles_distro_id)"
    wsl_version="$(dotfiles_wsl_version)"
    printf '  WSL%s, %s %s (%s)\n' "$wsl_version" "${distro:-unknown}" "$(dotfiles_distro_version)" "$(uname -m)"
    if [ "$distro" != "ubuntu" ]; then
      printf '%s\n' "Unsupported: only Ubuntu is supported on WSL. Nothing was changed."
      exit 2
    fi
    if [ "$wsl_version" = "1" ]; then
      printf '%s\n' "  warning: WSL1 detected. WSL2 is the supported target; continuing."
    fi
    steps="apt mise mise_tools claude codex"
    ;;
  windows)
    printf '%s\n' "Windows native: run scripts/bootstrap.ps1 from PowerShell instead (docs/windows.md). Nothing was changed."
    exit 2
    ;;
  *)
    printf '%s\n' "Unsupported platform: $platform (only macOS and WSL are supported). Nothing was changed."
    exit 2
    ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' "Run this as your normal user, not root: installers target \$HOME, and apt is called through sudo."
  exit 2
fi

# ---------------------------------------------------------------------------
# chezmoi must have placed the files a step depends on: mise reads its tool list
# from its configuration, and installers must find the shell startup files that
# put ~/.local/bin on PATH. Only those targets are checked; an unapplied change
# to anything else (e.g. Git settings) is listed but does not block a step.

# Targets (relative to $HOME, as `chezmoi status` prints them) each step needs.
shell_targets=".zshrc .zprofile"
mise_targets=".config/mise/config.toml"
if [ "$platform" = "wsl" ]; then
  mise_targets="$mise_targets .config/mise/conf.d .config/mise/conf.d/wsl.toml"
fi

# Physical path, so a symlinked checkout still matches chezmoi's source path.
physical_dir() {
  [ -n "$1" ] && (cd "$1" 2>/dev/null && pwd -P)
}

# chezmoi_state: ok | missing | foreign | failed. chezmoi_pending: one target
# per line that chezmoi status reports as not applied.
chezmoi_state=ok
chezmoi_pending=""
section "Prerequisite: chezmoi"
if ! command -v chezmoi >/dev/null 2>&1; then
  chezmoi_state=missing
  printf '  %s\n' "todo  chezmoi is not installed (see docs/wsl.md or docs/chezmoi.md)"
elif [ "$(physical_dir "$(chezmoi source-path 2>/dev/null)")" != "$(physical_dir "$repo_root/home")" ]; then
  chezmoi_state=foreign
  printf '  %s\n' "todo  chezmoi source is not this repository: write sourceDir to ~/.config/chezmoi/chezmoi.toml"
elif ! chezmoi_status="$(chezmoi status 2>&1)"; then
  chezmoi_state=failed
  printf '  %s\n' "todo  'chezmoi status' failed: $(printf '%s\n' "$chezmoi_status" | head -1)"
else
  # Each status line is two status letters, a space, then the target path.
  chezmoi_pending="$(printf '%s\n' "$chezmoi_status" | awk 'NF {print substr($0, 4)}')"
  if [ -z "$chezmoi_pending" ]; then
    printf '  %s\n' "ok    source state is applied ($(chezmoi source-path))"
  else
    printf '  %s\n' "note  not applied yet (review 'chezmoi diff', then apply it yourself):"
    printf '%s\n' "$chezmoi_pending" | while IFS= read -r target; do
      case " $shell_targets $mise_targets " in
        *" $target "*) printf '          %s  (needed by bootstrap)\n' "$target" ;;
        *) printf '          %s  (not needed by bootstrap)\n' "$target" ;;
      esac
    done
  fi
fi

# chezmoi_blocker TARGET...: prints why a step needing these targets must wait,
# or nothing (and fails) when chezmoi has applied all of them.
chezmoi_blocker() {
  local target
  case "$chezmoi_state" in
    missing) echo "chezmoi is not installed" && return 0 ;;
    foreign) echo "chezmoi source is not this repository" && return 0 ;;
    failed) echo "'chezmoi status' failed" && return 0 ;;
  esac
  for target in "$@"; do
    if printf '%s\n' "$chezmoi_pending" | grep -qxF "$target"; then
      echo "~/$target is not applied yet (chezmoi apply)"
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Steps. check_<step> sets step_state (ok | todo | blocked | manual) and
# step_detail; plan_<step> prints the commands; apply_<step> runs them.

step_state=""
step_detail=""

check_step() {
  step_state="" step_detail=""
  eval "check_$1"
}

title_homebrew="Homebrew"
check_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    step_state=ok step_detail="$(command -v brew)"
  else
    step_state=blocked step_detail="install Homebrew yourself with the official installer from https://brew.sh"
  fi
}
plan_homebrew() { :; }

title_brew_bundle="Brewfile (packages/macos/Brewfile)"
check_brew_bundle() {
  if ! command -v brew >/dev/null 2>&1; then
    step_state=blocked step_detail="needs Homebrew"
  # --no-upgrade matches the install below: bootstrap installs what is missing
  # and never upgrades, so an installed but outdated package counts as present.
  # Updates are listed by `brew outdated` and applied separately.
  elif HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --file "$brewfile" >/dev/null 2>&1; then
    step_state=ok step_detail="all declared formulae and casks are installed (updates are not checked)"
  else
    step_state=todo step_detail="some declared packages are not installed"
  fi
}
plan_brew_bundle() {
  printf '        $ brew bundle install --file %s --no-upgrade\n' "${brewfile#"$repo_root"/}"
}
apply_brew_bundle() {
  run_cmd "brew bundle install (missing packages only, no upgrades)" \
    brew bundle install --file "$brewfile" --no-upgrade
}

apt_missing() {
  local package
  for package in $(sed 's/#.*//' "$apt_list"); do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed' ||
      printf '%s ' "$package"
  done
}
title_apt="apt packages (packages/wsl/apt.txt)"
check_apt() {
  local missing
  if ! command -v dpkg-query >/dev/null 2>&1 || ! command -v apt-get >/dev/null 2>&1; then
    step_state=blocked step_detail="apt-get / dpkg-query not found"
    return
  fi
  missing="$(apt_missing)"
  if [ -z "$missing" ]; then
    step_state=ok step_detail="all declared packages are installed"
  else
    step_state=todo step_detail="missing: $missing"
  fi
}
plan_apt() {
  printf '        $ sudo apt-get update\n'
  printf '        $ sudo apt-get install -y %s\n' "$(apt_missing)"
}
apply_apt() {
  local missing
  missing="$(apt_missing)"
  run_cmd "apt-get update" sudo apt-get update
  # shellcheck disable=SC2086 # package names are single words by construction
  run_cmd "apt-get install (missing packages only)" sudo apt-get install -y $missing
}

title_mise="mise"
check_mise() {
  if command -v mise >/dev/null 2>&1; then
    step_state=ok step_detail="$(command -v mise)"
  else
    step_state=todo step_detail="not installed"
  fi
}
plan_mise() { plan_official mise; }
apply_mise() { install_official mise; }

# Tool versions declared in the global configuration but not installed. Run from
# $HOME so that no project mise.toml is involved, and offline so that the check
# only reads local state.
# Fails (instead of printing nothing) when mise itself cannot answer.
mise_missing() {
  local listing
  listing="$(cd "$HOME" && MISE_OFFLINE=1 mise ls --current --missing --no-header 2>/dev/null)" || return 1
  printf '%s\n' "$listing" | awk 'NF {printf "%s@%s ", $1, $2}'
}
title_mise_tools="mise tools (Java, Node, Go, ...)"
check_mise_tools() {
  local missing blocker
  if ! command -v mise >/dev/null 2>&1; then
    step_state=todo step_detail="runs after mise is installed"
    return
  fi
  # shellcheck disable=SC2086 # target lists are space-separated words
  if blocker="$(chezmoi_blocker $mise_targets)"; then
    step_state=blocked step_detail="$blocker"
    return
  fi
  if [ ! -f "$HOME/.config/mise/config.toml" ] ||
    { [ "$platform" = "wsl" ] && [ ! -f "$HOME/.config/mise/conf.d/wsl.toml" ]; }; then
    step_state=blocked step_detail="mise configuration is missing (chezmoi apply)"
    return
  fi
  if ! missing="$(mise_missing)"; then
    step_state=todo step_detail="could not list installed versions; mise install will check"
  elif [ -z "$missing" ]; then
    step_state=ok step_detail="all declared tool versions are installed"
  else
    step_state=todo step_detail="missing: $missing"
  fi
}
plan_mise_tools() {
  printf '        $ (cd ~ && mise install)\n'
}
mise_install_global() {
  cd "$HOME" && mise install
}
apply_mise_tools() {
  run_cmd "mise install (global configuration only)" mise_install_global
}

# Satisfied when the command exists as a Linux/macOS binary. On WSL a match
# under /mnt/ is a Windows executable reached through interop and does not count.
check_official() {
  local name="$1" path blocker
  path="$(command -v "$name" 2>/dev/null)"
  case "$path" in
    "") ;;
    /mnt/*) step_detail="only a Windows binary was found ($path)" ;;
    *)
      step_state=ok step_detail="$path"
      return
      ;;
  esac
  # shellcheck disable=SC2086 # target lists are space-separated words
  if blocker="$(chezmoi_blocker $shell_targets)"; then
    step_state=blocked step_detail="${step_detail:+$step_detail; }$blocker; the installer needs the configured PATH"
  else
    step_state=todo step_detail="${step_detail:-not installed}"
  fi
}

title_claude="Claude Code"
check_claude() { check_official claude; }
plan_claude() { plan_official claude; }
apply_claude() { install_official claude; }

title_codex="Codex CLI"
check_codex() { check_official codex; }
plan_codex() { plan_official codex; }
apply_codex() { install_official codex; }

plan_official() {
  local name="$1"
  printf '        $ curl -fsSL --proto =https --tlsv1.2 -o %s/installers/%s-<timestamp>.sh %s\n' \
    "$state_dir" "$name" "$(official_installer_url "$name")"
  printf '        $ %s%s %s/installers/%s-<timestamp>.sh\n' \
    "$([ "$name" = codex ] && echo 'CODEX_NON_INTERACTIVE=1 ')" "$(official_installer_shell "$name")" "$state_dir" "$name"
}

# ---------------------------------------------------------------------------
# Execution helpers (used only with --apply)

log_file=""

run_cmd() {
  local description="$1" status
  shift
  printf '==> %s\n    $ %s\n' "$description" "$*"
  printf '\n[%s] %s\n$ %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$description" "$*" >>"$log_file"
  "$@" 2>&1 | tee -a "$log_file"
  status="${PIPESTATUS[0]}"
  if [ "$status" -ne 0 ]; then
    printf 'FAILED: %s (exit status %s)\n' "$description" "$status" | tee -a "$log_file"
    printf 'Full log: %s\n' "$log_file"
    printf 'Fix the cause and re-run; completed steps are skipped.\n'
    exit 1
  fi
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

install_official() {
  local name="$1" file
  file="$state_dir/installers/$name-$(date +%Y%m%d-%H%M%S).sh"
  mkdir -p "$state_dir/installers"
  run_cmd "download $name installer from $(official_installer_url "$name")" \
    official_installer_fetch "$name" "$file"
  printf '    saved %s (sha256 %s)\n' "$file" "$(file_sha256 "$file")" | tee -a "$log_file"
  run_cmd "run $name installer" official_installer_run "$name" "$file"
  hash -r
  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'FAILED: the %s installer finished but %s is not on PATH. Full log: %s\n' \
      "$name" "$name" "$log_file" | tee -a "$log_file"
    exit 1
  fi
}

# Shell startup files that installers are known to edit. Compared before and
# after each step so an unexpected edit is reported instead of going unnoticed.
profile_files=".zshrc .zprofile .zshenv .bashrc .bash_profile .profile"
profile_snapshot() {
  local file
  for file in $profile_files; do
    if [ -f "$HOME/$file" ]; then
      printf '%s %s\n' "$file" "$(cksum <"$HOME/$file")"
    else
      printf '%s absent\n' "$file"
    fi
  done
}

# ---------------------------------------------------------------------------
# Plan

section "Plan"
todo_count=0
blocked_count=0
manual_count=0
for step in $steps; do
  check_step "$step"
  eval "title=\$title_$step"
  # shellcheck disable=SC2154 # title is assigned through eval above
  printf '  %-8s %-40s %s\n' "$step_state" "$title" "$step_detail"
  case "$step_state" in
    todo)
      todo_count=$((todo_count + 1))
      eval "plan_$step"
      ;;
    blocked) blocked_count=$((blocked_count + 1)) ;;
    manual) manual_count=$((manual_count + 1)) ;;
  esac
done

next_steps() {
  section "Next steps (manual)"
  if [ "$platform" = "wsl" ]; then
    case "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)" in
      */zsh) ;;
      *) printf '  %s\n' 'chsh -s "$(command -v zsh)"        # make zsh the login shell' ;;
    esac
  fi
  printf '  %s\n' 'exec zsh -l                          # new shell: activates mise and the PATH'
  printf '  %s\n' './scripts/link.sh && ./scripts/link.sh --apply   # Neovim config symlink'
  printf '  %s\n' 'nvim --headless "+Lazy! restore" +qa # plugins at the versions in lazy-lock.json'
  printf '  %s\n' './scripts/doctor.sh                  # verify'
}

if [ "$apply" -ne 1 ]; then
  printf '\nDry run: nothing was installed or written. %s step(s) to run, %s blocked, %s manual.\n' \
    "$todo_count" "$blocked_count" "$manual_count"
  if [ "$todo_count" -gt 0 ]; then
    printf '%s\n' "Re-run with --apply to run them."
  fi
  next_steps
  exit 0
fi

# ---------------------------------------------------------------------------
# Apply

if [ "$todo_count" -eq 0 ]; then
  printf '\nNothing to install. %s blocked, %s manual.\n' "$blocked_count" "$manual_count"
  [ "$blocked_count" -eq 0 ] || exit 1
  exit 0
fi

mkdir -p "$state_dir"
log_file="$state_dir/$(date +%Y%m%d-%H%M%S).log"
printf '\nLogging to %s\n' "$log_file"
printf 'bootstrap --apply on %s (%s)\n' "$platform" "$(uname -a)" >"$log_file"

section "Apply"
for step in $steps; do
  # Re-check: an earlier step (e.g. installing mise) may have changed the state.
  check_step "$step"
  case "$step_state" in
    ok) continue ;;
    todo) ;;
    *)
      printf '==> skip %s: %s\n' "$step" "$step_detail" | tee -a "$log_file"
      continue
      ;;
  esac
  before="$(profile_snapshot)"
  eval "apply_$step"
  after="$(profile_snapshot)"
  if [ "$before" != "$after" ]; then
    printf 'WARNING: %s changed a shell startup file. Review it with chezmoi diff / git diff:\n' "$step" |
      tee -a "$log_file"
    printf '%s\n' "$after" | while IFS= read -r line; do
      case "$before" in *"$line"*) ;; *) printf '  %s\n' "${line%% *}" ;; esac
    done | tee -a "$log_file"
  fi
done

section "Result"
remaining=0
for step in $steps; do
  check_step "$step"
  eval "title=\$title_$step"
  printf '  %-8s %-40s %s\n' "$step_state" "$title" "$step_detail" | tee -a "$log_file"
  case "$step_state" in
    todo | blocked) remaining=$((remaining + 1)) ;;
  esac
done
printf '\nLog: %s\n' "$log_file"
next_steps
[ "$remaining" -eq 0 ] || exit 1
exit 0
