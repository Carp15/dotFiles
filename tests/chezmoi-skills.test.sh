# Claude Code skill symlinks declared with chezmoi (docs/ai-tools.md, section 6,
# "chezmoi による宣言管理"): home/dot_claude/skills/symlink_<name>.tmpl holds one
# fixed line, {{ .chezmoi.homeDir }}/.agents/skills/<name>, and the B2 block at
# the end of home/.chezmoiignore leaves a declared link unmanaged while
# ~/.agents/skills/<name> (the APM-deployed skill) does not exist.
#
# Layer 1, static: the source state under test (the working tree, copied the way
#   platform.test.sh copies it) may declare nothing else. Runs without chezmoi.
# Layer 2, behaviour: chezmoi on a copy of that source with an isolated HOME,
#   config, state and cache. The expectations are what chezmoi v2.73.3 does
#   (measured 2026-11-03, Phase 4D-2c-9b/10b). Some of them pin dangerous
#   behaviour on purpose (a real directory or file at a declared path is
#   replaced; an empty template deletes): a chezmoi that behaves differently
#   fails here, and docs/ai-tools.md must be re-checked before the expectation
#   is changed. Do not relax them just to make a newer chezmoi pass.
# Layer 3, meta: deliberately broken copies of the source must fail layer 1 or 2.
#
# Nothing here reads the live APM lock or the live HOME. Every chezmoi run goes
# through sk_cz, which refuses to start unless every path it is given resolves,
# after following symlinks, inside $TEST_TMP/skills (sk_guard).
# shellcheck shell=bash

sk_root="$TEST_TMP/skills"
mkdir -p "$sk_root"
sk_root_p="$(cd -P -- "$sk_root" && pwd -P)"
sk_live_home="${HOME:-}"
sk_live_home_p=""
[ -n "$sk_live_home" ] && sk_live_home_p="$(cd -P -- "$sk_live_home" 2>/dev/null && pwd -P)"
sk_name_re='^[a-z0-9][a-z0-9-]*$'
sk_refused=0

# --- isolation guard ----------------------------------------------------------

# sk_phys PATH: the physical path (symlinks resolved) of an existing directory,
# or of an existing parent directory plus the last component.
sk_phys() {
  local d
  if [ -d "$1" ]; then
    (cd -P -- "$1" 2>/dev/null && pwd -P)
  else
    d="$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P)" || return 1
    printf '%s/%s\n' "$d" "$(basename -- "$1")"
  fi
}

