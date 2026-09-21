# mise

現在のMacでは、miseをuser-levelのtool version管理に使用しています。リポジトリで管理する宣言は次の4つです。

| Tool | 管理値 | 方針 |
| --- | --- | --- |
| Go | `1.26.3` | exact versionで再現性を優先 |
| Java | `21` | major versionを維持 |
| Node.js | `24` | major versionを宣言 |
| npm | `11.15.0` | exact versionを維持 |

source stateは `home/dot_config/mise/config.toml` で、配置先は `~/.config/mise/config.toml` です。liveは現在 `go = "latest"` で `node` 宣言がないため、`chezmoi status` に差分が出ます。反映する場合は `chezmoi diff` を確認してから `chezmoi apply` を実行し、tool本体は明示的にinstallしてください（[chezmoi](chezmoi.md) 参照）。

mise本体、download/install cache、shims、migration stateは生成物または環境依存状態なのでGit管理しません。project固有のtoolはglobal設定へ混ぜず、各projectの `mise.toml` で管理します。secretやcredentialをmise設定へ保存しないでください。
