#!/usr/bin/env bash
# Docker Compose lifecycle verification of the production stack (contract
# "Compose interface"): startup → 200 → DB stop → 503 ≤5 s → DB start → 200 with
# the same app container/process → app stop → no response → cleanup.
# Uses an ephemeral env file with a generated password (never printed), a unique
# Compose project and removes only that project's containers, network, volume
# and locally built image. Never reads the developer .env.
# Usage: docker-health.sh [label]
# Environment (used by fresh-checkout.sh): DH_ENV_FILE = an existing env file to
# use instead of a generated one; DH_EVIDENCE = evidence output path;
# DH_STAGE = stage name recorded in the evidence.
source "$(dirname "$0")/lib.sh"
label="${1:-initial}"
evidence="${DH_EVIDENCE:-$EVIDENCE_DIR/docker-health.json}"
stage="${DH_STAGE:-docker-health}"
url="http://127.0.0.1:3000/api/health"
mkdir -p "$(dirname "$evidence")"

tmp="$(mktemp -d)"
chmod 700 "$tmp"
project="toolhunter-verify-$(date +%s)-$$"
body="$tmp/body.json"; headers="$tmp/headers.txt"
umask 077
if [ -n "${DH_ENV_FILE:-}" ]; then
  [ -f "$DH_ENV_FILE" ] || fail "DH_ENV_FILE $DH_ENV_FILE missing"
  env_file="$DH_ENV_FILE"
else
  password="$(openssl rand -hex 24)"
  printf '%s\n' POSTGRES_HOST=db POSTGRES_PORT=5432 POSTGRES_DB=foundation \
    POSTGRES_USER=foundation "POSTGRES_PASSWORD=$password" > "$tmp/verify.env"
  unset password
  env_file="$tmp/verify.env"
fi
# --env-file replaces the project .env for interpolation; exported values make
# the same settings visible to Compose regardless of how compose.yaml reads them.
set -a; . "$env_file"; set +a
dc() { docker compose -p "$project" --env-file "$env_file" "$@"; }

cleanup() {
  dc down --volumes --remove-orphans --rmi local >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

records="[]"
tree="$(worktree_tree)"   # docker-health must not change files; checked at the end
write_evidence() {
  jq -n --arg label "$label" --arg tree "$tree" --arg project "$project" --arg stage "$stage" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson checks "$records" '{
      stage: $stage, label: $label, recorded_at: $at, worktree_tree: $tree,
      compose_project: $project, checks: $checks }' > "$evidence"
}
record() {  # record <criterion> <PASS|FAIL> <detail>
  records="$(jq --arg c "$1" --arg r "$2" --arg d "$3" '. + [{criterion: $c, result: $r, detail: $d}]' <<<"$records")"
  write_evidence
  [ "$2" = "PASS" ] && pass "$1: $3" || fail "$1: $3"
}

# One request: sets code, ms and leaves body/headers in $tmp.
probe() {
  local start end
  : > "$body"; : > "$headers"
  start="$(now_ms)"
  code="$(curl -sS -m 6 -D "$headers" -o "$body" -w '%{http_code}' "$url" 2>/dev/null || true)"
  end="$(now_ms)"
  ms=$((end - start))
  [ -n "$code" ] || code="000"
}

expect_health() {  # expect_health <criterion> <code> <status> <application> <database>
  probe
  local keys nostore
  keys="$(jq -c 'keys' "$body" 2>/dev/null || echo invalid)"
  nostore="$(grep -iE '^cache-control:.*no-store' "$headers" >/dev/null && echo yes || echo no)"
  if [ "$code" = "$2" ] && [ "$ms" -le 5000 ] && [ "$keys" = '["application","database","status"]' ] \
     && [ "$(jq -r .status "$body")" = "$3" ] && [ "$(jq -r .application "$body")" = "$4" ] \
     && [ "$(jq -r .database "$body")" = "$5" ] && [ "$nostore" = yes ]; then
    record "$1" PASS "HTTP $code {status:$3,application:$4,database:$5} no-store in ${ms} ms"
  else
    record "$1" FAIL "HTTP $code keys=$keys no-store=$nostore in ${ms} ms (expected $2 $3/$4/$5 ≤5000 ms)"
  fi
}

wait_for_code() {  # wait_for_code <code> <seconds>
  local deadline=$(( $(date +%s) + $2 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    probe; [ "$code" = "$1" ] && return 0; sleep 1
  done
  return 1
}

app_state() { docker inspect -f '{{.Id}} {{.State.StartedAt}} {{.RestartCount}}' "$(dc ps -q app)"; }

dc up -d --build --wait --wait-timeout 120 >/dev/null 2>&1 \
  && record "compose-startup" PASS "docker compose up -d --build --wait (project $project)" \
  || record "compose-startup" FAIL "docker compose up --wait failed"

wait_for_code 200 60 || true
expect_health "healthy-200" 200 ok ok ok
before="$(app_state)"

dc stop db >/dev/null 2>&1
expect_health "db-stopped-503" 503 degraded ok unavailable

dc start db >/dev/null 2>&1
wait_for_code 200 90 || true
expect_health "db-restarted-200" 200 ok ok ok
after="$(app_state)"
[ "$before" = "$after" ] \
  && record "same-app-process" PASS "app container id, StartedAt and RestartCount unchanged" \
  || record "same-app-process" FAIL "app container or process changed during DB stop/start"

dc stop app >/dev/null 2>&1
probe
[ "$code" = "000" ] \
  && record "app-stopped-no-response" PASS "no HTTP response after app stop" \
  || record "app-stopped-no-response" FAIL "HTTP $code after app stop"

dc down --volumes --remove-orphans --rmi local >/dev/null 2>&1
[ -z "$(docker ps -aq --filter "label=com.docker.compose.project=$project")" ] \
  && record "cleanup" PASS "project containers, network, volume and local image removed" \
  || record "cleanup" FAIL "project resources remain"
[ "$(worktree_tree)" = "$tree" ] || fail "working tree changed during Docker verification"
pass "DOCKER LIFECYCLE (evidence: $evidence)"
