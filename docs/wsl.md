# WSL

Windows では、WSL2 上の Ubuntu をバックエンド開発の主環境にします。Windows native は GUI のホスト（IntelliJ、Android Studio など）です。この文書は WSL 側の構築手順と、macOS との差分をまとめます。パッケージの担当分けは [packages](packages.md) を参照してください。

> この手順と `scripts/bootstrap.sh` の WSL 経路は、macOS 上のモックテストで検証しただけで、WSL 実機ではまだ通していません。初回の実機セットアップで確認し、ずれがあればこの文書を直します。

## 方針

- project は Linux filesystem 上（`~/ghq/...`）に置く。`/mnt/c/...` 上の project は I/O が遅く、ファイル監視・権限・改行コードで問題が起きやすい。
- 設定は macOS と共通の chezmoi source state を使う。WSL だけの差分は次の2つ。
  - `~/.config/mise/conf.d/wsl.toml`：WSL で mise が担当する CLI。WSL でだけ配置する。
  - `~/.config/mise/config.toml` の Java の vendor：WSL は `temurin-21`、macOS は移行まで `21` のまま。
- OS / WSL の判定は `scripts/lib/platform.sh` の1か所にまとめている。chezmoi も `home/.chezmoitemplates/platform` 経由でこれを呼ぶ。`/proc/sys/kernel/osrelease` に `microsoft` を含めば WSL（WSL1 は `-Microsoft`、WSL2 は `-microsoft-standard-WSL2`）。カスタムカーネルの場合に備えて `WSL_DISTRO_NAME` も見る。
- zsh / Git / Neovim の設定ファイルは macOS と同一。Homebrew の初期化は `/opt/homebrew` と `/usr/local` の存在チェックで囲んであるので、WSL では何もしない。
- `chezmoi apply` は設定ファイルを置くだけ。パッケージは `scripts/bootstrap.sh --apply` で、明示的に入れる。

## 新しい Windows PC での手順

### 1. WSL2 と Ubuntu を入れる（Windows 側、PowerShell）

```powershell
wsl --install -d Ubuntu-24.04
```

再起動を求められたら再起動します。Ubuntu の初回起動で Linux のユーザー名とパスワードを作り、WSL2 で動いていることを確認します。WSL1 では、Claude Code の native binary に公式ドキュメントが案内する回避策が必要になるなどの制約があり、bootstrap と doctor は警告を出します。

```powershell
wsl -l -v      # VERSION が 2 であること
```

### 2. WSL 内の初期パッケージ（Ubuntu）

clone と chezmoi の導入に必要な最小限だけを入れます。残りは bootstrap が `packages/wsl/apt.txt` から入れます。

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates zsh
```

### 3. dotfiles リポジトリを clone する

ghq はまだないので、ghq と同じ配置へ git で clone します。public repository なので認証は不要です。

```bash
mkdir -p ~/ghq/github.com/Carp15
git clone https://github.com/Carp15/dotFiles.git ~/ghq/github.com/Carp15/dotFiles
cd ~/ghq/github.com/Carp15/dotFiles
```

### 4. chezmoi を入れて初期化する

公式 installer を、取得と実行に分けて実行します。`~/.local/bin/chezmoi` に入り、shell profile は変更しません。

```bash
curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/chezmoi-install.sh https://get.chezmoi.io
less /tmp/chezmoi-install.sh                  # 任意: 内容を確認する
sh /tmp/chezmoi-install.sh -b ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"          # この shell だけ。恒久設定は chezmoi apply で入る
```

source directory を設定します。`chezmoi init --source` は値を保存しないので、設定ファイルを書きます。

```bash
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s"\n' "$HOME/ghq/github.com/Carp15/dotFiles" > ~/.config/chezmoi/chezmoi.toml
chezmoi source-path        # .../dotFiles/home になること
```

### 5. chezmoi diff で事前に確認する

```bash
chezmoi diff
chezmoi managed            # .config/mise/conf.d/wsl.toml が含まれていれば WSL と判定されている
```

新しい WSL では、`~/.zshrc`、`~/.zprofile`、`~/.config/git/ignore`、`~/.config/mise/config.toml`（`java = "temurin-21"`）、`~/.config/mise/conf.d/wsl.toml` が新規作成として表示されます。Ubuntu が用意した `~/.bashrc` などは管理対象外なので変更されません。

### 6. chezmoi apply

diff の内容を確認できたら、自分で実行します。

```bash
chezmoi apply
```

### 7. bootstrap の dry-run

```bash
./scripts/bootstrap.sh
```

各ステップの状態（`ok` / `todo` / `blocked` / `manual`）と、`--apply` で実行するコマンドを表示します。何もインストールせず、ファイルも書きません。chezmoi が未適用だと、mise のツールと公式 installer は `blocked` になります。

### 8. bootstrap --apply

```bash
./scripts/bootstrap.sh --apply
```

不足しているものだけを次の順で入れ、最初の失敗で止まります。

1. apt：`packages/wsl/apt.txt` のうち未インストールのものだけ（`sudo` のパスワードを聞かれます）
2. mise：公式 installer（`https://mise.run`）で `~/.local/bin/mise` に入れる
3. mise のツール：`cd ~ && mise install`（Java、Node、Go、npm、Neovim、gh、ghq、lazygit、fd、tree-sitter、kubectl、helm、Rust）
4. Claude Code：公式 native installer（`https://claude.ai/install.sh`）
5. Codex CLI：公式 installer（`https://chatgpt.com/codex/install.sh`。`CODEX_NON_INTERACTIVE=1` 付き）

