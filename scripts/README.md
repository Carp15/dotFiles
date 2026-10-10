# Scripts

- `doctor.sh`: 読み取り専用の環境確認です。OS / WSL の判定、`packages/commands/` で宣言した必須コマンド、PATH（相対・空のエントリ、重複）、chezmoi の適用状態、mise の有効化と未インストールの tool、Java / Node / Go が動くか、Neovim の version（0.11 以上）、Claude Code / Codex を確認します。問題は error（`not installed` と `misconfigured` を区別）と warn に分けて表示し、error があれば exit code 1 で終わります。credential、環境変数の値、設定ファイルの内容は表示しません。自動修復はしません。
- `bootstrap.sh`: macOS と WSL (Ubuntu) のパッケージを導入します。既定は dry-run で、各ステップの状態と `--apply` で実行するコマンドを表示するだけです（何も書き込みません）。`--apply` では不足しているステップだけを順に実行し、ログを `~/.local/state/dotfiles/bootstrap/` に残して、最初の失敗で止まります。既存のコマンドは入れ直さず、アップグレード・削除・`chezmoi apply`・`brew bundle cleanup` は行いません。WSL 以外の Linux では exit 2 で止まります。
- `lib/platform.sh`: OS / WSL 判定の唯一の実装です（`macos` / `wsl` / `linux` / `unknown`、WSL1 か WSL2 か、distribution）。doctor・bootstrap が source し、chezmoi も `home/.chezmoitemplates/platform` 経由で呼びます。
- `install/official.sh`: 公式 installer（mise、Claude Code、Codex CLI）の URL と、取得・実行の関数です。installer はファイルに保存してから別ステップで実行し、network から直接 shell に流し込みません。
- `link.sh`: symlink 方式で管理する設定を live 環境へ配置します。既定は dry-run で、`--apply` を付けたときだけ symlink を作成します。既存の実ファイル・実ディレクトリは移動も削除もせず、conflict として報告します。現在の対象は `config/nvim` のみです。

script を拡張するときは、dry-run を優先し、live 設定の上書き・symlink 変更・`chezmoi apply`・package install は明示的な操作として分離します。`link.sh` に link を追加する場合も、対象が「編集の実体を repository に置いてよい設定」か確認してから宣言します。
