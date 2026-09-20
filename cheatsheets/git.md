# Git quick reference

```bash
# 状態と変更内容
git status --short
git diff --check
git diff -- <path>

# 安全確認済みのファイルだけを追加
git add -- <path>

# 追跡対象を確認
git ls-files
```

dotfiles では `git add .` と `git add -A` を避け、secret や local override を個別確認します。
