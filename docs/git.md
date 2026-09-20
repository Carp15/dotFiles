# Git

## Current inventory

現在確認できている Git は Apple Git 2.50.1 です。Git は XDG の既定位置を利用しており、global ignore の live source は `~/.config/git/ignore` です。このファイルは内容確認済みで、管理対象を [config/git/ignore](../config/git/ignore) に登録しています。

`~/.gitconfig` には Git identity と GitHub / Gist の credential helper が設定されています。identity の値と credential helper の詳細値は記録しません。credential helper は local auth integration としてローカルに残し、credential 実体は管理対象にしません。

現時点で、Git alias、include、signing 設定はありません。したがって一般的な alias や推奨設定を勝手に追加せず、必要になった時点で意図、対象環境、secret / machine dependency を確認して個別に管理します。

## Operating rules

Git 設定を追加・変更するときは、live source と managed copy の対応、secret、account・machine 依存を確認します。`~/.gitconfig` 全体は identity と認証連携を含むためコピーしません。manager は未選定なので、現在は自動適用や symlink 作成を行いません。

dotfiles を追加する際は対象パスを個別確認し、secret・generated state・machine 固有値を分類します。`git add .` や `git add -A` は設定候補の安全確認を飛ばしやすいため使いません。

頻用コマンドは [Git cheatsheet](../cheatsheets/git.md) に限定し、設定の考え方・分類・配置先はこの文書に記録します。
