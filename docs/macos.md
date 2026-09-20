# macOS

この基盤を作成した環境は macOS 26.5.1（Darwin 25.5.0）、arm64 です。Homebrew の利用有無や CLI の実在は、パッケージ一覧を収集せず `scripts/doctor.sh` で確認できます。

macOS 固有の GUI application path や device 固有値は、共通 `config/` に直接固定しません。必要時に `local/` または将来の manager の条件分岐へ分離します。
