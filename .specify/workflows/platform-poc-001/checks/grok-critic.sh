#!/usr/bin/env bash
# Optional independent critic. Grok runs in plan (read-only) permission mode
# with edit/write/shell tools denied; afterwards Git proves nothing but the
# report changed. Never uses --always-approve.
# Structured evidence (.agent-out/evidence/critic.json) decides participation:
# only exit code 0 with non-empty output produces GROK_CRITIC.md and
# status=success. Any failure removes a stale report, records status=failed
# with the exit code only (no stderr), and exits non-zero.
source "$(dirname "$0")/lib.sh"
report="$REVIEWS_DIR/GROK_CRITIC.md"
evidence="$EVIDENCE_DIR/critic.json"
grok_bin="${GROK_BIN:-grok}"   # override only for verifier self-tests
mkdir -p "$EVIDENCE_DIR" "$REVIEWS_DIR"
base="$(git rev-parse HEAD)"

record() {  # record <status> <exit_code> <reason>
  jq -n --arg s "$1" --argjson rc "$2" --arg r "$3" --arg base "$base" \
    --arg report "$( [ "$1" = success ] && echo "$report" || echo "" )" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{stage: "critic", status: $s, exit_code: $rc, reason: $r, reviewed_sha: $base,
      report: (if $report == "" then null else $report end), recorded_at: $at}' > "$evidence"
}
not_performed() {  # not_performed <exit_code> <reason>
  rm -f "$report"   # never leave a stale or partial report behind
  record failed "$1" "$2"
  fail "critic not performed: $2 (exit $1)"
}

command -v "$grok_bin" >/dev/null || not_performed 127 "grok not installed"
[ -z "$(git status --porcelain -- . ":!$report")" ] || not_performed 1 "working tree not clean before the critic"

prompt="$(cat "$(dirname "$0")/../prompts/grok-critic.md")
Base commit for the diff: 288cdc7..$base"

out=".agent-out/grok-critic.txt"; err=".agent-out/grok-critic.err"
rm -f "$out" "$err"
set +e
env -u XAI_API_KEY "$grok_bin" -p "$prompt" --cwd "$PWD" \
  --permission-mode plan --deny Edit --deny Write --deny 'Bash(*)' \
  --max-turns 40 --output-format plain >"$out" 2>"$err"
rc=$?
set -e

changed="$(git status --porcelain -- . ":!$report")"
[ -z "$changed" ] || { echo "$changed"; not_performed "$rc" "Grok changed repository files"; }
[ "$rc" -eq 0 ] || not_performed "$rc" "grok exited non-zero"
[ -s "$out" ] || not_performed 0 "grok produced no output"
has_secret < "$out" >/dev/null && not_performed 0 "possible secret in grok output"

{ echo "# GROK_CRITIC"; echo; echo "Read-only critique of $base."; echo; cat "$out"; } > "$report"
record success 0 "report produced"
pass "Grok made no repository changes; saved $report"
