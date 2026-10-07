#!/usr/bin/env bash
# Refuses to start the workflow unless the repository and agent setup match
# the state approved at HUMAN GATE #1.
source "$(dirname "$0")/lib.sh"

[ "$(git branch --show-current)" = "$POC_BRANCH" ] || fail "current branch is not $POC_BRANCH"
pass "branch $POC_BRANCH"

[ -z "$(git status --porcelain)" ] || { git status --short; fail "working tree is not clean"; }
pass "working tree clean"

git fetch -q origin "$POC_BRANCH"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD differs from origin/$POC_BRANCH"
pass "HEAD matches origin/$POC_BRANCH"

[ -f "$REVIEWS_DIR/HUMAN_GATE_1.md" ] && grep -q "APPROVED FOR PLANNING" "$REVIEWS_DIR/HUMAN_GATE_1.md" \
  || fail "HUMAN_GATE_1.md missing or not approved"
pass "HUMAN GATE #1 approved"
check_protected_artifacts

[ -z "$(git ls-files .specify/feature.json)" ] || fail ".specify/feature.json is tracked by Git"
[ "$(jq -r .feature_directory .specify/feature.json)" = "$FEATURE_DIR" ] || fail ".specify/feature.json does not point to $FEATURE_DIR"
pass "local feature pointer = $FEATURE_DIR (untracked)"

specify version 2>&1 | grep -q '1\.0\.12' || fail "Spec Kit is not 1.0.12"
[ "$(specify integration status --json | jq -r .default_integration)" = "codex" ] || fail "default integration is not codex"
pass "Spec Kit 1.0.12, default integration codex"

for var in OPENAI_API_KEY ANTHROPIC_API_KEY XAI_API_KEY; do
  [ -z "$(printenv "$var" 2>/dev/null)" ] || fail "$var=SET (subscription auth path required)"
done
pass "API key env NOT_SET (subscription auth path)"

for var in SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS SPECKIT_INTEGRATION_CLAUDE_EXTRA_ARGS; do
  value="$(printenv "$var" 2>/dev/null || true)"
  [ -n "$value" ] || fail "$var NOT_SET; load .specify/workflows/platform-poc-001/agent-flags.env"
  if printf '%s' "$value" | grep -qiE 'dangerously|always-approve|bypassPermissions|danger-full-access|yolo|approve-for-me'; then
    fail "$var contains a permission-bypass flag"
  fi
done
pass "agent flags loaded, no permission-bypass flags"

for cmd in codex claude docker gh jq npm; do command -v "$cmd" >/dev/null || fail "$cmd not found"; done
docker info >/dev/null 2>&1 || fail "Docker engine not running"
gh auth status >/dev/null 2>&1 || fail "gh not authenticated"
pass "codex, claude, docker, gh, jq, npm available"

mkdir -p .agent-out
pass "PREFLIGHT"
