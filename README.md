# dotfiles

個人の開発・CLI 環境を、設定ファイルと使い方の両方から再現・理解するための基盤です。dotfiles manager は [chezmoi](https://www.chezmoi.io/) を採用しています。現在の正本は macOS (Apple Silicon) で、Linux / WSL と複数 Mac へ広げられる構成にしています。

## はじめに

```bash
./scripts/doctor.sh      # 読み取り専用の環境確認（chezmoi の状態も表示）
./scripts/bootstrap.sh   # 新規マシン導入手順の進捗を読み取り専用で表示
chezmoi status           # source state と $HOME の差分がある管理対象
chezmoi diff             # その差分の内容
```

いずれも `$HOME` を変更しません。反映は `chezmoi diff` を読んだうえで、明示的に `chezmoi apply` を実行します。新規マシンへの導入手順は [docs/chezmoi.md](docs/chezmoi.md) にあります。

Codex や Claude Code にはまず [AGENTS.md](AGENTS.md) を読ませ、chezmoi source state・`docs/`・`cheatsheets/` の順で確認するよう依頼してください。

## 構成

```text
.
├── AGENTS.md              # agent と人向けの運用・安全ルール
├── .chezmoiroot           # chezmoi の source directory を home/ に限定する
├── home/                  # chezmoi source state（ここだけが $HOME へ適用される）
│   ├── dot_zshrc          #   -> ~/.zshrc
│   ├── dot_zprofile       #   -> ~/.zprofile
│   └── dot_config/        #   -> ~/.config/...
├── docs/                  # 背景、設計、運用の理解
├── cheatsheets/           # 日常的にすぐ参照する短い手順
├── config/nvim/           # symlink 方式で管理する Neovim 設定の実体
├── scripts/               # 非破壊の診断、symlink 配置、導入案内
└── local/                 # Git 管理しない machine 固有 override
```

`.chezmoiroot` により、`AGENTS.md`、`docs/`、`cheatsheets/`、`scripts/` は chezmoi の target state に入りません。ナレッジ層が `$HOME` へ書き出される事故を、ignore ではなく構造で防いでいます。

詳しい責務は [architecture](docs/architecture.md)、chezmoi の運用は [chezmoi](docs/chezmoi.md)、入口は [docs index](docs/index.md)、短いコマンド集は [cheatsheets](cheatsheets/README.md) を参照してください。

## 現在の管理対象

| 方式 | source | 配置先 |
| --- | --- | --- |
| chezmoi | `home/dot_zshrc` | `~/.zshrc` |
| chezmoi | `home/dot_zprofile` | `~/.zprofile` |
| chezmoi | `home/dot_config/git/ignore` | `~/.config/git/ignore` |
| chezmoi | `home/dot_config/mise/config.toml` | `~/.config/mise/config.toml` |
| symlink | `config/nvim/` | `~/.config/nvim` |

## Secret policy

password、API/access/refresh token、private key、credential、cookie、session、`.env`、cloud credential、kubeconfig 内の secret、SSH private key は追加しません。secret は `.chezmoiignore` で隠すのではなく、source state に入れないことで扱います。`.gitignore` は補助策であり、安全確認の代わりにはなりません。疑わしいファイルは内容や値を記録せず、Git に追加せず報告します。

`~/.ssh/`、`~/.aws/`、`~/.config/gcloud/`、`~/.kube/config`、`~/.docker/config.json`、`~/.config/gh/`、`~/.gitconfig` は管理対象外です。理由は [docs/chezmoi.md](docs/chezmoi.md) に記録しています。

`local/` は machine 固有の非機密 override 用です。secret の保存先としては推奨せず、OS の credential store や既存の安全な仕組みを利用します。

## Roadmap

### Phase 1 — foundation（完了）

- repository structure
- AGENTS.md
- docs and cheatsheets
- doctor

### Phase 2 — inventory（完了）

- current dotfiles inventory
- `manage-dotfiles` Skill による安全な追加
- Git global ignore、zsh、mise、Neovim（AstroNvim）を管理対象化

### Phase 3 — manager selection（完了）

- chezmoi を採用
- `.chezmoiroot` でナレッジ層と source state を分離
- zsh、Git global ignore、mise を source state へ移行

### Phase 4 — portability（進行中）

- `chezmoi apply` による live 反映（zsh / mise は差分レビュー待ち）
- Linux / WSL 実機での検証と、必要になった時点での `.tmpl` 導入
- bootstrap の自動化範囲の判断
- 追加候補（starship、tmux、gh の非認証設定など）の個別評価
