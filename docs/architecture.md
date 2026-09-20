# Repository architecture

このリポジトリは manager 非依存の knowledge layer と、将来選定する管理方式で利用する implementation layer を分離します。

```text
knowledge layer:       AGENTS.md, docs/, cheatsheets/
                                      ↓
implementation layer:  config/, templates/, scripts/, local/
                                      ↓
future manager:        chezmoi or Nix/Home Manager or GNU Stow
```

| Directory | Responsibility |
| --- | --- |
| `config/` | 人が管理する実設定を、導入済み manager に縛られない形で置く領域。 |
| `docs/` | 設計意図、設定の背景、環境差分、運用ルールを説明する。 |
| `cheatsheets/` | よく使う短いコマンドと忘れやすい操作だけを置く。 |
| `scripts/` | 診断・配置・将来の再現作業を支援する。既定では live 設定を変更せず、変更は明示的な操作に限る。 |
| `local/` | Git 管理しない hostname・path 等の machine 固有 override 用。secret の保管場所ではない。 |
| `templates/` | chezmoi や Nix 等が必要になった場合に、差分設計を移す候補領域。現時点では展開処理を持たない。 |

## 配置方式

`config/` 配下は2つの方式が併存します。

| 方式 | 対象 | live との関係 |
| --- | --- | --- |
| reference copy | `config/git`、`config/zsh`、`config/mise` | live をコピーして管理する。repository からは適用しない |
| symlink | `config/nvim` | repository 側が実体で、live が symlink。`scripts/link.sh --apply` で配置する |

symlink は、日常的に編集して差分が頻繁に出る設定に限って使います。判断の経緯は [Neovim](neovim.md) を参照してください。`link.sh` は宣言された link だけを扱い、既存の実体を移動・削除しないため、manager を選定したときに置き換えられます。

新しい設定は、安全性を確認してから `config/` に追加します。OS 共通部分を優先し、macOS/Linux/WSL の違いは条件分岐・OS 別ファイル・ignored local override のいずれかへ小さく分離します。manager を導入しても knowledge layer は原則そのまま残します。
