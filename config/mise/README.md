# mise configuration

このディレクトリは、現在のMacで利用するmiseのtool宣言を管理します。managerはまだ選定していないため、ここから `~/.config/mise/config.toml` へ自動適用したり、symlinkを作成したりしません。

## Source and destination

- Live source: `~/.config/mise/config.toml`
- Managed copy: [`config.toml`](config.toml)
- Future destination: `~/.config/mise/config.toml`

今回のmanaged copyでは、live設定の `go = "latest"` を現在の `1.26.3` に固定し、再現性のためにNode.js `24`を追加しています。Javaはmajor `21`、npmはexact version `11.15.0`を維持します。

miseの `installs/`、`downloads/`、`shims/`、migration stateなどの生成物は管理しません。`.NET`、古いGo/Node.js、pnpm、Python、uvなど、現在インストール済みでもこのglobal宣言へ含めていないtoolは、必要になった時点で個別に判断します。project固有のtoolは各projectの `mise.toml` で管理します。

設定にはsecret、credential、token、private pathを入れないでください。再現時はmiseを別途用意し、内容を確認してから明示的にinstallしてください。
