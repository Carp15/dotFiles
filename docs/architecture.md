# Repository architecture

このリポジトリは、manager に依存しない knowledge layer と、chezmoi が実際に適用する source state を分離します。

```text
knowledge layer:   AGENTS.md, docs/, cheatsheets/, scripts/
                          （$HOME へは適用されない）
                                     ↓ 参照
source state:      home/  ──(chezmoi apply)──>  $HOME
                                     ↑ 取り込み
live environment:  $HOME
```

| Path | Responsibility |
| --- | --- |
| `.chezmoiroot` | chezmoi の source directory を `home/` に限定する。これによりナレッジ層が target state に入らない |
| `home/` | chezmoi source state。ここだけが `$HOME` へ適用される正本 |
| `docs/` | 設計意図、設定の背景、環境差分、運用ルールを説明する |
| `cheatsheets/` | よく使う短いコマンドと忘れやすい操作だけを置く |
| `scripts/` | 診断・配置・導入案内。既定では live 設定を変更せず、変更は明示的な操作に限る |
| `config/nvim/` | symlink 方式で管理する Neovim 設定の実体。chezmoi の管理対象外 |
| `local/` | Git 管理しない hostname・path 等の machine 固有 override。secret の保管場所ではない |

## 配置方式

方式は2つだけです。どちらも live を勝手に上書きしません。

| 方式 | 対象 | live との関係 | 適用操作 |
| --- | --- | --- | --- |
| chezmoi | `home/` 配下 | source state が正本。`$HOME` へコピーとして適用される | `chezmoi apply`（`chezmoi diff` の確認後） |
| symlink | `config/nvim/` | repository 側が実体で、live が symlink | `scripts/link.sh --apply` |

以前あった `config/git`、`config/zsh`、`config/mise` の reference copy 方式（live をコピーするだけで適用しない）は廃止し、chezmoi の標準 source state 形式へ移しました。`templates/` も chezmoi の template 機能が代替するため削除しました。

symlink 方式を残しているのは、日常的に編集して差分が頻繁に出る設定に限ります。判断の経緯は [Neovim](neovim.md)、chezmoi 側の運用は [chezmoi](chezmoi.md) を参照してください。

## 新しい設定を追加するとき

1. live の内容と構造を確認する（secret、machine 依存、generated state の判定）
2. 安全なら `chezmoi add` で `home/` へ取り込む
3. machine 依存値があれば、共通化・OS 条件・machine 固有・secret に分類し、共通設定へ埋め込まない
4. `chezmoi diff` で `$HOME` への影響を確認する
5. repository root で `git diff` を確認して commit する
6. 必要なら `docs/` と `cheatsheets/` を更新する

OS 共通部分を優先し、macOS / Linux / WSL の違いは shell の条件分岐、chezmoi template、ignored local override のいずれかへ小さく分離します。
