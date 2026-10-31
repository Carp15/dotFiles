# AI 開発ツール

Claude Code、Codex などの AI 開発ツールの設定を、どこで誰が管理するかの方針です。2026-11-01 の読み取り専用監査（Phase 4D-1）の結果を元にしています。この文書は方針の記録で、現時点では dotfiles はどの AI ツールの設定も管理していません（`chezmoi managed` に該当なし）。

記述の根拠を次の3つで区別します。

- **［実測］**: この Mac で確認した事実
- **［仕様］**: ツールの公式仕様。Codex は、CLI バイナリに含まれる設定キー名・文字列でも裏付けた
- **［未確認］**: 確認していないこと。推測で補わない

## 1. 目的と適用範囲

- 共通の指示と、再現できる非機密の設定だけを dotfiles から配布する。
- Skills・Agents の実体は dotfiles に持たない（配布元は APM）。
- 認証情報、実行時の状態、他のツールが書き換えるファイルは管理しない。

対象は macOS、WSL、Windows native の user-level 設定です。各 project の `AGENTS.md` / `CLAUDE.md` は、その repository の管理物で、この文書の対象外です。

## 2. 現在のツール構成

2026-11-01 時点の macOS ［実測］。

| ツール | 導入経路 | 状態 | 設定・状態の場所 |
| --- | --- | --- | --- |
| Claude Code | 公式 native installer（`~/.local/bin/claude`）。VS Code 拡張もある | 使用中 | `~/.claude/`、`~/.claude.json` |
| Codex CLI | Homebrew cask `codex`（[packages](packages.md)） | 使用中 | `~/.codex/` |
| Codex app | 既存の ChatGPT.app（[packages](packages.md#codex-appmacos)） | 使用中 | `~/.codex/`（CLI と共有） |
| APM（Agent Package Manager） | 手動（`/usr/local/bin/apm`。導入方法は未決定） | 使用中 | `~/.apm/`（`apm.yml`、`apm.lock.yaml`） |
| Antigravity CLI（`agy`） | 公式 installer | 導入済み | `~/.gemini/antigravity-cli/` |
| Orca、herdr | Homebrew cask・formula | 使用中 | Claude / Codex の Hooks に自分の hook を登録する |
| Gemini CLI、OpenCode | – | コマンドは未導入。`~/.gemini/`、`~/.config/opencode/` だけが残っている | – |
| `npx skills`（vercel skills CLI） | – | 過去に使った痕跡（`~/.agents/.skill-lock.json`、skills は空） | – |

Skills・Agents の配布元は、GitHub の `Carp15/my-agent-harness`（`~/.apm/apm.yml` の依存）です。`~/.apm/apm.lock.yaml` の解決済み commit は repository の HEAD より1つ古く、最新の Skill（`chezmoi-diff-apply`）は未配布です。

## 3. 管理責務の一覧

| 管理者 | 責務 | 例 |
| --- | --- | --- |
| dotfiles（chezmoi） | 共通指示と、再現できる非機密の設定の配布 | 将来の `~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`（下記 5） |
| my-agent-harness / APM | Skills・Agents の配布元 | `~/.agents/skills/*`、`~/.codex/agents/*.toml` の一部 |
| Claude Code | Claude 固有の設定と実行時状態 | `~/.claude/settings.json`、`~/.claude.json`、plugins |
| Codex | Codex 固有の設定と実行時状態 | `~/.codex/config.toml`、plugins、`rules/` |
| Orca / herdr | 自分が生成・更新する Hooks | Claude の `settings.json` の `hooks`、Codex の `hooks.json` |
| 各 project | project 固有の指示 | repository の `AGENTS.md`、`CLAUDE.md` |

## 4. Git 管理対象と除外対象

### 管理できる候補

| 分類 | 対象 | 状態 |
| --- | --- | --- |
| 共通設定 | 共通ルール（`~/.codex/AGENTS.md` の内容） | 未作成。現在 `~/.codex/AGENTS.md` は空、`~/.claude/CLAUDE.md` は無い |
| ツール固有設定 | `~/.claude/CLAUDE.md`（import だけの薄いファイル） | 未作成 |
| ツール固有設定 | `~/.apm/apm.yml`、`apm.lock.yaml`（宣言だけ） | 未管理 |
| ツール固有設定 | `~/.codex/full.config.toml`、`~/.claude/statusline-command.sh`、各ツールの `keybindings.json` | 未管理。管理するかは未決定（`full.config.toml` は下記 9 を参照） |
| ツール固有設定 | Claude の `settings.json` のうち、`language`、`statusLine` など一部のキー | 未管理。ファイル全体は管理しない（下記） |

### 管理しないもの

chezmoi の source state（`home/`）に入れません。`~/.claude/` や `~/.codex/` をディレクトリごと管理することもしません。

| 種類 | 例（値は記載しない） |
| --- | --- |
| 認証情報、API キー、OAuth トークン | `~/.codex/auth.json`、`~/.gemini/oauth_creds.json`、`google_accounts.json`、`~/.claude.json` の account 情報、MCP の認証ヘッダー |
| セッション、会話履歴、ログ、キャッシュ | `history.jsonl`、`~/.claude/projects/`、`~/.codex/sessions/`、`archived_sessions/`、`*.sqlite`、`file-history/`、`paste-cache/`、`memories/`、`cache/`、`log/` |
| Orca や herdr が動的に更新する Hooks | Claude の `settings.json` の `hooks`、`~/.codex/hooks.json` |
| Codex の信頼済み project 一覧 | `config.toml` の `[projects]`（`trust_level`）と `hooks.state`（信頼済み hash） |
| 自動生成される設定値や状態ファイル | `~/.claude.json`、`.codex-global-state.json`、`models_cache.json`、`installed_plugins.json`、`.skill-lock.json`、`tui.*` の表示状態、`*.bak` |
| アプリケーション内部の MCP 設定 | Codex app が書き込む `node_repl`、`computer-use` |
| 端末固有の絶対 path | `config.toml` の `desktop.*`、MCP の `command` / `env`、Hooks の script path |

**ファイル単位で丸ごと管理しない理由**: Claude の `settings.json` と Codex の `config.toml` は、ツール本体と Orca が実行中に書き換えます（hooks、信頼済み hash、project 一覧、モデル選択の表示状態など）［実測］。chezmoi で丸ごと管理すると `chezmoi apply` のたびに上書きし合い、Hooks の信頼も外れます。一部のキーだけを管理する場合は、chezmoi の `modify_` script などを別途検討します。

## 5. AGENTS.md / CLAUDE.md の設計候補

### 候補の構成（未作成）

| ファイル | 役割 |
| --- | --- |
| `~/.codex/AGENTS.md` | 全 project 共通のルールの基準 |
| `~/.claude/CLAUDE.md` | `@~/.codex/AGENTS.md` の1行で共通ルールを import する薄いファイル。Claude 固有の指示だけを追記する |
| 各 project の `AGENTS.md` | project 固有のルール |
| 各 project の `CLAUDE.md` | `@AGENTS.md` の1行（この repository と同じ形）。Claude 固有の指示だけを追記する |

共通ルールは全 project の挙動を変えるため、内容は個別に承認を得て決めます。Codex の読み込み量の上限と Claude の import の深さの上限があるため、短く保ちます。

### Claude Code の読み込み

- ［仕様］ user の `~/.claude/CLAUDE.md`、作業ディレクトリから親へさかのぼった各 `CLAUDE.md`、`CLAUDE.local.md` を読み込む。サブディレクトリの `CLAUDE.md` は、そのディレクトリのファイルを扱うときに読み込まれる。
- ［仕様］ `@path` で他のファイルを import できる。相対 path は import を書いたファイルからの相対で、`@~/...` は home からの path。import はネストできるが、深さに上限がある。
- ［実測］ この repository の `CLAUDE.md`（`@AGENTS.md` の1行）で、`AGENTS.md` の内容が読み込まれている。
- ［未確認］ `@~/.codex/AGENTS.md` のような home 起点の import の実際の動作。Windows で `~` が `%USERPROFILE%` に解決されるか。
- ［未確認］ Claude Code が `AGENTS.md` を import なしで直接読むか（`~/.claude.json` の利用記録に `agents-md@builtin` という項目があるが、仕様としては確認していない）。確実な方法として、`@AGENTS.md` か symlink を使う。

### Codex の読み込み

- ［仕様］ `~/.codex/AGENTS.md`（`AGENTS.override.md` があればそちら）を global として読み、次に Git の root から作業ディレクトリまでの各階層の `AGENTS.override.md` / `AGENTS.md` を順に連結する。合計は `project_doc_max_bytes` で制限される。`project_doc_fallback_filenames` で、`AGENTS.md` が無い階層の代替ファイル名（例: `CLAUDE.md`）を指定できる。
- ［実測］ CLI バイナリ（0.166.0）に `AGENTS.override.md`、`project_doc_max_bytes`、`project_doc_fallback_filenames` の文字列がある。現在の `config.toml` ではどちらも設定していない。
- ［未確認］ Windows での `CODEX_HOME` の既定値（`%USERPROFILE%\.codex` と想定）と、WSL と Windows で設定を共有しないこと（別の home なので共有しない想定）。

### 現在の project の状態［実測］

`~/ghq` 配下で、書き方が3通りに分かれています。dotfiles からは変更しません。

| 形 | 例 |
| --- | --- |
| `CLAUDE.md` が `@AGENTS.md` を import | この repository |
| `CLAUDE.md` が `AGENTS.md` への symlink | 1 repository |
| `CLAUDE.md` と `AGENTS.md` を別々に記述（重複） | 3 repositories |
| どちらか片方だけ | `AGENTS.md` だけが4、`CLAUDE.md` だけが1（もう一方のツールからは読まれない） |

## 6. Skills / Agents / Commands の管理方針

- **管理元は APM**（my-agent-harness）。dotfiles に Skills・Agents の実体をコピーしない。
- **既存の重複は削除しない**（片付けは、退避と個別承認を前提に後続フェーズで扱う）。

### Skills

| 場所 | 中身［実測］ | 読むツール |
| --- | --- | --- |
| `~/.agents/skills/` | APM が配布した9つ（実体） | Codex（`user-agent-skills` として）［仕様］ |
| `~/.claude/skills/` | 上記9つへの symlink、手動の `cc-notes`（実体）、アカウント同期の `synced/` | Claude Code |
| `~/.codex/skills/` | `.system/`（Codex 同梱）、`codex-primary-runtime`、APM と同名の5つ（commit、delegate-implementation、ios-device-install、plan、review。2026-05 の古いコピー） | Codex（`codex-home-skills` として）［仕様］ |

- ［実測］ `~/.codex/skills/` の5つのうち、commit と ios-device-install は `SKILL.md` の内容が `~/.agents/skills/` 版と異なる。
- ［未確認］ Codex が `~/.codex/skills` と `~/.agents/skills` の同名 Skill をどの順で解決するか。どちらが使われているかも確認していない。
- Claude 側は `~/.claude/skills/<name>` を `~/.agents/skills/<name>` への symlink にする運用を続ける（実体を置かない）。例外として `cc-notes` は APM 外の手動 Skill。

### Agents

| 場所 | 中身［実測］ |
| --- | --- |
| `~/.codex/agents/*.toml` | 14個。うち9つは APM が `.apm/agents/*.agent.md` から生成（2026-09）、5つは手動（2026-05） |
| `~/.claude/agents/*.md` | 14個（と README）。APM の配布対象外で、手動（2026-04）。名前は Codex 側と同じ |

Claude 側の手動 Agents と APM 配布 Agents（Codex 側）の内容の差は、後続フェーズで検討します。`~/.apm/config.json` の `default_client` は `vscode` です。

### Commands

`~/.claude/commands/` は無く、Skills に統一済みです［実測］。

### 共有方法の比較

| 方法 | 評価 |
| --- | --- |
| ネイティブ参照（APM → `~/.agents/skills`、Claude は symlink） | 現行。採用する |
| chezmoi で Skill の実体を複製・配置 | 正が APM と二重になるため採用しない |
| chezmoi で `~/.claude/skills/` の symlink を管理 | macOS / WSL は可能。Windows は symlink に Developer Mode が要る。Skill の追加ごとに dotfiles の変更が要る。保留 |

## 7. Hooks / Plugins / MCP の管理方針

### Hooks

Claude の `settings.json`（16 event）と Codex の `hooks.json`（9 event）の hook は、ほぼすべて Orca が登録したもので、ほかに herdr の SessionStart があります［実測］。生成元のアプリが管理するものとし、dotfiles では管理しません。Codex は hook ごとの信頼済み hash を `config.toml` の `hooks.state` に保存します［実測］。

### Plugins

- Claude: user scope は `swift-lsp` だけ。ほかは project / local scope。marketplace は4つ（GitHub）［実測］。
- Codex: `config.toml` の `[plugins]` で13個を有効化（openai-bundled、openai-curated など）［実測］。

どちらもツール本体の管理物とし、dotfiles では管理しません。

### MCP

現時点では共通化しません。名前と方式だけを記録します（接続テスト・起動はしていない）。

| 名前 | ツール | 方式 | 備考 |
| --- | --- | --- | --- |
| `openaiDeveloperDocs` | Codex | HTTP | 認証なし |
| `stitch` | Codex | HTTP | 認証ヘッダーの設定がある（値は記載しない） |
| `node_repl` | Codex | stdio | Codex app が管理。内部 path を含む環境変数 |
| `computer-use` | Codex | stdio | Codex app が管理 |

Claude Code にはローカルの MCP 設定がありません（`~/.claude.json`、project の `.mcp.json` のどちらにも無い）。claude.ai のコネクタはアカウント側の設定です。ツール間で重複する MCP はありません［実測］。

## 8. macOS / WSL / Windows への対応

| 項目 | macOS | WSL | Windows native |
| --- | --- | --- | --- |
| Claude Code | 導入済み（[packages](packages.md)） | bootstrap が公式 installer で導入 | bootstrap は導入しない |
| Codex CLI | Homebrew cask | bootstrap が公式 installer で導入 | bootstrap は導入しない |
| APM | 手動で導入済み | 導入手順なし［未確認］ | 導入手順なし［未確認］ |
| 設定の home | `~/.claude`、`~/.codex` | WSL 側の `~/.claude`、`~/.codex`（Windows と別） | `%USERPROFILE%\.claude`、`.codex`［未確認］ |
| 共通ルール（候補） | 配置可能 | 配置可能 | 配置可能。`@~/` の解決は［未確認］ |
| Skills の symlink | 現行どおり | 可能 | Developer Mode が要る |
| Orca / herdr の Hooks | 使用中 | 未使用 | bash 前提のため使えない |

- chezmoi で配置する場合、OS ごとの出し分けは `home/.chezmoiignore` と `.chezmoitemplates/platform`（[chezmoi](chezmoi.md)）で行います。
- bootstrap は、chezmoi の target のうち自分が使うものだけを確認します（[packages](packages.md)）。AI ツールの設定を `home/` に追加しても、bootstrap の判定は変わりません。`.chezmoiignore` を変更したら `tests/run.sh` で確認します。
- WSL・Windows の実機では、この文書の内容をまだ確認していません。

## 9. セキュリティと権限

- `danger-full-access` や承認の無効化（`approval_policy = "never"`）を共通のデフォルトにしない。現在の Codex の既定は `workspace-write` / `on-request` ［実測］。
- 権限の緩和は、用途を明示し、承認を得て使う。`~/.codex/full.config.toml`（`danger-full-access` + `never`）と shell の `codexf` alias（[shell](shell.md)）はこの扱いで、既定にはしない。`full.config.toml` を dotfiles で配布するかは未決定。
- Codex の `rules/default.rules`（allow の `prefix_rule` 14件）や Claude の `permissions` は、端末ごとの許可設定として管理しない。
- 機密情報の実値は、この文書・ログ・コマンド出力に記載しない。存在とキー名だけを扱う。
- MCP 設定は現時点では共通化しない（上記 7）。

## 10. 既知の問題と未確認事項

- **Codex の Skills の重複**: `~/.codex/skills/` に APM と同名の古いコピーが5つある。解決順序は［未確認］。削除はしていない。
- **APM の配布が古い**: lock は my-agent-harness の HEAD より1つ前で、`chezmoi-diff-apply` が未配布。
- **Claude の Agents が手動**: `~/.claude/agents/` は APM の配布対象外で、Codex 側の APM 版と内容が揃っているかは未比較。
- **グローバル指示が無い**: `~/.claude/CLAUDE.md` は無く、`~/.codex/AGENTS.md` は空。
- **herdr の hook script**: Claude 用と Codex 用で内容が異なる（管理対象外。記録のみ）。
- **未導入ツールの残骸**: `~/.gemini/`（認証ファイルを含む）、`~/.config/opencode/`。扱いは未決定。
- **［未確認］** Claude Code の `@~/` import の動作と Windows でのパス解決、Claude Code が `AGENTS.md` を直接読むか、Codex の同名 Skill の解決順序、Windows の `CODEX_HOME` の既定値、WSL・Windows での APM。

## 11. Phase 4D-2b 以降の作業候補

それぞれ個別に承認を得てから行います。

1. 共通ルールの内容を決め、`home/dot_codex/AGENTS.md` と `home/dot_claude/CLAUDE.md`（import だけ）を chezmoi で配置する。`@~/` の動作を macOS で確認し、Windows に配置するかを決める。
2. `~/.codex/skills/` の重複5つを退避してから片付け、Codex の参照を `~/.agents/skills` に揃える。
3. `apm install` で my-agent-harness の最新版を配布する。
4. Claude の手動 Agents と APM 配布 Agents の差を比較し、Claude 側も APM で配布するかを決める。
5. `~/.apm/apm.yml` / `apm.lock.yaml` と APM 本体の導入方法（[packages](packages.md) の保留事項）を決める。
6. `full.config.toml`、statusline、keybindings を配布するか決める。
7. Claude の `settings.json` の一部のキーを `modify_` で管理するか決める。
