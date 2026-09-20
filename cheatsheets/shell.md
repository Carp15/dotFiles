# Shell quick reference

```bash
# Codex profiles used on this Mac
codexa  # codex --profile auto
codexf  # codex --profile full

# 現在の shell と実行ファイルを確認
printf '%s\n' "$SHELL"
command -v <command>

# zsh configuration syntax check (does not change the live configuration)
zsh -n config/zsh/zprofile config/zsh/zshrc

# dotfiles 基盤の非破壊診断
./scripts/doctor.sh

# 変更前後の確認
git status --short
git diff --check
```

環境変数の一覧や credential-bearing file の内容は、診断目的でも出力しません。
