#!/usr/bin/env bash
# Records a human gate decision in Git (file + commit + push).
# Usage: record-gate.sh <FILE_STEM> "<title>" <choice> <run_id> <verdict_input_name> [verdict_input_value]
# The reviewed commit must already be on GitHub so an external reviewer could read it.
source "$(dirname "$0")/lib.sh"
stem="${1:?}"; title="${2:?}"; choice="${3:?}"; run_id="${4:?}"; vname="${5:?}"; vvalue="${6:-}"
file="$REVIEWS_DIR/$stem.md"
# Never overwrite an earlier decision for the same gate (e.g. a rejected
# candidate); later decisions get the run id in the file name.
[ -e "$file" ] && file="$REVIEWS_DIR/${stem}_${run_id}.md"
mkdir -p "$REVIEWS_DIR"

[ -z "$(git status --porcelain)" ] || { git status --short; fail "uncommitted changes at gate time; reviewed state must be a pushed commit"; }
git fetch -q origin "$POC_BRANCH"
reviewed="$(git rev-parse HEAD)"
[ "$reviewed" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "reviewed commit $reviewed is not on origin/$POC_BRANCH"
if [ -n "$vvalue" ]; then
  source_line="non-interactive, workflow input \`$vname=$vvalue\` passed on resume by the operator from the owner's explicit decision"
else
  source_line="interactive gate prompt"
fi

{
  echo "# $title"
  echo
  echo "**Feature:** PLATFORM-POC-001 — Foundation Health"
  echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Reviewer:** Human project owner — $(git config user.name)"
  echo "**Decision:** $(printf '%s' "$choice" | tr '[:lower:]' '[:upper:]')"
  echo "**Workflow run:** platform-poc-001 / $run_id"
  echo "**Decision source:** $source_line"
  echo "**Reviewed commit (on origin/$POC_BRANCH):** $reviewed"
  echo
  echo "## Reviewed artifacts"
  echo
  for f in .specify/memory/constitution.md "$FEATURE_DIR"/spec.md "$FEATURE_DIR"/plan.md \
           "$FEATURE_DIR"/tasks.md "$FEATURE_DIR"/research.md "$FEATURE_DIR"/data-model.md \
           "$FEATURE_DIR"/quickstart.md "$REVIEWS_DIR"/PLAN_REPORT.md "$REVIEWS_DIR"/ANALYZE.md \
           "$REVIEWS_DIR"/CONVERGE.md "$REVIEWS_DIR"/CONVERGE_AFTER_REPAIR.md \
           "$REVIEWS_DIR"/IMPLEMENTATION_REPORT.md "$REVIEWS_DIR"/GROK_CRITIC.md; do
    [ -f "$f" ] && echo "- \`$f\` — blob \`$(git hash-object "$f")\`"
  done
  [ -d "$FEATURE_DIR/contracts" ] && find "$FEATURE_DIR/contracts" -type f | sort | while read -r f; do
    echo "- \`$f\` — blob \`$(git hash-object "$f")\`"
  done
  echo
  echo "Recorded by the platform-poc-001 Spec Kit workflow from the interactive gate choice."
} > "$file"

bash "$(dirname "$0")/commit-push.sh" "docs: record $title ($choice)"
