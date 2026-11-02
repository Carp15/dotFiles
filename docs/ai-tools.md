# AI 開発ツール

Claude Code、Codex などの AI 開発ツールの設定を、どこで誰が管理するかの方針です。2026-11-01 の読み取り専用監査（Phase 4D-1）の結果を元にしています。dotfiles が管理するのは、共通の AI 指示（`~/.codex/AGENTS.md` と `~/.claude/CLAUDE.md`、下記 5）と、Claude Code 用の Skills の symlink の宣言（`~/.claude/skills/<name>`、下記 6）だけです。source state（`home/dot_codex/AGENTS.md`、`home/dot_claude/CLAUDE.md`）から、macOS 実機で `chezmoi apply` しました（2026-11-01、Phase 4D-2b-3）。Codex・Claude Code の両方で読み込みを確認しています（下記 5）。Skills の symlink は、既存の live の symlink とリンク先が完全に一致する形で宣言したので（2026-11-03、Phase 4D-2c-9c）、`chezmoi apply` はしていません。WSL・Windows の実機では未検証です。

記述の根拠を次の5つで区別します。

- **［実測］**: この Mac で確認した事実。Codex は、HOME と `CODEX_HOME` を一時ディレクトリにし、network を遮断した sandbox で `codex debug prompt-input`（model に渡す入力を表示するだけで、model は呼ばない）を実行して確認した。認証ファイルは使っていない。ただし、共通指示の適用後の検証（下記 5）と、Skills・APM の整理（Phase 4D-2c、下記 6）は、実際の `~/.codex` で `codex debug prompt-input` を実行して確認した
- **［バイナリ］**: インストール済み CLI（Claude Code 2.1.316、Codex 0.166.0、APM 0.14.2）に含まれる文字列・コードの読解。実行での確認ではない
- **［仕様］**: ツールの公式ドキュメント、または CLI の `--help`
- **［推定］**: 実測や仕様からの推測。事実としては扱わない
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
| APM（Agent Package Manager） | 手動（`/usr/local/bin/apm`、0.14.2。導入方法は未決定） | 使用中 | `~/.apm/`（`apm.yml`、`apm.lock.yaml`、`apm_modules/`） |
| Antigravity CLI（`agy`） | 公式 installer | 導入済み | `~/.gemini/antigravity-cli/` |
| Orca、herdr | Homebrew cask・formula | 使用中 | Claude / Codex の Hooks に自分の hook を登録する |
| Gemini CLI、OpenCode | – | コマンドは未導入。`~/.gemini/`、`~/.config/opencode/` だけが残っている | – |
| `npx skills`（vercel skills CLI） | – | 過去に使った痕跡（`~/.agents/.skill-lock.json`、skills は空） | – |

Skills・Agents の配布元は、GitHub の `Carp15/my-agent-harness`（`~/.apm/apm.yml` の依存）です。2026-11-01 に macOS 実機で APM 0.14.2 を使って更新し（Phase 4D-2c-4b）、依存を完全な SHA `ba6934c2cd514c8b043fa69e9ca1957cade69a33` に固定しました。`apm.yml` の依存、lock の `resolved_commit`、`apm_modules` の pin と中身、配布済みの Skills 10件・Codex Agents 9件は、すべてこの commit と一致しています［実測］。手順は下記 6 の「APM の更新手順」を参照してください。

## 3. 管理責務の一覧

| 管理者 | 責務 | 例 |
| --- | --- | --- |
| dotfiles（chezmoi） | 共通指示と、再現できる非機密の設定の配布 | `~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`（下記 5。macOS は適用済み）、`~/.claude/skills/<name>` の symlink 10件の宣言（下記 6） |
| my-agent-harness / APM | Skills と一部の Agents の配布元 | `~/.agents/skills/*`（10件）、`~/.codex/agents/*.toml` のうち9件 |
| 手動（ユーザー） | どの manager も管理していないもの | `~/.claude/agents/`、`~/.codex/agents/` の APM 管理外5件（下記 6） |
| Claude Code | Claude 固有の設定と実行時状態 | `~/.claude/settings.json`、`~/.claude.json`、plugins |
| Codex | Codex 固有の設定と実行時状態 | `~/.codex/config.toml`、plugins、`rules/` |
| Orca / herdr | 自分が生成・更新する Hooks | Claude の `settings.json` の `hooks`、Codex の `hooks.json` |
| 各 project | project 固有の指示 | repository の `AGENTS.md`、`CLAUDE.md` |

## 4. Git 管理対象と除外対象

### 管理できる候補

| 分類 | 対象 | 状態 |
| --- | --- | --- |
| 共通設定 | 共通ルール（`~/.codex/AGENTS.md`） | source state は `home/dot_codex/AGENTS.md`。macOS の live は適用済み |
| ツール固有設定 | `~/.claude/CLAUDE.md`（import だけの薄いファイル） | source state は `home/dot_claude/CLAUDE.md`。macOS の live は適用済み |
| ツール固有設定 | `~/.apm/apm.yml`、`apm.lock.yaml`（宣言だけ） | chezmoi の管理外。live の `apm.yml` で harness の commit を固定している（下記 6） |
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

## 5. AGENTS.md / CLAUDE.md の構成

### 採用した構成（方式 A、2026-11-01）

