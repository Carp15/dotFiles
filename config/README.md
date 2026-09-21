# config

chezmoi 管理対象の実設定は [`home/`](../home) にあります。このディレクトリに残っているのは、symlink 方式で管理する設定だけです。

| 方式 | 対象 | live との関係 |
| --- | --- | --- |
| symlink | [`nvim/`](nvim/README.md) | ここが実体で、`~/.config/nvim` が symlink。`scripts/link.sh --apply` で配置する |

以前ここにあった `git/`、`zsh/`、`mise/` の reference copy は、chezmoi 標準の source state 形式へ移しました。

| 旧 | 現在 |
| --- | --- |
| `config/git/ignore` | `home/dot_config/git/ignore` |
| `config/zsh/zshrc` | `home/dot_zshrc` |
| `config/zsh/zprofile` | `home/dot_zprofile` |
| `config/mise/config.toml` | `home/dot_config/mise/config.toml` |

新しい設定は原則として chezmoi 管理にします。symlink 方式を選ぶのは、live を日常的に編集して差分が頻繁に出る設定に限り、個別に判断します。方針は [docs/chezmoi.md](../docs/chezmoi.md) と [docs/architecture.md](../docs/architecture.md) を参照してください。
