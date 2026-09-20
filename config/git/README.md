# Git configuration

## Scope

現在の最初の管理対象は、XDG の既定位置で Git が読む global ignore です。

| 層 | 配置 | 役割 |
| --- | --- | --- |
| live source | `~/.config/git/ignore` | 現在のユーザー環境で実際に使われている設定 |
| managed | `config/git/ignore` | このリポジトリでレビュー・再現性のために管理するコピー |
| future destination | manager が選定された後に決定 | chezmoi / Nix Home Manager / Stow 等で配置する候補 |

現時点では manager 未選定のため、自動適用、symlink 作成、live 設定の変更は行いません。`config/git/ignore` は XDG 既定位置を前提にした内容として管理します。

## Classification

- global ignore: Class 1（再現可能な設定）として管理対象
- Git identity（user name / email）: Class 2（machine・account 依存）としてローカルに残し、Git 管理しない
- credential helper: local auth integration としてローカルに残す。credential の実体は Class 3 として管理禁止

`~/.gitconfig` は identity や認証連携を含むため、ファイル全体をコピーしません。値、credential、token をこのリポジトリ、文書、ログへ記録しないでください。
