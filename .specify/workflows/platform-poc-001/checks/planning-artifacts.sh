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

  # Role boundary: workflow-owned obligations live in a non-checkbox section,
  # and no checkbox task may perform workflow-only actions.
  grep -qE '^## Workflow-owned verification and human obligations' "$tasks" \
    || fail "tasks.md lacks the 'Workflow-owned verification and human obligations' section"
  section_boxes="$(awk '/^## Workflow-owned verification and human obligations/{f=1;next} /^## /{f=0} f && /^- \[[ xX]\]/' "$tasks")"
  [ -z "$section_boxes" ] || { echo "$section_boxes"; fail "checkbox tasks inside the workflow-owned section"; }
  if grep -nE '^- \[ \] T[0-9]{3}' "$tasks" | grep -iE '\bgit push\b|\bgh run (watch|view|list)\b|speckit[-.]converge'; then
    fail "unchecked implementation tasks require workflow-only actions (above)"
  fi
  pass "workflow-owned obligations separated from implementer checkbox tasks"
fi

# Scope guard: planning must not pull in excluded PoC scope. Lines that state
# exclusions (no/not/never/without/forbidden/excluded/out of scope ...) are
# allowed to name excluded items; "restore" alone is not flagged because the
# spec requires restoring the database after a stop (only backup is excluded).
if grep -niE '\b(avito|telegram|oauth|next-auth|ruflo|cline|backups?|caddy|tailscale|auto-?merge)\b' \
     "$plan" ${tasks:-} \
   | grep -viE '\b(no|not|never|without|forbid(den)?|prohibit(ed)?|exclu(de|ded|des|sion|sions)|out of scope|must not|do not|don.t)\b'; then
  fail "planning artifacts reference excluded scope (see lines above)"
fi
pass "no excluded scope in planning artifacts"
