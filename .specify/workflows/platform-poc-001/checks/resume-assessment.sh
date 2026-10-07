#!/usr/bin/env bash
# Repository-only resume assessment (SC-006). A fresh agent process with no chat
# context reads only a fresh clone of the pushed HEAD and reports approved
# scope, current status, evidence, remaining gaps and next action. Read-only:
#   implementer → Claude Code, tools limited to Read/Glob/Grep + read-only git
#   reviewer    → Codex CLI, --sandbox read-only
# The clone must be unchanged afterwards. The report is saved as a
# revision-linked review artifact in this repository.
# Usage: resume-assessment.sh implementer|reviewer <run_id>
source "$(dirname "$0")/lib.sh"
role="${1:?usage: resume-assessment.sh implementer|reviewer <run_id>}"; run_id="${2:-unknown}"
case "$role" in
  implementer) report="$REVIEWS_DIR/RESUME_IMPLEMENTER.md"; agent="Claude Code" ;;
  reviewer)    report="$REVIEWS_DIR/RESUME_REVIEWER.md";    agent="Codex CLI" ;;
  *) fail "role must be implementer or reviewer" ;;
esac
evidence="$EVIDENCE_DIR/resume-$role.json"
mkdir -p "$EVIDENCE_DIR" "$REVIEWS_DIR"

sha="$(git rev-parse HEAD)"
git fetch -q origin "$POC_BRANCH"
[ "$sha" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD $sha is not pushed"
# The assessed state is the pushed commit (cloned below); only earlier resume
# reports of this stage may be uncommitted here.
[ -z "$(git status --porcelain -- . ":!$REVIEWS_DIR/RESUME_IMPLEMENTER.md" ":!$REVIEWS_DIR/RESUME_REVIEWER.md")" ] \
  || fail "working tree has uncommitted changes besides resume reports"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
clone="$tmp/toolhunter-resume-$role"
git clone -q --no-local "$(git remote get-url origin)" "$clone"
git -C "$clone" checkout -q "$sha"

prompt="You are resuming the PLATFORM-POC-001 work as the $role with no prior conversation. Use only this repository (start from docs/poc/PLATFORM-POC-001.md, specs/001-foundation-health/, docs/poc/PLATFORM-POC-001-RESULT.md, docs/poc/PLATFORM-POC-001-RUN-HISTORY.md and git log). Do not modify any file and do not run commands other than reading files and read-only git. Report in Markdown with exactly these sections: ## Approved scope, ## Current work status, ## Evidence, ## Remaining gaps, ## Next action. Cite file paths (and commit SHAs where relevant) for every claim. End with a line 'RESUME_ASSESSMENT_COMPLETE'."

out="$tmp/out.md"
start="$(now_ms)"
set +e
if [ "$role" = implementer ]; then
  (cd "$clone" && env -u ANTHROPIC_API_KEY claude -p "$prompt" \
     --allowedTools "Read,Glob,Grep,Bash(git log*),Bash(git show*),Bash(git status*),Bash(git diff*)" \
     --disallowedTools "Edit,Write,NotebookEdit" --max-turns 40 --output-format text) >"$out" 2>"$tmp/err.log"
  rc=$?
else
  env -u OPENAI_API_KEY codex exec "$prompt" --sandbox read-only -C "$clone" \
     --output-last-message "$out" >"$tmp/run.log" 2>&1 </dev/null
  rc=$?
fi
set -e
ms=$(( $(now_ms) - start ))

[ "$rc" -eq 0 ] || { tail -5 "$tmp/err.log" "$tmp/run.log" 2>/dev/null; fail "$agent resume assessment exited $rc"; }
changes="$(git -C "$clone" status --porcelain --untracked-files=all)"
[ -z "$changes" ] || fail "$agent changed the clone during a read-only assessment: $changes"
grep -q 'RESUME_ASSESSMENT_COMPLETE' "$out" || fail "$agent report incomplete (no completion marker)"
for section in "Approved scope" "Current work status" "Evidence" "Remaining gaps" "Next action"; do
  grep -q "^## $section" "$out" || fail "$agent report lacks section '$section'"
done
has_secret < "$out" >/dev/null && fail "possible secret in $agent report"

{
  echo "# Resume assessment — $role ($agent)"
  echo
  echo "- Assessed commit: \`$sha\` (fresh clone of origin, no chat context, read-only)"
  echo "- Workflow run: \`$run_id\`; duration ${ms} ms; recorded $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  cat "$out"
} > "$report"
[ -s "$report" ] || fail "could not write $report"
jq -n --arg role "$role" --arg agent "$agent" --arg sha "$sha" --arg report "$report" --argjson ms "$ms" \
  '{stage: "resume-\($role)", agent: $agent, assessed_sha: $sha, chat_context: "none (fresh process)",
    source: "fresh clone of origin", read_only_verified: true, duration_ms: $ms, report: $report}' > "$evidence"
check_protected_artifacts
pass "$agent repository-only resume assessment saved to $report"
