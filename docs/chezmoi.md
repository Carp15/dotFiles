# chezmoi

このリポジトリの dotfiles manager は [chezmoi](https://www.chezmoi.io/) です。公式マニュアルの複製はせず、この repository での運用だけを記録します。

## 採用理由

| 要件 | chezmoi での扱い |
| --- | --- |
| 単一 Git repository で完結させたい | source state が通常の Git repository。既存履歴とナレッジ層をそのまま使える |
| macOS を正本に、将来 Linux / WSL と複数 Mac へ広げたい | `.tmpl` と OS / hostname 変数で分岐でき、OS ごとの repository 分割が不要 |
| HOME を勝手に変えたくない | `chezmoi status` / `chezmoi diff` / `--dry-run` が標準で、apply が明示操作 |
| secret を Git に入れたくない | source state へ入れない運用を前提にでき、必要なら後から外部 secret 参照へ拡張できる |
| 将来 manager を替える余地を残したい | source state は平文ファイルの木構造で、Nix / Stow へ移す際も内容がそのまま使える |

Nix + Home Manager は環境全体の宣言まで踏み込むため、現時点の目的（dotfiles の再現）に対して範囲が広すぎます。GNU Stow は symlink 配置のみで、OS 差分と template を持ちません。

## Source directory

```text
dotFiles/                     <- Git repository root / chezmoi working tree
├── .chezmoiroot              <- "home"
├── home/                     <- chezmoi source directory（apply 対象はここだけ）
│   ├── .chezmoiignore
│   ├── dot_zshrc             -> ~/.zshrc
│   ├── dot_zprofile          -> ~/.zprofile
│   └── dot_config/
│       ├── git/ignore        -> ~/.config/git/ignore
│       └── mise/config.toml  -> ~/.config/mise/config.toml
├── AGENTS.md, docs/, cheatsheets/, scripts/   <- ナレッジ層（apply されない）
├── config/nvim/              <- symlink 方式のまま（後述）
└── local/                    <- Git 管理しない machine 固有 override
```

`.chezmoiroot` が重要な安全装置です。これがないと chezmoi は repository root 直下の `AGENTS.md`、`docs/`、`scripts/` などをすべて target state と解釈し、`~/AGENTS.md` や `~/docs/` を作ろうとします。ナレッジ層を `.chezmoiignore` で除外し続ける設計にはせず、`home/` の外に置くことで構造的に対象外にしています。

`sourceDir` は machine 固有の絶対 path なので repository には入れず、HOME 側の `~/.config/chezmoi/chezmoi.toml` に置きます。

```toml
sourceDir = "/path/to/dotFiles"
```

`chezmoi init --source=...` はこの値を設定ファイルへ保存しないため、新規マシンでは上記ファイルを自分で作ります。現在の値は `chezmoi source-path` で確認でき、`home` まで解決されていれば正しい状態です。

## 基本操作

正本は source state です。HOME 側の管理対象ファイルを直接編集しても、次の apply で上書きされます。

```bash
chezmoi status                      # 差分のある管理対象を一覧（読み取り専用）
chezmoi diff                        # source state -> HOME の差分を確認
chezmoi edit ~/.zshrc               # source state を編集する（正しい入口）
chezmoi add ~/.config/foo/bar.toml  # live のファイルを source state へ取り込む
chezmoi apply                       # HOME へ反映する。必ず diff の後
chezmoi cd                          # source directory (home/) へ移動
```

`chezmoi edit` や `chezmoi add` は repository の作業ツリーを書き換えるので、そのあと repository root で `git diff` を確認して commit します。`chezmoi cd` が降りるのは `home/` なので、Git 操作は一階層上で行います。

### add するとき

`chezmoi add` は live の内容をそのまま source state へ複製します。取り込む前に内容と構造を確認し、secret と machine 依存値がないことを確かめます。live に machine 固有値が含まれている場合は、`chezmoi add` したあとに source state 側を可搬な形へ直し、`chezmoi diff` で HOME への影響を確認します。

### apply するとき

apply は HOME を書き換える唯一の操作です。次の順で行います。

```bash
chezmoi status
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
```

差分が意図どおりだと確認できるまで apply しません。特定のファイルだけ反映する場合は `chezmoi apply ~/.zshrc` のように対象を限定します。

## Machine-specific 設定

machine 依存値は、次の順で「共通化 → OS 依存 → machine 依存 → secret」に分類し、共通設定へ直接埋め込みません。

| 分類 | 扱い | 現在の例 |
| --- | --- | --- |
| 共通化可能 | source state にそのまま置く | `~/.local/bin` の PATH 追加、mise activation、alias、mise の tool 宣言、Git global ignore |
| OS 依存 | shell 側の存在チェック、または chezmoi template (`.tmpl` + `.chezmoi.os`) | Homebrew prefix（Apple Silicon `/opt/homebrew` と Intel `/usr/local` を `-x` で判定） |
| machine 依存 | HOME 側の設定ファイル、または `local/` 配下の非機密 override | chezmoi の `sourceDir`、Git identity |
| secret | source state に入れない | Git credential helper が扱う認証情報 |

現時点で `.tmpl` ファイルは1つもありません。取り込んだ設定に username、絶対 home path、hostname、OS 固有 path が残っていないためです。OS 差分は shell の存在チェックで済んでおり、これを template 化すると同じ条件分岐を二重に持つことになります。`.tmpl` は、shell の条件分岐では表現できない差分（設定ファイル形式が条件分岐を持たない場合など）が出た時点で導入します。

## Secret の扱い

secret は原則として source state へ入れません。`.chezmoiignore` は target state から除外するだけで、source state に置いたファイルは Git に入るため、secret 対策にはなりません。現在の `.chezmoiignore` は `.DS_Store` のみを対象にしています。

今回管理対象にしなかったもの。

| 対象 | 理由 |
| --- | --- |
| `~/.gitconfig` | Git identity（account 依存）と GitHub / Gist の credential helper を含む。全体を複製しない |
| `~/.ssh/`、`~/.aws/`、`~/.config/gcloud/`、`~/.kube/config`、`~/.docker/config.json` | credential・private key・session を含む、または安全に否定できない |
| `~/.config/gh/` | OAuth token を保持する host 設定を含む |
| `.env` 系、cookie、session | credential 相当 |

secret を含むファイルの安全な部分だけを管理したい場合も、元ファイルを `chezmoi add` せず、共通部分を別ファイルへ分離してから取り込みます。将来 secret 参照が必要になった場合は、chezmoi の外部 secret manager 連携を個別に検討します（現時点では未導入）。

## 新規 PC への導入

```bash
# 1. Git（macOS なら xcode-select --install で足りる）
# 2. chezmoi
brew install chezmoi

# 3. このリポジトリを clone（ghq 運用に合わせる）
ghq get Carp15/dotFiles

# 4. source directory を設定
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s"\n' "$(ghq list -p Carp15/dotFiles)" > ~/.config/chezmoi/chezmoi.toml
chezmoi source-path            # .../dotFiles/home になることを確認

# 5. 差分を確認する（ここまでは HOME を変更しない）
chezmoi status
chezmoi diff

# 6. 納得したうえで反映する
chezmoi apply
```

`scripts/bootstrap.sh` はこの手順のどこまで進んでいるかを読み取り専用で表示します。自動 apply はしません。既存の dotfiles がある新規マシンでは、必ず 5 で差分を読んでから 6 に進みます。

## Neovim だけ symlink 方式のままにしている理由

`config/nvim/` は repository 側が実体で、`~/.config/nvim` が symlink です（`scripts/link.sh --apply`）。chezmoi へ移すと、`:Lazy update` が書き換える `lazy-lock.json` を毎回 `chezmoi add` で source state へ取り込み直す必要があり、編集のたびに二重管理が発生します。symlink なら live 編集がそのまま作業ツリーの差分になります。

chezmoi にも `.chezmoiexternal` や symlink 属性がありますが、移行の価値と手順は別途検討します。判断の背景は [Neovim](neovim.md) を参照してください。

日常操作は [chezmoi cheatsheet](../cheatsheets/chezmoi.md) にまとめています。
