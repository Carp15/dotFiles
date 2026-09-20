# dotfiles

個人の開発・CLI 環境を、設定ファイルと使い方の両方から再現・理解するための基盤です。現時点では dotfiles manager を導入せず、将来の chezmoi、Nix + Home Manager、GNU Stow の選定を妨げない構成にしています。

## はじめに

```bash
./scripts/doctor.sh
./scripts/bootstrap.sh
./scripts/link.sh
```

`doctor.sh` は読み取り専用の環境確認です。`bootstrap.sh` は安全な案内用 stub であり、パッケージのインストールや設定変更を行いません。`link.sh` は symlink 方式で管理する設定の配置計画を表示し、`--apply` を付けたときだけ symlink を作成します。

Codex にはまず [AGENTS.md](AGENTS.md) を読ませ、現在の設定・`docs/`・`cheatsheets/` の順で確認するよう依頼してください。設定を追加する際は、live 環境を移動・上書きせず、安全性と machine 依存を確認してから `config/` に取り込みます。

## 構成

```text
.
├── AGENTS.md              # Codex と人向けの運用・安全ルール
├── docs/                  # 背景、設計、運用の理解
├── cheatsheets/           # 日常的にすぐ参照する短い手順
├── config/                # 将来管理する実設定の置き場
├── scripts/               # 非破壊の診断、symlink 配置、将来の bootstrap
├── local/                 # Git 管理しない machine 固有 override
└── templates/             # 将来の manager 用テンプレート候補
```

詳しい責務は [architecture](docs/architecture.md)、入口は [docs index](docs/index.md)、短いコマンド集は [cheatsheets](cheatsheets/README.md) を参照してください。

## Secret policy

password、API/access/refresh token、private key、credential、cookie、session、`.env`、cloud credential、kubeconfig 内の secret、SSH private key は追加しません。`.gitignore` は補助策であり、安全確認の代わりにはなりません。疑わしいファイルは内容や値を記録せず、Git に追加せず報告します。

`local/` は machine 固有の非機密 override 用です。secret の保存先としては推奨せず、OS の credential store や既存の安全な仕組みを利用します。

## Roadmap

### Phase 1 — foundation

- repository structure
- AGENTS.md
- docs and cheatsheets
- doctor

### Phase 2 — inventory

- current dotfiles inventory
- `manage-dotfiles` Skill による安全な追加
- Git global ignore、zsh、mise、Neovim（AstroNvim）を管理対象化

### Phase 3 — manager selection

- chezmoi
- Nix / Home Manager
- GNU Stow

manager は未選定です。`config/nvim` のみ `scripts/link.sh` による symlink 方式で配置しており、これは manager の代替ではなく、頻繁に編集する設定の二重管理を避けるための最小の仕組みです。

### Phase 4 — portability

- bootstrap automation
- machine-specific configuration
