# Platform detection: the single source of truth for "macos / wsl / linux".
#
# Sourced by scripts/doctor.sh and scripts/bootstrap.sh, and called by chezmoi
# through home/.chezmoitemplates/platform, so every consumer agrees on what a
# WSL machine is. POSIX sh; defines functions only and has no side effects.
#
# chezmoi's .chezmoi.os reports "linux" for both WSL and plain Linux, so WSL is
# identified from the kernel release string instead:
#   WSL2: 6.6.87.2-microsoft-standard-WSL2
#   WSL1: 4.4.0-19041-Microsoft
# WSL_DISTRO_NAME (set by wsl.exe) covers WSL2 with a custom kernel whose
# release string does not mention Microsoft.
#
# Test hooks (read-only): DOTFILES_OSRELEASE_FILE, DOTFILES_OS_RELEASE_FILE.

dotfiles_kernel_release() {
  cat "${DOTFILES_OSRELEASE_FILE:-/proc/sys/kernel/osrelease}" 2>/dev/null
}

# Prints macos | wsl | linux | unknown.
dotfiles_platform() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      echo macos
      ;;
    Linux)
      case "$(dotfiles_kernel_release | tr '[:upper:]' '[:lower:]')" in
        *microsoft*) echo wsl ;;
        *)
          if [ -n "${WSL_DISTRO_NAME:-}" ]; then
            echo wsl
          else
            echo linux
          fi
          ;;
      esac
      ;;
    *)
      echo unknown
      ;;
  esac
}

# Prints 1 | 2 | unknown. Only meaningful when dotfiles_platform is wsl.
dotfiles_wsl_version() {
  case "$(dotfiles_kernel_release | tr '[:upper:]' '[:lower:]')" in
    *microsoft-standard* | *wsl2*) echo 2 ;;
    *microsoft*) echo 1 ;;
    *) echo unknown ;;
  esac
}

# Prints the os-release ID (ubuntu, debian, ...) or nothing on macOS.
dotfiles_distro_id() {
  (
    file="${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}"
    [ -r "$file" ] || exit 0
    # shellcheck disable=SC1090
    . "$file"
    printf '%s\n' "${ID:-}"
  )
}

# Prints the os-release VERSION_ID (24.04, ...) or nothing.
dotfiles_distro_version() {
  (
    file="${DOTFILES_OS_RELEASE_FILE:-/etc/os-release}"
    [ -r "$file" ] || exit 0
    # shellcheck disable=SC1090
    . "$file"
    printf '%s\n' "${VERSION_ID:-}"
  )
}
