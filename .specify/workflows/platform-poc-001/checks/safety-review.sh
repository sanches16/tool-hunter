#!/usr/bin/env bash
# Deterministic safety and scope review of the implementation working tree
# (SC-007), run after local/Docker verification and before implement-commit.
# Checks approved artifacts, dependencies, changed paths, Docker build-context
# exclusions, local env files, key/credential material and workflow files, and
# writes sanitized evidence to .agent-out/evidence/safety-review.json.
# Usage: safety-review.sh [label]
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="$EVIDENCE_DIR/safety-review.json"
base="288cdc7"   # approved spec baseline (feature.json correction)
mkdir -p "$EVIDENCE_DIR"
git rev-parse -q --verify "$base^{commit}" >/dev/null || fail "approved baseline $base not found"
records="[]"
failed=0
record() {  # record <check> <PASS|FAIL> <detail>
  records="$(jq --arg c "$1" --arg r "$2" --arg d "$3" '. + [{check: $c, result: $r, detail: $d}]' <<<"$records")"
  echo "$2: $1: $3"
  [ "$2" = PASS ] || failed=$((failed + 1))
}

# 1. Approved spec/plan/workflow artifacts unchanged.
if check_protected_artifacts >/dev/null 2>&1; then
  record approved-spec-artifacts PASS "constitution, spec.md and requirements checklist match HUMAN GATE #1 blobs"
else
  record approved-spec-artifacts FAIL "constitution/spec/checklist differ from HUMAN GATE #1 blobs"
fi
reviewed_2a="$(sed -n 's/^\*\*Reviewed commit (on origin\/poc\/platform-poc-001):\*\* \([0-9a-f]\{40\}\)$/\1/p' "$REVIEWS_DIR/HUMAN_GATE_2A.md")"
plan_paths=("$FEATURE_DIR/plan.md" "$FEATURE_DIR/research.md" "$FEATURE_DIR/data-model.md" "$FEATURE_DIR/quickstart.md" "$FEATURE_DIR/contracts")
if [ -n "$reviewed_2a" ] && git diff --quiet "$reviewed_2a" -- "${plan_paths[@]}"; then
  record approved-plan-artifacts PASS "plan, research, data-model, quickstart and contracts identical to Gate 2A commit ${reviewed_2a:0:12}"
else
  record approved-plan-artifacts FAIL "plan artifacts differ from the Gate 2A reviewed commit"
fi
wf=".specify/workflows/platform-poc-001"
if [ -z "$(git status --porcelain --untracked-files=all --ignored -- "$wf")" ] && git diff --quiet "origin/$POC_BRANCH" -- "$wf"; then
  record workflow-files PASS "workflow, checks, prompts and agent flags unchanged"
else
  record workflow-files FAIL "workflow directory modified"
fi

