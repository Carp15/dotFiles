# Scripts

- `doctor.sh`: 読み取り専用の環境確認です。OS / WSL の判定、`packages/commands/` で宣言した必須コマンド、PATH（相対・空のエントリ、重複）、chezmoi の適用状態、mise の有効化と未インストールの tool、Java / Node / Go が動くか、Neovim の version（0.11 以上）、Claude Code / Codex を確認します。問題は error（`not installed` と `misconfigured` を区別）と warn に分けて表示し、error があれば exit code 1 で終わります。credential、環境変数の値、設定ファイルの内容は表示しません。自動修復はしません。
- `bootstrap.sh`: macOS と WSL (Ubuntu) のパッケージを導入します。既定は dry-run で、各ステップの状態と `--apply` で実行するコマンドを表示するだけです（何も書き込みません）。`--apply` では不足しているステップだけを順に実行し、ログを `~/.local/state/dotfiles/bootstrap/` に残して、最初の失敗で止まります。既存のコマンドは入れ直さず、アップグレード・削除・`chezmoi apply`・`brew bundle cleanup` は行いません。WSL 以外の Linux では exit 2 で止まります。
- `lib/platform.sh`: OS / WSL 判定の唯一の実装です（`macos` / `wsl` / `linux` / `windows` / `unknown`、WSL1 か WSL2 か、distribution）。`windows` は Git Bash（MINGW / MSYS）で実行された場合で、bootstrap.sh は exit 2 で `bootstrap.ps1` を案内します。doctor・bootstrap が source し、chezmoi も `home/.chezmoitemplates/platform` 経由で呼びます。
- `bootstrap.ps1`: Windows native の基本環境のパッケージを `packages/windows/winget.json` から winget で導入します。任意のツール（`winget-<group>.json`、例：Android Studio）は `--with <group>` を付けたときだけ対象にします。既定は dry-run で、`--apply` では未導入のものだけを1つずつ `--no-upgrade` で入れ、最初の失敗で止まります。規約への同意（`--accept-*-agreements`）は自動化しません。管理者として実行すると exit 2。Windows PowerShell 5.1 でも動きます。手順は [docs/windows.md](../docs/windows.md)。
- `doctor.ps1`: Windows native の読み取り専用の診断です。`packages/commands/windows.txt`、winget の導入状態、PowerShell 7、chezmoi の状態と Windows / WSL の target 分離、PowerShell 7 が実際に共有設定を読み込むか（profile 付きで pwsh を1回起動して確認）、Windows Terminal の fragment を確認します。任意のグループ（Android の adb など）は情報表示だけで、`--with <group>` のときだけ必須にします。報告形式と exit code は `doctor.sh` と同じです。
- `lib/windows.ps1`: `bootstrap.ps1` と `doctor.ps1` の共通関数です。Windows 以外での判定は `lib/platform.sh` に委ねます。
- `install/official.sh`: 公式 installer（mise、Claude Code、Codex CLI）の URL と、取得・実行の関数です。installer はファイルに保存してから別ステップで実行し、network から直接 shell に流し込みません。
- `link.sh`: symlink 方式で管理する設定を live 環境へ配置します。既定は dry-run で、`--apply` を付けたときだけ symlink を作成します。既存の実ファイル・実ディレクトリは移動も削除もせず、conflict として報告します。現在の対象は `config/nvim` のみです。

script を拡張するときは、dry-run を優先し、live 設定の上書き・symlink 変更・`chezmoi apply`・package install は明示的な操作として分離します。`link.sh` に link を追加する場合も、対象が「編集の実体を repository に置いてよい設定」か確認してから宣言します。