| ファイル | source state | 役割 |
| --- | --- | --- |
| `~/.codex/AGENTS.md` | `home/dot_codex/AGENTS.md` | 全 project 共通のルールの基準。Codex がそのまま読む |
| `~/.claude/CLAUDE.md` | `home/dot_claude/CLAUDE.md` | `@~/.codex/AGENTS.md` の1行だけ。Claude 固有の指示が必要になったら、この下に追記する |
| 各 project の `AGENTS.md` | 各 repository | project 固有のルール |
| 各 project の `CLAUDE.md` | 各 repository | `@AGENTS.md` の1行（この repository と同じ形）など |

共通ルールは全 project の Claude / Codex の挙動を変えるため、内容は個別に承認を得て決め、短く保ちます。共通ルール自体に「project 固有の指示を尊重する（安全上の制約は維持する）」と書いています。

`dot_codex/` と `dot_claude/` は `exact_` を付けない通常のディレクトリで、chezmoi はこの2ファイルと、`~/.claude/skills/` の下の宣言した symlink（下記 6）だけを管理します。`~/.codex/` と `~/.claude/` のほかのファイル（認証、設定、セッション、Skills の実体、`cc-notes`、`synced/` など）には触れません。

### 方式を選んだ理由

| 方式 | 評価 |
| --- | --- |
| **A. `~/.codex/AGENTS.md` を基準にし、Claude は import する（採用）** | Codex がそのまま読む場所で、読み込みを実測で確認できた。正のファイルが1つで、template が要らない。Claude の `@~/` import も macOS 実機で読み込みを確認した（下記） |
| B. `~/.agents/AGENTS.md` などツール非依存の場所を基準にする | Codex は `~/.agents/AGENTS.md` を読まず、`AGENTS.md` の中の `@` import も展開しない［実測］。symlink かコピーが必要になり、Windows では symlink に Developer Mode が要る。`~/.agents/` は APM なども使うため、管理者が混ざる |
| C. 各ツールに同一内容を配置する | 読み込みは両ツールとも確実で、Windows も配置だけで済む。repository では `.chezmoitemplates` の共通原本から2ファイルを生成すれば正は1つだが、template が増え、live で片方だけ直すとずれる |

Windows で `~/` が解決されない場合や、ほかの環境で Claude の import が効かない場合は、C（共通原本から2ファイルを生成）に切り替えます。

### macOS 実機での適用と検証（2026-11-01、Phase 4D-2b-3）

- `chezmoi apply ~/.codex/AGENTS.md ~/.claude/CLAUDE.md` で、この2ファイルだけを適用した（chezmoi 2.73.3。事前に `--dry-run --verbose` で対象が2つだけと確認）。live の2ファイルは source state と完全一致し、適用後の `chezmoi status`・`chezmoi diff` は空、`scripts/doctor.sh` は 0 errors / 0 warnings。
- ［実測］ Codex CLI 0.166.0 の `codex debug prompt-input`（model は呼ばない）で、Git の外と、この repository の中の両方で、global の `AGENTS.md` の全文が入り、ルールは 9/9 行とも含まれていた。repository の中では、global の後に `--- project-doc ---` で repository の `AGENTS.md` が続く。
- ［実測］ Claude Code の新しい session で、`/memory` に User instructions として `~/.claude/CLAUDE.md`、その import 先として `.codex/AGENTS.md` が表示された。`/context` の Memory files は 2 files / 419 tokens。これをもって、Claude Code の import は確認済みとする（ユーザーが確認）。
- ［未確認］ Claude Code が展開した全文と source の直接比較（byte 単位の一致）は行っていない。
- ［未確認］ live で `codex debug prompt-input` を実行した後、`~/.codex` の状態ファイル・キャッシュ（sqlite の WAL/SHM、`models_cache.json`、`cache/codex_apps_*`）が更新されていた。このコマンドによるものか、起動中の Codex app によるものか、通信を伴ったかは確認していない。

### Codex の読み込み

隔離環境の `codex debug prompt-input` で確認しました（Codex 0.166.0）。

- ［実測］ global の `$CODEX_HOME/AGENTS.md`（既定は `~/.codex`）を最初に読み、続けて Git の root から作業ディレクトリまでの各階層の `AGENTS.md` を `--- project-doc ---` の区切りで連結する。どれも上書きされず、すべて model に渡る。
- ［実測］ `AGENTS.override.md` があると、その階層では `AGENTS.md` の代わりにそれだけを読む（global で確認）。
- ［実測］ 空の `AGENTS.md` は無視される（適用前の live の `~/.codex/AGENTS.md` は 0 byte で、何も読み込まれていなかった）。
- ［実測］ Git の外では、作業ディレクトリの `AGENTS.md` だけを読み、親はさかのぼらない。
- ［実測］ `project_doc_max_bytes` は project の指示だけを制限し（超えた分は切り捨て）、global は数えない。既定値 32 KiB は［仕様］。
- ［実測］ `project_doc_fallback_filenames = ["CLAUDE.md"]` を設定すると、`AGENTS.md` が無い階層の `CLAUDE.md` も読む。現在の `config.toml` では設定していない。
- ［実測］ `AGENTS.md` の中の `@path` は展開されない（文字列のまま渡る）。
- ［実測］ `CODEX_HOME` を変えると、global の指示も `$CODEX_HOME/AGENTS.md` に変わる。Skills・設定・認証の場所も同時に変わる［仕様］。
- ［未確認］ Windows の `CODEX_HOME` の既定値（`%USERPROFILE%\.codex` と想定）。WSL と Windows は別の home なので、設定は共有しない想定。

### Claude Code の読み込み