# 2. Dependencies: only the approved set (plan: Next.js, React, pg; dev:
#    TypeScript, @types/*, ESLint, eslint-config-next), nothing forbidden.
if [ -f package.json ]; then
  extra="$(jq -r '
    ((.dependencies // {}) | keys[] | select(IN("next","react","react-dom","pg") | not) | "dependency \(.)"),
    ((.devDependencies // {}) | keys[] | select((IN("typescript","eslint","eslint-config-next") or startswith("@types/")) | not) | "devDependency \(.)"),
    ((.optionalDependencies // {}, .peerDependencies // {}) | keys[] | "unexpected \(.)")' package.json)"
  [ -z "$extra" ] && record dependencies-approved-set PASS "package.json dependencies within the approved plan set" \
    || record dependencies-approved-set FAIL "not in approved set: $(echo "$extra" | tr '\n' ',' )"
  forbidden='^(drizzle|drizzle-orm|prisma|@prisma/client|typeorm|sequelize|knex|mongoose|next-auth|@auth/.*|passport.*|telegraf|node-telegram-bot-api|grammy|bull|bullmq|redis|ioredis|kafkajs|@temporalio/.*|langchain|@langchain/.*|openai|@anthropic-ai/.*|ruflo|cline|puppeteer|playwright|@playwright/.*|avito.*)$'
  if [ -f package-lock.json ]; then
    hits="$(jq -r '.packages // {} | keys[] | select(startswith("node_modules/")) | sub(".*node_modules/"; "")' package-lock.json | grep -E "$forbidden" | sort -u || true)"
    [ -z "$hits" ] && record dependencies-forbidden PASS "no orchestration, ORM, auth, queue, LLM, browser-automation or marketplace packages in package-lock.json" \
      || record dependencies-forbidden FAIL "forbidden packages: $(echo "$hits" | tr '\n' ',')"
  else
    record dependencies-forbidden FAIL "package-lock.json missing"
  fi
else
  record dependencies-approved-set FAIL "package.json missing"
fi

# 3. Changed paths: no excluded scope.
changed="$( { git diff --name-only "$base" -- . ':!specs' ':!.specify' ':!docs'; git ls-files --others --exclude-standard -- . ':!specs' ':!.specify' ':!docs'; } | sort -u)"
scope_hits="$(printf '%s\n' "$changed" | grep -iE 'avito|telegram|catalog|auth|backup|caddy|orchestr|agent-?db|task-?queue|memory-?server' || true)"
[ -z "$scope_hits" ] && record excluded-scope-paths PASS "$(printf '%s\n' "$changed" | grep -c . || true) changed paths, none in excluded scope" \
  || record excluded-scope-paths FAIL "excluded-scope paths: $(echo "$scope_hits" | tr '\n' ',')"

# 4. Docker build context excludes private/local state.
if [ -f .dockerignore ]; then
  missing=""
  has_pat() { grep -qxE "$1" .dockerignore; }
  if has_pat '(\*\*/)?\.env\*' || { has_pat '(\*\*/)?\.env' && has_pat '(\*\*/)?\.env\.\*'; }; then :; else missing="$missing .env*"; fi
  has_pat '\.git/?' || missing="$missing .git"
  has_pat '(\*\*/)?node_modules/?' || missing="$missing node_modules"
  has_pat '(\*\*/)?\.next/?' || missing="$missing .next"
  has_pat '\.agent-out/?' || missing="$missing .agent-out"
  [ -z "$missing" ] && record dockerignore PASS ".dockerignore excludes .env*, .git, node_modules, .next and .agent-out" \
    || record dockerignore FAIL ".dockerignore lacks:$missing"
else
  record dockerignore FAIL ".dockerignore missing"
fi

# 5. Env files: example tracked, real env files untracked and ignored.
git ls-files --error-unmatch .env.example >/dev/null 2>&1 \
  && record env-example PASS ".env.example present (allowed template)" || record env-example FAIL ".env.example not tracked"
tracked_env="$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '(^|/)\.env\.example$' || true)"
[ -z "$tracked_env" ] && record env-untracked PASS "no real .env files tracked" || record env-untracked FAIL "tracked env files: $tracked_env"
local_env="$(find . -name '.env*' -not -name '.env.example' -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null || true)"
not_ignored=""
for f in $local_env; do git check-ignore -q "$f" || not_ignored="$not_ignored $f"; done
[ -z "$not_ignored" ] && record env-ignored PASS "$(printf '%s\n' "$local_env" | grep -c . || true) local env file(s), all ignored by Git" \
  || record env-ignored FAIL "not ignored:$not_ignored"

# 6. No credential or key material in tracked/candidate files.
candidates="$( { git ls-files; git ls-files --others --exclude-standard; } | sort -u)"
key_files="$(printf '%s\n' "$candidates" | grep -iE '\.(pem|key|p12|pfx)$|(^|/)id_(rsa|ed25519)|(^|/)auth\.json$' || true)"
key_text="$(printf '%s\n' "$candidates" | while read -r f; do [ -f "$f" ] && grep -lE 'BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY' "$f" 2>/dev/null; done || true)"
secret_hits="$( { git diff "$base" -- . ':!package-lock.json'; git ls-files --others --exclude-standard -z | xargs -0 cat 2>/dev/null; } | has_secret | head -3 || true)"
[ -z "$key_files$key_text$secret_hits" ] && record credentials PASS "no key files, private keys or secret patterns in candidate files" \
  || record credentials FAIL "credential material found (files: ${key_files:-none}${key_text:+, private keys in $key_text})"

jq -n --arg label "$label" --arg tree "$(worktree_tree)" --argjson checks "$records" --argjson failed "$failed" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{stage: "safety-review", label: $label, recorded_at: $at,
    worktree_tree: $tree, result: (if $failed == 0 then "PASS" else "FAIL" end), checks: $checks}' > "$evidence"
[ "$failed" -eq 0 ] || fail "safety review: $failed check(s) failed (evidence: $evidence)"
pass "SAFETY REVIEW (evidence: $evidence)"
