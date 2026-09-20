# Scripts

- `doctor.sh`: OS と主要 CLI の存在を非破壊で確認します。credential や環境変数の値は表示しません。
- `bootstrap.sh`: 将来の再現作業の入口となる、安全な説明用 stub です。既定では install や設定変更をしません。
- `link.sh`: symlink 方式で管理する設定を live 環境へ配置します。既定は dry-run で、`--apply` を付けたときだけ symlink を作成します。既存の実ファイル・実ディレクトリは移動も削除もせず、conflict として報告します。現在の対象は `config/nvim` のみです。

script を拡張するときは、dry-run を優先し、live 設定の上書き・symlink 変更・package install は明示的な操作として分離します。`link.sh` に link を追加する場合も、対象が「編集の実体を repository に置いてよい設定」か確認してから宣言します。
