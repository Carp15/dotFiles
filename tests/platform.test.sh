# Platform detection (scripts/lib/platform.sh), the chezmoi templates that call
# it, and the per-platform mise configuration they render.
# shellcheck shell=bash

# --- scripts/lib/platform.sh -------------------------------------------------

detect() { # UNAME_DIR OSRELEASE_FILE [WSL_DISTRO_NAME]
  env -i PATH="$1:$TOOLS" DOTFILES_OSRELEASE_FILE="$2" ${3:+WSL_DISTRO_NAME=$3} \
    sh -c '. "$0"; echo "$(dotfiles_platform) $(dotfiles_wsl_version)"' "$REPO/scripts/lib/platform.sh"
}

for case_line in \
  "WSL2 kernel|uname-linux|wsl2||wsl 2" \
  "WSL1 kernel|uname-linux|wsl1||wsl 1" \
  "plain Linux kernel|uname-linux|plain||linux unknown" \
  "custom kernel + WSL_DISTRO_NAME|uname-linux|custom|Ubuntu|wsl unknown" \
  "no osrelease file|uname-linux|missing||linux unknown" \
  "macOS|uname-darwin|plain||macos unknown" \
  "Git Bash on Windows|uname-mingw|plain||windows unknown" \
  "other OS|uname-bsd|plain||unknown unknown"; do
  split "$case_line"
  label="${split_fields[0]}" uname_dir="${split_fields[1]}" fixture="${split_fields[2]}"
  distro="${split_fields[3]}" want="${split_fields[4]}"
  got="$(detect "$TEST_TMP/$uname_dir" "$FX/$fixture" "$distro")"
  [ "$got" = "$want" ] && ok "platform: $label -> $got" || ng "platform: $label -> '$got', want '$want'"
done

got="$(env -i PATH="$TOOLS" DOTFILES_OS_RELEASE_FILE="$FX/ubuntu" \
  sh -c '. "$0"; echo "$(dotfiles_distro_id) $(dotfiles_distro_version)"' "$REPO/scripts/lib/platform.sh")"
[ "$got" = "ubuntu 24.04" ] && ok "platform: os-release -> $got" || ng "platform: os-release -> '$got'"

# --- chezmoi on a fresh clone -----------------------------------------------
# A copy of the working tree (no .git, then with an empty git repository) is
# used as the source directory, with config, destination and state all in the
# temporary directory. mise is not on PATH: applying must not depend on it.

chezmoi_bin="$(command -v chezmoi 2>/dev/null)"
if [ -z "$chezmoi_bin" ] || ! command -v git >/dev/null 2>&1; then
  skip "chezmoi templates (chezmoi or git not installed)"
