# Local overrides

`local/` は hostname 依存設定、private path、machine-specific override、local-only 設定のための Git 管理しない領域です。README 以外は `.gitignore` で除外されます。chezmoi source state (`home/`) の外にあるため、`chezmoi apply` の対象にもなりません。

secret をここへ保存することは推奨しません。password、token、private key、credential は OS の credential store または既存の安全な仕組みで管理し、repository やその近傍に複製しないでください。

共通設定が local override を必要とする場合も、読み込みを任意にし、local file が無い新しい machine で安全に動作するよう設計します。
