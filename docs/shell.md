# Shell

現在の login shell は `/bin/zsh` です。GitHub にあった旧 `.zshrc`、`.zshrc.zplug`、`init.vim` は現在のMacの実環境と一致しなかったため、管理対象から外しました。現在のMacの `~/.zprofile` と `~/.zshrc` を確認し、移植可能な形を chezmoi source state の `home/dot_zprofile` と `home/dot_zshrc` で管理します。

## 現在の共通設定

- `~/.local/bin` をPATHに加える（重複は避ける）。
- macOSでは存在するHomebrewを検出して`brew shellenv`を読み込む。
- miseがある環境だけでzsh integrationを有効にし、miseが選択したJava実行ファイルから`JAVA_HOME`を設定する。
- `vim` は Neovim がある環境でのみ `nvim` の alias にする。存在チェックで囲んでいるため、Neovim が無い machine では実体の vim がそのまま使える。
- `codexa` は `codex --profile auto`、`codexf` は `codex --profile full` の短縮名。

この source state は live の `~/.zprofile` / `~/.zshrc` とまだ一致していません。live 側には `/Users/<user>` の絶対 path、stale な Go の PATH 追加、Antigravity CLI installer が追記した重複 PATH が残っています。反映するには `chezmoi diff` を確認してから `chezmoi apply` を実行します（[chezmoi](chezmoi.md) 参照）。

`brew`、`mise`、`codex`、JavaはこのMacで確認済みですが、別環境で必須とはしません。Homebrew prefixはApple SiliconとIntelの既定位置を条件付きで扱い、Linux/WSLでは存在しなければ何もしません。hostname、private path、account・組織固有値は共通設定に入れず、必要なら `local/` または将来のmanagerの条件分岐に分離します。

古いzplugin/zplug設定、バージョン固定のGo PATHは、現行のlive設定で確認できず再現対象にしませんでした。旧 `init.vim` も同様に再現せず、Neovim は AstroNvim で新規に構成し直して [docs/neovim.md](neovim.md) で管理しています。日常的な操作は [shell cheatsheet](../cheatsheets/shell.md) に短く記録します。
