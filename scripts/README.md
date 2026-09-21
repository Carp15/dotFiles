# Scripts

- `doctor.sh`: OS と主要 CLI の存在、および chezmoi の version・source directory・`chezmoi status` を非破壊で確認します。credential、環境変数の値、設定ファイルの内容は表示しません。apply や変更は行いません。
- `bootstrap.sh`: 新規マシン導入（Git → chezmoi → repository → `chezmoi init` → `chezmoi diff` → `chezmoi apply`）の進捗を読み取り専用で表示し、次に実行するコマンドを案内します。install も設定変更も行わず、`chezmoi apply` は決して自動実行しません。
- `link.sh`: symlink 方式で管理する設定を live 環境へ配置します。既定は dry-run で、`--apply` を付けたときだけ symlink を作成します。既存の実ファイル・実ディレクトリは移動も削除もせず、conflict として報告します。現在の対象は `config/nvim` のみです。

script を拡張するときは、dry-run を優先し、live 設定の上書き・symlink 変更・`chezmoi apply`・package install は明示的な操作として分離します。`link.sh` に link を追加する場合も、対象が「編集の実体を repository に置いてよい設定」か確認してから宣言します。
