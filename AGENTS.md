# Dotfiles repository guidance

## Purpose

このリポジトリは個人環境の設定、dotfiles、CLI 利用方法を管理する。設定そのものと、その意図・使い方を分離して記録し、複数環境へ安全に展開できる基盤とする。

## Source of truth

質問や変更を行う場合、以下を優先する。

1. chezmoi source state (`home/`) と `config/nvim/`
2. `docs/`
3. `cheatsheets/`
4. CLI の `--help`
5. ローカル documentation
6. 必要な場合のみ公式 documentation

一般的なデフォルトより、現在のユーザー環境を優先する。live 設定は確認対象であって、明示的な承認なしに上書き・移動・削除しない。

## Safety

以下を Git に追加しない。

- password
- API token、access token、refresh token
- private key
- credential
- cookie、session
- `.env`
- cloud credential
- kubeconfig 内の secret
- SSH private key

疑わしい場合は追加せず報告する。secret の値をドキュメント、ログ、コマンド出力にコピーしない。`.gitignore` は補助策であり、追加前の内容・構造確認を省略する理由にしない。

## Dotfiles manager

dotfiles manager は chezmoi である。配置方式は2つだけで、どちらも live を自動では変更しない。

| 方式 | 対象 | live との関係 | 適用操作 |
| --- | --- | --- | --- |
| chezmoi | `home/` 配下 | source state が正本。`$HOME` へコピーとして適用される | `chezmoi apply`（`chezmoi diff` の確認後） |
| symlink | `config/nvim/` | repository 側が実体で、live が symlink | `scripts/link.sh --apply` |

`.chezmoiroot` が `home` を指すため、chezmoi の source directory は `home/` である。`AGENTS.md`、`docs/`、`cheatsheets/`、`scripts/`、`config/`、`local/` は target state に入らない。ナレッジ層を `.chezmoiignore` で除外する設計へ戻さない。

`sourceDir` は machine 固有の絶対 path なので、repository ではなく `~/.config/chezmoi/chezmoi.toml` に置く。運用の詳細は [docs/chezmoi.md](docs/chezmoi.md)。

### chezmoi を扱うときの規則

- source state を source of truth とする。`$HOME` の管理対象ファイルを直接編集して終了しない。編集したなら `chezmoi add` で source state へ戻すか、source state 側で直し直す。
- 変更前に `chezmoi status`、`chezmoi source-path`、`chezmoi managed` で現在状態を確認する。
- 管理対象の設定を編集するときは `chezmoi edit <target>`、または `home/` 配下のファイルを直接編集する。
- live のファイルを新規に取り込むときは、内容と構造を確認してから `chezmoi add <path>` する。
- secret を source state へ追加しない。`.chezmoiignore` は secret 対策ではない。
- machine-specific 設定を共通設定へ直接埋め込まない。共通化・OS 依存・machine 依存・secret に分類する。
- template (`.tmpl`) は、shell の条件分岐等で表現できない差分が出た場合に限って使う。過剰に template 化しない。
- apply の前に必ず `chezmoi diff` を確認する。必要なら `chezmoi apply --dry-run --verbose` を使う。
- `chezmoi apply`、`chezmoi apply <path>`、`chezmoi init --apply` など live を変更する操作は自動実行しない。差分を提示し、人の承認を得る。
- `chezmoi edit` / `chezmoi add` は repository の作業ツリーを書き換える。実行後は repository root で `git diff` を確認し、生成物を誤って commit しない。`chezmoi cd` は `home/` へ降りるので、Git 操作は一階層上で行う。

### 依頼の読み替え

管理対象の設定変更を依頼された場合は、live ではなく source state を変更する。

| 依頼 | 変更する場所 |
| --- | --- |
| zsh 設定を変更して / alias を追加して | `home/dot_zshrc`（login shell 側なら `home/dot_zprofile`） |
| Git 設定を変えて | global ignore は `home/dot_config/git/ignore`。identity と credential helper は管理対象外なので live に残し、勝手に取り込まない |
| tool version を変えて | `home/dot_config/mise/config.toml` |
| Neovim 設定を変えて | `config/nvim/`（symlink 方式なので live 側もそのまま変わる） |
| tmux の alias を追加して | tmux は未インストール・未管理。まず管理方式を確認し、alias だけなら `home/dot_zshrc` |

未管理のツールの設定を依頼された場合は、推測で追加しない。live の有無、secret、machine 依存を確認し、管理方式を決めてから取り込む。

## Changes

設定を変更する場合は、次の順で進める。

1. 現在の状態を確認する（`chezmoi status`、`git status`）
2. 管理対象か、どの方式で管理されているか確認する
3. secret / machine dependency を確認する
4. source state を変更する
5. `chezmoi diff` と `git diff` を確認する
6. validation を行う
7. 必要なら `docs/` / `cheatsheets/` を更新する

symlink の作成は `scripts/link.sh --apply` に限る。既存の実ファイル・実ディレクトリは移動・削除せず、conflict として報告して人の判断を待つ。新しい設定を symlink 方式にするかは、日常的な編集頻度と secret / machine 依存を確認したうえで個別に判断する。既定は chezmoi 管理とする。

## Machine-specific settings

machine 固有設定は共通設定へ直接入れない。`local/`、template、条件分岐などを使う前提で設計する。hostname、private path、account・組織依存値は公開範囲も確認し、共通設定へ混在させない。

## Documentation

一般的なマニュアルを大量にコピーしない。このユーザー固有の設定・alias・運用ルールを優先して記録する。背景と方針は `docs/`、短い日常操作は `cheatsheets/`、実設定は chezmoi source state (`home/`) と `config/nvim/` に置く。
