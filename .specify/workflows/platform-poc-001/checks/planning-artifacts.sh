#!/usr/bin/env bash
# Deterministic validation of Spec Kit planning artifacts.
# Usage: planning-artifacts.sh plan|tasks
source "$(dirname "$0")/lib.sh"
stage="${1:?usage: planning-artifacts.sh plan|tasks}"

check_protected_artifacts

no_markers() {
  if grep -nE 'NEEDS CLARIFICATION|\[TODO|TBD\b' "$1"; then fail "$1 has unresolved markers"; fi
}

plan="$FEATURE_DIR/plan.md"
[ -s "$plan" ] || fail "$plan missing or empty"
no_markers "$plan"
for term in '/api/health' 'PostgreSQL' 'Docker Compose' 'Next.js' 'TypeScript'; do
  grep -qF "$term" "$plan" || fail "$plan does not mention $term"
done
pass "plan.md present, no unresolved markers, covers health/PostgreSQL/Compose/Next.js/TypeScript"

if [ "$stage" = "tasks" ]; then
  tasks="$FEATURE_DIR/tasks.md"
  [ -s "$tasks" ] || fail "$tasks missing or empty"
  no_markers "$tasks"
  count="$(grep -cE '^- \[[ xX]\] T[0-9]{3}' "$tasks" || true)"
  [ "$count" -gt 0 ] || fail "$tasks has no T### task items"
  dupes="$(grep -oE '^- \[[ xX]\] T[0-9]{3}' "$tasks" | grep -oE 'T[0-9]{3}' | sort | uniq -d)"
  [ -z "$dupes" ] || fail "duplicate task ids: $dupes"
  pass "tasks.md has $count uniquely numbered tasks"
fi

# Scope guard: planning must not pull in excluded PoC scope.
if grep -niE '\b(avito|telegram|oauth|next-auth|ruflo|cline|backup|restore|caddy|tailscale|auto-?merge)\b' \
     "$plan" ${tasks:-} | grep -viE 'out of scope|not (in scope|implement)|exclu|must not|no (auth|backup)'; then
  fail "planning artifacts reference excluded scope (see lines above)"
fi
pass "no excluded scope in planning artifacts"
