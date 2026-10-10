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
| OS パッケージ・CLI | Homebrew（`packages/macos/Brewfile`） | apt（`packages/wsl/apt.txt`）。apt では不十分なものは個別判断 | winget（`packages/windows/winget.json`） |
| GUI アプリ | Homebrew Cask（同 Brewfile） | – | winget（同 winget.json） |
| 開発ランタイム | mise（`home/dot_config/mise/config.toml`） | mise（同） | 原則不要（WSL 側を使う） |
| 公式 installer 推奨の CLI | 公式 installer（Claude Code は導入済み） | 公式 installer | 原則不要 |
| 設定ファイル | chezmoi（`home/`）・symlink（`config/nvim/`） | 同左 | 未導入 |
| 必須コマンドの宣言 | `packages/commands/common.txt` + `macos.txt` | `common.txt` + `wsl.txt` | `windows.txt` + winget.json |

Windows では、WSL がバックエンド開発の環境、Windows native が GUI のホスト（PowerShell 7、Windows Terminal、IntelliJ、Android Studio、Android SDK、adb）という分担です。Spring Boot / Kotlin は Windows の IntelliJ から WSL 上の project と JDK・Gradle・Git を使います。Android 開発は Windows native で行います。Java・Node・Go は Windows native に入れません（Android Studio は Gradle 用の JBR を同梱しています）。

## ファイル

```text
packages/
├── commands/
│   ├── common.txt     # macOS と WSL の両方で必須のコマンド
│   ├── macos.txt      # macOS だけで必須のコマンド
│   ├── wsl.txt        # WSL だけで必須のコマンド
│   └── windows.txt    # Windows native で必須の CLI（common.txt は読まない）
├── macos/Brewfile     # Homebrew formula / cask の宣言
├── wsl/apt.txt        # apt パッケージの宣言（1行1パッケージ）
└── windows/winget.json  # winget import 形式の宣言
```

`packages/` は `home/` の外にあるので、chezmoi の target state には入りません。

### commands/*.txt

1行に1コマンドを書き、`#` 以降はコメントです。宣言しているのは「そのコマンドが PATH で見つかること」で、どの manager で入れたかは問いません。そのため Mac と WSL で導入経路が違っても、同じ宣言で検証できます。

`scripts/doctor.sh` は OS を判定し（macOS / WSL / その他の Linux）、該当するリストのコマンドを `command -v` で探します。コマンドそのものは実行しません。必須コマンドが1つでも missing、または該当するリストのファイルが見つからない場合は exit code 1、それ以外は 0 です。その他の診断項目（tmux、Docker など）は表示だけで、exit code には影響しません。

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

Windows native には bash の doctor がないため、CLI と GUI アプリを別の方法で確認します。GUI アプリは PATH 上のコマンドを持たないので、winget の package ID で導入済みかを確認します。

```powershell
# CLI: packages/commands/windows.txt
Get-Content packages/commands/windows.txt |
  ForEach-Object { ($_ -replace '#.*', '').Trim() } | Where-Object { $_ } |
  ForEach-Object {
    $c = Get-Command $_ -ErrorAction SilentlyContinue
    '{0,-12} {1}' -f $_, $(if ($c) { $c.Source } else { 'missing' })
  }

# GUI / package: packages/windows/winget.json
(Get-Content packages/windows/winget.json -Raw | ConvertFrom-Json).Sources.Packages.PackageIdentifier |
  ForEach-Object {
    winget list --id $_ --exact --accept-source-agreements | Out-Null
    '{0,-28} {1}' -f $_, $(if ($LASTEXITCODE -eq 0) { 'installed' } else { 'missing' })
  }
```

この PowerShell 手順は Windows 実機でまだ検証していません。初回の Windows セットアップ時に確認し、必要なら `scripts/` へ移します。

## 導入（新規環境のみ・手動）

Phase 1 では導入の自動化を実装していません。新規環境で導入する場合は、宣言を読んでから明示的に実行します。

