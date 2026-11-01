# scripts/doctor.sh: exit status for healthy and broken environments. Every
# declared command is a stub, so results do not depend on the host.
# shellcheck shell=bash

D="$TEST_TMP/doctor"
mkdir -p "$D/stubs" "$D/hidden" "$D/home"
for name in $(sed 's/#.*//' "$REPO/packages/commands/common.txt" "$REPO/packages/commands/wsl.txt" \
  "$REPO/packages/commands/macos.txt"); do
  stub "$D/stubs/$name" 'exit 0'
done
stub "$D/stubs/nvim" 'echo "NVIM v0.12.6"'
stub "$D/stubs/mise" 'case "$1" in which) [ -n "${MISE_HAS:-}" ] && [ "$2" = "$MISE_HAS" ] && echo "/m/installs/$2/bin/$2" || exit 1 ;; esac; exit 0'
stub "$D/stubs/chezmoi" "case \"\$1\" in source-path) echo $REPO/home ;; esac; exit 0"

# doctor_run PATH_PREFIX [VAR=value...]: doctor on a fake WSL2 Ubuntu machine.
doctor_run() {
  local prefix="$1"
  shift
  env -i HOME="$D/home" MISE_SHELL=zsh PATH="$prefix:$D/stubs:$TOOLS" \
    DOTFILES_OSRELEASE_FILE="$FX/wsl2" DOTFILES_OS_RELEASE_FILE="$FX/ubuntu" "$@" \
    bash "$REPO/scripts/doctor.sh" 2>&1
}
hide() { mv "$D/stubs/$1" "$D/hidden/$1"; }
unhide() { mv "$D/hidden/$1" "$D/stubs/$1"; }
linux="$TEST_TMP/uname-linux"

chmod -R a-w "$D/home"
out="$(doctor_run "$linux")"
rc=$?
chmod -R u+w "$D/home"
check "doctor (WSL2, everything present, read-only HOME): exit 0" 0 "$rc" "$out" \
  'Platform +wsl' 'WSL2, ubuntu 24.04' 'Version +ok +0\.12 >= 0\.11' 'Result: 0 error'
printf '%s\n' "$out" | grep -qiE 'permission denied|not permitted|cannot create' &&
  ng "doctor tried to write" "$out" || ok "doctor: no write attempts"

out="$(doctor_run "$linux" DOTFILES_OSRELEASE_FILE="$FX/plain")"
rc=$?
check "doctor (plain Linux): warning only, common list checked" 0 "$rc" "$out" \
  'Platform +linux' 'not a supported target'

out="$(doctor_run "$TEST_TMP/uname-darwin")"
rc=$?
check "doctor (macOS): common + macos lists, exit 0" 0 "$rc" "$out" 'Platform +macos' 'packages/commands/macos.txt'

hide helm
out="$(doctor_run "$linux")"
rc=$?
unhide helm
check "doctor: missing command is 'not installed', exit 1" 1 "$rc" "$out" 'helm +error +not installed'

hide node
out="$(doctor_run "$linux" MISE_HAS=node)"
rc=$?
unhide node
check "doctor: tool installed by mise but not on PATH is 'misconfigured', exit 1" 1 "$rc" "$out" \
  'node +error +misconfigured: installed by mise'

hide mise
out="$(doctor_run "$linux")"
rc=$?
unhide mise
check "doctor: mise not installed, exit 1" 1 "$rc" "$out" 'mise +error +not installed'
[ "$(printf '%s\n' "$out" | grep -cE '^mise +error')" = 1 ] && ok "doctor: a missing mise is counted once" ||
  ng "doctor: mise counted more than once" "$out"

for r in java node go; do hide "$r"; done
out="$(doctor_run "$linux")"
rc=$?
for r in java node go; do unhide "$r"; done
check "doctor: Java / Node / Go not installed, exit 1" 1 "$rc" "$out" \
  'java +error +not installed' 'node +error +not installed' 'go +error +not installed'

out="$(doctor_run "$linux:relative/bin::$D/stubs")"
rc=$?
check "doctor: relative / empty PATH entries are errors, duplicates warned" 1 "$rc" "$out" \
  'PATH +error +misconfigured: relative' 'relative/bin' '\(empty\)' 'PATH +warn +duplicate'

out="$(doctor_run "$linux:$D/stubs")"
rc=$?
check "doctor: duplicate PATH entries alone are a warning, exit 0" 0 "$rc" "$out" 'PATH +warn +duplicate' 'Result: 0 error'

for case_line in "NVIM v0.10.4|1|Neovim +error +misconfigured: 0\.10 is older" \
  "NVIM v0.11.0-dev-1234+g0123|0|Version +ok" "NVIM v1.0.0|0|Version +ok"; do
  version="${case_line%%|*}"
  rest="${case_line#*|}"
  stub "$D/stubs/nvim" "echo \"$version\""
  out="$(doctor_run "$linux")"
  rc=$?
  check "doctor: Neovim '$version'" "${rest%%|*}" "$rc" "$out" "${rest#*|}"
