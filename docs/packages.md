# Packages

パッケージとツールの導入経路を、OS ごとにどこで宣言し、どう検証するかを記録します。目標は「全 OS で同じ package manager を使うこと」ではなく、「各環境で必要なコマンドが揃い、同じ開発体験になること」です。

## 原則

- **chezmoi は設定ファイルだけを扱う。** `chezmoi apply` はパッケージを導入しない。`run_` script も置かない。
- **パッケージ導入は明示的な bootstrap で行う。** `packages/` の宣言ファイルを置いても、何も自動では導入されない。
- **導入経路は道具ごとに判断する。** 判断基準は、更新のしやすさ、互換性、公式サポートの3点。mise を含め、特定の manager を万能扱いしない。
- **開発ランタイム（Java、Node、Go など）は mise。** version を宣言したい言語ランタイムに限る。
- **公式 installer を推奨する CLI は公式 installer を優先する。** ただし既存環境の移行は別フェーズで個別に行う。
- **既存 macOS の挙動を変えない。** 宣言は現状に合わせ、現状と食い違う問題は「既知の問題」として記録してから個別に直す。

## 担当

| 対象 | macOS | WSL (Ubuntu) | Windows native |
| --- | --- | --- | --- |
| OS パッケージ・CLI | Homebrew（`packages/macos/Brewfile`） | apt（`packages/wsl/apt.txt`）。apt では不十分な CLI は mise（`home/dot_config/mise/conf.d/wsl.toml`） | winget（基本環境は `packages/windows/winget.json`、任意のツールは `winget-<group>.json`） |
| GUI アプリ | Homebrew Cask（同 Brewfile） | – | winget（同 winget.json） |
| 開発ランタイム | mise（`home/dot_config/mise/config.toml.tmpl`） | mise（同。Java だけ `temurin-21`） | 原則不要（WSL 側を使う） |
| 公式 installer 推奨の CLI | 公式 installer（Claude Code は導入済み） | 公式 installer（mise、Claude Code、Codex CLI） | 原則不要 |
| 設定ファイル | chezmoi（`home/`）・symlink（`config/nvim/`） | 同左 | chezmoi（Git ignore、PowerShell profile、Windows Terminal fragment。[Windows](windows.md)） |
| 必須コマンドの宣言 | `packages/commands/common.txt` + `macos.txt` | `common.txt` + `wsl.txt` | `windows.txt` + winget.json（任意のグループは `windows-<group>.txt` + `winget-<group>.json`。`--with <group>` のときだけ必須） |

Windows では、WSL がバックエンド開発の環境、Windows native が GUI のホスト（PowerShell 7、Windows Terminal、IntelliJ、Android Studio、Android SDK、adb）という分担です（詳細は [Windows](windows.md)）。Spring Boot / Kotlin は Windows の IntelliJ から WSL 上の project と JDK・Gradle・Git を使います。Android 開発は Windows native で行います。Java・Node・Go は Windows native に入れません（Android Studio は Gradle 用の JBR を同梱しています）。

## ファイル

```text
packages/
├── commands/
│   ├── common.txt     # macOS と WSL の両方で必須のコマンド
│   ├── macos.txt      # macOS だけで必須のコマンド
│   ├── wsl.txt        # WSL だけで必須のコマンド
│   ├── windows.txt    # Windows native の基本環境で必須の CLI（common.txt は読まない）
│   └── windows-android.txt  # 任意：Android 開発で必須の CLI（adb）。--with android のときだけ必須
├── macos/Brewfile     # Homebrew formula / cask の宣言
├── wsl/apt.txt        # apt パッケージの宣言（1行1パッケージ）
└── windows/
    ├── winget.json          # winget import 形式。Windows native の基本環境
    └── winget-android.json  # 任意：Android Studio。bootstrap.ps1 --with android のときだけ導入
```

`packages/` は `home/` の外にあるので、chezmoi の target state には入りません。

### commands/*.txt

1行に1コマンドを書き、`#` 以降はコメントです。宣言しているのは「そのコマンドが PATH で見つかること」で、どの manager で入れたかは問いません。そのため Mac と WSL で導入経路が違っても、同じ宣言で検証できます。

