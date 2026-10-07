#!/usr/bin/env bash
# Commits the current changes on the PoC branch and pushes them.
# Usage: commit-push.sh "<commit message>" [only-path]
# With only-path, any change outside that path fails the step.
source "$(dirname "$0")/lib.sh"
msg="${1:?usage: commit-push.sh <message> [only-path]}"
only="${2:-}"

[ "$(git branch --show-current)" = "$POC_BRANCH" ] || fail "not on $POC_BRANCH"
check_protected_artifacts

if [ -n "$only" ]; then
  outside="$(git status --porcelain | awk '{print $NF}' | grep -vxF "$only" || true)"
  [ -z "$outside" ] || { echo "$outside"; fail "changes outside $only"; }
fi
# After commit + push the tree must be clean and HEAD must exist on GitHub.
verify_pushed() {
  [ -z "$(git status --porcelain)" ] || { git status --short; fail "working tree not clean after commit"; }
  git fetch -q origin "$POC_BRANCH"
  [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD is not on origin/$POC_BRANCH"
}

git add -A
if [ -z "$(git diff --cached --name-only)" ]; then
  verify_pushed
  pass "nothing to commit; HEAD $(git rev-parse --short HEAD) is on origin"
  exit 0
fi

# Never commit changes to the workflow or its deterministic verifier.
if git diff --cached --name-only | grep -E '^\.specify/workflows/platform-poc-001/'; then
  git reset -q
  fail "workflow/verifier files changed (above); unstaged, nothing committed"
fi
if git diff --cached --name-only | grep -E '(^|/)node_modules/|(^|/)\.next/'; then
  fail "build output or dependencies staged (add them to .gitignore)"
fi
if git diff --cached --name-only | grep -E '(^|/)\.env$|(^|/)\.env\.[^e]|\.pem$|\.key$|(^|/)auth\.json$'; then
  fail "credential-like files staged (above)"
fi
if git diff --cached -U0 | grep -E '^\+' | grep -E 'sk-[A-Za-z0-9_-]{10,}|xai-[A-Za-z0-9_-]{10,}|gh[opsu]_[A-Za-z0-9]{20,}|Bearer [A-Za-z0-9._-]{20,}'; then
  fail "possible secret in staged changes"
fi
git diff --cached --check || echo "WARNING: whitespace issues in staged changes (not blocking)"

git diff --cached --stat
git commit -q -m "$msg"
git push -q origin "$POC_BRANCH"
verify_pushed
pass "committed and pushed $(git rev-parse --short HEAD): $msg"
