# mise

現在のMacでは、miseをuser-levelのtool version管理に使用しています。リポジトリで管理する宣言は次の4つです。

| Tool | 管理値 | 方針 |
| --- | --- | --- |
| Go | `1.26.3` | exact versionで再現性を優先 |
| Java | `21` | major versionを維持 |
| Node.js | `24` | major versionを宣言 |
| npm | `11.15.0` | exact versionを維持 |

managed copyは [`config/mise/config.toml`](../config/mise/config.toml) です。liveの `~/.config/mise/config.toml` は今回変更していません。実環境へ反映する場合は、miseの導入後に内容と対象環境を確認し、明示的にinstallしてください。

mise本体、download/install cache、shims、migration stateは生成物または環境依存状態なのでGit管理しません。project固有のtoolはglobal設定へ混ぜず、各projectの `mise.toml` で管理します。secretやcredentialをmise設定へ保存しないでください。
