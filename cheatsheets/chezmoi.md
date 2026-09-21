# chezmoi

背景と運用方針は [docs/chezmoi.md](../docs/chezmoi.md)。ここは実際に打つコマンドだけ。

## 確認（HOME を変更しない）

```bash
chezmoi status       # 差分のある管理対象だけを表示
chezmoi diff         # source state -> HOME の差分
chezmoi managed      # 管理対象のパス一覧
chezmoi source-path  # source directory（.../dotFiles/home）
chezmoi doctor       # chezmoi 自身の設定と環境の点検
```

## 編集と取り込み

```bash
chezmoi edit ~/.zshrc                    # source state を編集（HOME を直接触らない）
chezmoi add ~/.config/foo/bar.toml       # live のファイルを source state へ取り込む
chezmoi cd                               # home/ へ移動。git は cd .. してから
```

`edit` / `add` のあとは repository root で `git diff` を見て commit する。

## 反映

```bash
chezmoi apply --dry-run --verbose   # 何が変わるかだけ表示
chezmoi apply                       # 全体を反映
chezmoi apply ~/.zshrc              # 対象を絞って反映
```

`diff` を読む前に `apply` しない。

## source state の命名

| source state | 配置先 |
| --- | --- |
| `dot_zshrc` | `~/.zshrc` |
| `dot_config/git/ignore` | `~/.config/git/ignore` |
| `*.tmpl` | template として render される（現在は未使用） |

## やらないこと

- secret・credential・private key を `chezmoi add` しない
- `~/.ssh/`、`~/.aws/`、`~/.config/gcloud/`、`~/.kube/config`、`~/.config/gh/` を追加しない
- 未確認の差分を `chezmoi apply` しない
