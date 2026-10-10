# mise

mise は user-level の tool version 管理に使います。macOS と WSL で共通の宣言を持ち、WSL だけ CLI を追加します。担当分けの全体は [packages](packages.md) を参照してください。

## 共通の宣言（`home/dot_config/mise/config.toml.tmpl` → `~/.config/mise/config.toml`）

| Tool | 管理値 | 方針 |
| --- | --- | --- |
| Go | `1.26.3` | exact version で再現性を優先 |
| Java | macOS: `21` / WSL: `temurin-21` | major version を維持。vendor は後述 |
| Node.js | `24` | major version を宣言 |
| npm | `11.15.0` | exact version を維持（後述の既知の問題を参照） |

`config.toml` は chezmoi template です。違いは Java の行だけで、macOS でレンダリングされる内容は template にする前と1バイトも変わりません。

### Java の vendor

`java = "21"` は mise の既定 vendor（openjdk）に解決され、この Mac では 21.0.2（2024-01）のまま更新されていません。openjdk の GA build は次の feature release が出ると更新が止まるためです。新しく作る WSL 環境では、security update が続く `temurin-21` から始めます。

macOS の移行（`21` → `temurin-21`）はまだ行っていません。移行するときは template の分岐をなくして両方を `temurin-21` にし、IntelliJ や Gradle に登録された旧 JDK の path を確認したうえで、旧版を `mise prune` で整理します。`JAVA_HOME` は zshrc が mise の選んだ java から求めるので、手で変える必要はありません。

## WSL だけの宣言（`home/dot_config/mise/conf.d/wsl.toml`）

Neovim（aqua backend、`0.12`）、gh、ghq、lazygit、fd、tree-sitter、kubectl、helm、Rust（`core:rust`。内部で rustup を使う）を宣言しています。macOS ではこれらを Homebrew で入れるため、chezmoi はこのファイルを WSL でだけ配置します（`home/.chezmoiignore`）。

## 読み込み順序

mise 2026.10.0 で、隔離した設定ディレクトリを使って確認した結果です。

| 設定 | 優先度 | 用途 |
| --- | --- | --- |
| project の `mise.toml` | 最も高い | project 固有の version。global 設定には混ぜない。初回は `mise trust` が必要 |
| `~/.config/mise/config.local.toml` | `config.toml` より高い | machine ごとの手元用。repository では使わない |
| `~/.config/mise/config.toml` | conf.d より高い | 共通の宣言 |
| `~/.config/mise/conf.d/*.toml` | 最も低い | 追加専用。`config.toml` にあるツールの値は上書きできない |

## 既知の問題

`npm = "11.15.0"` は、通常の login shell では宣言どおりに使われます（mise が npm の path を node の path より前に置く）。ただしこの Mac では、node 同梱の npm を global 更新した 11.17.0 が node 24 の install 内に残っています。PATH の先頭に `node/24/bin` を注入する起動元（Orca 経由の shell など）では、こちらが使われます。npm の扱い（mise で宣言するか、node 同梱版に任せるか）は未決定で、今は変更していません。

## 管理しないもの

mise 本体、download / install の cache、shims、migration state は、生成物か環境に依存する状態なので Git 管理しません。secret や credential を mise の設定に保存しないでください。
