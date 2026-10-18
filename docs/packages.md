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
| 開発ランタイム | mise（`home/dot_config/mise/config.toml`。Java は `temurin-21`） | mise（同じファイル） | 原則不要（WSL 側を使う） |
| 公式 installer 推奨の CLI | 公式 installer（Claude Code、Antigravity CLI）。Codex CLI は Homebrew cask（Brewfile の `cask "codex"`） | 公式 installer（mise、Claude Code、Codex CLI） | 原則不要 |
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
| macOS | Homebrew の確認（無ければ停止）→ `brew bundle install --no-upgrade`（Codex CLI はここで cask として入る）→ `mise install` → Claude Code（無ければ） |
| WSL (Ubuntu) | apt（不足分だけ）→ mise（公式 installer）→ `mise install` → Claude Code → Codex CLI |
| Windows native | `winget.json` の順に、未導入のものだけ `winget install --id <ID> --exact --source winget --no-upgrade`（PowerShell 7 → Windows Terminal → Git → chezmoi）。`--with android` を付けたときだけ、続けて Android Studio。規約への同意は自動化しない |

bootstrap は既存のコマンドを入れ直さず、アップグレードも削除もしません。`chezmoi apply` と `brew bundle cleanup` も実行しません。WSL 以外の Linux、Ubuntu 以外の WSL distribution、root での実行は exit 2 で止まります。Windows の `bootstrap.ps1` は、管理者として実行した場合と Windows 以外では exit 2 で止まり、Git Bash から `bootstrap.sh` を実行した場合も exit 2 で `bootstrap.ps1` を案内します。

`winget import` は使いません。パッケージごとに導入済みの判定・実行コマンドの表示・失敗時の停止を行うためです。

bootstrap が待つのは、各ステップが依存する chezmoi の target だけです。mise のツールは mise の設定（`~/.config/mise/config.toml`、WSL では `conf.d/wsl.toml` も）、公式 installer は PATH を通す shell の起動ファイル（`~/.zshrc`、`~/.zprofile`）が未適用のとき `blocked` になります。それ以外の target（Git の共通設定など）が未適用でも、`not needed by bootstrap` と表示するだけで止まりません。`chezmoi` が無い、source が別の repository、`chezmoi status` 自体が失敗した、のいずれかの場合は、両方とも `blocked` です。

既存の Mac では、bootstrap の dry-run で全ステップが `ok` になることを確認済みです（2026-10-13）。

### Antigravity CLI（macOS、手動）

Antigravity CLI（`agy`）の管理元は Google の公式 installer で、`~/.local/bin/agy` に入ります（2026-10-18 時点で 1.4.2）。Antigravity app は Brewfile の `cask "antigravity"` で管理し、CLI は Brewfile にも bootstrap にも入れていません。CLI の Homebrew cask（`antigravity-cli`）は 2026-10-18 に uninstall しました（後述）。

新しい Mac では、`chezmoi apply` で `~/.local/bin` が PATH に入った後に、公式 installer を取得してから実行します。URL は公式 docs の `curl -fsSL https://antigravity.google/cli/install.sh | bash` と同じです。

```bash
curl -fsSL https://antigravity.google/cli/install.sh -o /tmp/agy-install.sh
less /tmp/agy-install.sh            # 任意: 内容を確認する
bash /tmp/agy-install.sh
chezmoi status                      # shell の起動ファイルが書き換えられていないか確認する
```

- **shell 設定の変更に注意**: installer は最後に `agy install`（「Configuring shell environment...」）を実行します。これが chezmoi 管理の `~/.zshrc` などに PATH の行を追記するかどうかは未確認です。`chezmoi status` に差分が出たら、`chezmoi add` で取り込まず、`chezmoi diff` で内容を確認して不要な行を戻します（`~/.local/bin` は dotfiles の zprofile / zshrc がすでに PATH に入れています）。
- **quarantine**: installer は macOS で `com.apple.quarantine` 属性を外します。
- **自己更新**: `agy` は起動するたびにバックグラウンドで更新を確認し（前回から 15 分以内なら省略）、`~/.local/bin/agy` を置き換えます。状態は `~/.gemini/antigravity-cli/updater/update_status.json` に残ります。置き換えのときに `~/.local/bin/agy.<数字>.old` が作られることがありますが、CLI 自身が後で消すことがあるため、永続的なバックアップとはみなしません。動作確認のために `agy` を実行すると更新が走ることがあるので、バイナリを調べるだけなら実行せずに署名やファイル情報を見ます。
- **自己更新の無効化**: バイナリには `AGY_CLI_DISABLE_AUTO_UPDATE` という環境変数が含まれていますが、公開 docs には記載がなく、値の仕様は未確認です。設定していません。
- **cask を使わない理由**: 公式 installer 版と cask 版の二重導入になっていたうえ、cask 版（1.1.17）は 2026-10-17 の確認で `--version` / `--help` に応答しませんでした（原因は未特定のままで、cask を入れ直すと再発する可能性があります）。また自己更新が Caskroom 内のファイルを書き換えると、Homebrew の記録とずれます。uninstall は `HOMEBREW_NO_AUTOREMOVE=1` を付け、`--zap` なしで行いました。前者は、`brew uninstall` が既定で、使われていない formula まで autoremove するのを止めるためです（このときは `openssl@3` が対象になっていた）。後者は、`--zap` が `~/.gemini/antigravity-cli`（CLI の設定・会話・状態）を消すためです。

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
| Java / Node / Go / npm | mise（`config.toml`） | macOS と共通の宣言。Java は全 platform で `temurin-21` |
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
- `config.toml` にあるツールの値は conf.d では上書きできない。platform ごとに値を変える必要が出たら、`config.toml` を template にして分岐する（以前の Java の vendor がそうだったが、全 platform を `temurin-21` にそろえたため今は不要）。
- project の `mise.toml` は global 設定より優先される（同じ方法で確認）。project 固有の version は project 側で宣言する。
- `config.local.toml` も `config.toml` より優先されるが、machine ごとの手元用に空けておき、repository では使わない。

