# Shell quick reference

```bash
# Aliases
vim     # nvim（Neovim がある環境のみ。実体の vim は \vim か /usr/bin/vim）
codexa  # codex --profile auto
codexf  # codex --profile full

# 現在の shell と実行ファイルを確認
printf '%s\n' "$SHELL"
command -v <command>

# zsh configuration syntax check (does not change the live configuration)
zsh -n home/dot_zprofile home/dot_zshrc

# source state と $HOME の差分（apply はしない）
chezmoi status
chezmoi diff

# dotfiles 基盤の非破壊診断
./scripts/doctor.sh

# 変更前後の確認
git status --short
git diff --check
```

環境変数の一覧や credential-bearing file の内容は、診断目的でも出力しません。
