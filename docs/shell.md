# Shell

現在の login shell は `/bin/zsh` です。GitHub にあった旧 `.zshrc`、`.zshrc.zplug`、`init.vim` は現在のMacの実環境と一致しなかったため、管理対象から外しました。現在のMacの `~/.zprofile` と `~/.zshrc` を確認し、移植可能な形を chezmoi source state の `home/dot_zprofile` と `home/dot_zshrc` で管理します。

## 現在の共通設定

- `~/.local/bin` をPATHに加える（重複は避ける）。
- macOSでは存在するHomebrewを検出して`brew shellenv`を読み込む。
- miseがある環境だけでzsh integrationを有効にし、miseが選択したJava実行ファイルから`JAVA_HOME`を設定する。
- `vim` は Neovim がある環境でのみ `nvim` の alias にする。存在チェックで囲んでいるため、Neovim が無い machine では実体の vim がそのまま使える。同じ条件で `EDITOR`/`VISUAL` も `nvim` にし、alias が効かない git や `chezmoi edit` でも Neovim を使う。
- 履歴は `HISTFILE` を明示し（macOS 以外では既定が無いため）、10万件保存・タブ間共有・重複除去・時刻記録を有効にする。先頭にスペースを付けたコマンドは履歴に残らない。
- `compinit` で補完を有効にする。`fpath` には `brew shellenv` が Homebrew の `site-functions` を入れるため、formula が入れた補完（chezmoi 等）も使える。
- `codexa` は `codex --profile auto`、`codexf` は `codex --profile full` の短縮名。

この source state は macOS の live `~/.zprofile` / `~/.zshrc` へ反映済みで、`chezmoi status` に差分は出ません（2026-10-13 確認）。以前 live にあった `/Users/<user>` の絶対 path、stale な Go の PATH 追加、Antigravity CLI installer が追記した重複 PATH は、反映の時点で消えています。変更するときは source state を編集し、`chezmoi diff` を確認してから自分で `chezmoi apply` します（[chezmoi](chezmoi.md) 参照）。同じ2ファイルが WSL にも配置され、Windows native には配置されません（[windows](windows.md)）。

新しい login shell の PATH には重複も相対 path もありません。Orca などのアプリから起動した shell では、起動元が渡した PATH（存在しない directory や相対 path を含むことがある）が引き継がれるため、`scripts/doctor.sh` が error や warning を出すことがあります。これは dotfiles ではなく起動元の問題です（[packages](packages.md) の既知の問題）。

`brew`、`mise`、`codex`、JavaはこのMacで確認済みですが、別環境で必須とはしません。Homebrew prefixはApple SiliconとIntelの既定位置を条件付きで扱い、Linux/WSLでは存在しなければ何もしません。hostname、private path、account・組織固有値は共通設定に入れず、必要なら `local/` または将来のmanagerの条件分岐に分離します。

古いzplugin/zplug設定、バージョン固定のGo PATHは、現行のlive設定で確認できず再現対象にしませんでした。旧 `init.vim` も同様に再現せず、Neovim は AstroNvim で新規に構成し直して [docs/neovim.md](neovim.md) で管理しています。日常的な操作は [shell cheatsheet](../cheatsheets/shell.md) に短く記録します。
