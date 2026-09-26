# Neovim (AstroNvim)

leader は `Space`、localleader は `,` です。leader を押すと which-key が候補を表示するので、迷ったら `Space` だけ押します。

## 起動と管理

```bash
nvim                                # 起動
nvim --headless "+Lazy! sync" +qa   # plugin を設定どおりに同期
nvim --headless "+Lazy! restore" +qa # lazy-lock.json の commit へ戻す
```

| 操作 | コマンド |
| --- | --- |
| plugin 管理 UI | `:Lazy` |
| plugin 更新（lock が変わる） | `:Lazy update` |
| LSP・formatter 管理 UI | `:Mason` |
| LSP の状態確認 | `:LspInfo` |
| 設定の健全性確認 | `:checkhealth` |

## よく使うキー

| キー | 動作 |
| --- | --- |
| `Space f f` | ファイル検索 |
| `Space f w` | 全文検索（ripgrep） |
| `Space f o` | 最近開いたファイル |
| `Space e` | file explorer の開閉 |
| `Space c` | buffer を閉じる |
| `Space w` | 保存 |
| `Space q` | 終了 |
| `Space g g` | lazygit |
| `Space t f` | 浮動 terminal |
| `Space l a` | code action |
| `Space l r` | rename |
| `Space l f` | format |
| `g d` / `g D` / `g I` | 定義 / 宣言 / 実装へ移動 |
| `Space l R` | 参照一覧 |
| `Space l D` | diagnostics 一覧 |
| `Space l s` | symbol outline |
| `x` | 1文字 / 選択範囲を削除（clipboard・レジスタに入れない。個人設定） |
| `[ b` / `] b` | buffer を前後へ |

## 設定を変更する

設定の実体は `config/nvim/` で、`~/.config/nvim` はその symlink です。どちらを編集しても同じファイルなので、変更後は repository で `git diff` を確認します。

- plugin の追加・上書き: `config/nvim/lua/plugins/user.lua`（先頭の `if true then return {} end` を削除して有効化）
- astrocommunity の pack: `config/nvim/lua/community.lua`（同上）
- option と keymap: `config/nvim/lua/plugins/astrocore.lua`

背景と管理方針は [docs/neovim.md](../docs/neovim.md) を参照してください。
