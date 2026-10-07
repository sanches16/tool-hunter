#!/usr/bin/env bash
# Records a human gate decision in Git (file + commit + push).
# Usage: record-gate.sh <FILE_STEM> "<title>" <choice> <run_id>
source "$(dirname "$0")/lib.sh"
stem="${1:?}"; title="${2:?}"; choice="${3:?}"; run_id="${4:?}"
file="$REVIEWS_DIR/$stem.md"
mkdir -p "$REVIEWS_DIR"

{
  echo "# $title"
  echo
  echo "**Feature:** PLATFORM-POC-001 — Foundation Health"
  echo "**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "**Reviewer:** Human project owner — $(git config user.name)"
  echo "**Decision:** $(printf '%s' "$choice" | tr '[:lower:]' '[:upper:]')"
  echo "**Workflow run:** platform-poc-001 / $run_id"
  echo "**Reviewed commit:** $(git rev-parse HEAD)"
  echo
  echo "## Reviewed artifacts"
  echo
  for f in .specify/memory/constitution.md "$FEATURE_DIR"/spec.md "$FEATURE_DIR"/plan.md \
           "$FEATURE_DIR"/tasks.md "$FEATURE_DIR"/research.md "$FEATURE_DIR"/data-model.md \
           "$FEATURE_DIR"/quickstart.md; do
    [ -f "$f" ] && echo "- \`$f\` — blob \`$(git hash-object "$f")\`"
  done
  [ -d "$FEATURE_DIR/contracts" ] && find "$FEATURE_DIR/contracts" -type f | sort | while read -r f; do
    echo "- \`$f\` — blob \`$(git hash-object "$f")\`"
  done
  echo
  echo "Recorded by the platform-poc-001 Spec Kit workflow from the interactive gate choice."
} > "$file"

bash "$(dirname "$0")/commit-push.sh" "docs: record $title ($choice)"