else
  clone="$TEST_TMP/clone"
  mkdir -p "$clone"
  # Tracked and untracked (not ignored) files that exist: what a clone would hold.
  # Outside a git checkout, everything but .git.
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
    (cd "$REPO" && git ls-files -co --exclude-standard | while IFS= read -r f; do [ -e "$f" ] && echo "$f"; done |
      tar -cf - -T -) | tar -xf - -C "$clone"
  else
    (cd "$REPO" && tar --exclude=.git -cf - .) | tar -xf - -C "$clone"
  fi

  # czrun LABEL UNAME_DIR OSRELEASE CHEZMOI_ARGS...; prints output, returns status.
  czrun() {
    local cfg="$TEST_TMP/chezmoi-$1" uname_dir="$2" osrelease="$3"
    shift 3
    mkdir -p "$cfg/home"
    printf 'sourceDir = "%s"\n' "$clone" >"$cfg/chezmoi.toml"
    (cd / && env -i HOME="$cfg/home" PATH="$TEST_TMP/$uname_dir:$TOOLS" DOTFILES_OSRELEASE_FILE="$osrelease" \
      "$chezmoi_bin" --config "$cfg/chezmoi.toml" --destination "$cfg/home" \
      --persistent-state "$cfg/state.boltdb" --no-tty "$@" 2>&1)
  }

  for variant in no-git git; do
    [ "$variant" = git ] && git -C "$clone" init -q
    for case_line in "wsl|uname-linux|wsl2|temurin-21|yes" "linux|uname-linux|plain|21|no" "macos|uname-darwin|plain|21|no"; do
      split "$case_line"
      platform="${split_fields[0]}" uname_dir="${split_fields[1]}" fixture="${split_fields[2]}"
      java="${split_fields[3]}" conf_d="${split_fields[4]}"
      label="$variant-$platform"
      managed="$(czrun "$label" "$uname_dir" "$FX/$fixture" managed)"
      rc=$?
      has_conf_d=no
      printf '%s\n' "$managed" | grep -qx '.config/mise/conf.d/wsl.toml' && has_conf_d=yes
      windows_targets="$(printf '%s\n' "$managed" | grep -E '^(AppData|Documents|\.config/powershell)' | tr '\n' ' ')"
      rendered="$(czrun "$label" "$uname_dir" "$FX/$fixture" cat "$TEST_TMP/chezmoi-$label/home/.config/mise/config.toml")"
      czrun "$label" "$uname_dir" "$FX/$fixture" diff >/dev/null
      diff_rc=$?
      written="$(find "$TEST_TMP/chezmoi-$label/home" -mindepth 1 | wc -l | tr -d ' ')"
      if [ "$rc" = 0 ] && [ "$diff_rc" = 0 ] && [ "$has_conf_d" = "$conf_d" ] && [ "$written" = 0 ] &&
        [ -z "$windows_targets" ] &&
        printf '%s\n' "$rendered" | grep -qx "java = \"$java\""; then
        ok "chezmoi ($variant, $platform): conf.d/wsl.toml=$conf_d, java=$java, no Windows targets, nothing written"
      else
        ng "chezmoi ($variant, $platform): rc=$rc diff=$diff_rc conf.d=$has_conf_d written=$written windows=[$windows_targets]" "$managed
$rendered"
      fi
    done
  done

  # --- Windows native ---------------------------------------------------------
  # chezmoi cannot run as a Windows binary here, so .chezmoi.os is overridden.
  # This exercises the templates' Windows branch, not Windows itself.
  win='{"chezmoi":{"os":"windows"}}'
  win_files='.config/git/ignore
.config/powershell/dotfiles.ps1
AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json
Documents/PowerShell/Microsoft.PowerShell_profile.ps1'
  managed="$(czrun windows uname-linux "$FX/wsl2" --override-data "$win" managed --include=files)"
  rc=$?
  [ "$rc" = 0 ] && [ "$managed" = "$win_files" ] &&
    ok "chezmoi (windows): only Git ignore, PowerShell profile and Terminal fragment; no zsh / mise" ||
    ng "chezmoi (windows): rc=$rc" "$managed"

  # A machine whose Documents is redirected opts out of the ~/Documents loader
  # in its own chezmoi.toml ([data] skipPowerShellProfile = true).
  managed="$(czrun windows-skip uname-linux "$FX/wsl2" \
    --override-data '{"chezmoi":{"os":"windows"},"skipPowerShellProfile":true}' managed)"
  rc=$?
  [ "$rc" = 0 ] && ! printf '%s\n' "$managed" | grep -q '^Documents' &&
    printf '%s\n' "$managed" | grep -qx '.config/powershell/dotfiles.ps1' &&
    ok "chezmoi (windows, skipPowerShellProfile): no Documents target, shared settings kept" ||
    ng "chezmoi (windows, skipPowerShellProfile): rc=$rc" "$managed"

  # Windows answers without scripts/lib/platform.sh (there is no sh on Windows).
  mv "$clone/scripts/lib/platform.sh" "$TEST_TMP/platform.sh.moved"
  managed="$(czrun windows uname-linux "$FX/wsl2" --override-data "$win" managed --include=files)"
  rc=$?
  czrun missing-lib uname-linux "$FX/wsl2" managed >/dev/null
  rc_wsl=$?
  mv "$TEST_TMP/platform.sh.moved" "$clone/scripts/lib/platform.sh"
  [ "$rc" = 0 ] && [ "$managed" = "$win_files" ] && ok "chezmoi (windows): does not call platform.sh" ||
    ng "chezmoi (windows) without platform.sh: rc=$rc" "$managed"
  [ "$rc_wsl" != 0 ] && ok "chezmoi: missing platform.sh is an error, not a silent fallback" ||
    ng "chezmoi: missing platform.sh did not fail"

  # An existing $PROFILE is never overwritten (create_), on the first apply or
  # later; the shared file and the fragment are kept up to date.
  wh="$TEST_TMP/chezmoi-windows-apply/home"
  mkdir -p "$wh/Documents/PowerShell"
  printf 'my profile\n' >"$wh/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  out="$(czrun windows-apply uname-linux "$FX/wsl2" --override-data "$win" apply)"
  rc=$?
  if [ "$rc" = 0 ] && [ "$(cat "$wh/Documents/PowerShell/Microsoft.PowerShell_profile.ps1")" = "my profile" ] &&
    cmp -s "$wh/.config/powershell/dotfiles.ps1" "$clone/home/dot_config/powershell/dotfiles.ps1" &&
    [ -f "$wh/AppData/Local/Microsoft/Windows Terminal/Fragments/dotfiles/dotfiles.json" ] &&
    [ ! -e "$wh/.zshrc" ] && [ ! -e "$wh/.config/mise" ]; then
    ok "chezmoi apply (windows): existing \$PROFILE kept; shared profile and fragment written; no zsh / mise"
  else
    ng "chezmoi apply (windows) with an existing profile: rc=$rc" "$out
