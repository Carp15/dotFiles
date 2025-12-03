# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for managing shell and editor configurations across systems. The repository contains configuration files for:
- Zsh shell with zplugin/zplug plugin management
- Neovim with vim-plug plugin management
- Development environment setup for Go, Python, Node.js, Rust, Flutter, and Deno

## File Structure

- `.zshrc` - Main Zsh configuration file with plugin setup, key bindings, history settings, PATH configuration, and custom functions
- `.zshrc.zplug` - zplug plugin loader configuration (referenced from .zshrc but contains zplug-specific setup)
- `init.vim` - Neovim configuration with vim-plug, deoplete autocompletion, ALE linting, and Go development plugins

## Configuration Architecture

### Zsh Configuration

The `.zshrc` file is structured into several sections:
1. **Zplugin initialization** - Loads zplugin and core plugins (zsh-autosuggestions, zsh-syntax-highlighting, powerlevel10k)
2. **Autoload modules** - Colors, completion (compinit), directory history (cdr), VCS info
3. **History configuration** - 10000 entries saved to `~/.zsh_history`
4. **Key bindings** - Emacs-style with custom history search (^r, ^s, ^p, ^b) and zaw shortcuts (^[d, ^[f, ^[b, ^[@, ^[a)
5. **PATH setup** - Configures paths for Go, anyenv, cargo, Flutter, Dart, and Deno
6. **Environment managers** - pyenv, anyenv initialization
7. **Zstyle configuration** - VCS info display, completion behavior with case-insensitive matching and caching
8. **Custom functions** - `zaw-src-gitdir` for git directory navigation, `_update_vcs_info_msg` for VCS prompt integration
9. **Setopts** - Shell behavior options (history management, completion, glob patterns, auto-cd)

The zsh configuration uses zplugin (referenced in .zshrc) but also has a separate zplug setup file (.zshrc.zplug) that loads zsh-completions, zaw, and zsh-syntax-highlighting.

### Neovim Configuration

The `init.vim` file follows this structure:
1. **vim-plug bootstrap** - Auto-installs vim-plug if not present
2. **Plugin declarations** - FZF, deoplete, ALE linter, color schemes (jellybeans, molokai), Go development tools (nvim-go, gocode, deoplete-go)
3. **Core settings** - UTF-8 encoding, 4-space tabs with expansion, line numbers, ruler
4. **Visual customization** - Molokai colorscheme with transparent background
5. **Deoplete configuration** - Autocomplete with case-insensitive smart matching, zero delay, 10000 item limit
6. **Go settings** - Uses goimports for formatting

## Development Environment Setup

This configuration supports multiple language environments:
- **Go**: `$GOPATH` set to `$HOME/go`, vim-go/nvim-go with gocode completion
- **Python**: pyenv with root at `/usr/local/var/pyenv`, virtualenv support
- **Node.js**: Managed through anyenv
- **Rust**: Cargo environment loaded from `$HOME/.cargo/env`
- **Flutter/Dart**: Multiple PATH entries for Flutter SDK, Dart SDK, and pub cache
- **Deno**: Binary path at `$HOME/.deno/bin`
- **Java**: `JAVA_HOME` set to Java 1.8 via `/usr/libexec/java_home`

## Key Commands and Bindings

### Zsh Key Bindings
- `^r` / `^s` - Incremental history search (backward/forward)
- `^p` / `^b` - History search by command prefix (backward/forward)
- `^[d` - zaw recent directories (cdr)
- `^[f` - zaw git files
- `^[b` - zaw git branches
- `^[@` - zaw git directory navigation
- `^[a` - zaw tmux session selection

### Aliases
- `vim` → `nvim` (Neovim is the default)
- `ll` → `ls -al`

## Modification Guidelines

When editing configuration files:

1. **Zsh changes**: Consider which section the change belongs in (PATH, setopts, zstyles, functions, key bindings)
2. **Plugin additions**:
   - For zplugin: Add to the plugin section after zplugin initialization
   - For zplug: Add to `.zshrc.zplug` before `zplug load`
3. **Neovim plugins**: Add between `call plug#begin()` and `call plug#end()`, respecting the lazy-loading patterns (e.g., `'for': 'go'` for language-specific plugins)
4. **PATH modifications**: Add to the PATH export section after line 48, maintain the pattern of exporting to `$PATH`
5. **Environment manager setup**: pyenv and anyenv init commands are near the end of .zshrc

## Notes

- The repository uses Unix line endings and should be maintained as executable files
- VCS info integration with prompt shows git branch, staged (+), and unstaged (-) changes
- Completion is cached in `~/.zsh/cache` for performance
- History is shared across all zsh sessions via `share_history` option
