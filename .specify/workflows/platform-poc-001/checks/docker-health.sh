#!/usr/bin/env bash
# Docker Compose health, DB-loss and recovery verification (AC-02..AC-04).
source "$(dirname "$0")/lib.sh"
url="$APP_URL/api/health"
out=".agent-out/health.json"

# One health request; prints "<http_code> <seconds>" and stores the body.
probe() { curl -sS -m 6 -o "$out" -w '%{http_code} %{time_total}' "$url" || echo "000 6"; }

expect() {  # expect <http_code> <status> <database> <label>
  local code secs
  read -r code secs < <(probe)
  awk -v s="$secs" 'BEGIN { exit !(s <= 5.0) }' || fail "$4: response took ${secs}s (> 5s bound)"
  [ "$code" = "$1" ] || { cat "$out" 2>/dev/null; fail "$4: HTTP $code, expected $1"; }
  [ "$(jq -r .status "$out")" = "$2" ] || { cat "$out"; fail "$4: status != $2"; }
  [ "$(jq -r .database "$out")" = "$3" ] || { cat "$out"; fail "$4: database != $3"; }
  pass "$4: HTTP $code status=$2 database=$3 in ${secs}s"
}

wait_for() {  # wait_for <http_code> <label>
  for _ in $(seq 1 60); do
    [ "$(probe | cut -d' ' -f1)" = "$1" ] && return 0
    sleep 2
  done
  fail "$2: endpoint never returned HTTP $1"
}

trap 'docker compose down >/dev/null 2>&1 || true' EXIT
[ -f .env ] || cp .env.example .env
docker compose up -d --build
db="$(db_service)"

wait_for 200 "startup"
expect 200 ok ok "healthy"

app_id_before="$(docker compose ps -q | sort | tr '\n' ' ')"
docker compose stop "$db"
sleep 2
expect 503 degraded unavailable "database stopped"

docker compose start "$db"
wait_for 200 "recovery"
expect 200 ok ok "recovered without app restart"
app_id_after="$(docker compose ps -q | sort | tr '\n' ' ')"
[ "$app_id_before" = "$app_id_after" ] || fail "containers were recreated during recovery"
pass "DOCKER HEALTH: healthy, DB-loss 503, recovery"