done
stub "$D/stubs/nvim" 'echo "NVIM v0.12.6"'

# --- AI tools: APM skills for Claude Code -----------------------------------
# Each case gets its own fake HOME under $D/ai. Symlinks are made by this shell;
# doctor runs with only $TOOLS and the stubs on PATH, plus readlink.
ln -sf "$(command -v readlink)" "$D/stubs/readlink"
AI="$D/ai"
mkdir -p "$AI"

# ai_lock HOME NAME...: an APM 0.14.2 lock that deployed the named skills.
ai_lock() {
  local h="$1" n
  shift
  mkdir -p "$h/.apm"
  {
    printf '%s\n' "lockfile_version: '1'" "apm_version: 0.14.2" "dependencies:" \
      "- repo_url: Carp15/my-agent-harness" "  deployed_files:"
    for n in "$@"; do printf '  - .agents/skills/%s\n' "$n"; done
    printf '%s\n' "  - .codex/agents/planner.toml" "  deployed_file_hashes:" \
      "    .codex/agents/planner.toml: sha256:00" "  content_hash: sha256:00"
  } >"$h/.apm/apm.lock.yaml"
}

# ai_home CASE: a healthy HOME with skills alpha, beta, gamma linked for Claude,
# plus Claude's own cc-notes and synced/. Prints the HOME path.
ai_home() {
  local h="$AI/$1" n
  mkdir -p "$h/.claude/skills/cc-notes" "$h/.claude/skills/synced"
  echo '---' >"$h/.claude/skills/cc-notes/SKILL.md"
  ai_lock "$h" alpha beta gamma
  for n in alpha beta gamma; do
    mkdir -p "$h/.agents/skills/$n"
    echo '---' >"$h/.agents/skills/$n/SKILL.md"
    ln -s "$h/.agents/skills/$n" "$h/.claude/skills/$n"
  done
  printf '%s' "$h"
}

# The AI tools section of a doctor output.
ai_section() { printf '%s\n' "$1" | sed -n '/^AI tools/,/^Required commands/p'; }