`scripts/doctor.sh` は OS を判定し（macOS / WSL / その他の Linux。判定は `scripts/lib/platform.sh`）、該当するリストのコマンドを `command -v` で探します。リストの確認ではコマンドを実行しません。見つからないコマンドは原因を分けて報告します。

- `not installed`：どこにもない
- `misconfigured`：mise には入っているが PATH にない（mise が有効になっていない）、または WSL で Windows の実行ファイル（`/mnt/...`）に解決された

ほかに PATH（相対・空のエントリは error、重複は warn）、chezmoi の適用状態（未適用は warn）、mise の有効化と未インストールの tool、Java / Node / Go が実際に動くか、Neovim の version（0.11 以上）を確認します。error が1つでもあれば exit code 1、warn だけなら 0 です。tmux や Docker などの一覧表示は情報だけで、exit code に影響しません。読み取り専用で、自動修復はしません。

## 検証（読み取り専用）

### macOS

```bash
./scripts/doctor.sh                                              # 必須コマンドの存在
brew bundle check --file packages/macos/Brewfile --verbose       # 宣言との差分
brew bundle list  --file packages/macos/Brewfile                 # 宣言の一覧
```

`brew bundle cleanup` は実行しません。Brewfile には、導入済みだが保留中で宣言していない cask があり（後述）、cleanup すると削除対象になるためです。

### WSL

```bash
./scripts/doctor.sh
sed 's/#.*//' packages/wsl/apt.txt | xargs dpkg-query -W -f='${Package} ${Status}\n'
```

### Windows native（PowerShell）

```powershell
pwsh -File scripts\doctor.ps1
```