- ［仕様・バイナリ］ user の `<config dir>/CLAUDE.md`（既定は `~/.claude`、`CLAUDE_CONFIG_DIR` で変わる）、作業ディレクトリから親へさかのぼった各 `CLAUDE.md`、`.claude/CLAUDE.md`、`CLAUDE.local.md` を読み込む。
- ［バイナリ］ import は `@path` の形で、`./`、`~/`、`/` で始まる path と相対 path を受け付け、import を書いたファイルからの相対で解決する。code block、code span、HTML comment の中は無視する。`@~/...` の例は公式 docs にもある［仕様］。ネストの深さには上限がある（5段）［仕様］。
- ［バイナリ］ project の外のファイルを import するときの承認（project ごとの `hasClaudeMdExternalIncludesApproved`）は、user 以外の指示ファイルの import に適用される。`~/.claude/CLAUDE.md` からの import は対象外と読める。
- ［バイナリ］ Claude Code 2.1.316 には `instructionFiles` 設定があり、既定（`claude-md-or-agents-md`）では、`CLAUDE.md` が無い project で `AGENTS.md`（と `.claude/AGENTS.md`）を代わりに読む。ほかに `claude-md`、`claude-md-and-agents-md`、`managed-only` がある。公式 docs では未確認。
- ［実測］ この repository の `CLAUDE.md`（`@AGENTS.md` の1行）で、`AGENTS.md` の内容が読み込まれている。
- ［実測］ `~/.claude/CLAUDE.md` の `@~/.codex/AGENTS.md` は macOS で読み込まれる（上記の `/memory`・`/context`）。
- ［未確認］ import に失敗したときにエラーになるか、黙って読み飛ばされるか。
- ［未確認］ Windows で `~/` が `%USERPROFILE%` に解決されるか。

### 現在の project の状態［実測］

`~/ghq` 配下で、書き方が分かれています。dotfiles からは変更しません。

| 形 | 例 |
| --- | --- |
| `CLAUDE.md` が `@AGENTS.md` を import | この repository |
| `CLAUDE.md` が `AGENTS.md` への symlink | 1 repository |
| `CLAUDE.md` と `AGENTS.md` を別々に記述（重複） | 3 repositories |
| `AGENTS.md` だけ | 4 repositories。Claude Code も `instructionFiles` の既定で `AGENTS.md` を読む可能性がある［バイナリ］ |
| `CLAUDE.md` だけ | 1 repository。Codex は `project_doc_fallback_filenames` を設定しない限り読まない［実測］ |

## 6. Skills / Agents / Commands の管理方針

- **管理元は APM**（my-agent-harness）。dotfiles に Skills・Agents の実体をコピーしない。
- **重複は削除せずに退避する**。見つけた重複は、内容を比較し、退避先と復元手順を記録したうえで、個別に承認を得て Skills の探索 path の外へ移す。

ここに書いた件数と状態は、2026-11-01 の macOS の［実測］です（Phase 4D-2c）。WSL・Windows では確認していません。

### Skills

| 場所 | 中身［実測］ | 読むツール |
| --- | --- | --- |
| `~/.agents/skills/` | APM が配布した10件（実体）。chezmoi-diff-apply、commit、delegate-codex-implementation、delegate-implementation、harness-doctor、ios-device-install、manage-dotfiles、plan、refine-requirements、review | Codex（`user-agent-skills` として）［仕様］ |
| `~/.claude/skills/` | 上記10件への symlink（chezmoi で宣言。下記「Claude Code への公開」）。ほかに、APM 外の手動 Skill `cc-notes`（実体）と、アカウント同期の `synced/` | Claude Code |
| `~/.codex/skills/` | `.system/`（Codex 同梱）と `codex-primary-runtime` だけ | Codex（`codex-home-skills` として）［仕様］ |

- ［実測］ Codex は、`~/.codex/skills` と `~/.agents/skills` に同名の Skill があると、重複を除かずに両方を Skill 一覧に載せる。そのため、`~/.codex/skills` には Skill を置かない。
- ［実測］ 2026-11-01 に、`~/.codex/skills` に残っていた APM と同名の古いコピー（2026-05）5件を、Skills の探索 path の外へ退避した。**削除はしていない**。
  - delegate-implementation、plan、review は、APM 版と内容・権限まで完全に一致していた（Phase 4D-2c-5）。
  - commit と ios-device-install は内容が異なっていた。commit は常に `Co-Authored-By` を付ける旧手順、ios-device-install は `~/.codex/skills` の絶対 path を使う旧手順で、どちらも APM 版を正とした（Phase 4D-2c-6b）。script は同一だった。
  - 退避先と復元手順は、`~/.local/state/dotfiles/backup/phase-4d-2c-5/*/README.txt` と `~/.local/state/dotfiles/backup/phase-4d-2c-6b/20261101T213946/README.txt`。同じ階層の `20261101T213912/` は、script の誤りで中断したときの空の記録で、退避したデータは入っていない（`ABORTED.txt`）。
- ［実測］ 退避後の Codex の Skill 一覧は21件で、名前の重複は0件。APM 管理の10件は、どれも `~/.agents/skills` から1回だけ読み込まれている。
- 重複の確認には `codex debug prompt-input` の出力を使う。Skill の path は `r0` などの別名で表示され、番号は一覧の内容で変わるので、比較するときは別名を絶対 path に展開してから比べる。

### Claude Code への公開