$(find "$wh" -type f)"
  fi

  wh="$TEST_TMP/chezmoi-windows-fresh/home"
  czrun windows-fresh uname-linux "$FX/wsl2" --override-data "$win" apply >/dev/null
  loader="$wh/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  cmp -s "$loader" "$clone/home/Documents/PowerShell/create_Microsoft.PowerShell_profile.ps1" &&
    ok "chezmoi apply (windows, no profile): loader created" || ng "chezmoi apply (windows): loader not created"
  printf '# local addition\n' >>"$loader"
  czrun windows-fresh uname-linux "$FX/wsl2" --override-data "$win" apply >/dev/null
  status="$(czrun windows-fresh uname-linux "$FX/wsl2" --override-data "$win" status)"
  tail -1 "$loader" | grep -qx '# local addition' && [ -z "$status" ] &&
    ok "chezmoi apply (windows) again: local edits to \$PROFILE kept, status clean" ||
    ng "chezmoi apply (windows) again" "$status"

  # --- mise reads the rendered WSL configuration as intended ------------------
  mise_bin="$(command -v mise 2>/dev/null)"
  if [ -z "$mise_bin" ]; then
    skip "mise configuration loading (mise not installed)"
  else
    mise_home="$TEST_TMP/mise-home"
    mkdir -p "$mise_home/.config/mise/conf.d"
    czrun git-wsl uname-linux "$FX/wsl2" cat "$TEST_TMP/chezmoi-git-wsl/home/.config/mise/config.toml" \
      >"$mise_home/.config/mise/config.toml"
    czrun git-wsl uname-linux "$FX/wsl2" cat "$TEST_TMP/chezmoi-git-wsl/home/.config/mise/conf.d/wsl.toml" \
      >"$mise_home/.config/mise/conf.d/wsl.toml"
    listing="$(cd "$mise_home" && env -i HOME="$mise_home" PATH="$TOOLS" MISE_OFFLINE=1 \
      "$mise_bin" ls --current --no-header 2>&1)"
    check "mise (WSL): java from config.toml is temurin-21; conf.d adds aqua Neovim 0.12 and the CLIs" 0 $? "$listing" \
      '^java +temurin-21' '^aqua:neovim/neovim +0\.12' '^gh ' '^rust +stable' '^node +24'
  fi
fi