# sk_guard_one PATH STRICT: PATH must be absolute, without "..", resolve inside
# $sk_root and stay out of the live HOME's tool directories. STRICT (HOME,
# destination, source, config, state, cache, working directory) also refuses a
# symlink; otherwise a symlink is resolved through its parent only, as chezmoi
# acts on the link itself. Sets sk_guard_msg and returns 1 on a violation.
sk_guard_one() {
  local a="$1" p
  case "$a" in
    "~"*) sk_guard_msg="home-relative path: $a"; return 1 ;;
    /*) ;;
    *) sk_guard_msg="relative path: $a"; return 1 ;;
  esac
  case "/$a/" in */../*) sk_guard_msg="path with ..: $a"; return 1 ;; esac
  if [ -L "$a" ]; then
    [ "$2" = strict ] && { sk_guard_msg="path is a symlink: $a"; return 1; }
    # the link must also point into the test root, dangling or not
    p="$(readlink "$a")"
    case "$p" in
      "$sk_root_p"/*) case "/$p/" in */../*) sk_guard_msg="link with ..: $a"; return 1 ;; esac ;;
      *) sk_guard_msg="link out of the test root: $a -> $p"; return 1 ;;
    esac
    if [ -e "$a" ]; then
      p="$(sk_phys "$a")" || { sk_guard_msg="unresolvable: $a"; return 1; }
      case "$p" in "$sk_root_p"/*) ;; *) sk_guard_msg="link resolves out of the test root: $a -> $p"; return 1 ;; esac
    fi
    p="$(cd -P -- "$(dirname -- "$a")" 2>/dev/null && pwd -P)/${a##*/}" || { sk_guard_msg="unresolvable: $a"; return 1; }
  else
    p="$(sk_phys "$a")" || { sk_guard_msg="unresolvable: $a"; return 1; }
  fi
  case "$p" in
    "$sk_root_p"/*) ;;
    *) sk_guard_msg="outside the test root: $a -> $p"; return 1 ;;
  esac
  if [ -n "$sk_live_home_p" ]; then
    case "$p" in
      "$sk_live_home_p" | "$sk_live_home_p"/.claude | "$sk_live_home_p"/.claude/* | \
        "$sk_live_home_p"/.agents | "$sk_live_home_p"/.agents/* | "$sk_live_home_p"/.apm | \
        "$sk_live_home_p"/.apm/* | "$sk_live_home_p"/.codex | "$sk_live_home_p"/.codex/* | \
        "$sk_live_home_p"/.config/chezmoi | "$sk_live_home_p"/.config/chezmoi/* | \
        "$sk_live_home_p"/.local/share/chezmoi | "$sk_live_home_p"/.local/share/chezmoi/*)
        sk_guard_msg="live path: $a"
        return 1
        ;;
    esac
  fi
  return 0
}

# sk_guard STRICT_PATH... [-- ARG...]: every STRICT_PATH strictly, and every
# ARG that is a path ("/..." or "~...") loosely; other ARGs (flags, JSON) pass.
sk_guard() {
  local a mode=strict
  sk_guard_msg=""
  case "$sk_root_p" in /?*) ;; *) sk_guard_msg="no test root"; return 1 ;; esac
  if [ -n "$sk_live_home_p" ]; then
    case "$sk_live_home_p/" in "$sk_root_p"/*) sk_guard_msg="test root contains the live HOME"; return 1 ;; esac
  fi
  for a in "$@"; do
    if [ "$mode" = strict ] && [ "$a" = -- ]; then
      mode=loose
      continue
    fi
    if [ "$mode" = loose ]; then
      case "$a" in "~"* | /*) ;; *) continue ;; esac
    fi
    sk_guard_one "$a" "$mode" || return 1
  done
  return 0
}

# sk_cz SRC CASE_DIR PLATFORM CHEZMOI_ARGS...: chezmoi with source SRC, HOME and
# destination CASE_DIR/home, config, state, cache and TMPDIR in CASE_DIR, run
# from CASE_DIR. PLATFORM is macos or wsl (fake uname, as platform.test.sh).
# Prints the output; returns chezmoi's status, or 125 without running it when
# the guard refuses.
sk_cz() {
  local src="$1" c="$2" plat="$3" un osr
  shift 3
  if ! sk_guard "$src" "$c"; then
    sk_refused=$((sk_refused + 1))
    printf 'REFUSED: %s\n' "$sk_guard_msg"
    return 125
  fi
  case "$plat" in
    wsl) un="$TEST_TMP/uname-linux" osr="$FX/wsl2" ;;
    *) un="$TEST_TMP/uname-darwin" osr="$FX/plain" ;;
  esac
  mkdir -p "$c/home" "$c/cache" "$c/tmp"
  if ! sk_guard "$src" "$c" "$c/home" "$c/cache" "$c/tmp" "$c/chezmoi.toml" "$c/state.boltdb" -- "$@"; then
    sk_refused=$((sk_refused + 1))
    printf 'REFUSED: %s\n' "$sk_guard_msg"
    return 125
  fi
  printf 'sourceDir = "%s"\n' "$src" >"$c/chezmoi.toml"
  (cd "$c" && env -i HOME="$c/home" PATH="$un:$TOOLS" DOTFILES_OSRELEASE_FILE="$osr" TMPDIR="$c/tmp" \
    "$sk_chezmoi" --config "$c/chezmoi.toml" --source "$src" --destination "$c/home" \
    --persistent-state "$c/state.boltdb" --cache "$c/cache" --no-tty --color=false "$@" 2>&1)
}

# --- layer 1: static checks ---------------------------------------------------

# sk_lint SRC: SRC holds .chezmoiroot and home/. Prints one line per problem and
# returns 1 if there is any.
sk_lint() {
  local src="$1" d="$1/home/dot_claude/skills" e base n want bytes lines found=0 bad=0 f
  if [ ! -d "$d" ]; then
    echo "no home/dot_claude/skills directory"
    bad=1
  else
    for e in "$d"/* "$d"/.[!.]* "$d"/..?*; do
      [ -e "$e" ] || [ -L "$e" ] || continue
      base="${e##*/}"
      case "$base" in
        symlink_*.tmpl) ;;
        *) echo "unexpected entry: dot_claude/skills/$base"; bad=1; continue ;;
      esac
      if [ -L "$e" ] || [ ! -f "$e" ]; then
        echo "not a regular file: dot_claude/skills/$base"
        bad=1
        continue
      fi
      found=$((found + 1))
      n="${base#symlink_}"
      n="${n%.tmpl}"
      if ! [[ $n =~ $sk_name_re ]]; then
        echo "unsafe name: $base"
        bad=1
        continue
      fi
      case "$n" in cc-notes | synced)
        echo "unmanaged name declared: $base"
        bad=1
        continue
        ;;
      esac
      want="{{ .chezmoi.homeDir }}/.agents/skills/$n"
      bytes="$(wc -c <"$e" | tr -d ' ')"
      lines="$(wc -l <"$e" | tr -d ' ')"
      if [ "$lines" != 1 ] || [ "$bytes" != $((${#want} + 1)) ] || [ "$(cat "$e")" != "$want" ]; then
        echo "not the fixed single line: $base"
        bad=1
      fi
    done
    [ "$found" -gt 0 ] || { echo "no symlink_*.tmpl declarations"; bad=1; }
  fi
  # exact_ anywhere on the way to ~/.claude would delete unmanaged entries
  # (cc-notes, synced/), and a symlink_ elsewhere under dot_claude could replace
  # a whole directory with a link.
  for f in $(cd "$src/home" && find . -path '*dot_claude*' \( -name '*exact_*' -o -name 'symlink_*' \) | LC_ALL=C sort); do
    case "$f" in
      *exact_*) echo "exact_ under dot_claude: ${f#./}"; bad=1 ;;
      ./dot_claude/skills/symlink_*) ;;
      *) echo "symlink_ outside dot_claude/skills: ${f#./}"; bad=1 ;;
    esac
  done
  # B2: the conditional exclusion that keeps chezmoi from creating dangling
  # links when the APM skill is missing (behaviour checked in layer 2).
  for want in \
    '{{ range $f := glob (joinPath .chezmoi.sourceDir "dot_claude/skills/symlink_*.tmpl") -}}' \
    '{{ $name := base $f | trimPrefix "symlink_" | trimSuffix ".tmpl" -}}' \
    '{{ if not (stat (joinPath $.chezmoi.homeDir ".agents/skills" $name)) -}}' \
    '.claude/skills/{{ $name }}'; do
    grep -Fqx -- "$want" "$src/home/.chezmoiignore" 2>/dev/null || { echo "B2 exclusion missing in .chezmoiignore: $want"; bad=1; }
  done
  grep -qx '\.claude' "$src/home/.chezmoiignore" 2>/dev/null || { echo "Windows exclusion of .claude missing"; bad=1; }
  return "$bad"
}

