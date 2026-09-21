# Neovim

現在の Neovim 環境は Homebrew の Neovim 0.12.5 と [AstroNvim](https://github.com/AstroNvim/AstroNvim) v6 です。GitHub にあった旧 `init.vim`（vim-plug + deoplete + nvim-go）は現在のMacに存在せず再現対象にしなかったため、AstroNvim を新規導入した時点の構成を正本にしています。

## 管理方式

Neovim 設定は `config/` の中で唯一 symlink 方式で配置します。

```text
config/nvim/  ← Git 管理する実体。ここを編集する
     ↑ symlink
~/.config/nvim
```

zsh・Git・mise は chezmoi 管理（source state から `$HOME` へコピーとして適用）です。Neovim を同じ方式にすると、`:Lazy update` が書き換える `lazy-lock.json` を毎回 `chezmoi add` で source state へ取り込み直す必要があり、編集のたびに二重管理が発生します。そのため Neovim だけ実体を repository に置き、live 側を symlink にしています。

`scripts/link.sh` は宣言された link のみを扱う最小の仕組みです。chezmoi にも `.chezmoiexternal` や symlink 属性があるため、将来 chezmoi へ寄せる選択肢は残っています。移行するかどうかは、`lazy-lock.json` の扱いを決めたうえで個別に判断します。chezmoi 側の運用は [chezmoi](chezmoi.md) を参照してください。

## 配置と復元

```bash
./scripts/link.sh            # 計画の確認のみ（dry run）
./scripts/link.sh --apply    # symlink を作成
nvim --headless "+Lazy! sync" +qa
```

`link.sh` は既存の実ファイル・実ディレクトリを移動も削除もしません。`~/.config/nvim` に実体がある環境では conflict として報告するだけなので、退避するか残すかを人が決めます。

## Version の固定

| 対象 | 固定方法 |
| --- | --- |
| AstroNvim 本体 | `lua/lazy_setup.lua` の `version = "^6"` |
| plugin 群 | `config/nvim/lazy-lock.json`（Git 管理） |
| Neovim 本体 | Homebrew。version 宣言はしていない |
| LSP / formatter | Mason が `~/.local/share/nvim` へ導入。Git 管理しない |

`:Lazy update` は `lazy-lock.json` を書き換えます。symlink 経由で repository の作業ツリーが直接変わるため、更新後は `git diff` を確認してから commit します。別環境で同じ状態を再現する場合は、repository を clone して `link.sh --apply` の後に `:Lazy restore` を使います。

## 管理しないもの

- `~/.local/share/nvim`、`~/.local/state/nvim`、`~/.cache/nvim`: plugin・parser・Mason の生成物
- Nerd Font と terminal の配色: terminal application 側の設定
- machine 固有の絶対 path や account 依存値: 必要なら `local/` へ分離する

日常のキー操作は [nvim cheatsheet](../cheatsheets/nvim.md)、ファイル構成は [config/nvim/README.md](../config/nvim/README.md) を参照してください。
