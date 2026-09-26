# Neovim configuration

このディレクトリは [AstroNvim](https://github.com/AstroNvim/AstroNvim) v6 の user configuration 本体です。`config/` の中で唯一、reference copy ではなく **live 設定の実体** を置いています。

| 層 | 配置 | 役割 |
| --- | --- | --- |
| managed source | `config/nvim/` | Git 管理する実体。ここを直接編集する |
| live destination | `~/.config/nvim` | `config/nvim` への symlink |
| plugin state | `~/.local/share/nvim`、`~/.local/state/nvim`、`~/.cache/nvim` | lazy.nvim / Mason の生成物。Git 管理しない |

zsh・Git・mise が reference copy 方式なのに対し、Neovim 設定は日常的に編集するため symlink で一本化しています。理由と運用は [docs/neovim.md](../../docs/neovim.md) を参照してください。

## Origin

[AstroNvim/template](https://github.com/AstroNvim/template) の `main`（commit `49a7161`、2026-09-21 取得）を起点にしています。template の `README.md` はこのファイルに置き換え、それ以外のファイルは未編集のまま取り込みました。

AstroNvim 本体の version は `lua/lazy_setup.lua` の `version = "^6"` で追従範囲を固定しています。nightly に切り替える場合はこの行を外します。

## Layout

| ファイル | 役割 |
| --- | --- |
| `init.lua` | lazy.nvim の bootstrap。原則として編集しない |
| `lua/lazy_setup.lua` | AstroNvim 本体の version・leader key・lazy.nvim options |
| `lua/community.lua` | [astrocommunity](https://github.com/AstroNvim/astrocommunity) の pack 取り込み |
| `lua/plugins/` | plugin の追加と上書き（`astrocore`・`astrolsp`・`astroui`・`mason`・`none-ls`・`treesitter`・`user`） |
| `lua/plugins/mappings.lua` | 個人の key mapping（有効）。`x` を black hole register へ送り clipboard を上書きしない |
| `lua/polish.lua` | setup 最終段で走る素の Lua |
| `lazy-lock.json` | plugin の commit 固定。再現性のため Git 管理する |
| `.luarc.json`、`.neoconf.json`、`.stylua.toml`、`selene.toml`、`neovim.yml` | Lua LSP・formatter・linter の設定 |

`lua/community.lua`、`lua/plugins/user.lua`、`lua/polish.lua` は先頭の `if true then return ... end` で無効化されています。使うときはその行を削除します。

## Dependencies

| tool | 用途 | 現状 |
| --- | --- | --- |
| Neovim 0.11+ | 本体 | Homebrew の `neovim`（0.12.5） |
| git | plugin 取得 | 導入済み |
| ripgrep | 全文検索 | Homebrew の `ripgrep`（15.2.0） |
| fd | ファイル検索 | Homebrew の `fd` |
| tree-sitter-cli | parser build | Homebrew の `tree-sitter-cli` |
| lazygit | Git UI 連携 | 導入済み |
| Nerd Font | icon 表示 | terminal 側の設定。このリポジトリでは管理しない |

`gdu`（ディスク使用量）と `bottom`（プロセス表示）は AstroNvim の推奨に含まれますが、必要になるまで導入していません。Mason が install する LSP・formatter は `~/.local/share/nvim` 配下の生成物であり、Git 管理対象外です。

## Operations

```bash
./scripts/link.sh            # 配置予定の確認（dry run）
./scripts/link.sh --apply    # ~/.config/nvim の symlink を作成
nvim --headless "+Lazy! sync" +qa
```

`lazy-lock.json` は `:Lazy update` のたびに変化します。更新後は `git diff config/nvim/lazy-lock.json` で差分を確認してから commit します。secret、token、machine 固有の絶対 path は設定へ書かず、必要なら `local/` へ分離します。
