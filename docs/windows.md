# Windows

Windows 11 native の構成と、WSL との役割分担をまとめます。WSL 側の手順は [WSL](wsl.md)、パッケージの担当は [packages](packages.md) を参照してください。

> **状態（2026-10-11）**: Windows native の bootstrap・doctor・chezmoi 設定は、WSL 上の pwsh（Linux 版）とスタブで動かすモックテスト（`tests/windows.test.sh`）と、`.chezmoi.os` を `windows` に上書きしたレンダリングで確認しただけです。**Windows 実機では一度も実行していません。** 実機で確認する項目は[実機検証手順](#実機検証手順)と[未検証事項](#未検証事項)にまとめています。

## 役割分担

| | Windows native | WSL2 (Ubuntu) |
| --- | --- | --- |
| 役割 | GUI のホスト | バックエンド開発の主環境 |
| shell | PowerShell 7（Windows Terminal） | zsh |
| パッケージ | winget（`packages/windows/winget.json`） | apt + mise + 公式 installer |
| 開発ランタイム（Java、Node、Go） | 入れない | mise |
| アプリ（基本環境） | PowerShell 7、Windows Terminal、Git、chezmoi | – |
| アプリ（任意） | Android Studio（+ SDK、emulator、adb。`--with android`）、IntelliJ IDEA（保留） | – |
| project の置き場所 | Android project だけ | `~/ghq/...`（Linux filesystem） |
| chezmoi の配置先 | Git ignore、PowerShell profile、Windows Terminal fragment | zsh、Git ignore、mise |

Windows には mise も言語ランタイムも入れません。Spring Boot / Kotlin は Windows の IntelliJ から WSL 上の project・JDK・Gradle を使い、Android は Windows native の Android Studio で開発します（[後述](#android-studio-と-android-sdk)）。

## 判定

| 実行環境 | 判定 | 実装 |
| --- | --- | --- |
| chezmoi（Windows 版） | `windows` | `home/.chezmoitemplates/platform` が `.chezmoi.os` を見て返す。sh を呼ばない |
| PowerShell 5.1 / 7（Windows） | `windows` | `scripts/lib/windows.ps1` の `Get-DotfilesPlatform`（5.1 は `PSEdition = Desktop`、7 は `$IsWindows`） |
| Git Bash（MINGW / MSYS / Cygwin） | `windows` | `scripts/lib/platform.sh`。`bootstrap.sh` は exit 2 で `bootstrap.ps1` を案内し、`doctor.sh` は warn を出す |
| WSL 上の pwsh | `wsl` | `windows.ps1` は Windows 以外では `platform.sh` に判定を委ねる |

WSL の判定は従来どおり `scripts/lib/platform.sh` の1か所だけです。`.chezmoi.os` は WSL でも `linux` を返しますが、`windows` を返すのは Windows native の chezmoi だけなので、Windows の判定に使っても WSL と混ざりません。

## chezmoi が Windows に置くもの

| source | 配置先 | 方式 |
| --- | --- | --- |
| `home/dot_config/git/ignore` | `~\.config\git\ignore` | 全 OS 共通。Git for Windows も `$HOME/.config/git/ignore` を読む |
| `home/dot_config/powershell/dotfiles.ps1` | `~\.config\powershell\dotfiles.ps1` | 共有の PowerShell 7 設定。chezmoi が常に最新に保つ |
| `home/Documents/PowerShell/create_Microsoft.PowerShell_profile.ps1` | `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`（`$PROFILE`） | `create_`：**存在しないときだけ作る**。既存の profile は上書きしない |
| `home/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json` | `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\dotfiles\dotfiles.json` | Windows Terminal の JSON fragment。`settings.json` は触らない |

`.zshrc`、`.zprofile`、`.config/mise` は Windows では配置しません。逆に、上の Windows 用の3つは macOS / WSL / Linux では配置しません（`home/.chezmoiignore`）。`doctor.ps1` は `chezmoi managed` にこれらが混ざっていないかも確認します。

### 既存の設定を上書きしない仕組み

chezmoi は、一度も管理したことのない既存ファイルでも、初回の `chezmoi apply` で**確認なしに上書きします**（chezmoi 2.73.0 で確認）。Windows では既存の `$PROFILE` や Windows Terminal の設定がある可能性が高いので、上書きが起きない構造にしています。

- **`$PROFILE` は `create_` で、1行の loader だけ**。既存の profile があれば何もせず、なければ `~\.config\powershell\dotfiles.ps1` を読み込む loader を作ります。作ったあとに追記した内容も、以後の apply で上書きされません。
- **共有設定は dotfiles 専用の新しい path**（`~\.config\powershell\dotfiles.ps1`）に置くので、既存ファイルとぶつかりません。
- **Windows Terminal は fragment だけ**を置きます。`settings.json` は Terminal 自身が UI 操作のたびに書き換え、WSL distribution の GUID など machine 固有の値を含むため、chezmoi では管理しません。fragment は profile と color scheme の追加・既存 profile の一部変更ができますが、`defaultProfile` などの global 設定は変えられません（[Microsoft Learn: JSON fragment extensions](https://learn.microsoft.com/windows/terminal/json-fragment-extensions)）。既定の profile は Settings で自分で選びます。
- bootstrap も doctor も profile を書き換えません。

それでも初回は必ず `chezmoi diff` を読んでから apply します。

### PowerShell profile の配置と読み込み

PowerShell 7 は `$PROFILE`（`$PROFILE.CurrentUserCurrentHost`）を「ドキュメント」known folder の下の `PowerShell\Microsoft.PowerShell_profile.ps1` から読みます。chezmoi が loader を置くのは常に `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` です。

| ケース | chezmoi apply の結果 | 必要な手動操作 | doctor の表示 |
| --- | --- | --- | --- |
| 標準の Documents、`$PROFILE` なし | loader を作る | なし | `Loaded ok` |
| 標準の Documents、既存の `$PROFILE` あり | 何もしない（`create_`） | 既存の `$PROFILE` に下の1行を追加 | 追加前は `Loaded warn ... add this line`、追加後は `Loaded ok` |
| OneDrive でリダイレクト、`$PROFILE` なし / あり | `~\Documents\PowerShell\` に loader を作るが、PowerShell 7 は読まない | 下の「Documents がリダイレクトされている場合」 | `Loaded warn ... Documents is redirected`、使われない loader があれば `Unused` |
| Windows PowerShell 5.1 の profile（`Documents\WindowsPowerShell\`） | 管理しない | なし（共有設定は PowerShell 7 用。5.1 から読んでも先頭で return する） | `5.1 profile`（情報のみ） |

既存の `$PROFILE` に追加する1行：

```powershell
. (Join-Path $HOME '.config/powershell/dotfiles.ps1')
```

doctor は PowerShell 7 を1回、**あなたの profile 付きで**起動し（terminal を開いたときと同じ）、実際に読んだ `$PROFILE` の path と、共有設定の関数 `wsl-home` がどのファイルで定義されたかを確認します。profile の内容は表示しません。profile がない・共有設定を読まない・Documents がリダイレクトされている、はいずれも warn（exit code は 0）です。

### Documents が OneDrive にリダイレクトされている場合

自動では何も変更しません。次を自分で行います。

1. PowerShell 7 で実際の path を確認する：`$PROFILE`（例：`...\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`）。`bootstrap.ps1` の Next steps と `doctor.ps1` もこの path を表示します。
2. **chezmoi apply の前に**、この machine だけ loader の管理を外す。`~\.config\chezmoi\chezmoi.toml`（machine 固有で repository には入らない）に追記します。

   ```toml
   [data]
   skipPowerShellProfile = true
   ```

   `chezmoi managed` から `Documents/...` が消えることを確認します。既に apply して `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` が作られていた場合、そのファイルは PowerShell 7 に読まれないので、内容を確認してから自分で削除して構いません（chezmoi も doctor も削除しません）。
3. 実際の `$PROFILE` に上の1行を追加する（ファイルがなければ作る）。

   ```powershell
   if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Force $PROFILE | Out-Null }   # 既存の profile はそのまま
   Add-Content $PROFILE ". (Join-Path `$HOME '.config/powershell/dotfiles.ps1')"
   ```

4. 新しい PowerShell 7 を開き、`pwsh -File scripts\doctor.ps1` が `Loaded ok` になることを確認する。

### PowerShell profile の内容

`~\.config\powershell\dotfiles.ps1` は最小限です。

- PSReadLine：重複しない長い履歴（password / token らしい行を履歴ファイルに残さない既定の filter はそのまま）
- `wsl-home`：既定の WSL distribution を Linux の home で開く（`wsl.exe --cd ~`）
- `wsl-here`：現在の Windows directory で WSL を開く

Windows Terminal の fragment は profile「WSL (home)」（`wsl.exe --cd ~`）を追加します。Terminal が自動生成する Ubuntu の profile は `/mnt/c/Users/...` から始まることがあるため、project のある Linux home へ直接入れる入口を用意しています。distribution 名は machine ごとに違い得るので、既定の distribution を使い、名前は書きません。

## 新しい Windows PC での手順

WSL 側（[WSL](wsl.md)）とは独立に進められます。以下は PowerShell で実行します。

### 1. Git を入れて repository を clone する

新しい Windows 11 には winget（App Installer）と Windows PowerShell 5.1 があり、Git と PowerShell 7 はありません。clone のためだけに Git を先に入れます。

```powershell
winget install --id Git.Git --exact --source winget
```

新しい terminal を開き、ghq と同じ配置へ clone します。Windows 用の clone は WSL の clone とは別の working copy です（後述）。

```powershell
git clone https://github.com/Carp15/dotFiles.git "$HOME\ghq\github.com\Carp15\dotFiles"
Set-Location "$HOME\ghq\github.com\Carp15\dotFiles"
```

Git for Windows の既定（`core.autocrlf=true`）でも、`.gitattributes` が `home/**` とシェルスクリプトを LF に固定しています。`*.ps1` は CRLF / LF のどちらでも動きます。

### 2. bootstrap の dry-run

PowerShell 7 はまだないので、Windows PowerShell 5.1 で実行します。`-ExecutionPolicy Bypass` はこのプロセスだけに効き、恒久的な設定は変えません。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1
```

`packages/windows/winget.json` の各パッケージについて `ok`（導入済み）/ `todo`（未導入）/ `blocked`（確認できない）と、`--apply` で実行する `winget install` を表示します。何もインストールせず、ファイルも書きません。

導入済みかの確認は `winget list --id <ID> --exact --source winget --disable-interactivity` で行います。`--disable-interactivity` により、source の利用規約への同意を求められる状況では、確認が同意を勝手に済ませたり入力待ちで止まったりせず `blocked`（`0x8A150046: source agreements were not accepted`）になります。その場合は `winget list` を一度自分で実行し、表示される規約を読んで答えてください。winget は確認の際に source の cache を更新することがあります（設定は変えません）。

### 3. bootstrap --apply

管理者ではない通常の terminal で実行します（管理者として実行すると exit 2 で止まります）。必要な installer は winget がパッケージごとに UAC で昇格を求めます。

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 --apply
```

- 未導入のパッケージだけを、`winget.json`（基本環境）の順に1つずつ `winget install --id <ID> --exact --source winget --no-upgrade` で入れます。
- `--accept-package-agreements` / `--accept-source-agreements` は付けません。規約への同意を求めるパッケージでは winget の確認がそのまま表示されるので、自分で読んで答えます。
- 失敗（同意しなかった場合を含む）したらその場で止まり、exit 1 で終わります。原因を直して再実行すると、導入済みのものは skip され、失敗したパッケージから再開します。
- winget が成功を返しても `winget list` に出てこない場合も失敗として止まります。
- アップグレード、アンインストール、`chezmoi apply` は行いません。
- ログは `%LOCALAPPDATA%\dotfiles\bootstrap\<時刻>.log` です（installer の詳細は winget 自身のログ `%LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir\`）。
- 各パッケージの前後で `$PROFILE`、Windows PowerShell 5.1 の profile、`~\.config\powershell\dotfiles.ps1`、Windows Terminal の `settings.json`、`~\.gitconfig` を比較し、installer が変更していれば警告します。

### 任意の開発ツール（`--with`）

Android Studio などの任意のツールは、基本環境とは別のファイルに宣言しています。`--with` を付けない限り、`--apply` でも導入しません（dry-run では導入状況を情報として表示するだけです）。

| グループ | パッケージ | 必須コマンド |
| --- | --- | --- |
| `android` | `packages/windows/winget-android.json`（`Google.AndroidStudio`） | `packages/commands/windows-android.txt`（`adb`） |

```powershell
powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 --with android            # dry-run
powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1 --apply --with android    # 基本環境 → Android Studio の順
```

IntelliJ IDEA は ID が未決定のため、まだどのグループにも宣言していません。

### 4. PowerShell 7 で chezmoi を設定する

Windows Terminal を開き、新しい PowerShell 7 の tab で repository に戻ります（PATH に pwsh、chezmoi が入った状態にするため）。`sourceDir` は machine 固有の path なので repository には入れず、`~\.config\chezmoi\chezmoi.toml` に書きます。TOML のリテラル文字列（単引用符）にすると、Windows の `\` をエスケープせずに書けます。PowerShell 7 の `-Encoding utf8` は BOM を付けません。

```powershell
New-Item -ItemType Directory -Force "$HOME\.config\chezmoi" | Out-Null
Set-Content -Encoding utf8 "$HOME\.config\chezmoi\chezmoi.toml" "sourceDir = '$PWD'"
chezmoi source-path        # ...\dotFiles\home になること
```

bootstrap の「Next steps」にも、その machine の path を埋めた同じコマンドが表示されます。

### 5. chezmoi diff で確認してから apply する

Documents が OneDrive にリダイレクトされている場合（`$PROFILE` が `~\Documents\PowerShell\` 以外。bootstrap の Next steps にも表示されます）は、apply の前に[その手順](#documents-が-onedrive-にリダイレクトされている場合)の 2 を済ませます。

```powershell
chezmoi managed            # .config/powershell/dotfiles.ps1 などがあり、.zshrc がないこと
chezmoi diff
chezmoi apply              # diff を読んで納得してから、自分で実行する
```

新しい machine では、`~\.config\git\ignore`、`~\.config\powershell\dotfiles.ps1`、`$PROFILE`（既存がなければ loader）、Windows Terminal の fragment が新規作成として表示されます。既存の `~\.config\git\ignore` がある場合は diff に変更として出るので、内容を確認してから apply します（このファイルは全 OS 共通で、`create_` ではありません）。

### 6. Windows Terminal

- Settings > Startup > Default profile を「PowerShell」（PowerShell 7。Windows PowerShell ではない方）にします。
- profile 一覧に「WSL (home)」が増えていることを確認します。

### 7. doctor で検証する

```powershell
pwsh -File scripts\doctor.ps1
```

`Platform windows`、必須コマンドがすべて present、`winget.json` のパッケージがすべて installed、chezmoi の Status が clean、Targets が `Windows only`、Loaded が `ok`、Fragment が present で、`Result: 0 error(s)` になることを確認します。

Android 開発環境は基本環境ではないので、Android SDK がなくても doctor は 0 error で終わります。「Optional group: android (information only)」に adb と Android Studio の状態と `not set up` が表示されるだけです。Android 開発を始めたら `pwsh -File scripts\doctor.ps1 --with android` で、adb（[後述](#android-studio-と-android-sdk)）と Android Studio を必須として確認します。

## scripts

| script | 内容 |
| --- | --- |
| `scripts/bootstrap.ps1` | 上記。既定は dry-run、`--apply`（`-Apply` も可）で基本環境の未導入のものだけ導入。`--with <group>` で任意のグループを追加。Windows PowerShell 5.1 でも動く |
| `scripts/doctor.ps1` | 読み取り専用の診断。基本環境の必須コマンド（`packages/commands/windows.txt`）と `winget.json` の導入状態、任意のグループ（情報のみ。`--with <group>` で必須）、PowerShell 7 の version、Git、chezmoi の source・status・Windows / WSL の target 分離、PowerShell 7 が実際に共有設定を読み込むか、Documents のリダイレクト、5.1 の profile（情報）、Terminal の fragment。Windows の Java / Node / Go / mise は情報として表示するだけ |
| `scripts/lib/windows.ps1` | 上の2つが共有する関数（判定、引数、任意のグループ、リストの読み込み、winget の確認と return code、chezmoi の状態、`$PROFILE` の path） |

doctor の報告と exit code は `doctor.sh` と同じです：error は `not installed` と `misconfigured` に分け、error があれば exit 1、warn だけなら 0。Windows 以外で実行すると exit 2 です。

## Windows 用と WSL 用の clone

chezmoi の source は、それぞれの環境の clone を使います。

- Windows：`%USERPROFILE%\ghq\github.com\Carp15\dotFiles`（Windows の Git で管理）
- WSL：`~/ghq/github.com/Carp15/dotFiles`

Windows の chezmoi から `\\wsl.localhost\<distro>\home\...` の WSL 側 clone を `sourceDir` にすれば working copy を1つにできますが、WSL が起動していないと chezmoi が動かず、Windows の Git で WSL 上の repository を操作すると所有者の不一致（`safe.directory`）や速度の問題が出やすいため、採用していません（未検証）。2つの clone は Git の push / pull で同期します。

## Android Studio と Android SDK

調査日：2026-10-11。実機では未確認です。

### インストール先

| 対象 | 推奨 | 補足 |
| --- | --- | --- |
| Android Studio | installer の既定（`C:\Program Files\Android\Android Studio`） | `bootstrap.ps1 --apply --with android` で導入（既定の `--apply` では入らない）。winget の `Google.AndroidStudio` は公式 installer を実行する。導入先と scope（machine / user）は実機で確認する |
| Android SDK | Android Studio の既定（`%LOCALAPPDATA%\Android\Sdk`） | SDK Manager で platform-tools・emulator・system image を入れる。winget では管理しない |
| AVD | 既定（`%USERPROFILE%\.android\avd`） | |

- SDK の path に空白を含めないでください。Windows のユーザー名に空白や ASCII 以外の文字が含まれる場合は、SDK を `C:\Android\Sdk` のような短い ASCII の path に置くことを検討します（emulator・NDK・一部の Gradle plugin が問題を起こすことがあるため。未検証）。
- `adb` を PowerShell から使うには、`<SDK>\platform-tools` をユーザーの PATH に自分で追加します。machine 固有の path なので、chezmoi では管理しません。追加後、`doctor.ps1` の android グループで adb が present になります。
- Android Studio は Gradle 用の JDK（JetBrains Runtime）を同梱しているので、Windows 側に別の JDK は要りません。

### Android Emulator

- Windows で推奨される高速化は **Windows Hypervisor Platform（WHPX）** です。「Windows の機能の有効化または無効化」で「Windows ハイパーバイザー プラットフォーム」を有効にし、再起動します（[Android Developers: Configure hardware acceleration](https://developer.android.com/studio/run/emulator-acceleration)）。
- **WSL2 と併用できるのは WHPX だけ**です。もう1つの選択肢である Android Emulator hypervisor driver（AEHD）は Hyper-V を使う Windows 機能をすべて無効にする必要があり、WSL2 と両立しません。AEHD は 2026-12-31 で提供終了、HAXM は emulator 36.2 で使われなくなっています。
- CPU の仮想化支援（Intel VT-x / AMD-V・SVM）を BIOS / UEFI で有効にしておく必要があります。
- 確認：`<SDK>\emulator\emulator.exe -accel-check` が `WHPX(...) is installed and usable.` を返すこと。
- Windows の機能の有効化は管理者権限と再起動を伴うため、bootstrap では行いません。

### WSL から adb を使う場合

Android 開発は Windows native で完結させる前提なので、WSL に adb は入れません（`packages/commands/wsl.txt` に未記載）。WSL の adb と Windows の adb を同時に動かすと、別々の adb server が port 5037 を取り合うことがあります（未検証）。

## IntelliJ IDEA と WSL

調査日：2026-10-11（[IntelliJ IDEA 2026.1 Help: WSL](https://www.jetbrains.com/help/idea/2026.1/how-to-use-wsl-development-environment-in-product.html)）。実機では未確認です。

- **project**：WSL の Linux filesystem に置いたまま、IntelliJ の File | Open で `\\wsl.localhost\<distro>\home\<user>\ghq\...` を開きます。Windows 側へ copy しません。
- **JDK**：WSL 内の JDK を project SDK に選びます。WSL では mise が入れた `temurin-21` です（WSL で `mise where java` が示す directory を `\\wsl.localhost\...` 経由で指定）。
- **Gradle / Maven**：WSL の project は WSL 内で build・実行されます。Gradle wrapper を使い、Gradle JVM には WSL の JDK を指定します（Settings | Build, Execution, Deployment | Build Tools | Gradle）。
- **Git**：`\\wsl$` / `\\wsl.localhost` の project では、IntelliJ は自動で WSL の Git を使います。Windows に Git.Git が入っていても、WSL の project は WSL の Git と `~/.config/git/ignore` を使います。
- **debugger / firewall**：WSL の project の debug では Windows Defender Firewall の許可が必要になることがあります。公式手順では、WSL のネットワークアダプター向けの受信規則を管理者の PowerShell で追加します（machine の設定なので dotfiles では扱いません）。
- **制約**：Windows 側の project を WSL で実行する「run target」は Ultimate edition の機能と記載されています。WSL 上の project をそのまま開く方法には、この制約はありません。
- 代替として JetBrains の Remote Development（IDE の backend を WSL 内で動かす）もありますが、検討していません。

### Java や Gradle を Windows と WSL で重複管理する必要性

**不要**です。

| 用途 | JDK | Gradle |
| --- | --- | --- |
| Spring Boot / Kotlin（WSL 上の project） | WSL の mise（`temurin-21`） | WSL 内の Gradle wrapper |
| Android（Windows 上の project） | Android Studio 同梱の JBR | Windows 上の Gradle wrapper（Android Studio が実行） |
| IDE 自体の実行 | 各 IDE に同梱の JBR | – |

project ごとの Gradle version は wrapper（`gradle-wrapper.properties`）が決めるので、Gradle を Windows に入れる必要もありません。Windows に JDK を追加するのは、Android Studio の外で Windows 上の Gradle を CLI から実行する必要が出たときだけで、その場合も Android Studio の JBR を `JAVA_HOME` に指定すれば足ります（未検証）。

## winget による IDE 管理

| | 内容 |
| --- | --- |
| メリット | `winget.json` に ID を宣言でき、他のパッケージと同じ dry-run・導入済み判定・停止の仕組みに乗る。新しい PC で手順を減らせる |
| 制約：更新 | IDE は自身の updater（Android Studio）や Toolbox で更新される。bootstrap は `--no-upgrade` で導入するだけなので衝突しないが、`winget upgrade --all` を手で実行すると IDE も更新対象になる |
| 制約：中身 | SDK、emulator、system image、plugin、JDK の設定は winget の管理外。SDK Manager と IDE の設定で行う |
| 制約：version | winget-pkgs の manifest は公開から遅れることがあり、Canary / Beta channel は扱えない |
| 制約：ID | `JetBrains.IntelliJIDEA.Ultimate` は 2025.2.5 で更新が止まっている。IntelliJ を winget で入れるなら統合版の `JetBrains.IntelliJIDEA`、複数 IDE を Toolbox に任せるなら `JetBrains.Toolbox` だけを宣言する（[packages](packages.md#winget-id)） |
| 制約：権限 | machine scope の installer は UAC の昇格を求める |

IntelliJ を `JetBrains.IntelliJIDEA` と `JetBrains.Toolbox` のどちらで入れるかは保留のままです（[packages](packages.md#保留事項)）。決まるまで `winget.json` には宣言しません。

## 実機検証手順

Windows 実機で初めてセットアップするときに、この順で確認し、結果をこの文書へ反映します。

1. **判定**：Windows PowerShell 5.1 で `powershell -ExecutionPolicy Bypass -File scripts\bootstrap.ps1` を実行し、`Platform` に Windows の version が表示され、構文エラーが出ないこと（5.1 での実行は未検証）。
2. **dry-run は何も変えない**：dry-run の前後で `winget list` の結果と `%LOCALAPPDATA%\dotfiles` の有無が変わらないこと。source の同意が未済なら `blocked` と `0x8A150046` が表示されること。Android Studio が「Optional, not selected: android」に情報として出て、Plan に入らないこと。
3. **導入済みの判定**：Windows 11 に最初から入っている Windows Terminal（Microsoft Store 版）が `ok` と判定されること。手動で入れた Git が `ok` になること。
4. **--apply**：基本環境の未導入のものだけが `winget install --id ... --exact --source winget --no-upgrade` で入り、Android Studio は入らないこと。規約の確認が表示されたら winget の画面で答えられること。ログが残ること。
5. **冪等性**：もう一度 `--apply` して `Nothing to install` になること。
6. **失敗時の停止**：同意を求められたパッケージで `N` と答え、`FAILED` と winget の return code が表示されて次のパッケージに進まないこと（return code の値は実機で記録する）。
7. **管理者で実行した場合**：exit 2 で止まること。
8. **profile の場所**：PowerShell 7 で `$PROFILE` を表示し、`~\Documents\PowerShell\...` か OneDrive 側かを記録する。`[Environment]::GetFolderPath('MyDocuments')` と一致すること。リダイレクトされていれば bootstrap の Next steps に案内が出ること。
9. **chezmoi**：`chezmoi managed` に `.zshrc`・`.config/mise` がなく、PowerShell の共有設定と fragment があること。
   - 既存の `$PROFILE` がある状態で `chezmoi apply` しても内容が変わらないこと（apply 前後で `Get-FileHash $PROFILE`）。
   - `$PROFILE` がない状態では loader が作られ、新しい PowerShell 7 で `Get-Command wsl-home` が見つかること。
   - OneDrive の場合は `skipPowerShellProfile = true` で `chezmoi managed` から `Documents/...` が消えること。
10. **doctor の profile 判定**：上の各状態で `pwsh -File scripts\doctor.ps1` の `Loaded` が [表](#powershell-profile-の配置と読み込み) のとおりになること。Windows PowerShell 5.1 の profile がある場合は `5.1 profile present` が情報として出るだけで、内容が変わらないこと。
11. **Windows Terminal**：「WSL (home)」profile が表示され、開くと Linux の home にいること。`settings.json` が chezmoi apply で変わっていないこと。
12. **Git ignore**：Windows の Git で `git check-ignore -v .DS_Store` が `~/.config/git/ignore` を示すこと。
13. **doctor（基本環境）**：Android SDK がない状態で `pwsh -File scripts\doctor.ps1` が `Result: 0 error(s)` になり、android グループが `not set up` と表示されること。Windows PowerShell 5.1 で実行すると PowerShell 7 の warn が出ること。
14. **Android（任意）**：`--apply --with android` で Android Studio だけが追加で入ること。SDK の platform-tools を PATH に入れた後、`doctor.ps1 --with android` が 0 error になること。emulator（`-accel-check`）。
15. **WSL 側の回帰**：WSL で `./scripts/doctor.sh` と `chezmoi managed` が以前と同じであること。
16. **IntelliJ**：上の IntelliJ と WSL の項目。

## 未検証事項

モックテスト（`tests/windows.test.sh`）は、WSL 上の pwsh 7（Linux 版）とスタブで動かしています。Windows 実機でしか確認できないのは次の事項です。

- 上の実機検証手順のすべて。Windows PowerShell 5.1・実際の winget・NTFS・Windows の known folder では一度も動かしていない。
- `$PROFILE` の path：テストでは Linux pwsh の `XDG_CONFIG_HOME` で Documents の位置を模擬している。Windows の pwsh が known folder（OneDrive のリダイレクトを含む）から `$PROFILE` を決めること、`[Environment]::GetFolderPath('MyDocuments')` が同じ path を返すことは未確認。
- doctor が profile 付きで pwsh を起動する確認で、`-EncodedCommand` が Windows PowerShell 5.1 からも正しく渡ること、利用者の profile が対話的な処理や長い処理を含む場合の挙動。
- winget が Store 版の Windows Terminal を `--source winget` の `winget list` で導入済みと判定するか。
- 同意を拒否した場合や再起動が必要な場合に winget が返す実際の return code（`scripts/lib/windows.ps1` の表は公式ドキュメントの値）。
- `pwsh` の version が 7 未満の場合の判定（テストでは、テストを実行している pwsh が PATH の先頭に来るため模擬できない）。
- `whoami /groups` による管理者判定（日本語表示の Windows でも SID `S-1-16-12288` で判定している）。
- Windows Terminal の fragment が読み込まれること、`wsl.exe --cd ~` の挙動。
- Git for Windows が `~\.config\git\ignore` を読むこと。
- Android Studio の導入先と scope、SDK の既定 path、WHPX と WSL2 の併用、WSL / Windows の adb の衝突。
- IntelliJ IDEA で WSL の project・JDK・Gradle・Git を使う手順。

## 管理しないもの

Windows の PATH（adb の追加を含む）、環境変数、Windows の機能（Hyper-V、WHPX）、Windows Terminal の `settings.json`、Windows Defender の設定、firewall の規則、credential（Git Credential Manager を含む）、`~\.gitconfig` は machine 固有か secret を含むため、chezmoi でも bootstrap でも変更しません。