公式 installer は `~/.local/state/dotfiles/bootstrap/installers/` に保存してから実行し、SHA-256 を記録します。取得したファイルが `#!` で始まらない場合（proxy の HTML ページなど）は実行しません。ログは `~/.local/state/dotfiles/bootstrap/<時刻>.log` です。既にあるコマンドは再インストールしません。各ステップの前後で shell の起動ファイル（`.zshrc` など）を比較し、変更されていれば警告します。何度実行しても、済んだステップは skip されます。

### 9. 新しい shell で mise を有効化する

login shell を zsh にして、新しい shell を開きます。zshrc が `mise activate` を実行し、`~/.local/bin` と mise のツールが PATH に入ります。

```bash
chsh -s "$(command -v zsh)"
exec zsh -l
mise doctor                 # activated: yes
```

Neovim の設定は symlink で配置し、plugin を lockfile の version で復元します。

```bash
./scripts/link.sh && ./scripts/link.sh --apply
nvim --headless "+Lazy! restore" +qa
```

### 10. doctor で検証する

```bash
./scripts/doctor.sh
```

`Platform wsl`、`Distribution WSL2, ubuntu 24.04`、必須コマンドが全部 present、Neovim が 0.11 以上、`Result: 0 error(s)` であることを確認します。error には「not installed」（入っていない）と「misconfigured」（入っているがこの shell から使えない）の2種類があります。warn は終了コードに影響しません。

## 認証（手動、管理対象外）

認証情報は repository で管理しません。必要になったときに各ツールで login します。

```bash
gh auth login
claude          # 初回起動時にブラウザで login
codex           # 初回起動時に Sign in with ChatGPT
```

ブラウザは Windows 側で開きます。開かない場合は、表示された URL を Windows のブラウザに貼り付けます。

## 任意: Windows の PATH を取り込まない

WSL は既定で Windows の PATH を末尾に追加します。`doctor.sh` は `Interop` 行にその件数を表示し、必須コマンドが `/mnt/...` の Windows 実行ファイルに解決された場合は error にします。取り込み自体をやめたい場合は、`/etc/wsl.conf` に次を書き、Windows 側で `wsl --shutdown` してから開き直します。

```ini
[interop]
appendWindowsPath = false
```

`/etc` 配下のシステム設定なので、chezmoi も bootstrap も変更しません。必要な場合に自分で行ってください。無効にすると `code .`（VS Code）や `explorer.exe .` が PATH から消えます。使う場合は alias や絶対 path で補います。

## 管理しないもの

Windows 側の path、interop、credential bridge は machine 固有になりやすいため、共通設定に入れません。secret や Windows の credential も複製しません。Windows native 側（PowerShell profile、Windows Terminal の fragment、winget）は [Windows](windows.md) で別に管理します。