## 保留事項

| 項目 | 現状 | 保留の理由 |
| --- | --- | --- |
| `cask "codex-app"` | 記録は `/Applications/Codex.app` を想定しているが、そこには無い | 使用中の Codex app の実体は `/Applications/ChatGPT.app`（bundle id `com.openai.codex`、app 自身が更新する）。cask を宣言・更新すると Codex.app が二重に入る。cask の uninstall は `quit com.openai.codex` で ChatGPT.app を終了させ、`--zap` は app の data を消すため、整理は app を終了してから `--zap` なしで行う |
| `tap "stablyai/orca"` / `cask "orca"` | 導入済み・使用中（削除対象ではない）。tap は Untrusted、cask は個別に trusted | Brewfile に宣言すると、新しい Mac でも third-party tap を信頼することになる。Orca は `~/.claude/settings.json` と `~/.codex/hooks.json` に hook を入れ、起動した shell に PATH を渡す |
| `cask "intellij-idea"` | Caskroom に記録だけがあり app がない | 壊れている。Toolbox と直接導入のどちらにするか未決定 |
| `go "golang.org/x/tools/gopls"` など | `brew bundle dump` が出力する `go` の3件 | Homebrew の管理物ではない。Go は Homebrew ではなく mise の担当で、mise が `GOBIN` を使用中の Go の `bin` にしているため、bundle がそこにある `go` / `gofmt` / `gopls` を列挙するだけ。Brewfile には宣言しない。`gopls` は Go 1.26.3 の中にあり、Go を更新すると見えなくなるので、担当（mise の go backend など）が未決定 |
| Claude.app、ChatGPT、Brave、Chrome、Logi Options+ | 手動導入 | cask で管理し直すと既存 app の扱いに影響する |
| Xcode | App Store | `mas` を導入するか未決定 |
| WSL のコンテナ CLI | – | Podman と Docker Engine のどちらにするか未決定（`commands/wsl.txt` に未記載。Phase 2 の対象外） |
| Windows の IntelliJ | – | `JetBrains.IntelliJIDEA` と `JetBrains.Toolbox` のどちらにするか未決定 |

## 既知の問題（未修正）

既存 macOS の挙動を変えないため、記録だけしておきます。Phase 4C で1件ずつ、承認を得てから扱います（2026-10-13 の Phase 4A 調査でも同じ状態）。

- **Java**: 2026-10-15 に macOS も `temurin-21` へ移行し、解消した（[mise](mise.md)）。切り戻し用に旧 JDK の openjdk 21.0.2 を残しており、削除は未実施。
- **npm**: Node 24.19.0 には npm 11.17.0 が同梱されている（nodejs.org の配布一覧で確認。global 更新したものではない）。通常の login shell では、mise で宣言した `npm 11.15.0` が PATH で先に来るため、同梱版より古い 11.15.0 が使われている。Orca が PATH の先頭に `node/24/bin` を渡す shell では同梱の 11.17.0 が使われる。npm の宣言を外して同梱版に任せるかは未決定（mise の設定は WSL にも配置される）。
- **Codex**: macOS の Codex CLI は Homebrew cask で管理し、2026-10-17 に Brewfile へ `cask "codex"` を宣言した（WSL は公式 installer）。Codex app は上の保留事項のとおり、cask の記録と実体が一致していない。
- **Antigravity CLI**: 公式 installer 版と cask 版の二重導入は、2026-10-18 に cask 版を uninstall して解消した（「導入」の「Antigravity CLI（macOS、手動）」を参照）。残っている問題は2つ。`agy` を数分から数十分おきに起動しているもの（2026-10-17〜18 に、対話セッションとして起動した記録がある）が特定できていない。cask 版 1.1.17 が応答しなかった原因も特定できていない（cask を削除しただけで、原因は解決していない）。
- **IntelliJ**: 壊れた cask の記録。
- **PATH**: 起動元アプリ（Orca）経由の環境に、存在しない path、相対 path、`node/24/bin` が先頭に入る。login shell 自体の PATH は正常。`scripts/doctor.sh` はこの環境で実行すると、相対 path を error として exit 1 を返す。
- **mise**: 未使用だった go 1.25.1 / 1.26.2、node 24.14.1、pnpm 10.33.0 は 2026-10-17 に削除した（`mise prune --tools go node pnpm`）。node 22.23.1、pnpm 10.12.4、python 3.11.15、uv 0.11.14 は project が使っている。dotnet 10.0.300 は用途が不明なため保留、Java 21.0.2 は切り戻し用に残している。
- **手動 binary**: `~/.local/bin/omp`、`/usr/local/bin/docker-compose` は、どの manager の管理下にもない。`/usr/local/bin/apm` は Microsoft APM（Agent Package Manager）で、Skills・Agents を `~/.apm` から配布している。本体の導入方法は Phase 4D で決める。
