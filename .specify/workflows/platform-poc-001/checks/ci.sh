#!/usr/bin/env bash
# Observes GitHub Actions for the pushed HEAD on BOTH paths required by FR-010:
#   push         — the run triggered by pushing the implementation commit;
#   pull_request — the run for a proposed change from poc/platform-poc-001 into
#                  main. An existing open PR is reused; otherwise a DRAFT PR is
#                  created for verification only. No approval, no merge, no
#                  auto-merge: the draft PR is not a promotion.
# Sanitized evidence (.agent-out/evidence/ci.json) is written for any outcome;
# exits non-zero unless both runs concluded "success".
# Usage: ci.sh [label]
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="$EVIDENCE_DIR/ci.json"
mkdir -p "$EVIDENCE_DIR"
sha="$(git rev-parse HEAD)"
git fetch -q origin "$POC_BRANCH"
[ "$sha" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD is not pushed"

summarize() {  # summarize <event> <run-json|null> <conclusion> [pr-json]
  jq -n --arg e "$1" --argjson run "$2" --arg c "$3" --argjson pr "${4:-null}" '
    def step($pat): [($run.jobs // [])[].steps[]? | select(.name | test($pat; "i"))] | first
      | if . == null then "not identified" else .conclusion end;
    { event: $e, conclusion: $c, run_url: ($run.url // null), run_id: ($run.databaseId // null),
      head_sha: ($run.headSha // null),
      pull_request: (if $pr == null then null else {number: $pr.number, url: $pr.url, draft: $pr.isDraft} end),
      jobs: [($run.jobs // [])[] | {name, conclusion, url}],
      core_checks: { lint: step("lint"), typecheck: step("typecheck"), build: step("build"),
                     test: step("npm test|\\btest\\b"), "verify:startup": step("verify:startup|verify startup") } }'
}

wait_run() {  # wait_run <event> → prints run JSON or nothing
  local id=""
  for _ in $(seq 1 36); do
    id="$(gh run list --branch "$POC_BRANCH" --commit "$sha" --event "$1" --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
    [ -n "$id" ] && break
    sleep 10
  done
  [ -n "$id" ] || return 0
  gh run watch "$id" --interval 15 >/dev/null 2>&1 || true
  gh run view "$id" --json databaseId,url,conclusion,headSha,jobs
}

# Push path
push_run="$(wait_run push)"
if [ -n "$push_run" ]; then
  push_json="$(summarize push "$push_run" "$(jq -r .conclusion <<<"$push_run")")"
else
  push_json="$(summarize push null no_run_found)"
fi

# Proposed-change path: reuse an open PR or open a draft PR (verification only).
pr="$(gh pr list --head "$POC_BRANCH" --base main --state open --json number,url,isDraft -q '.[0] // empty' 2>/dev/null || true)"
if [ -z "$pr" ]; then
  body="$(printf '%s\n' \
    '<!-- ccr-projects-attribution: {"github_login":"sanches16"} -->' \
    '_Requested by **Sanches**_' '' \
    'Before: PLATFORM-POC-001 changes were verified only by push CI.' '' \
    'After: this draft pull request exists so GitHub Actions also runs the proposed-change (pull_request) path required by FR-010.' '' \
    'How: opened by the platform-poc-001 Spec Kit workflow (checks/ci.sh) for verification only. It is not a promotion, it is not approved or merged by the workflow, and auto-merge is not enabled; merging requires the FINAL HUMAN GATE.' '' \
    '🤖 Generated with [Claude Code](https://claude.com/claude-code)')"
  gh pr create --draft --base main --head "$POC_BRANCH" \
    --title "PLATFORM-POC-001 (draft — proposed-change CI verification only)" --body "$body" >/dev/null \
    || fail "could not create draft PR for pull_request CI"
  pr="$(gh pr list --head "$POC_BRANCH" --base main --state open --json number,url,isDraft -q '.[0] // empty')"
  [ -n "$pr" ] || fail "draft PR not found after creation"
  echo "Opened draft PR $(jq -r .url <<<"$pr") (verification only)"
fi
pr_run="$(wait_run pull_request)"
if [ -n "$pr_run" ]; then
  pr_json="$(summarize pull_request "$pr_run" "$(jq -r .conclusion <<<"$pr_run")" "$pr")"
else
  pr_json="$(summarize pull_request null no_run_found "$pr")"
fi

jq -n --arg label "$label" --arg sha "$sha" --argjson push "$push_json" --argjson prr "$pr_json" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    stage: "ci", label: $label, recorded_at: $at, implementation_sha: $sha,
    push: $push, pull_request: $prr,
    conclusion: (if $push.conclusion == "success" and $prr.conclusion == "success" then "success" else "failure" end) }' > "$evidence"
jq -r '"CI push=\(.push.conclusion) \(.push.run_url) | pull_request=\(.pull_request.conclusion) \(.pull_request.run_url)"' "$evidence"
[ "$(jq -r .conclusion "$evidence")" = "success" ] || fail "CI not green on both push and pull_request for $sha"
pass "CI green on push and pull_request for $sha"
