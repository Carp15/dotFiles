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
      rendered="$(czrun "$label" "$uname_dir" "$FX/$fixture" cat "$TEST_TMP/chezmoi-$label/home/.config/mise/config.toml")"
      czrun "$label" "$uname_dir" "$FX/$fixture" diff >/dev/null
      diff_rc=$?
      written="$(find "$TEST_TMP/chezmoi-$label/home" -mindepth 1 | wc -l | tr -d ' ')"
      if [ "$rc" = 0 ] && [ "$diff_rc" = 0 ] && [ "$has_conf_d" = "$conf_d" ] && [ "$written" = 0 ] &&
        printf '%s\n' "$rendered" | grep -qx "java = \"$java\""; then
        ok "chezmoi ($variant, $platform): conf.d/wsl.toml=$conf_d, java=$java, nothing written"
      else
        ng "chezmoi ($variant, $platform): rc=$rc diff=$diff_rc conf.d=$has_conf_d written=$written" "$managed
$rendered"
      fi
    done
  done

  mv "$clone/scripts/lib/platform.sh" "$TEST_TMP/platform.sh.moved"
  czrun missing-lib uname-linux "$FX/wsl2" managed >/dev/null
  rc=$?
  mv "$TEST_TMP/platform.sh.moved" "$clone/scripts/lib/platform.sh"
  [ "$rc" != 0 ] && ok "chezmoi: missing platform.sh is an error, not a silent fallback" ||
    ng "chezmoi: missing platform.sh did not fail"

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
