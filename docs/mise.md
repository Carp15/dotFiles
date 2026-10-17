# mise

mise は user-level の tool version 管理に使います。macOS と WSL で共通の宣言を持ち、WSL だけ CLI を追加します。担当分けの全体は [packages](packages.md) を参照してください。

## 共通の宣言（`home/dot_config/mise/config.toml` → `~/.config/mise/config.toml`）

| Tool | 管理値 | 方針 |
| --- | --- | --- |
| Go | `1.26.3` | exact version で再現性を優先 |
| Java | `temurin-21` | vendor と major version を明示（後述） |
| Node.js | `24` | major version を宣言 |
| npm | `11.15.0` | exact version を維持（後述の既知の問題を参照） |

macOS と WSL に同じファイルを配置します（Windows native には配置しません）。template ではありません。

### Java の vendor

Java は全 platform で `temurin-21`（Eclipse Temurin 21）を明示します。Temurin は LTS に四半期ごとの security update を出し続けます。

vendor を省いた `java = "21"` は、mise の既定 vendor（`java.shorthand_vendor`）に従います。既定は現在の mise では `temurin` ですが、以前の mise は `openjdk`（jdk.java.net の build）でした。openjdk の GA build は次の feature release が出ると更新が止まるため、その頃に入れた JDK は 21.0.2 のままになります。さらに mise は、宣言を満たす版がインストール済みならそれを使い続けるため、`21` のままでは古い JDK から自動では移りません。vendor を明示すれば、既定がまた変わってもどの machine でも同じ JDK になります。

macOS は 2026-10-15 に `21`（openjdk 21.0.2）から `temurin-21`（Temurin 21.0.12.1+1、mise 上の名前は `temurin-21.0.12+101.0.LTS`）へ移行しました。手順は次のとおりです。

1. 先に `mise install java@temurin-21` で新しい JDK を入れる（設定はまだ変えない）
2. `chezmoi apply ~/.config/mise/config.toml` で宣言を切り替える
3. 新しい shell で `java -version` と `JAVA_HOME` を確認する

順序を逆にすると、宣言された版が未インストールの間、`java` が macOS の `/usr/bin/java`（JDK ではない stub）に解決され、`JAVA_HOME` も空になります。

`JAVA_HOME` は zshrc が `mise which java` から求めます。macOS の JDK bundle は、mise が vendor に関係なく `Contents/Home` の中身をインストール先の直下に展開するので、Temurin でも同じ式で正しい path になります。

旧 JDK（`21.0.2`）は、切り戻し用にしばらく残しています。戻すときは Java の行を `21` に戻して `chezmoi apply ~/.config/mise/config.toml` すれば、インストール済みの 21.0.2 が使われます（download は不要）。削除は様子を見てから別途行います。

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

`npm = "11.15.0"` は、通常の login shell では宣言どおりに使われます（mise が npm の path を node の path より前に置く）。一方、Node 24.19.0 には npm 11.17.0 が同梱されています（nodejs.org の配布一覧で確認。global 更新したものではありません）。つまり今は、宣言によって同梱版より古い npm を使っています。PATH の先頭に `node/24/bin` を渡す起動元（Orca 経由の shell など）では、同梱の 11.17.0 が使われます。npm の宣言を外して Node 同梱版に任せるかは未決定で、今は変更していません（このファイルは WSL にも配置されます）。

## 管理しないもの

mise 本体、download / install の cache、shims、migration state は、生成物か環境に依存する状態なので Git 管理しません。secret や credential を mise の設定に保存しないでください。
