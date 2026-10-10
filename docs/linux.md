# Linux

Linux は将来の対象環境です。ディストリビューション、package manager、desktop integration はここでは前提にしません。共通設定を優先し、Linux 固有の package 名・path・service 設定が必要になった時点で最小限を分離します。

新しい環境では、まず `scripts/doctor.sh` を実行して実在する shell と CLI を確認します（`packages/commands/common.txt` だけを検査し、対象外の platform であることを warn で表示します）。`scripts/bootstrap.sh` は WSL 以外の Linux に対応しておらず、何も変更せずに exit 2 で終了します。WSL かどうかの判定は `scripts/lib/platform.sh` です。WSL については [WSL](wsl.md) を参照してください。
