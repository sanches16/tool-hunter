#!/usr/bin/env bash
# Optional independent critic. Grok runs in plan (read-only) permission mode
# with edit/write/shell tools denied; afterwards Git proves nothing but the
# report changed. Never uses --always-approve.
source "$(dirname "$0")/lib.sh"
report="$REVIEWS_DIR/GROK_CRITIC.md"

command -v grok >/dev/null || fail "grok not installed (critic is optional)"
[ -z "$(git status --porcelain)" ] || fail "working tree must be clean before the critic runs"
base="$(git rev-parse HEAD)"

prompt="$(cat "$(dirname "$0")/../prompts/grok-critic.md")
Base commit for the diff: 288cdc7..$base"

env -u XAI_API_KEY grok -p "$prompt" --cwd "$PWD" \
  --permission-mode plan --deny Edit --deny Write --deny 'Bash(*)' \
  --max-turns 40 --output-format plain > .agent-out/grok-critic.txt 2>&1 || true

changed="$(git status --porcelain)"
[ -z "$changed" ] || { echo "$changed"; fail "Grok changed repository files; inspect them before resuming"; }
pass "Grok made no repository changes"

[ -s .agent-out/grok-critic.txt ] || fail "Grok produced no output"
{ echo "# GROK_CRITIC"; echo; echo "Read-only critique of $base."; echo; cat .agent-out/grok-critic.txt; } > "$report"
pass "saved $report"
