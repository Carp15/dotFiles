# Official installers used by scripts/bootstrap.sh. Sourced, not executed.
#
# Each installer is fetched to a file first and run as a separate step, so the
# script that runs is the one that was saved and can be read afterwards; nothing
# is piped from the network into a shell. Every URL below is the one published
# in the tool's own documentation (checked 2026-10-10, see docs/packages.md):
#
#   mise    https://mise.run                       mise.jdx.dev/installing-mise.html
#   claude  https://claude.ai/install.sh           code.claude.com/docs/en/setup
#   codex   https://chatgpt.com/codex/install.sh   github.com/openai/codex (README)
#
# Each installer puts its command in ~/.local/bin and verifies the downloaded
# binary against a published checksum. Shell profiles: the mise installer only
# prints activation instructions, and the Claude Code installer reports a
# missing PATH entry "but doesn't change PATH itself"
# (code.claude.com/docs/en/troubleshoot-install). The Codex installer appends a
# PATH block to ~/.zshrc (Linux + zsh) unless ~/.local/bin is already on PATH,
# so bootstrap puts it on PATH before running it.

official_installer_url() {
  case "$1" in
    mise) echo "https://mise.run" ;;
    claude) echo "https://claude.ai/install.sh" ;;
    codex) echo "https://chatgpt.com/codex/install.sh" ;;
    *) return 1 ;;
  esac
}

# Interpreter each installer is written for (its shebang).
official_installer_shell() {
  case "$1" in
    mise | codex) echo sh ;;
    claude) echo bash ;;
    *) return 1 ;;
  esac
}

# Download an installer to a file. Fails on HTTP errors, refuses non-HTTPS, and
# rejects a response that is not a script (e.g. an HTML page from a proxy).
official_installer_fetch() {
  local url
  url="$(official_installer_url "$1")" || return 1
  curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$url" || return 1
  if [ "$(head -c 2 "$2")" != "#!" ]; then
    echo "downloaded file is not a shell script: $url" >&2
    return 1
  fi
}

# Run a previously fetched installer file.
#   CODEX_NON_INTERACTIVE=1 skips Codex's "Start Codex now?" prompt.
official_installer_run() {
  local shell
  shell="$(official_installer_shell "$1")" || return 1
  case "$1" in
    codex) CODEX_NON_INTERACTIVE=1 "$shell" "$2" ;;
    *) "$shell" "$2" ;;
  esac
}
