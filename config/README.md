# Managed configuration

`config/` は、将来 Git 管理する実設定の候補領域です。現時点では live 環境から設定を一括コピーしません。

候補には shell、Git、tmux、Neovim、Starship、その他 CLI tools が含まれます。追加前に、設定の生成元、secret の有無、OS / hostname / path 依存を確認します。

manager は未選定です。この layout は chezmoi、Nix + Home Manager、GNU Stow、または既存方式に合わせて変更できるため、今は特定の home 相対形式や template 命名を強制しません。

## 現在の管理対象

現在の管理対象は Git の global ignore、現在のMacを正本にしたzsh設定、miseのtool宣言、およびAstroNvimによるNeovim設定です。詳細は [config/git/README.md](git/README.md)、[config/zsh/README.md](zsh/README.md)、[config/mise/README.md](mise/README.md)、[config/nvim/README.md](nvim/README.md) を参照してください。

## 配置方式

配置方式はディレクトリごとに異なります。追加する設定は、live source、managed copy、配置先の対応関係を確認してから登録します。

| 配置方式 | 対象 | 内容 |
| --- | --- | --- |
| reference copy | `git/`、`zsh/`、`mise/` | live からコピーして管理する。自動適用やsymlink作成は行わない |
| symlink | `nvim/` | ここが実体で、live 側が symlink。`scripts/link.sh` で配置する |

manager は依然として未選定です。symlink 方式は日常的に編集する設定の二重管理を避けるための最小の仕組みであり、manager の選定を先取りするものではありません。判断の背景は [docs/neovim.md](../docs/neovim.md) を参照してください。