```bash
brew bundle install --file packages/macos/Brewfile                 # macOS
sed 's/#.*//' packages/wsl/apt.txt | xargs sudo apt-get install -y  # WSL
```

```powershell
winget import --import-file packages/windows/winget.json             # Windows
```

既存の Mac では実行しません。

## winget ID

`winget.json` には、[microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) に manifest が実在し、現行 version が公開されていることを 2026-10-10 に確認した ID だけを記載しています。

| ID | 用途 | 状態 |
| --- | --- | --- |
| `Microsoft.PowerShell` | PowerShell 7 | 宣言済み |
| `Microsoft.WindowsTerminal` | Windows Terminal | 宣言済み |
| `Git.Git` | Windows 側の project（Android）用の Git | 宣言済み |
| `Google.AndroidStudio` | Android Studio（SDK・emulator・adb は SDK Manager で導入） | 宣言済み |
| `JetBrains.IntelliJIDEA` | IntelliJ IDEA（統合版、2025.3 以降） | 保留 |
| `JetBrains.Toolbox` | JetBrains Toolbox App | 保留 |

`JetBrains.IntelliJIDEA.Ultimate` は 2025.2.5 で更新が止まっています。IntelliJ を winget で入れる場合は `JetBrains.IntelliJIDEA` を使います。

## WSL で apt 以外になる候補（未決定）

以下は `commands/common.txt` で必須としていますが、Ubuntu の apt では不十分か、apt に存在しません。導入経路は Phase 2 で、更新のしやすさ・互換性・公式サポートを基準に1つずつ決めます。

| Tool | apt の状況（Ubuntu 24.04） | 候補 |
| --- | --- | --- |
| chezmoi | 初回の bootstrap では使えない | 公式 `get.chezmoi.io` |
| mise | 標準の repo にない | 公式 `mise.run`、PPA `jdxcode/mise` |
| Neovim | 0.9.5（AstroNvim v6 には 0.11 以上が必要） | 公式 release の tarball、mise |
| fd | `fd-find`（実行ファイル名が `fdfind`） | apt + 名前の対応付け、mise |
| gh | 古い | 公式 apt repo（cli.github.com） |
| kubectl | ない | 公式 apt repo（pkgs.k8s.io） |
| helm | ない | 公式 installer、mise |
| ghq / lazygit / tree-sitter | ない | 公式 release、mise |
| Claude Code / Codex / rustup | – | 公式 installer |

公式 installer の多くは、`~/.local/bin` が PATH にないと shell profile に追記します。WSL では `chezmoi apply` で zsh 設定を配置してから installer を実行します。uv は `UV_NO_MODIFY_PATH=1`、rustup は `--no-modify-path` を付けます。

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
| WSL のコンテナ CLI | – | Podman と Docker Engine のどちらにするか未決定（`commands/wsl.txt` に未記載） |
| Windows の IntelliJ | – | `JetBrains.IntelliJIDEA` と `JetBrains.Toolbox` のどちらにするか未決定 |

## 既知の問題（Phase 1 では修正しない）

既存 macOS の挙動を変えないため、記録だけしておきます。

- **Java**: mise の `java = "21"` が更新の止まった openjdk 21.0.2 に解決される。候補は `temurin-21`。
- **npm**: mise で宣言した `npm = "11.15.0"` より、node 同梱の npm（11.17.0）が PATH で先に来る。
- **Codex**: brew cask で導入。公式 standalone installer との経路の違い。
- **Antigravity CLI**: 手動配置の binary と cask の二重導入。
- **IntelliJ**: 壊れた cask の記録。
- **PATH**: 起動元アプリ（Orca）経由の環境に、存在しない path や相対 path が入る。login shell 自体の PATH は正常。
- **mise**: どの設定からも参照されていない古い version が残っている（`mise prune --dry-run` で確認できる）。
- **手動 binary**: `~/.local/bin/omp`、`/usr/local/bin/apm`、`/usr/local/bin/docker-compose` は、どの manager の管理下にもない。