`~/.claude/skills/<name>` を `~/.agents/skills/<name>` への symlink にして、Claude Code から APM 管理の Skills を使っています。形式は絶対 path（`/Users/<user>/.agents/skills/<name>`、末尾の `/` なし）です［実測］。2026-11-03 から、この symlink は **chezmoi の `symlink_` で宣言して管理**しています（下記「chezmoi による宣言管理」）。live の10件はもともと `ln -s` で手動で作ったもので、宣言とリンク先が完全に一致するため、作り直していません。APM は Claude 側に何も配置しません。

- APM が Skill を追加しても、Claude 側の symlink は自動では作られない（dotfiles に宣言を足す）。
- APM が Skill を消したり名前を変えたりすると、Claude 側の symlink はリンク切れのまま残る（chezmoi は消さない）。
- `cc-notes` と `synced/` は APM 外の既存のディレクトリとして残し、自動で削除・移動しない。下記の確認は symlink だけを対象にし、この2つには触れない。

整合性の確認（読み取りだけ。macOS の bash と zsh で動作を確認）:

```sh
# 1. 名前の一致: APM 管理の Skill と、Claude 側の symlink の名前の差を表示する（何も出なければ一致）
comm -3 <(ls ~/.agents/skills) <(find ~/.claude/skills -maxdepth 1 -type l -exec basename {} \; | sort)

# 2. リンク切れ: リンク先が存在しない symlink を表示する
find ~/.claude/skills -maxdepth 1 -type l ! -exec test -e {} \; -print

# 3. リンク先: ~/.agents/skills/<同じ名前> 以外を指している symlink を表示する
find ~/.claude/skills -maxdepth 1 -type l -exec sh -c \
  't=$(readlink "$1"); [ "$t" = "$HOME/.agents/skills/${1##*/}" ] || echo "unexpected: $1 -> $t"' _ {} \;
```

1 は名前だけを比べるので、同じ名前で別の場所を指す symlink は 3 で見つけます。

**Skill を追加したとき**（APM の配布後。dotfiles の変更と live の変更は、それぞれ承認を得てから行う）:

1. `~/.agents/skills/<name>/SKILL.md` があり、`~/.apm/apm.lock.yaml` の `deployed_files` に `.agents/skills/<name>` があることを確かめる。
2. `~/.claude/skills/<name>` に、ファイル・ディレクトリ・symlink のどれも無いことを確かめる。**実ディレクトリや実ファイルがあれば止める**（apply すると中身ごと symlink に置き換わる。下記）。
3. `home/dot_claude/skills/symlink_<name>.tmpl` を作り、中身を `{{ .chezmoi.homeDir }}/.agents/skills/<name>` の1行だけにする。
4. `chezmoi status ~/.claude/skills` に `A <name>` だけが出ること、`chezmoi apply --dry-run --verbose ~/.claude/skills` に想定外の削除・置き換えが無いことを確かめる。
5. 承認を得てから、`chezmoi apply ~/.claude/skills/<name>` で作る（または従来どおり `ln -s "$HOME/.agents/skills/<name>" "$HOME/.claude/skills/<name>"`。`-f` は付けない）。
6. `chezmoi status ~/.claude/skills` が空になり、上の確認 1〜3 と `scripts/doctor.sh` で問題が無いこと、`~/.claude/skills/<name>/SKILL.md` を symlink 経由で読めることを確かめる。

**Skill を削除・改名したとき**（承認を得てから行う）:

1. APM の lock にその Skill が無く、`~/.agents/skills/<name>` が本当に無くなっていることを確かめる。この時点で、chezmoi は `.chezmoiignore` の条件で宣言を除外し、live の symlink はリンク切れのまま残る（doctor が warn を出す）。
2. `home/dot_claude/skills/symlink_<name>.tmpl` を削除する。
3. live の symlink を消す。対象が symlink であること（`[ -L ~/.claude/skills/<name> ]`）とリンク先を確かめてから、symlink だけを消す（`rm ~/.claude/skills/<name>`。`-r` や末尾の `/` は付けない）。実体のディレクトリ、`cc-notes`、`synced/` には触れない。
4. 改名の場合は、新しい名前で「追加したとき」の手順を行う。

#### doctor による整合性確認（実装済み、2026-11-01）

`scripts/doctor.sh` の「AI tools (APM skills for Claude Code)」節が、上記の確認 1〜3 と `SKILL.md` の有無を読み取り専用で行います。目的は、APM 管理の Skills と Claude 用 symlink のずれを早く見つけることで、**修復はしません**（symlink の作成・修復・削除、`apm` の実行、`SKILL.md` の内容の読み取りは行わない）。