# ai_check NAME HOME WARNINGS PATTERN... [-- VAR=value...]: doctor on HOME must
# exit 0, print exactly WARNINGS warnings in the AI section, and match PATTERNs.
ai_check() {
  local name="$1" h="$2" want="$3" section count
  shift 3
  local patterns=() vars=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do patterns+=("$1"); shift; done
  [ $# -gt 0 ] && shift
  vars=("$@")
  out="$(doctor_run "$linux" HOME="$h" ${vars[@]+"${vars[@]}"})"
  rc=$?
  section="$(ai_section "$out")"
  count="$(printf '%s\n' "$section" | grep -cE '^[^ ].{11} warn ')"
  if [ "$count" != "$want" ]; then
    ng "$name ($count AI warning(s), want $want)" "$section"
    return
  fi
  check "$name" 0 "$rc" "$section" ${patterns[@]+"${patterns[@]}"}
}

# 1, 9, 15. Healthy, with unmanaged entries, on a read-only HOME: no warnings,
# and nothing in HOME changes.
h="$(ai_home ok)"
mkdir -p "$h/.agents/skills/from-other-tool"
before="$(ls -laR "$h")"
chmod -R a-w "$h"
ai_check "doctor AI: healthy, read-only HOME, unmanaged entries left alone" "$h" 0 \
  'Claude +ok +3 of 3 APM skill' 'Unmanaged +cc-notes synced' 'Not in lock +from-other-tool'
chmod -R u+w "$h"
printf '%s\n' "$out" | grep -qiE 'permission denied|not permitted|cannot create' &&
  ng "doctor AI tried to write" "$out" || ok "doctor AI: no write attempts"
[ "$before" = "$(ls -laR "$h")" ] && ok "doctor AI: HOME unchanged" || ng "doctor AI: HOME changed"

# 2. A skill in the lock without a Claude link.
h="$(ai_home missing-link)"
rm "$h/.claude/skills/beta"
ai_check "doctor AI: missing link warns" "$h" 1 'Claude link +warn +beta: not linked' '2 of 3 APM skill'

# 3. A broken link for a skill in the lock.
h="$(ai_home broken)"
rm "$h/.claude/skills/beta"
ln -s "$h/.agents/skills/beta-old" "$h/.claude/skills/beta"
ai_check "doctor AI: broken link warns" "$h" 1 'Claude link +warn +beta: broken link'

# 4. A link that points somewhere else.
h="$(ai_home elsewhere)"
mkdir -p "$h/elsewhere/beta"
rm "$h/.claude/skills/beta"
ln -s "$h/elsewhere/beta" "$h/.claude/skills/beta"
ai_check "doctor AI: link to another place warns" "$h" 1 'Claude link +warn +beta: points elsewhere'

# 5. SKILL.md missing.
h="$(ai_home no-skill-md)"
rm "$h/.agents/skills/gamma/SKILL.md"
ai_check "doctor AI: missing SKILL.md warns" "$h" 1 'Skills +warn +gamma: SKILL.md missing'

# APM skill directory missing (the link is then broken too).
h="$(ai_home no-apm-dir)"
rm -r "$h/.agents/skills/gamma"
ai_check "doctor AI: skill in the lock but not deployed warns" "$h" 2 \
  'Skills +warn +gamma: in the APM lock but' 'Claude link +warn +gamma: broken link'

# 6. No APM.
h="$(ai_home no-apm)"
rm -r "$h/.apm"
ai_check "doctor AI: no APM lock is skipped" "$h" 0 'APM +not set up'

# 7. Unreadable lock.
h="$(ai_home unreadable)"
chmod 000 "$h/.apm/apm.lock.yaml"
ai_check "doctor AI: unreadable lock warns" "$h" 1 'APM lock +warn +.*not a readable file'
chmod 644 "$h/.apm/apm.lock.yaml"

# 8. Unknown lock formats are not read as zero skills; an empty one is.
h="$(ai_home unknown-format)"
printf '%s\n' "lockfile_version: '2'" "packages:" "  - alpha" >"$h/.apm/apm.lock.yaml"
ai_check "doctor AI: unknown lock version warns" "$h" 1 'APM lock +warn +unrecognized format'
printf '%s\n' "lockfile_version: '1'" "dependencies:" "- repo_url: x/y" "  files:" "  - .agents/skills/alpha" \
  >"$h/.apm/apm.lock.yaml"
ai_check "doctor AI: lock without deployed_files warns" "$h" 1 'APM lock +warn +unrecognized format'
printf '%s\n' "lockfile_version: '1'" "dependencies: []" >"$h/.apm/apm.lock.yaml"
ai_check "doctor AI: lock with no dependencies is skipped" "$h" 0 'APM skills +no skills deployed'
ai_lock "$h" alpha beta/nested
ai_check "doctor AI: nested skill entry warns" "$h" 1 'APM lock +warn +unrecognized skill entries: \.agents/skills/beta/nested'

# 10. Unmanaged symlinks (resolving, or broken outside ~/.agents/skills) are listed only.
h="$(ai_home unmanaged-links)"
mkdir -p "$h/elsewhere/mine"
ln -s "$h/elsewhere/mine" "$h/.claude/skills/mine"
ln -s "$h/nowhere/gone" "$h/.claude/skills/gone-elsewhere"
ln -s "$h/.agents/skills/from-other-tool" "$h/.claude/skills/from-other-tool"
mkdir -p "$h/.agents/skills/from-other-tool"
ai_check "doctor AI: unmanaged symlinks are not warned" "$h" 0 \
  'Unmanaged .*mine' 'Unmanaged .*gone-elsewhere' 'Unmanaged .*from-other-tool'

# 11. A link left after APM removed the skill.
h="$(ai_home removed)"
ln -s "$h/.agents/skills/old-skill" "$h/.claude/skills/old-skill"
ai_check "doctor AI: link left after a removed skill warns" "$h" 1 \
  'Claude link +warn +old-skill: broken link into ~/\.agents/skills, not in the APM lock'

# 12. CLAUDE_CONFIG_DIR.
h="$(ai_home config-dir)"
mv "$h/.claude" "$h/alt-claude"
ai_check "doctor AI: CLAUDE_CONFIG_DIR is used" "$h" 0 'Claude +ok +3 of 3' -- CLAUDE_CONFIG_DIR="$h/alt-claude"
ai_check "doctor AI: empty CLAUDE_CONFIG_DIR falls back to ~/.claude" "$h" 0 'Claude +not set up \(~/\.claude' -- CLAUDE_CONFIG_DIR=
ai_check "doctor AI: relative CLAUDE_CONFIG_DIR warns" "$h" 1 'Claude +warn +CLAUDE_CONFIG_DIR is not an absolute path' -- CLAUDE_CONFIG_DIR=alt-claude
touch "$h/not-a-dir"
ai_check "doctor AI: CLAUDE_CONFIG_DIR that is a file warns" "$h" 1 'Claude +warn +.*is not a directory' -- CLAUDE_CONFIG_DIR="$h/not-a-dir"

# 13. No Claude Code: no warnings about links.
h="$(ai_home no-claude)"
rm -r "$h/.claude"
ai_check "doctor AI: no Claude Code is skipped without warnings" "$h" 0 'Claude +not set up' 'APM skills +3 skill'

# 14. Windows Git Bash skips the section.
h="$(ai_home windows)"
rm "$h/.claude/skills/beta"
out="$(doctor_run "$TEST_TMP/uname-mingw" HOME="$h")"
rc=$?
check "doctor AI: Git Bash skips the section" 0 "$rc" "$(ai_section "$out")" 'Skipped on this platform'
