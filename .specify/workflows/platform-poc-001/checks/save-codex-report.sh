#!/usr/bin/env bash
# Saves Codex's final message (written via --output-last-message) as a
# review artifact so the result lives in Git, not only in the terminal.
# Usage: save-codex-report.sh <REPORT_NAME> <run_id>
source "$(dirname "$0")/lib.sh"
name="${1:?usage: save-codex-report.sh <REPORT_NAME> <run_id>}"; run_id="${2:-unknown}"
src=".agent-out/codex-last-message.md"
dest="$REVIEWS_DIR/$name.md"

[ -s "$src" ] || fail "$src missing or empty; was the Codex step run with agent-flags.env loaded?"
mkdir -p "$REVIEWS_DIR"
{
  echo "# $name"
  echo
  echo "Source: Codex final message, workflow run $run_id, base commit $(git rev-parse --short HEAD)"
  echo
  cat "$src"
} > "$dest"
rm -f "$src"
check_protected_artifacts
pass "saved $dest"
