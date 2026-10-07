#!/usr/bin/env bash
# Deterministic local verification, independent of any agent claim.
source "$(dirname "$0")/lib.sh"

check_protected_artifacts

[ -f package.json ] || fail "package.json missing"
for script in lint typecheck test build; do
  jq -e --arg s "$script" '.scripts[$s]' package.json >/dev/null || fail "npm script '$script' missing"
done
[ -f .env.example ] || fail ".env.example missing (FR-05)"
[ -z "$(git ls-files .env)" ] || fail ".env is tracked by Git"
ls .github/workflows/*.y*ml >/dev/null 2>&1 || fail "no GitHub Actions workflow (FR-07)"
pass "required scripts and files present"

# Scope guard on changed paths since the approved spec baseline.
if git diff --name-only 288cdc7 -- . ':!specs' ':!.specify' | grep -iE 'avito|telegram|auth|backup|catalog|caddy|orchestr'; then
  fail "implementation touches excluded scope (paths above)"
fi
pass "no excluded-scope paths"

[ -f .env ] || cp .env.example .env

# Claude cannot run npm, so the lockfile may be missing after implementation.
# Create it deterministically without running any package lifecycle scripts;
# it is committed with the implementation.
if [ ! -f package-lock.json ]; then
  npm install --package-lock-only --ignore-scripts --no-audit --no-fund
  pass "package-lock.json created (lockfile only, lifecycle scripts not run)"
fi
[ -s package-lock.json ] || fail "package-lock.json missing after lockfile generation"

npm ci
npm run lint
npm run typecheck
npm run build

db="$(db_service)"
docker compose up -d --wait "$db"
npm test
pass "LOCAL CHECKS: lint, typecheck, build, test"