# The source under test: what a clone of the working tree would hold.
sk_src="$sk_root/src"
mkdir -p "$sk_src"
if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then
  (cd "$REPO" && git ls-files -co --exclude-standard -- .chezmoiroot home scripts/lib/platform.sh |
    while IFS= read -r sk_f; do [ -e "$sk_f" ] && echo "$sk_f"; done | tar -cf - -T -) | tar -xf - -C "$sk_src"
else
  (cd "$REPO" && tar -cf - .chezmoiroot home scripts/lib/platform.sh) | tar -xf - -C "$sk_src"
fi

sk_out="$(sk_lint "$sk_src")"
check "skills (static): only fixed one-line symlink_<name>.tmpl, no exact_, B2 and Windows exclusions kept" \
  0 $? "$sk_out"

sk_names="$(cd "$sk_src/home/dot_claude/skills" 2>/dev/null && for sk_f in symlink_*.tmpl; do
  sk_f="${sk_f#symlink_}"
  echo "${sk_f%.tmpl}"
done | LC_ALL=C sort)"
sk_count="$(printf '%s\n' "$sk_names" | grep -c .)"

# sk_mutant NAME: a fresh copy of the source under test to break on purpose.
sk_mutant() {
  local m="$sk_root/mut-$1"
  mkdir -p "$m"
  (cd "$sk_src" && tar -cf - .) | tar -xf - -C "$m"
  printf '%s\n' "$m"
}

# sk_meta_lint NAME PATTERN: the mutant must fail sk_lint with PATTERN.
sk_meta_lint() {
  local out rc
  out="$(sk_lint "$sk_root/mut-$1")"
  rc=$?
  if [ "$rc" != 0 ] && printf '%s\n' "$out" | grep -qE -- "$2"; then
    ok "skills (meta, static): $1 is rejected"
  else
    ng "skills (meta, static): $1 passed the static check (rc=$rc, want /$2/)" "$out"
  fi
}

sk_first="$(printf '%s\n' "$sk_names" | head -1)"
sk_second="$(printf '%s\n' "$sk_names" | sed -n 2p)"
sk_tdir="home/dot_claude/skills"

