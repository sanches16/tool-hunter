#!/usr/bin/env bash
# Deterministic local verification, independent of any agent claim, exactly as
# the approved plan/runtime contract defines it:
#   npm ci → lint → typecheck → build → test → verify:startup
# npm test and verify:startup own their isolated fixtures; this script does not
# create .env and does not start the base Compose services.
# Sanitized evidence (no command output, only exit status, timing and test
# counters) is written to .agent-out/evidence/local-checks.json.
# Usage: local-checks.sh [label]
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="$EVIDENCE_DIR/local-checks.json"
logs=".agent-out/logs"
mkdir -p "$EVIDENCE_DIR" "$logs"

check_protected_artifacts

[ -f package.json ] || fail "package.json missing"
for script in lint typecheck build test verify:startup; do
  jq -e --arg s "$script" '.scripts[$s]' package.json >/dev/null || fail "npm script '$script' missing"
done
[ -f .env.example ] || fail ".env.example missing (FR-05)"
[ -z "$(git ls-files .env)" ] || fail ".env is tracked by Git"
ls .github/workflows/*.y*ml >/dev/null 2>&1 || fail "no GitHub Actions workflow (FR-07)"
[ -f "$RESULT_FILE" ] || fail "$RESULT_FILE missing (T021 creates its structure)"
pass "required scripts and files present"

# Scope guard on changed paths since the approved spec baseline.
if git diff --name-only 288cdc7 -- . ':!specs' ':!.specify' ':!docs' | grep -iE 'avito|telegram|auth|backup|catalog|caddy|orchestr'; then
  fail "implementation touches excluded scope (paths above)"
fi
pass "no excluded-scope paths"

# The file-only implementer cannot run npm; create the lockfile here without
# running any package lifecycle scripts. It is committed with the implementation.
lock_generated=false
if [ ! -f package-lock.json ]; then
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund >"$logs/lockfile.log" 2>&1 \
    || { tail -20 "$logs/lockfile.log"; fail "lockfile generation failed"; }
  lock_generated=true
  pass "package-lock.json created (lockfile only, lifecycle scripts not run)"
fi

tree_before="$(worktree_tree)"
tree="$tree_before"
changed_by_checks="[]"
records="[]"
write_evidence() {
  jq -n --arg label "$label" --arg tree "$tree" --arg before "$tree_before" --argjson changed "$changed_by_checks" \
    --argjson lock "$lock_generated" \
    --arg node "$(node --version)" --arg npm "$(npm --version)" \
    --arg docker "$(docker --version 2>/dev/null || echo unavailable)" \
    --arg compose "$(docker compose version --short 2>/dev/null || echo unavailable)" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson checks "$records" '{
      stage: "local-checks", label: $label, recorded_at: $at, worktree_tree: $tree,
      worktree_tree_before_checks: $before, files_changed_by_checks: $changed,
      lockfile_generated_by_workflow: $lock,
      tools: { node: $node, npm: $npm, docker: $docker, compose: $compose },
      checks: $checks }' > "$evidence"
}

run_check() {  # run_check <name> <command...>
  local name="$1"; shift
  local log="$logs/$name.log" start end rc summary
  start="$(now_ms)"
  set +e; "$@" >"$log" 2>&1; rc=$?; set -e
  end="$(now_ms)"
  # Safe summary only: node test runner counters (TAP "# pass 3" or spec
  # reporter "ℹ pass 3"), never raw output.
  summary="$(grep -oE '^(# |ℹ )(tests|suites|pass|fail|cancelled|skipped|todo) [0-9]+$' "$log" | sed -E 's/^(# |ℹ )//' | tr '\n' ';' || true)"
  records="$(jq --arg n "$name" --arg c "$*" --argjson rc "$rc" --argjson ms "$((end - start))" --arg s "$summary" \
    '. + [{name: $n, command: $c, exit_code: $rc, result: (if $rc == 0 then "PASS" else "FAIL" end), duration_ms: $ms, summary: $s}]' <<<"$records")"
  write_evidence
  if [ "$rc" -ne 0 ]; then
    echo "--- last lines of $name (local log, not committed) ---"; tail -30 "$log"
    fail "$* exited $rc"
  fi
  pass "$* (${summary:-exit 0})"
}

run_check install        npm ci
run_check lint           npm run lint
run_check typecheck      npm run typecheck
run_check build          npm run build
rm -f "$TEST_OBSERVATIONS"
run_check test           env POC_TEST_EVIDENCE_PATH="$PWD/$TEST_OBSERVATIONS" npm test

# Request-level evidence (data-model): the tests must have written sanitized
# observations to the workflow-owned path. Validate schema and content.
[ -s "$TEST_OBSERVATIONS" ] || fail "npm test wrote no request observations to POC_TEST_EVIDENCE_PATH"
jq -e -s '
  ["phase","index","http_status","body","elapsed_ms","scenario","app_container_id","app_started_at"] as $allowed
  | length > 0
  and all(.[];
      ((keys - $allowed) | length) == 0
      and (.phase | type) == "string" and (.index | type) == "number"
      and (.http_status | type) == "number" and (.elapsed_ms | type) == "number"
      and (.body == null or ((.body | type) == "object" and (.body | keys) == ["application","database","status"]))
      and ([.. | strings] | all(test("^[A-Za-z0-9_.:+ /-]{0,128}$"))))
  and any(.[]; .http_status == 200) and any(.[]; .http_status == 503)' "$TEST_OBSERVATIONS" >/dev/null \
  || fail "request observations do not match the evidence schema (allowed keys, exact three-field body, plain short strings, both 200 and 503 present)"
if has_secret < "$TEST_OBSERVATIONS" >/dev/null || grep -qiE 'password|postgres(ql)?://|secret|token' "$TEST_OBSERVATIONS"; then
  fail "request observations contain credential-like or private connection data"
fi
pass "request observations: $(wc -l < "$TEST_OBSERVATIONS" | tr -d ' ') sanitized records (schema valid)"
run_check verify-startup npm run verify:startup

# Evidence is tied to the tree that will be committed. Files regenerated by the
# checks themselves (if any) are listed, not hidden.
tree="$(worktree_tree)"
if [ "$tree" != "$tree_before" ]; then
  changed_by_checks="$(git diff --name-only "$tree_before" "$tree" | jq -R . | jq -s .)"
  echo "NOTE: checks changed tracked/untracked files: $(jq -r 'join(", ")' <<<"$changed_by_checks")"
fi
write_evidence
pass "LOCAL CHECKS: npm ci, lint, typecheck, build, test, verify:startup (evidence: $evidence)"
