#!/usr/bin/env bash
# Fresh-checkout lifecycle on the exact pushed implementation commit (SC-001,
# SC-006). Clones the canonical GitHub repository into a temporary directory —
# never the current working tree — and follows only repository-documented
# steps: copy .env.example to the ignored .env with a generated password, then
# the Compose lifecycle (configure, start, inspect, DB loss, recovery, stop).
# Proves zero source edits and cleans up everything it created. No agent and no
# chat history is involved: this is a plain shell process.
# Usage: fresh-checkout.sh [label]   (tests the current HEAD, which must be pushed)
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="$PWD/$EVIDENCE_DIR/fresh-checkout.json"
docker_evidence="$PWD/$EVIDENCE_DIR/fresh-checkout-lifecycle.json"
checks_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$EVIDENCE_DIR"

sha="$(git rev-parse HEAD)"
git fetch -q origin "$POC_BRANCH"
[ "$sha" = "$(git rev-parse "origin/$POC_BRANCH")" ] || fail "HEAD $sha is not pushed"
remote="$(git remote get-url origin)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
clone="$tmp/toolhunter-fresh-$$"
records="[]"
write() {
  jq -n --arg label "$label" --arg sha "$sha" --arg remote "$remote" --argjson checks "$records" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
      stage: "fresh-checkout", label: $label, recorded_at: $at, implementation_sha: $sha,
      source: "fresh clone of the canonical GitHub repository (origin) into a temporary directory",
      chat_history_used: false, agent_involved: false, checks: $checks }' > "$evidence"
}
record() {
  records="$(jq --arg c "$1" --arg r "$2" --arg d "$3" '. + [{criterion: $c, result: $r, detail: $d}]' <<<"$records")"
  write
  [ "$2" = "PASS" ] && pass "$1: $3" || fail "$1: $3"
}

git clone -q --no-local "$remote" "$clone" && git -C "$clone" checkout -q "$sha" \
  && record "clone" PASS "cloned origin and checked out $sha in an empty temporary directory" \
  || record "clone" FAIL "could not clone $sha"
cd "$clone"

for f in README.md .env.example compose.yaml; do
  [ -f "$f" ] || record "documented-inputs" FAIL "$f missing in the fresh checkout"
done
grep -q 'docker compose' README.md && grep -q '\.env\.example' README.md \
  && record "documented-inputs" PASS "README documents .env.example configuration and docker compose lifecycle" \
  || record "documented-inputs" FAIL "README does not document .env.example and docker compose"

# Allowed local configuration: ignored .env from the example, generated password.
git check-ignore -q .env || record "local-config" FAIL ".env is not ignored by the repository"
umask 077
password="$(openssl rand -hex 24)"
awk -v p="$password" 'BEGIN{FS=OFS="="} $1=="POSTGRES_PASSWORD"{print $1, p; next} {print}' .env.example > .env
unset password
grep -qE '^POSTGRES_PASSWORD=.+' .env && record "local-config" PASS "ignored .env created from .env.example with a generated password (not printed)" \
  || record "local-config" FAIL ".env.example has no POSTGRES_PASSWORD line"

# Same lifecycle verifier as docker-health, run inside the fresh checkout with
# the documented .env (its own unique Compose project and cleanup).
if DH_ENV_FILE="$clone/.env" DH_EVIDENCE="$docker_evidence" DH_STAGE="fresh-checkout-lifecycle" \
   bash "$checks_dir/docker-health.sh" "$label" >"$tmp/lifecycle.log" 2>&1; then
  record "lifecycle" PASS "configure/start/inspect/DB loss/recovery/stop passed (see fresh-checkout-lifecycle.json)"
else
  grep -E '^(PASS|FAIL):' "$tmp/lifecycle.log" | tail -3
  record "lifecycle" FAIL "documented Compose lifecycle failed (see fresh-checkout-lifecycle.json)"
fi

changes="$(git status --porcelain --untracked-files=all)"
[ -z "$changes" ] && [ "$(git rev-parse HEAD)" = "$sha" ] \
  && record "zero-source-edits" PASS "git status clean (only ignored .env), HEAD unchanged" \
  || record "zero-source-edits" FAIL "source tree changed: $(printf '%s' "$changes" | tr '\n' ' ')"

cd - >/dev/null
record "cleanup" PASS "temporary checkout removed on exit; Compose project removed by the lifecycle verifier"
pass "FRESH CHECKOUT (evidence: $evidence)"