sk_mdir="$(sk_mutant empty-template)"
printf '{{ "" }}\n' >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint empty-template "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant blank-template)"
printf '{{ "   " }}\n' >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint blank-template "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant exact)"
mv "$sk_mdir/home/dot_claude/skills" "$sk_mdir/home/dot_claude/exact_skills"
sk_meta_lint exact 'exact_ under dot_claude: dot_claude/exact_skills'
sk_mdir="$(sk_mutant if-branch)"
printf '{{ if true }}{{ .chezmoi.homeDir }}/.agents/skills/%s{{ end }}\n' "$sk_first" >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint if-branch "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant absolute-path)"
printf '/Users/someone/.agents/skills/%s\n' "$sk_first" >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint absolute-path "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant name-mismatch)"
printf '{{ .chezmoi.homeDir }}/.agents/skills/%s\n' "$sk_second" >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint name-mismatch "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant two-lines)"
printf '{{ .chezmoi.homeDir }}/.agents/skills/%s\n\n' "$sk_first" >"$sk_mdir/$sk_tdir/symlink_$sk_first.tmpl"
sk_meta_lint two-lines "not the fixed single line: symlink_$sk_first"
sk_mdir="$(sk_mutant cc-notes-link)"
printf '{{ .chezmoi.homeDir }}/.agents/skills/cc-notes\n' >"$sk_mdir/$sk_tdir/symlink_cc-notes.tmpl"
sk_meta_lint cc-notes-link 'unmanaged name declared: symlink_cc-notes'
sk_mdir="$(sk_mutant cc-notes-dir)"
mkdir -p "$sk_mdir/$sk_tdir/cc-notes"
printf 'mine\n' >"$sk_mdir/$sk_tdir/cc-notes/SKILL.md"
sk_meta_lint cc-notes-dir 'unexpected entry: dot_claude/skills/cc-notes'
sk_mdir="$(sk_mutant unsafe-name)"
printf '{{ .chezmoi.homeDir }}/.agents/skills/Bad.Name\n' >"$sk_mdir/$sk_tdir/symlink_Bad.Name.tmpl"
sk_meta_lint unsafe-name 'unsafe name: symlink_Bad.Name'
sk_mdir="$(sk_mutant skills-dir-link)"
printf '{{ .chezmoi.homeDir }}/.agents/skills\n' >"$sk_mdir/home/dot_claude/symlink_skills.tmpl"
sk_meta_lint skills-dir-link 'symlink_ outside dot_claude/skills: dot_claude/symlink_skills'
sk_mdir="$(sk_mutant no-b2)"
sed '/^{{ range \$f := glob/,$d' "$sk_src/home/.chezmoiignore" >"$sk_mdir/home/.chezmoiignore"
sk_meta_lint no-b2 'B2 exclusion missing'

# --- isolation guard checks (no chezmoi is run) --------------------------------

sk_ok_case="$sk_root/case-guard"
mkdir -p "$sk_ok_case"
sk_guard "$sk_src" "$sk_ok_case" "$sk_ok_case/home" -- relative --include=all '{"chezmoi":{"os":"windows"}}' &&
  ok "skills (guard): test paths are accepted" || ng "skills (guard): test paths refused: $sk_guard_msg"
sk_bad_list="/|$sk_root/../outside|~/.claude/skills|$sk_root_p/../x|relative/path"
if [ -n "$sk_live_home_p" ]; then
  ln -s "$sk_live_home_p" "$sk_root/escape"
  sk_bad_list="$sk_bad_list|$sk_live_home|$sk_live_home/.claude/skills|$sk_root/escape|$sk_root/escape/.claude"
