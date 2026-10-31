# mise

mise は user-level の tool version 管理に使います。macOS と WSL で共通の宣言を持ち、WSL だけ CLI を追加します。担当分けの全体は [packages](packages.md) を参照してください。

## 共通の宣言（`home/dot_config/mise/config.toml` → `~/.config/mise/config.toml`）

| Tool | 管理値 | 方針 |
| --- | --- | --- |
| Go | `1.26.3` | exact version で再現性を優先 |
| Java | `temurin-21` | vendor と major version を明示（後述） |
| Node.js | `24` | major version を宣言 |
| npm | 宣言しない | Node.js 同梱版を使う（後述） |

macOS と WSL に同じファイルを配置します（Windows native には配置しません）。template ではありません。

### npm

npm は mise で独立に固定せず、Node.js に同梱された版を使います（2026-10-31 に `npm = "11.15.0"` の宣言を外しました）。この固定は chezmoi 導入時（2026-09-21）の状態を取り込んだもので、理由の記録がなく、Node 24.19.0 同梱の 11.17.0 より古い npm を使わせていました。また global の宣言なので、Node 22 を指定した project でも 11.15.0 になっていました。

同梱版を使うので、npm の版は使う Node.js の版で決まります。2026-10-31 時点で、Node 24.19.0 は npm 11.17.0、Node 22.23.1（project 用）は npm 10.9.8 です。project で npm の版をそろえる必要があれば、その project の `mise.toml` や `package.json` の `packageManager` で宣言します。

宣言を外しても、インストール済みの `~/.local/share/mise/installs/npm/11.15.0` は削除していません（`mise prune` は別に承認を得て行う）。確認は `mise which npm` だけでなく、実際に解決されるものを見ます。

```bash
command -v npm && npm --version          # shim 経由で実際に使われる npm
mise which npm                           # mise が解決する実体
mise exec node@22 -- npm --version       # Node 22 では同梱の 10.9.x
```

### gopls

gopls は mise にも Brewfile にも宣言しません。今は `go install golang.org/x/tools/gopls` で入れたものが、mise が `GOBIN` に設定する使用中の Go の `bin`（`~/.local/share/mise/installs/go/<version>/bin`）にあります（2026-10-31 時点で gopls v0.21.1、go1.26.3 で build）。ほかの場所（Homebrew、`~/go/bin`、Mason）にはありません。利用しているのは VS Code の Go 拡張で、Neovim（AstroNvim）は gopls を設定していません。VS Code の拡張が gopls を自動で導入・更新しているかは確認していません。`brew bundle dump` は `GOBIN` にある `go` / `gofmt` / `gopls` を `go "..."` の行として出力しますが、Homebrew の管理物ではないので Brewfile には宣言しません。

gopls は Go の版ごとの `bin` に入るため、Go を更新する（`config.toml` の `go` を変える、または `go = "latest"` の project で新しい Go が入る）と、新しい Go には gopls がありません。Go を更新したら次を確認し、無ければ入れ直します。

```bash
mise which gopls                              # 新しい Go の bin にあるか
go version "$(mise which gopls)"              # build した Go の版
go install golang.org/x/tools/gopls@latest    # 無い・古いときに入れ直す
```

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

## 管理しないもの

mise 本体、download / install の cache、shims、migration state は、生成物か環境に依存する状態なので Git 管理しません。secret や credential を mise の設定に保存しないでください。
