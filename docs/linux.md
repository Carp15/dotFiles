# Linux

Linux は将来の対象環境です。ディストリビューション、package manager、desktop integration はここでは前提にしません。共通設定を優先し、Linux 固有の package 名・path・service 設定が必要になった時点で最小限を分離します。

新しい環境では、まず `scripts/doctor.sh` を実行して実在する shell と CLI を確認します。パッケージ導入や設定適用は、明示的な bootstrap 設計後に行います。
