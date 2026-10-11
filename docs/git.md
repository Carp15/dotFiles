# Git

## Current inventory

現在確認できている Git は Apple Git 2.50.1 です。Git は XDG の既定位置を利用しており、global ignore の live source は `~/.config/git/ignore` です。このファイルは内容確認済みで、chezmoi source state の `home/dot_config/git/ignore` で管理しています。live と source state の内容は一致しており、`chezmoi status` に差分が出ません。

`~/.gitconfig` には Git identity と GitHub / Gist の credential helper が設定されています。identity の値と credential helper の詳細値は記録しません。credential helper は local auth integration としてローカルに残し、credential 実体は管理対象にしません。

### 共通設定と machine 固有設定の分離

| ファイル | 内容 | 管理 |
| --- | --- | --- |
| `~/.config/git/config` | 全 machine（macOS、WSL、Windows）共通の設定 | chezmoi（`home/dot_config/git/config`） |
| `~/.config/git/ignore` | global ignore | chezmoi（`home/dot_config/git/ignore`） |
| `~/.gitconfig` | `user.name` / `user.email`、credential helper など machine・account 依存の値 | live のまま。repository に入れない |

Git は `~/.config/git/config` を読んだあとに `~/.gitconfig` を読むので、同じ key があれば `~/.gitconfig`（machine 側）が勝ちます。Git for Windows も同じ場所を読みます（Windows 実機では未検証）。

共通設定に入れているのは、2026-10-11 に利用者が選んだ次の4つだけです。

| 設定 | 意図 |
| --- | --- |
| `init.defaultBranch = main` | 新しい repository の最初の branch を `main` にする |
| `pull.ff = only` | `git pull` は fast-forward だけ。履歴が分岐していたら止まり、意図しない merge commit を作らない（分岐したら `git pull --rebase` か `git merge` を自分で選ぶ） |
| `push.autoSetupRemote = true` | 新しい branch の最初の `git push` で upstream を自動設定する |
| `fetch.prune = true` | fetch のたびに、remote で消えた branch の追跡 ref を消す |

GitHub への SSH 接続は、共通設定の `url.insteadOf` ではなく、repository ごとに remote を `git@github.com:...` へ切り替えて行います。新しい machine で SSH 鍵を登録する前でも、[WSL](wsl.md) の手順どおり HTTPS で clone できるようにするためです。

### 新しい machine で identity を設定する

`~/.gitconfig` は管理しないので、machine ごとに自分で設定します。

```bash
git config --global user.name  "<name>"
git config --global user.email "<email>"
```

Git alias、include、signing 設定は現時点でありません。一般的な alias や推奨設定を勝手に追加せず、必要になった時点で意図、対象環境、secret / machine dependency を確認して個別に管理します。

## Operating rules

Git 設定を追加・変更するときは、secret、account・machine 依存を確認してから `chezmoi add` で source state へ取り込み、`chezmoi diff` で `$HOME` への影響を確認します。`~/.gitconfig` 全体は identity と認証連携を含むためコピーしません。

dotfiles を追加する際は対象パスを個別確認し、secret・generated state・machine 固有値を分類します。`git add .` や `git add -A` は設定候補の安全確認を飛ばしやすいため使いません。

頻用コマンドは [Git cheatsheet](../cheatsheets/git.md) に限定し、設定の考え方・分類・配置先はこの文書に記録します。
