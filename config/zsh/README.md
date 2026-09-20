# zsh configuration

This directory holds the portable, managed form of the current Mac zsh setup.

| Live source | Managed file | Intended destination |
| --- | --- | --- |
| `~/.zprofile` | `zprofile` | `~/.zprofile` |
| `~/.zshrc` | `zshrc` | `~/.zshrc` |

No dotfiles manager has been selected. These files are reference copies only: this repository does not automatically apply them, create symlinks, or modify the live shell configuration.

## Portable adjustments

- `$HOME` replaces a user-specific home path.
- Homebrew is detected at the Apple Silicon and Intel default locations before `shellenv` is evaluated.
- zsh's unique `path` array prevents duplicate `~/.local/bin` entries.
- `mise` activation and `JAVA_HOME` setup run only when mise and its selected Java executable are available.
- The stale Go executable path and a version-pinned Go installation path were omitted. Runtime selection belongs to mise rather than a machine-specific PATH entry.

`codexa` and `codexf` preserve the aliases currently used on this Mac. Machine-only overrides belong in `local/` and must not be copied into these shared files.
