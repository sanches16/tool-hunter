#!/usr/bin/env bash
# Observes the GitHub Actions run of the pushed HEAD and records sanitized
# evidence (.agent-out/evidence/ci.json) whatever the outcome. Exits non-zero
# unless the run concluded "success"; the workflow records the evidence in
# RESULT before enforcing that outcome.
# Usage: ci.sh [label]
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="$EVIDENCE_DIR/ci.json"
mkdir -p "$EVIDENCE_DIR"
sha="$(git rev-parse HEAD)"
[ "$sha" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD is not pushed"

write() {  # write <conclusion> [run-json]
  jq -n --arg label "$label" --arg sha "$sha" --arg c "$1" --argjson run "${2:-null}" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    def step($pat): [($run.jobs // [])[].steps[]? | select(.name | test($pat; "i"))] | first
      | if . == null then "not identified" else .conclusion end;
    { stage: "ci", label: $label, recorded_at: $at, implementation_sha: $sha, conclusion: $c,
      run_url: ($run.url // null), run_id: ($run.databaseId // null),
      jobs: [($run.jobs // [])[] | {name, conclusion, url}],
      core_checks: { lint: step("lint"), typecheck: step("typecheck"), build: step("build"),
                     test: step("npm test|\\btest\\b"), "verify:startup": step("verify:startup|verify startup") } }' > "$evidence"
}

run_id=""
for _ in $(seq 1 30); do
  run_id="$(gh run list --branch "$POC_BRANCH" --commit "$sha" --event push --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  [ -n "$run_id" ] && break
  sleep 10
done
[ -n "$run_id" ] || { write "no_run_found"; fail "no GitHub Actions run found for $sha"; }

gh run watch "$run_id" --interval 15 >/dev/null 2>&1 || true
run="$(gh run view "$run_id" --json databaseId,url,conclusion,jobs)"
conclusion="$(jq -r .conclusion <<<"$run")"
write "$conclusion" "$run"
jq -r '"CI \(.conclusion) \(.run_url) core=\(.core_checks|tostring)"' "$evidence"
[ "$conclusion" = "success" ] || fail "CI concluded $conclusion (run $run_id)"
pass "CI green for $sha"
