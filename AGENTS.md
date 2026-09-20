# Dotfiles repository guidance

## Purpose

このリポジトリは個人環境の設定、dotfiles、CLI 利用方法を管理する。設定そのものと、その意図・使い方を分離して記録し、複数環境へ安全に展開できる基盤とする。

## Source of truth

質問や変更を行う場合、以下を優先する。

1. 実際に管理されている設定
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

## Changes

設定を変更する場合は、次の順で進める。

1. 現在の状態を確認する
2. 管理対象か確認する
3. secret / machine dependency を確認する
4. 変更する
5. diff を確認する
6. validation を行う
7. 必要なら `docs/` / `cheatsheets/` を更新する

特定の dotfiles manager は、明示的な選定まで導入しない。

`config/` の配置方式は2つある。`config/git`、`config/zsh`、`config/mise` は reference copy で、repository から live へ適用しない。`config/nvim` は repository 側が実体で、`~/.config/nvim` が symlink である。symlink 対象の設定は live と managed が同一ファイルのため、編集がそのまま作業ツリーの差分になる。編集後は `git diff` で確認し、生成物を誤って commit しない。

symlink の作成は `scripts/link.sh --apply` に限る。既存の実ファイル・実ディレクトリは移動・削除せず、conflict として報告して人の判断を待つ。新しい設定を symlink 方式にするかは、日常的な編集頻度と secret / machine 依存を確認したうえで個別に判断する。

## Machine-specific settings

machine 固有設定は共通設定へ直接入れない。`local/`、template、条件分岐などを使う前提で設計する。hostname、private path、account・組織依存値は公開範囲も確認し、共通設定へ混在させない。

## Documentation

一般的なマニュアルを大量にコピーしない。このユーザー固有の設定・alias・運用ルールを優先して記録する。背景と方針は `docs/`、短い日常操作は `cheatsheets/`、実設定は `config/` に置く。