`scripts/doctor.ps1` が、`packages/commands/windows.txt` のコマンドを PATH で探し（実行はしない）、GUI アプリなど PATH 上のコマンドを持たないものは `packages/windows/winget.json` の package ID で `winget list` により確認します。任意のグループ（`windows-<group>.txt`、`winget-<group>.json`）は情報として表示するだけで、`--with <group>` を付けたときだけ必須（error の対象）になります。Android SDK がない Windows でも、基本環境が揃っていれば 0 error です。ほかに PowerShell 7 の version、chezmoi の状態と Windows / WSL の target 分離、`$PROFILE`、Windows Terminal の fragment を確認します。報告の形式と exit code は `doctor.sh` と同じです。Windows 実機では未検証です（[Windows](windows.md#未検証事項)）。

## 導入（新規環境のみ）

macOS と WSL は `scripts/bootstrap.sh`、Windows native は `scripts/bootstrap.ps1` で導入します。どちらも既定は dry-run で、`--apply` を付けたときだけ、不足しているものを入れます。手順は [WSL](wsl.md)、[Windows](windows.md)、[chezmoi](chezmoi.md) を参照してください。

| 環境 | `--apply` の順序 |
| --- | --- |
| macOS | Homebrew の確認（無ければ停止）→ `brew bundle install --no-upgrade` → `mise install` → Claude Code（無ければ）→ Codex CLI は担当が保留中のため案内だけ |
| WSL (Ubuntu) | apt（不足分だけ）→ mise（公式 installer）→ `mise install` → Claude Code → Codex CLI |
| Windows native | `winget.json` の順に、未導入のものだけ `winget install --id <ID> --exact --source winget --no-upgrade`（PowerShell 7 → Windows Terminal → Git → chezmoi）。`--with android` を付けたときだけ、続けて Android Studio。規約への同意は自動化しない |

bootstrap は既存のコマンドを入れ直さず、アップグレードも削除もしません。`chezmoi apply` と `brew bundle cleanup` も実行しません。WSL 以外の Linux、Ubuntu 以外の WSL distribution、root での実行は exit 2 で止まります。Windows の `bootstrap.ps1` は、管理者として実行した場合と Windows 以外では exit 2 で止まり、Git Bash から `bootstrap.sh` を実行した場合も exit 2 で `bootstrap.ps1` を案内します。

`winget import` は使いません。パッケージごとに導入済みの判定・実行コマンドの表示・失敗時の停止を行うためです。

既存の Mac では、bootstrap の dry-run で全ステップが `ok` になることを確認済みです（2026-10-11）。

## winget ID

`winget.json` には、[microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) に manifest が実在し、現行 version が公開されていることを 2026-10-10 に確認した ID だけを記載しています。

| ID | 用途 | 状態 |
| --- | --- | --- |
| `Microsoft.PowerShell` | PowerShell 7 | 宣言済み |
| `Microsoft.WindowsTerminal` | Windows Terminal | 宣言済み |
| `Git.Git` | Windows 側の project（Android）用の Git | 宣言済み |
| `twpayne.chezmoi` | Windows の設定ファイル（PowerShell profile、Windows Terminal fragment） | 宣言済み（2026-10-11 に manifest を確認） |
| `Google.AndroidStudio` | Android Studio（SDK・emulator・adb は SDK Manager で導入） | 宣言済み（任意：`winget-android.json`） |
| `JetBrains.IntelliJIDEA` | IntelliJ IDEA（統合版、2025.3 以降） | 保留 |
| `JetBrains.Toolbox` | JetBrains Toolbox App | 保留 |

`JetBrains.IntelliJIDEA.Ultimate` は 2025.2.5 で更新が止まっています。IntelliJ を winget で入れる場合は `JetBrains.IntelliJIDEA` を使います。

## WSL の CLI の担当

`commands/common.txt` と `commands/wsl.txt` で必須にしているコマンドを、WSL でどこから入れるかを道具ごとに決めた結果です（2026-10-11）。基準は、公式サポート、version 要件、更新のしやすさ、再現性です。mise に統一することが目的ではありません。

| Tool | 担当 | 理由 |
| --- | --- | --- |
| git、zsh、curl、ripgrep、jq、build-essential、unzip | apt | Ubuntu 24.04 の version で足り、security update が apt で届く |
| chezmoi | 公式 installer（`get.chezmoi.io`、手動・bootstrap より前） | bootstrap の前提なので、bootstrap では入れられない。checksum を照合し、profile は変更しない。更新は `chezmoi upgrade` |
| mise | 公式 installer（`mise.run`） | Linux での公式推奨。`mise self-update` が使え、profile は変更しない。PPA は `sudo` と apt source の追加が必要になる |
| Java / Node / Go / npm | mise（`config.toml`） | macOS と共通の宣言。Java は WSL だけ `temurin-21`（後述） |
| Neovim | mise（`aqua:neovim/neovim`、`0.12`） | apt は 0.9.5 で、AstroNvim v6 の要件（0.11 以上）を満たさない。公式 release を使う。registry の既定 backend は vfox なので aqua を明示している |
| gh | mise（`aqua:cli/cli`、`2`） | 公式 release binary を使い、root 権限も apt source の追加も要らない。公式 apt repo も選択肢だが、keyring 管理が増える |
| ghq / lazygit / tree-sitter | mise（aqua、`1` / `0.66` / `0.27`） | Ubuntu 24.04 の apt にない。公式 release binary を使う |
| fd | mise（`aqua:sharkdp/fd`、`10`） | apt の `fd-find` は実行ファイル名が `fdfind` になる。macOS と同じ `fd` という名前を、共通の zshrc を変えずに提供できる |
| kubectl / helm | mise（aqua、`1.37` / `4`） | apt にない。公式配布物（dl.k8s.io、get.helm.sh）を使い、version をそろえられる |
| Rust | mise（`core:rust`、`stable`） | 内部で公式の rustup を `--no-modify-path` 付きで実行する。shell profile を変更せず、`cargo` の PATH は mise が通す |
| Claude Code | 公式 native installer | 公式推奨。自動更新に対応し、profile は変更しない |
| Codex CLI | 公式 installer（`chatgpt.com/codex/install.sh`） | README が mac / Linux 向けに示す方法。`~/.local/bin` が PATH にないと `~/.zshrc` に追記するため、bootstrap は PATH を通してから実行する。「Start Codex now?」の確認は `CODEX_NON_INTERACTIVE=1` で省く |

version は prefix で宣言しています。`mise install` はその系列の最新版を入れ、既に入っている版は置き換えません。

### mise 設定の読み込み順序

mise は `~/.config/mise/config.toml` と `~/.config/mise/conf.d/*.toml` をどちらも global 設定として読みますが、同じツールがあると **`config.toml` が優先**されます（mise 2026.10.0 で、隔離した設定ディレクトリを使って確認）。そのため:

- WSL だけのツールは `conf.d/wsl.toml` に追加する。chezmoi はこのファイルを WSL でだけ配置する（`home/.chezmoiignore`）。
- `config.toml` にあるツールの値を WSL だけ変える場合（Java の vendor）は、conf.d では上書きできない。`config.toml.tmpl` の条件分岐で変える。macOS でレンダリングされる内容は変わらない。
- project の `mise.toml` は global 設定より優先される（同じ方法で確認）。project 固有の version は project 側で宣言する。
- `config.local.toml` も `config.toml` より優先されるが、machine ごとの手元用に空けておき、repository では使わない。

## 保留事項

| 項目 | 現状 | 保留の理由 |
| --- | --- | --- |
| `cask "antigravity-cli"` | 導入済み | 手動配置の `~/.local/bin/agy` が cask の binary より PATH で先に来る。どちらを正とするか未決定 |
| `cask "codex"` | 導入済み | Codex CLI を公式 standalone installer へ移行する可能性がある。`commands/common.txt` では必須なので、担当が決まるまで新規 Mac では個別に導入する |
| `cask "codex-app"` | 記録はあるが `/Applications/Codex.app` がない | 状態が不整合 |
| `tap "stablyai/orca"` / `cask "orca"` | 導入済み（third-party tap、`trusted: true`） | Brewfile に宣言すると tap への信頼も宣言することになる |
| `cask "intellij-idea"` | Caskroom に記録だけがあり app がない | 壊れている。Toolbox と直接導入のどちらにするか未決定 |
| `go "golang.org/x/tools/gopls"` など | `brew bundle dump` が Go のパッケージを出力した | Go 本体は mise の担当。gopls の担当（`go install` / Mason）が未決定 |
| Claude.app、ChatGPT、Brave、Chrome、Logi Options+ | 手動導入 | cask で管理し直すと既存 app の扱いに影響する |
| Xcode | App Store | `mas` を導入するか未決定 |
| WSL のコンテナ CLI | – | Podman と Docker Engine のどちらにするか未決定（`commands/wsl.txt` に未記載。Phase 2 の対象外） |
| Windows の IntelliJ | – | `JetBrains.IntelliJIDEA` と `JetBrains.Toolbox` のどちらにするか未決定 |

## 既知の問題（未修正）

既存 macOS の挙動を変えないため、記録だけしておきます。

- **Java**: macOS では mise の `java = "21"` が、更新の止まった openjdk 21.0.2 に解決される。WSL は Phase 2 から `temurin-21`。macOS の移行は未実施。
- **npm**: 通常の login shell では、宣言どおり mise の `npm 11.15.0` が node 同梱の npm より先に来る（2026-10-11 に確認）。Phase 0 の棚卸しで「node 同梱の npm（11.17.0）が先に来る」としたのは、Orca が PATH の先頭に `node/24/bin` を注入した環境で調べたためで、dotfiles の問題ではなかった。node 同梱の npm を global 更新した状態が残っている点だけが未整理。
- **Codex**: brew cask で導入。公式 standalone installer との経路の違い。
- **Antigravity CLI**: 手動配置の binary と cask の二重導入。
- **IntelliJ**: 壊れた cask の記録。
- **PATH**: 起動元アプリ（Orca）経由の環境に、存在しない path、相対 path、`node/24/bin` が先頭に入る。login shell 自体の PATH は正常。`scripts/doctor.sh` はこの環境で実行すると、相対 path を error として exit 1 を返す。
- **mise**: どの設定からも参照されていない古い version が残っている（`mise prune --dry-run` で確認できる）。
- **手動 binary**: `~/.local/bin/omp`、`/usr/local/bin/apm`、`/usr/local/bin/docker-compose` は、どの manager の管理下にもない。