fi
split "$sk_bad_list"
sk_accepted=""
for sk_p in "${split_fields[@]}"; do
  sk_guard "$sk_ok_case" "$sk_p" && sk_accepted="$sk_accepted [$sk_p]"
  sk_guard "$sk_ok_case" -- "$sk_p" && case "$sk_p" in relative/*) ;; *) sk_accepted="$sk_accepted [arg $sk_p]" ;; esac
done
[ -z "$sk_accepted" ] && ok "skills (guard): live HOME, /, .., ~, relative and symlinked paths out of the test root are refused" ||
  ng "skills (guard): accepted$sk_accepted"

# --- layer 2: behaviour ---------------------------------------------------------

sk_chezmoi="$(command -v chezmoi 2>/dev/null)"
if [ -z "$sk_chezmoi" ]; then
  skip "skills (behaviour and meta behaviour): chezmoi not installed"
else
  printf '# %s (expectations measured with v2.73.3)\n' "$("$sk_chezmoi" --version 2>/dev/null | cut -d, -f1)"

  if [ -n "$sk_live_home_p" ]; then
    sk_out="$(sk_cz "$sk_src" "$sk_live_home" macos managed)"
    [ $? = 125 ] && ok "skills (guard): sk_cz refuses the live HOME without running chezmoi" ||
      ng "skills (guard): sk_cz ran against the live HOME" "$sk_out"
  fi
  sk_expected_refusals=$sk_refused

  # sk_case NAME [SRC]: a case directory with a HOME like the live one: every
  # declared skill deployed by APM and linked for Claude, plus unmanaged
  # entries. Other managed targets are applied first (symlinks excluded) so that
  # `chezmoi status` and `chezmoi diff` without arguments only show the skills.
  # Not for a broken SRC (meta cases), whose apply could already delete things.
  sk_case() {
    local c="$sk_root/case-$1" h n
    h="$c/home"
    mkdir -p "$h/.agents/skills" "$h/.claude/skills/cc-notes" "$h/.claude/skills/synced/uuid-1" "$h/elsewhere/other"
    printf 'cc\n' >"$h/.claude/skills/cc-notes/SKILL.md"
    printf 's\n' >"$h/.claude/skills/synced/uuid-1/SKILL.md"
    : >"$h/.claude/skills/synced/.bucket-x"
    : >"$h/.claude/skills/.DS_Store"
    ln -s "$h/elsewhere/other" "$h/.claude/skills/other-link"
    for n in $sk_names; do
      mkdir -p "$h/.agents/skills/$n"
      printf 'x\n' >"$h/.agents/skills/$n/SKILL.md"
      ln -s "$h/.agents/skills/$n" "$h/.claude/skills/$n"
    done
    [ -z "${2:-}" ] && sk_cz "$sk_src" "$c" macos apply --exclude=symlinks >/dev/null
    printf '%s\n' "$c"
  }

  # sk_snap HOME: every entry under ~/.claude/skills with type, link target and
  # inode (a re-created link gets a new inode), file checksum.
  sk_snap() {
    (cd "$1/.claude/skills" 2>/dev/null && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then
        printf 'L %s -> %s #%s\n' "$p" "$(readlink "$p")" "$(ls -di "$p" | awk '{print $1}')"
      elif [ -d "$p" ]; then
        printf 'D %s\n' "$p"
      else
        printf 'F %s %s\n' "$p" "$(cksum <"$p")"
      fi
    done)
  }
  # sk_unmanaged HOME: the snapshot of cc-notes, synced/, .DS_Store, other-link.
  sk_unmanaged() { sk_snap "$1" | grep -E '^[LDF] \./(cc-notes|synced|\.DS_Store|other-link)( |/|$)'; }
  # sk_links HOME: number of symlinks among the declared names.
  sk_links() {
    local n k=0
    for n in $sk_names; do [ -L "$1/.claude/skills/$n" ] && k=$((k + 1)); done
    echo "$k"
  }
  # sk_managed SRC CASE [ARGS]: managed targets under .claude.
  sk_managed() { sk_cz "$1" "$2" macos managed --include=all "${@:3}" | grep '^\.claude/skills' ; }
  sk_expect_managed() { # NAMES...: the managed list for .claude/skills with those links
    local n
    { echo ".claude/skills"; for n in "$@"; do echo ".claude/skills/$n"; done; } | LC_ALL=C sort
  }

  # B1. healthy: the 10 existing links are already right and stay untouched.
  sk_c="$(sk_case healthy)"
  sk_h="$sk_c/home"
  sk_before="$(sk_snap "$sk_h")"
  # shellcheck disable=SC2086 # names are checked by sk_lint
  sk_want="$(sk_expect_managed $sk_names)"
  sk_got="$(sk_managed "$sk_src" "$sk_c")"
  [ "$sk_got" = "$sk_want" ] && ok "skills (healthy): managed = the $sk_count declared links (no cc-notes, synced, .DS_Store)" ||
    ng "skills (healthy): managed list" "$sk_got"
  sk_status="$(sk_cz "$sk_src" "$sk_c" macos status)"
  sk_diff="$(sk_cz "$sk_src" "$sk_c" macos diff)"
  sk_dry="$(sk_cz "$sk_src" "$sk_c" macos apply --dry-run --verbose)"
  sk_cz "$sk_src" "$sk_c" macos verify >/dev/null
  sk_verify=$?
  [ -z "$sk_status$sk_diff$sk_dry" ] && [ "$sk_verify" = 0 ] &&
    ok "skills (healthy): status, diff (no args), apply --dry-run empty; verify 0" ||
    ng "skills (healthy): verify=$sk_verify" "status: $sk_status
diff: $sk_diff
dry-run: $sk_dry"
  sk_out="$(sk_cz "$sk_src" "$sk_c" macos apply --verbose "$sk_h/.claude/skills")"
  sk_rc=$?
  [ "$sk_rc" = 0 ] && [ -z "$sk_out" ] && [ "$(sk_snap "$sk_h")" = "$sk_before" ] &&
    ok "skills (healthy): apply in the isolated HOME changes nothing (same link inodes)" ||
    ng "skills (healthy): apply rc=$sk_rc" "$sk_out
$(sk_snap "$sk_h")"

  # B2. APM not installed, ~/.claude/skills holds only unmanaged entries.
  sk_c="$(sk_case no-apm)"
  sk_h="$sk_c/home"
  rm -rf "$sk_h/.agents"
  for sk_n in $sk_names; do rm "$sk_h/.claude/skills/$sk_n"; done
  sk_before="$(sk_unmanaged "$sk_h")"
  sk_got="$(sk_managed "$sk_src" "$sk_c")"
  sk_status="$(sk_cz "$sk_src" "$sk_c" macos status)"
  sk_cz "$sk_src" "$sk_c" macos apply "$sk_h/.claude/skills" >/dev/null
  [ "$sk_got" = ".claude/skills" ] && [ -z "$sk_status" ] && [ "$(sk_links "$sk_h")" = 0 ] &&
    [ "$(sk_unmanaged "$sk_h")" = "$sk_before" ] &&
    ok "skills (no APM): nothing declared is managed, status empty, apply creates no link" ||
    ng "skills (no APM): links=$(sk_links "$sk_h")" "managed: $sk_got
status: $sk_status"

  # B2'. a fresh HOME without ~/.claude: chezmoi v2.73.3 creates the empty
  # ~/.claude/skills directory (it is a managed directory) but no link.
  sk_c="$sk_root/case-fresh"
  mkdir -p "$sk_c"
  sk_cz "$sk_src" "$sk_c" macos apply >/dev/null
  sk_rc=$?
  sk_entries="$(cd "$sk_c/home/.claude/skills" 2>/dev/null && find . -mindepth 1 | wc -l | tr -d ' ')"
  [ "$sk_rc" = 0 ] && [ "$(find "$sk_c/home" -type l | wc -l | tr -d ' ')" = 0 ] &&
    ok "skills (fresh HOME, no APM): full apply creates no symlink anywhere" ||
    ng "skills (fresh HOME, no APM): rc=$sk_rc" "$(find "$sk_c/home" -type l)"
  [ -d "$sk_c/home/.claude/skills" ] && [ ! -L "$sk_c/home/.claude/skills" ] && [ "$sk_entries" = 0 ] &&
    ok "skills (fresh HOME, no APM): ~/.claude/skills is created as an empty directory (v2.73.3)" ||
    ng "skills (fresh HOME, no APM): ~/.claude/skills is not an empty directory" "$(ls -la "$sk_c/home/.claude" 2>&1)"

  # B3. APM deployed a skill that is not declared: it is not linked.
  sk_c="$(sk_case apm-only)"
  sk_h="$sk_c/home"
  mkdir -p "$sk_h/.agents/skills/new-skill"
  printf 'x\n' >"$sk_h/.agents/skills/new-skill/SKILL.md"
  sk_got="$(sk_managed "$sk_src" "$sk_c")"
  sk_cz "$sk_src" "$sk_c" macos apply "$sk_h/.claude/skills" >/dev/null
  [ "$sk_got" = "$sk_want" ] && [ ! -e "$sk_h/.claude/skills/new-skill" ] && [ ! -L "$sk_h/.claude/skills/new-skill" ] &&
    ok "skills (APM-only skill): not managed, no link created" ||
    ng "skills (APM-only skill)" "$sk_got"

  # B4. APM removed a skill: its declaration drops out (B2) and the link left
  # behind is not deleted (doctor warns about it instead).
  sk_c="$(sk_case removed)"
  sk_h="$sk_c/home"
  rm -rf "$sk_h/.agents/skills/$sk_first"
  sk_before="$(sk_snap "$sk_h")"
  sk_got="$(sk_managed "$sk_src" "$sk_c")"
  sk_status="$(sk_cz "$sk_src" "$sk_c" macos status)"
  sk_cz "$sk_src" "$sk_c" macos apply "$sk_h/.claude/skills" >/dev/null
  ! printf '%s\n' "$sk_got" | grep -qx ".claude/skills/$sk_first" && [ -z "$sk_status" ] &&
    [ "$(sk_snap "$sk_h")" = "$sk_before" ] && [ "$(readlink "$sk_h/.claude/skills/$sk_first")" = "$sk_h/.agents/skills/$sk_first" ] &&
    ok "skills (skill removed by APM): unmanaged, status empty, the dangling link is kept" ||
    ng "skills (skill removed by APM)" "managed: $sk_got
status: $sk_status
$(sk_snap "$sk_h")"

  # B5. only some APM skills exist and none is linked yet: exactly those are
  # managed, and apply links exactly those, to the HOME of the run.
  sk_c="$(sk_case partial)"
  sk_h="$sk_c/home"
  for sk_n in $sk_names; do
    rm "$sk_h/.claude/skills/$sk_n"
    [ "$sk_n" = "$sk_first" ] || [ "$sk_n" = "$sk_second" ] || rm -rf "$sk_h/.agents/skills/$sk_n"
  done
  sk_got="$(sk_managed "$sk_src" "$sk_c")"
  sk_status="$(sk_cz "$sk_src" "$sk_c" macos status)"
  sk_cz "$sk_src" "$sk_c" macos apply "$sk_h/.claude/skills" >/dev/null
  [ "$sk_got" = "$(sk_expect_managed "$sk_first" "$sk_second")" ] &&
    [ "$sk_status" = "$(printf ' A .claude/skills/%s\n A .claude/skills/%s' "$sk_first" "$sk_second")" ] &&
    [ "$(sk_links "$sk_h")" = 2 ] && [ "$(readlink "$sk_h/.claude/skills/$sk_first")" = "$sk_h/.agents/skills/$sk_first" ] &&
    [ "$(readlink "$sk_h/.claude/skills/$sk_second")" = "$sk_h/.agents/skills/$sk_second" ] &&
    ok "skills (partial APM): only the 2 present skills are managed (status A) and linked" ||
    ng "skills (partial APM): links=$(sk_links "$sk_h")" "managed: $sk_got
status: $sk_status"

  # B6. Windows native: .claude is excluded altogether (.chezmoi.os overridden,
  # as platform.test.sh does).
  sk_c="$(sk_case windows)"
  sk_got="$(sk_cz "$sk_src" "$sk_c" macos --override-data '{"chezmoi":{"os":"windows"}}' managed --include=all | grep '^\.claude')"
  [ -z "$sk_got" ] && ok "skills (windows): nothing under .claude is managed" ||
    ng "skills (windows): .claude targets" "$sk_got"

  # B7. WSL (fake uname): links target the HOME of the run.
  sk_c="$(sk_case wsl)"
  sk_h="$sk_c/home"
  sk_status="$(sk_cz "$sk_src" "$sk_c" wsl status "$sk_h/.claude/skills")"
  sk_bad=""
  for sk_n in $sk_names; do
    [ "$(sk_cz "$sk_src" "$sk_c" wsl cat "$sk_h/.claude/skills/$sk_n")" = "$sk_h/.agents/skills/$sk_n" ] || sk_bad="$sk_bad $sk_n"
  done
  [ -z "$sk_status" ] && [ -z "$sk_bad" ] && ok "skills (wsl): status empty; every link renders as <HOME>/.agents/skills/<name>" ||
    ng "skills (wsl): wrong target:$sk_bad" "$sk_status"

  # A. drift at one declared path. For each case: status (no args) shows only
  # that path, diff (no args) and verify see it, dry-run changes nothing, apply
  # in the isolated HOME leaves the other links and the unmanaged entries alone.
  # sk_drift NAME STATUS DRYRUN_REGEX: prepares nothing; the caller has broken
  # $sk_h/.claude/skills/$sk_first.
  sk_drift() {
    local label="$1" want_status="$2" dry_re="$3" st df dr vf before_un before_all after
    before_un="$(sk_unmanaged "$sk_h")"
    before_all="$(sk_snap "$sk_h" | grep -vE " \./$sk_first( |/|$)")"
    st="$(sk_cz "$sk_src" "$sk_c" macos status)"
    df="$(sk_cz "$sk_src" "$sk_c" macos diff)"
    sk_cz "$sk_src" "$sk_c" macos verify "$sk_h/.claude/skills" >/dev/null
    vf=$?
    after="$(sk_snap "$sk_h")"
    dr="$(sk_cz "$sk_src" "$sk_c" macos apply --dry-run --verbose)"
    if [ "$st" = "$want_status" ] && printf '%s\n' "$df" | grep -Fqx "+$sk_h/.agents/skills/$sk_first" &&
      [ "$vf" = 1 ] && printf '%s\n' "$dr" | grep -qE -- "$dry_re" && [ "$(sk_snap "$sk_h")" = "$after" ]; then
      ok "skills ($label): detected by status, diff (no args), verify and dry-run; dry-run changes nothing"
    else
      ng "skills ($label): status/diff/verify=$vf/dry-run" "status: $st
diff: $df
dry-run: $dr"
    fi
    sk_cz "$sk_src" "$sk_c" macos apply "$sk_h/.claude/skills" >/dev/null
    if [ -L "$sk_h/.claude/skills/$sk_first" ] &&
      [ "$(readlink "$sk_h/.claude/skills/$sk_first")" = "$sk_h/.agents/skills/$sk_first" ] &&
      [ "$(sk_unmanaged "$sk_h")" = "$before_un" ] &&
      [ "$(sk_snap "$sk_h" | grep -vE " \./$sk_first( |/|$)")" = "$before_all" ] &&
      [ -z "$(sk_cz "$sk_src" "$sk_c" macos status)" ]; then
      ok "skills ($label): isolated apply replaces it with the declared link; nothing else changes"
    else
      ng "skills ($label): after apply" "$(sk_snap "$sk_h")"
    fi
  }

  sk_c="$(sk_case elsewhere)"
  sk_h="$sk_c/home"
  mkdir -p "$sk_h/elsewhere/$sk_first"
  rm "$sk_h/.claude/skills/$sk_first"
  ln -s "$sk_h/elsewhere/$sk_first" "$sk_h/.claude/skills/$sk_first"
  sk_drift "link elsewhere" " M .claude/skills/$sk_first" '^new mode 120000'
  # Pinned blind spot (docs/ai-tools.md): `chezmoi diff <directory>` does not
  # show symlink changes below it, so it must never be the only check.
  sk_c="$(sk_case elsewhere-dirdiff)"
  sk_h="$sk_c/home"
  rm "$sk_h/.claude/skills/$sk_first"
  ln -s "$sk_h/elsewhere/other" "$sk_h/.claude/skills/$sk_first"
  sk_out="$(sk_cz "$sk_src" "$sk_c" macos diff "$sk_h/.claude/skills")"
  sk_status="$(sk_cz "$sk_src" "$sk_c" macos status "$sk_h/.claude/skills")"
  [ -z "$sk_out" ] && [ -n "$sk_status" ] &&
    ok "skills (v2.73.3 pin): diff <directory> is empty although status reports the link" ||
    ng "skills (v2.73.3 pin): diff <directory> changed behaviour; update docs/ai-tools.md" "$sk_out"

  sk_c="$(sk_case broken)"
  sk_h="$sk_c/home"
  rm "$sk_h/.claude/skills/$sk_first"
  ln -s "$sk_h/.agents/skills/$sk_first-old" "$sk_h/.claude/skills/$sk_first"
  sk_drift "broken link" " M .claude/skills/$sk_first" '^new mode 120000'

  # DANGER, pinned on purpose: a real directory at a declared path is deleted
  # with its contents and replaced by the link, without a prompt (--no-tty).
  # Only the status / verify / doctor check before apply protects it.
  sk_c="$(sk_case real-dir)"
  sk_h="$sk_c/home"
  rm "$sk_h/.claude/skills/$sk_first"
  mkdir -p "$sk_h/.claude/skills/$sk_first"
  printf 'mine\n' >"$sk_h/.claude/skills/$sk_first/SKILL.md"
  sk_drift "real directory (DANGER)" " M .claude/skills/$sk_first" '^deleted file mode 40755'

  # DANGER, pinned on purpose: the same for a regular file.
  sk_c="$(sk_case real-file)"
  sk_h="$sk_c/home"
  rm "$sk_h/.claude/skills/$sk_first"
  printf 'mine\n' >"$sk_h/.claude/skills/$sk_first"
  sk_drift "regular file (DANGER)" " M .claude/skills/$sk_first" '^deleted file mode 100644'

  # --- layer 3, behaviour: broken sources must fail the layer 2 checks ---------

  # Without B2, a HOME without APM gets dangling links.
  sk_c="$sk_root/case-meta-no-b2"
  mkdir -p "$sk_c"
  sk_cz "$sk_root/mut-no-b2" "$sk_c" macos apply >/dev/null
  sk_k="$(find "$sk_c/home" -type l | wc -l | tr -d ' ')"
  [ "$sk_k" = "$sk_count" ] && ok "skills (meta, behaviour): without B2, a HOME without APM gets $sk_k dangling links" ||
    ng "skills (meta, behaviour): no-b2 mutant was not caught by the no-APM check (links=$sk_k)"

  # DANGER, pinned: an empty or blank template deletes what is at the path.
  for sk_m in empty-template blank-template; do
    sk_c="$(sk_case "meta-$sk_m" "$sk_root/mut-$sk_m")"
    sk_status="$(sk_cz "$sk_root/mut-$sk_m" "$sk_c" macos status "$sk_c/home/.claude/skills")"
    [ "$sk_status" = " D .claude/skills/$sk_first" ] &&
      ok "skills (meta, behaviour): $sk_m makes status report a deletion (healthy check fails)" ||
      ng "skills (meta, behaviour): $sk_m not caught by status" "$sk_status"
  done
  sk_c="$(sk_case meta-exact "$sk_root/mut-exact")"
  sk_status="$(sk_cz "$sk_root/mut-exact" "$sk_c" macos status "$sk_c/home/.claude/skills")"
  printf '%s\n' "$sk_status" | grep -qx ' D .claude/skills/cc-notes' &&
    printf '%s\n' "$sk_status" | grep -qx ' D .claude/skills/synced' &&
    printf '%s\n' "$sk_status" | grep -qx ' D .claude/skills/.DS_Store' &&
    ok "skills (meta, behaviour): exact_skills makes status report deleting cc-notes, synced, .DS_Store" ||
    ng "skills (meta, behaviour): exact_ mutant not caught by status" "$sk_status"
  sk_c="$(sk_case meta-cc-notes "$sk_root/mut-cc-notes-dir")"
  sk_got="$(sk_managed "$sk_root/mut-cc-notes-dir" "$sk_c")"
  printf '%s\n' "$sk_got" | grep -q '^\.claude/skills/cc-notes' &&
    ok "skills (meta, behaviour): managing cc-notes shows up in managed (healthy check fails)" ||
    ng "skills (meta, behaviour): cc-notes mutant not caught by managed" "$sk_got"

  [ "$sk_refused" = "$sk_expected_refusals" ] && ok "skills (guard): no chezmoi run was refused by the isolation guard" ||
    ng "skills (guard): $((sk_refused - sk_expected_refusals)) chezmoi run(s) refused"
fi