- **対象**: `~/.apm/apm.lock.yaml` の `deployed_files` にある `.agents/skills/<name>` だけを APM 管理の Skill とみなす（`~/.agents/skills` の全件ではない。ほかのツールも同じ場所を使うため）。Claude 側は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/<name>`。
- **lock の読み方**: APM 0.14.2 の lock の形式（`lockfile_version: '1'`、`dependencies:`、各依存の `  deployed_files:` の `  - <path>`）だけを行単位で読む。YAML を完全に解析するものではない。形式が違う lock は、0件として扱わず warn にする。
- **warn**（exit code には影響しない。この節は error を出さない）:
  - lock が読めない、または形式が分からない
  - lock にある Skill の実体（`~/.agents/skills/<name>`）が無い、`SKILL.md` が無い・読めない
  - Claude 側の symlink が無い、リンク切れ、`~/.agents/skills/<name>` 以外を指している（同名の実ディレクトリがある場合も含む）
  - lock に無い symlink のうち、リンク切れで、リンク先の文字列が `~/.agents/skills/` の下を指しているもの（Skill の削除後に残った symlink の可能性）
  - `~/.claude` はあるが `skills/` が無い、`CLAUDE_CONFIG_DIR` が絶対 path でない、またはディレクトリでない
- **skip**（warn なし）: lock が無い（APM 未導入）、lock に Skill が無い、Claude Code の設定ディレクトリが無い（このときも APM 側の実体と `SKILL.md` は確認する）、Windows（Git Bash）。
- **管理外**: `cc-notes`、`synced/`、lock に無い symlink（リンク先が別の場所、またはリンク切れで判断できないもの）、`~/.agents/skills` にあって lock に無い Skill は、名前を一覧に表示するだけで変更しない。
- **対応 OS**: macOS は実機で確認済み（10件すべて ok、doctor 全体で 0 errors / 0 warnings）。WSL・Linux は同じコード（bash 3.2 以降、`cd -P` と `pwd -P` でリンク先を比較）で動く想定だが、実機では未検証。Windows native（`doctor.ps1`）は対象外。

warn が出たら、上記の「Skill を追加したとき」「Skill を削除・改名したとき」の手順で、承認を得てから直します。

#### chezmoi による宣言管理（B2 方式、2026-11-03）

chezmoi 2.73.3 の隔離環境での検証（Phase 4D-2c-9b。偽の HOME、network 遮断、書き込みは一時ディレクトリだけ）で方式を比べ、条件付きで宣言する **B2** を採用しました（Phase 4D-2c-9c）。

**宣言**: APM の lock の `deployed_files` にある10件について、`home/dot_claude/skills/symlink_<name>.tmpl` を1つずつ置いています。中身は固定の1行だけです。

```text
{{ .chezmoi.homeDir }}/.agents/skills/<name>
```

- 末尾の改行は取り除かれ、リンク先は `<home>/.agents/skills/<name>` になる［実測］。
- ユーザーの絶対 path を書かない、`if` を入れない、空を返す条件を作らない、`exact_` を使わない、lock に無い Skill を宣言しない。

**B2 の条件付き除外**: `home/.chezmoiignore` の末尾で、宣言した `symlink_*.tmpl` の名前ごとに `~/.agents/skills/<name>` の有無を `stat` で調べ、無ければ `.claude/skills/<name>` を除外します。対象は宣言した名前だけなので、`cc-notes`、`synced/`、`.DS_Store` は管理対象になりません。

| 状態 | chezmoi の動き［実測、隔離環境］ |
| --- | --- |
| 正常（10件がそろっている） | 差分なし。apply しても何も変わらない |
| symlink が無い | `status` に `A`。apply で作る |
| リンク先が違う、リンク切れ（文字列が違う） | `status` に `M`。apply で張り替える |
| APM が入っていない（`~/.agents/skills` が無い） | 除外されるので何もしない（固定で宣言する B1 は、リンク切れの symlink を10件作る） |
| APM が Skill を削除した | 除外されるので、残った symlink を消さない（doctor が warn） |
| APM が Skill を追加した | 何もしない（宣言を足すまで。doctor が warn） |

**危険（すべて隔離環境で実測）**:

- 宣言した場所に**実ディレクトリ**があると、`chezmoi apply` は**中身ごと削除して symlink に置き換える**。`--no-tty` では確認も出ない（TTY があるときに確認が出るかは［未確認］）。apply の前に、宣言先がすべて symlink か空であることを確かめる。doctor の「exists but is not a symlink」の warn でも分かる。
- テンプレートの展開結果が**空、または空白だけ**だと、`status` に `D` が出て、apply は**その場所の symlink や実ディレクトリを削除する**。そのため、テンプレートには条件分岐を入れない。
- `exact_skills` にすると、`cc-notes`、`synced/`、`.DS_Store` が削除される。使わない。

**確認のしかた**: `chezmoi diff ~/.claude/skills` のようにディレクトリを指定した `diff` は、`-r` を付けても中の symlink の差分を表示しない［実測］。`status` が `A`・`M` を出していても空になるので、これだけで正常と判断しない。次を使う。

```sh
chezmoi status ~/.claude/skills                   # 空なら一致
chezmoi apply --dry-run --verbose ~/.claude/skills  # 何も出なければ変更予定なし
chezmoi diff                                      # 引数なし（または対象の symlink を1つずつ指定）
chezmoi verify ~/.claude/skills                   # 一致しなければ exit code 1
```

**macOS 実機の状態（2026-11-03）**［実測］: `chezmoi managed` に10件が出て、`chezmoi status`、引数なしの `chezmoi diff`、`chezmoi apply --dry-run --verbose`（全体と `~/.claude/skills`）はすべて空、`chezmoi verify` は exit code 0。`chezmoi apply` はしていない。宣言の前に、10件の symlink をリンクをたどらずにバックアップした（`~/.local/state/dotfiles/backup/phase-4d-2c-9c/20261103T001729/`、README に復元手順）。

**doctor との役割分担**:

| | chezmoi | `scripts/doctor.sh` |
| --- | --- | --- |
| 基準 | dotfiles の宣言（`symlink_*.tmpl`） | APM の lock（`deployed_files`） |
| すること | 宣言した symlink を作る・張り替える（人が apply したとき） | lock と symlink のずれを warn で知らせるだけ |
| 見つけられるもの | 宣言と live の差 | lock にあって宣言・symlink が無い Skill、リンク切れの残り、実ディレクトリ、`SKILL.md` の欠落 |

chezmoi は lock を読まないので、APM 側の追加・削除は doctor で見つけ、上記の手順で宣言を直します。

**OS ごとの状態**:

- macOS: 上記のとおり。
- WSL: 同じ source を使う。偽の `uname` と WSL2 の情報を与えた隔離環境では macOS と同じ動きだった［実測］。実機は未検証。B2 なので、APM を入れる前は何も配置されず、APM の配布後に `chezmoi apply ~/.claude/skills` で作る。
- Windows native: 既存の `home/.chezmoiignore` で `.claude` を丸ごと除外しているので、何も配置しない［実測、データの上書き］。

**回帰テスト**（`tests/chezmoi-skills.test.sh`、`tests/run.sh` に含まれる）: Skill の宣言や `.chezmoiignore` を変えたら `tests/run.sh` を実行します。3層で確認します。

- 静的検査（chezmoi が無くても実行）: `dot_claude/skills/` に `symlink_<name>.tmpl` 以外が無いこと、各テンプレートが固定の1行（`{{ .chezmoi.homeDir }}/.agents/skills/<ファイル名と同じ name>`）であること、name が `[a-z0-9][a-z0-9-]*` で `cc-notes`・`synced` でないこと、`dot_claude` の下に `exact_` や `skills/` 以外の `symlink_` が無いこと、B2 の除外と Windows の `.claude` の除外が `.chezmoiignore` に残っていること。
- 挙動テスト（chezmoi 2.73.3 の実測が基準）: 作業ツリーの source のコピーと隔離 HOME で、正常（10件の inode も不変）、APM なし（symlink は作らない。空の `~/.claude/skills` ディレクトリは作られる）、APM だけにある Skill、APM が消した Skill（残った symlink は消さない）、一部だけある Skill、Windows、WSL、リンク先の違い、リンク切れ、実ディレクトリ・通常ファイルの置き換え（危険な挙動を固定して確認）を、`status`、引数なしの `diff`、`verify`、`apply --dry-run --verbose` と隔離 HOME での `apply` で確かめる。`cc-notes`、`synced/`、`.DS_Store`、管理外の symlink が変わらないことも確かめる。`chezmoi diff <ディレクトリ>` が symlink の差分を出さないことも固定している。
- メタテスト: source のコピーをわざと壊し（空・空白だけのテンプレート、`exact_`、`if`、絶対 path、name の不一致、2行、`cc-notes` の宣言、B2 の削除など）、静的検査または挙動テストが失敗することを確かめる。
- 隔離: chezmoi の source・HOME・destination・config・state・cache・作業ディレクトリは、symlink を解決した実体 path で `$TEST_TMP/skills` の下にあることを確かめてから実行し、外れていれば実行せずに FAIL にする（live の HOME、`~/.claude`、`~/.agents`、`~/.apm`、`~/.codex`、chezmoi の設定は拒否）。live の APM lock は読まない。macOS ではさらに `tests/run.sh` の `sandbox-exec`（network 禁止、一時ディレクトリの外への書き込み禁止）の中で動く。
- chezmoi を更新して挙動のテストが失敗したら、期待値を緩めずに、上記の「危険」と「確認のしかた」を確かめ直してから直す。

**ロールバック**: 宣言を追加した commit を revert します。source から宣言が消えても、chezmoi は live の symlink を消さず、管理外になるだけです［仕様］（`exact_` を使っていないため）。live の symlink を失ったときは、上記のバックアップの README の手順（`tar -xpkf` で既存を上書きせずに展開し、`links.manifest` と照合）で戻します。

### Agents

| 場所 | 中身［実測］ |
| --- | --- |
| `~/.codex/agents/*.toml` | 14件。APM 管理の9件（api-designer、architect、code-reviewer、db-reviewer、feature-planner、planner、release-checker、security-checker、system-designer。`.apm/agents/*.agent.md` から生成）と、APM 管理外の手動の5件（debug-assistant、diagram-generator、doc-generator、e2e-tester、test-generator。2026-05） |
| `~/.claude/agents/*.md` | 14件（と README）。APM の配布対象外で、手動（2026-04）。名前は Codex 側の14件と同じ |

Agents の内容の統一（Claude 側の手動 Agents と Codex 側の APM 版の比較、管理外5件の扱い）は、まだ行っていません。`~/.apm/config.json` の `default_client` は `vscode` です。

### APM の更新手順（APM 0.14.2、macOS で実証）

2026-11-01 に macOS の APM 0.14.2 で、隔離環境での再現（network 遮断、偽の HOME）と実機での更新（Phase 4D-2c-4b）を行った結果です。WSL・Windows、ほかの APM の版では確認していません。

注意点:

- ［実測］ user scope（`~/.apm`）では `apm update` を使わない。0.14.2 の `apm update` には `--global` が無く［仕様］、`~/.apm` を project として扱う。
- ［実測］ `apm update --dry-run` も書き込む（`~/.apm/config.json`、`apm_modules/`、`~/Library/Caches/apm/git` を作る）。
- ［実測］ `apm install -g --dry-run` は依存の一覧（「install する予定」）しか表示せず、ファイル単位の差分は分からない。
- ［実測］ `apm.yml` で依存を固定しただけでは、lock の内容 hash と合わずに中断する。`--update` を付けると、lock・`apm_modules`・配布ファイルが1回の実行で同時に更新され、分けられない。`--update` は 0.14.2 では非推奨だが動作する［仕様・実測］。
- ［実測］ 失敗すると（clone の失敗、hash の不一致）、`apm_modules/<owner>/<repo>` が消えることがある。lock と配布済みのファイルは残る。
- ［バイナリ・推定］ 配布先は `~/.claude`、`~/.codex`、`~/.gemini` などの有無から自動で選ばれるため、`--target codex` を必ず付ける。付けないと `~/.claude` にも配布されるおそれがある。
- ［実測］ カレントディレクトリに `.gitignore` を作り（`apm_modules/` を追記）、`.apm/` があれば取り込む。そのため、新しく作った空のディレクトリで実行する。
- ［実測］ 配布先にある APM 管理の Skill は、手元で編集していても警告だけで上書きされる。手元の変更は事前にバックアップする。
- ［実測］ 実機では、GitHub からの取得は `gh` の認証を使った HTTPS だった（ログに `Auth: gh-auth-token`）。`gh` の認証が切れていると取得に失敗する見込み［推定］。
- ［実測］ 元に戻すときに、旧い `apm.yml` と lock に戻して `apm install` すると、追加された Skill が残り、手元の変更も戻らない。ロールバックは APM の再 install ではなく、バックアップから戻す。

手順（各段階の確認が終わるまで次へ進まない。`--force` は使わない）:

1. **事前確認**: dotFiles と my-agent-harness が clean で、harness の対象 commit が push 済みであること。`apm --version` が想定した版であること。lock の `resolved_commit`、`apm.yml` の依存、Skills の手元の変更の有無を記録する。
2. **バックアップ**: Skills の探索 path の外に、新しいディレクトリ（例: `~/.local/state/dotfiles/backup/<phase>/<timestamp>/`、権限 700、既存を上書きしない）を作り、次を保存・記録する。認証情報とセッションは含めない。
   - tar で保存: `~/.apm/apm.yml`、`apm.lock.yaml`、`config.json`、`apm_modules/`、`~/.agents/skills/`、`~/.codex/agents/`
   - 種別・権限・SHA-256 の一覧（symlink はたどらない）: 上記と、記録だけの `~/.codex/skills/`、`~/.claude/skills/`（リンク先）、`~/.codex/hooks.json`、`~/.claude/settings.json`、`~/.codex/config.toml`
   - tar を別の場所に展開して一覧と照合し、`SHA256SUMS` と復元手順（README）を残す。
3. **依存の固定**: `~/.apm/apm.yml` の該当する依存1行だけを、完全な SHA で書き換え、差分を確認する（例: `Carp15/my-agent-harness#ba6934c2cd514c8b043fa69e9ca1957cade69a33`）。
4. **実行**（1〜3 が終わってから。network を使う）: 新しく作った空の一時ディレクトリに移り、`.apm` と `.gitignore` が無いことを確かめてから、次を1回だけ実行する。macOS・APM 0.14.2 で検証済みのコマンド:

   ```sh
   apm install -g --target codex --update --verbose
   ```

   失敗したら再試行せず、それ以上何も変えずに、lock・`apm_modules`・配布ファイルの状態を確認する。
5. **事後確認**: `apm.yml`、lock の `resolved_commit` / `resolved_ref`、`apm_modules` の `.apm-pin` が同じ SHA であること。手順2の一覧と比べて、変わったのが lock・`apm_modules`・想定した Skills / Agents だけで、hooks・settings・`config.toml`・Claude の symlink が同じであること。`codex debug prompt-input` で、Skill が `~/.agents/skills` から1回ずつ読み込まれていること。新しい Skill を Claude Code で使う場合は、上記「Claude Code への公開」の追加手順を別に行う。一時ディレクトリ（`.gitignore` だけが入っている）は確認してから片付ける。
6. **ロールバック**: バックアップの README の手順で、現在のものを退避してから tar を展開し、一覧と照合する。`apm_modules` だけが消えた場合は、tar から `.apm/apm_modules` だけを戻す。

2026-11-01 の更新のバックアップは `~/.local/state/dotfiles/backup/phase-4d-2c-4b/20261101T130134/`（更新前の状態）です。手元で変更していた manage-dotfiles の参照ファイル（更新で上書きされた）は `~/.local/state/dotfiles/backup/phase-4d-2c/manage-dotfiles/` にあります。

### Commands

`~/.claude/commands/` は無く、Skills に統一済みです［実測］。

### 共有方法の比較

| 方法 | 評価 |
| --- | --- |
| ネイティブ参照（APM → `~/.agents/skills`、Claude は symlink） | 現行。採用する。Claude 側の symlink は chezmoi で宣言 |
| chezmoi で Skill の実体を複製・配置 | 正が APM と二重になるため採用しない |
| APM で Claude にも配布する（`--target` に claude を含める） | `~/.claude/skills/` に実体が置かれ、「`~/.claude/skills/` には symlink だけを置く」運用に反する。既存の symlink とぶつかったときの挙動は［未確認］。採用しない |
| chezmoi で `~/.claude/skills/` の symlink を管理 | 採用（2026-11-03、B2 方式。上記「chezmoi による宣言管理」）。macOS は実機で差分なしを確認、WSL は隔離環境だけで確認。Windows は除外。Skill の追加ごとに dotfiles の変更が要る |

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
| APM | 手動で導入済み（0.14.2） | 導入手順なし［未確認］ | 導入手順なし［未確認］ |
| APM の更新（上記 6 の手順） | 実機で実証済み（2026-11-01） | 未検証 | 未検証 |
| APM 管理の Skills（`~/.agents/skills`） | 10件を配布済み。Codex で読み込みを確認 | 未検証 | 未検証 |
| 設定の home | `~/.claude`、`~/.codex` | WSL 側の `~/.claude`、`~/.codex`（Windows と別） | `%USERPROFILE%\.claude`、`.codex`［未確認］ |
| 共通 AI 指示（`~/.codex/AGENTS.md`、`~/.claude/CLAUDE.md`） | 配布対象（適用・読み込み確認済み） | 配布対象（実機は未検証） | 配布しない（`home/.chezmoiignore` で `.codex`、`.claude` を除外）。Claude の `@~/` が `%USERPROFILE%` に解決されるか［未確認］のため保留 |
| Claude 用 Skills の symlink | chezmoi で10件を宣言（live は既存の symlink と一致。apply 不要） | 同じ宣言を使う。隔離環境で確認済み、実機は未検証。APM の導入前は何も配置しない（B2） | 配置しない（`.claude` を除外） |
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

- **解消（2026-11-01、macOS）Codex の Skills の重複**: `~/.codex/skills/` にあった APM と同名の古いコピー5件を退避し（削除はしていない）、Codex の Skill 一覧の重複は0件になった［実測］（上記 6）。
- **解消（2026-11-01、macOS）APM の配布が古い**: harness を `ba6934c` に固定して再配布し、`chezmoi-diff-apply` を含む10件を配布した［実測］（上記 2、6）。
- **Claude 用 Skills の symlink は APM に追従しない**: 2026-11-03 から chezmoi で宣言しているが（上記 6）、APM で Skill が増減しても宣言は自動では変わらず、削除・改名で残った symlink はリンク切れになる。ずれは `scripts/doctor.sh` が warn で知らせる（修復はしない）。宣言した場所に実ディレクトリがあると apply で置き換わる、空のテンプレートは削除になる、という危険がある（上記 6）。
- **APM の更新手順の制約**: 0.14.2 は user scope で安全な dry-run が無く、lock と配布を分けられない。`--update` は非推奨。GitHub からの取得は `gh` の認証に依存する。APM 本体の更新後は、手順を検証し直す必要がある。
- **Agents が統一されていない**: `~/.claude/agents/` は手動で APM の配布対象外。Codex 側の APM 版と内容が揃っているかは未比較。`~/.codex/agents/` の APM 管理外5件の扱いも未決定。
- **共通 AI 指示は macOS だけ適用済み**: WSL・Windows の実機では、適用も読み込みの確認もしていない。Windows は `home/.chezmoiignore` で配布から外している。
- **herdr の hook script**: Claude 用と Codex 用で内容が異なる（管理対象外。記録のみ）。
- **未導入ツールの残骸**: `~/.gemini/`（認証ファイルを含む）、`~/.config/opencode/`。扱いは未決定。
- **［未確認］** Claude Code が展開した共通ルールと source の全文比較。import 失敗時の挙動。live の `codex debug prompt-input` 後に更新された Codex の状態ファイル・キャッシュの原因と通信の有無。WSL・Windows 実機での配布と読み込み。Windows での `~/` の解決。`instructionFiles` の公式仕様。Windows の `CODEX_HOME` の既定値。WSL・Windows での APM の導入・更新と Skills の配布、Claude 用 symlink の運用。APM 0.14.2 より新しい版での更新手順。TTY があるときに、chezmoi が実ディレクトリを symlink に置き換える前に確認を出すか。WSL 実機での `symlink_` の宣言の動き。`~/.claude/skills/synced/` の同期の仕組み。

## 11. Phase 4D-2b 以降の作業候補

それぞれ個別に承認を得てから行います。

1. 共通 AI 指示を WSL 実機に適用し、macOS と同じ手順（`chezmoi diff` → 対象を指定した `chezmoi apply`、Codex は `codex debug prompt-input`、Claude は新しい session の `/memory` と `/context`）で確認する。Windows に配布するかは、Windows 実機で `@~/` の解決を確認してから決める。
2. （完了、2026-11-01）`~/.codex/skills/` の重複5件を退避し、Codex の参照を `~/.agents/skills` に揃えた。
3. （完了、2026-11-01）my-agent-harness を `ba6934c` に固定して APM で再配布した。
4. Agents の整理: Claude の手動 Agents と APM 配布 Agents の差を比較し、Claude 側も APM で配布するか、`~/.codex/agents/` の APM 管理外5件をどう扱うかを決める。
5. WSL での検証: APM の導入・更新、`~/.agents/skills` の配布、Claude 用 symlink、Codex の Skill 一覧を、macOS と同じ手順で確認する。
6. Claude 用 symlink の管理: `scripts/doctor.sh` の読み取り専用の確認（2026-11-01）と、chezmoi の `symlink_` による宣言（2026-11-03、B2 方式）は実装済み（上記 6）。回帰テストは `tests/chezmoi-skills.test.sh`（2026-11-03）。残りは WSL 実機での確認。
7. `~/.apm/apm.yml` / `apm.lock.yaml` を chezmoi で管理するかと、APM 本体の導入方法・更新（[packages](packages.md) の保留事項）を決める。
8. `full.config.toml`、statusline、keybindings を配布するか決める。
9. Claude の `settings.json` の一部のキーを `modify_` で管理するか決める。
