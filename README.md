# dotfiles

個人の開発・CLI 環境を、設定ファイルと使い方の両方から再現・理解するための基盤です。dotfiles manager は [chezmoi](https://www.chezmoi.io/) を採用しています。現在の正本は macOS (Apple Silicon) で、Linux / WSL と複数 Mac へ広げられる構成にしています。

## はじめに

```bash
./scripts/doctor.sh      # 読み取り専用の環境確認（chezmoi の状態も表示）
./scripts/bootstrap.sh   # パッケージ導入の計画を表示（dry-run。--apply で不足分だけ導入）
./tests/run.sh           # 回帰テスト（stub のみ。install・network・$HOME の変更なし）
chezmoi status           # source state と $HOME の差分がある管理対象
chezmoi diff             # その差分の内容
```

いずれも `$HOME` を変更しません。反映は `chezmoi diff` を読んだうえで、明示的に `chezmoi apply` を実行します。パッケージの導入は `./scripts/bootstrap.sh --apply` を明示したときだけ行います。新規マシンへの導入手順は macOS が [docs/chezmoi.md](docs/chezmoi.md)、WSL が [docs/wsl.md](docs/wsl.md)、Windows native が [docs/windows.md](docs/windows.md) です。

Windows native（PowerShell）では `scripts\doctor.ps1` と `scripts\bootstrap.ps1` を使います（既定は dry-run、`--apply` で基本環境の不足分だけを winget で導入。Android Studio などの任意のツールは `--with android` を付けたときだけ）。

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
├── packages/              # OS 別のパッケージ宣言と必須コマンド一覧（自動導入はしない）
├── scripts/               # 診断、symlink 配置、bootstrap（既定は dry-run）、OS 判定 (lib/platform.sh)。Windows 用は *.ps1
├── tests/                 # platform 判定・chezmoi template・bootstrap・doctor の回帰テスト（Windows はモック）
└── local/                 # Git 管理しない machine 固有 override
```

`.chezmoiroot` により、`AGENTS.md`、`docs/`、`cheatsheets/`、`scripts/` は chezmoi の target state に入りません。Windows では zsh と mise の設定を配置せず、macOS / WSL では Windows 用の設定を配置しません（`home/.chezmoiignore`）。ナレッジ層が `$HOME` へ書き出される事故を、ignore ではなく構造で防いでいます。

詳しい責務は [architecture](docs/architecture.md)、chezmoi の運用は [chezmoi](docs/chezmoi.md)、入口は [docs index](docs/index.md)、短いコマンド集は [cheatsheets](cheatsheets/README.md) を参照してください。

## 現在の管理対象

| 方式 | source | 配置先 |
| --- | --- | --- |
| chezmoi | `home/dot_zshrc` | `~/.zshrc` |
| chezmoi | `home/dot_zprofile` | `~/.zprofile` |
| chezmoi | `home/dot_config/git/config` | `~/.config/git/config`（共通の Git 設定。identity は `~/.gitconfig` に machine ごと） |
| chezmoi | `home/dot_config/git/ignore` | `~/.config/git/ignore` |
| chezmoi (template) | `home/dot_config/mise/config.toml.tmpl` | `~/.config/mise/config.toml`（Java の vendor だけ WSL で異なる） |
| chezmoi（WSL のみ） | `home/dot_config/mise/conf.d/wsl.toml` | `~/.config/mise/conf.d/wsl.toml` |
| chezmoi（Windows のみ） | `home/dot_config/powershell/dotfiles.ps1` | `~\.config\powershell\dotfiles.ps1`（PowerShell 7 の共有設定） |
| chezmoi（Windows のみ、`create_`） | `home/Documents/PowerShell/create_Microsoft.PowerShell_profile.ps1` | `$PROFILE`（存在しないときだけ作る loader） |
| chezmoi（Windows のみ） | `home/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json` | Windows Terminal の fragment（`settings.json` は管理しない） |
| symlink | `config/nvim/` | `~/.config/nvim` |

## パッケージ管理の方針

chezmoi は設定ファイルだけを扱い、`chezmoi apply` はパッケージを導入しません。パッケージは OS ごとの宣言ファイルに書き、新規環境の bootstrap で明示的に導入します。

| 対象 | macOS | WSL | Windows native |
| --- | --- | --- | --- |
| OS パッケージ・GUI | `packages/macos/Brewfile` | `packages/wsl/apt.txt` | `packages/windows/winget.json` |
| 開発ランタイム | mise | mise | 原則不要 |
| 公式 installer 推奨の CLI（Claude Code 等） | 公式 installer | 公式 installer | 原則不要 |

全 OS で同じ package manager を使うことは目指しません。`packages/commands/` に環境ごとの必須コマンドを宣言し、`scripts/doctor.sh` がその存在を確認します。導入経路は道具ごとに、更新のしやすさ・互換性・公式サポートで判断します。詳細と保留事項は [docs/packages.md](docs/packages.md) を参照してください。

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
- WSL2 Ubuntu 対応（設定・bootstrap・doctor を実装済み。WSL 実機での検証は未実施）
- bootstrap の自動化範囲の判断（macOS / WSL の bootstrap は実装済み）
- Windows 11 native 対応（PowerShell 7 profile、Windows Terminal fragment、`bootstrap.ps1` / `doctor.ps1` を実装済み。モックテストのみで、Windows 実機での検証は未実施。[docs/windows.md](docs/windows.md)）
- 追加候補（starship、tmux、gh の非認証設定など）の個別評価
