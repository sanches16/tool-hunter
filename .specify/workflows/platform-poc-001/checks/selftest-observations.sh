#!/usr/bin/env bash
# Self-test of validate-observations.sh: a valid fixture must PASS and each
# known-bad mutation must FAIL. Run by preflight before any agent step.
source "$(dirname "$0")/lib.sh"
validator="$(dirname "$0")/validate-observations.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Valid fixture: 10 healthy, 10 database-loss, 10 database-recovery with one app
# identity, plus one cold fault scenario without identity.
{
  for phase in healthy database-loss database-recovery; do
    for i in $(seq 0 9); do
      if [ "$phase" = database-loss ]; then
        code=503; body='{"status":"degraded","application":"ok","database":"unavailable"}'
      else
        code=200; body='{"status":"ok","application":"ok","database":"ok"}'
      fi
      printf '{"phase":"%s","index":%d,"http_status":%d,"body":%s,"elapsed_ms":%s,"scenario":"main-sequence","app_container_id":"c0ffee12","app_started_at":"2026-10-07T10:00:00.000Z"}\n' \
        "$phase" "$i" "$code" "$body" "1$i.5"
    done
  done
  echo '{"phase":"cold-unreachable","index":0,"http_status":503,"body":{"status":"degraded","application":"ok","database":"unavailable"},"elapsed_ms":4012.3,"scenario":"cold-unreachable","app_container_id":null,"app_started_at":null}'
} > "$tmp/valid.jsonl"

# mutate <name> <jq filter applied to the first record of the given phase>
mutate() {
  jq -c --arg n "$1" "if .phase == \"$2\" and .index == 0 then $3 else . end" "$tmp/valid.jsonl" > "$tmp/$1.jsonl"
}
mutate missing-body          healthy          'del(.body)'
mutate fractional-index      healthy          '.index = 1.5'
mutate fractional-status     healthy          '.http_status = 200.5'
mutate negative-elapsed      healthy          '.elapsed_ms = -1'
mutate missing-loss-identity database-loss    '.app_container_id = null'
mutate missing-recovery-identity database-recovery '.app_started_at = ""'
mutate extra-body-field      healthy          '.body.extra = "x"'
mutate wrong-503-body        database-loss    '.body.status = "ok"'
mutate extra-key             healthy          '.raw = "x"'
mutate over-deadline         database-loss    '.elapsed_ms = 5000.1'
mutate changed-identity      database-recovery '.app_container_id = "different1"'
mutate secret-like           cold-unreachable '.scenario = "postgres://user:pw@db"'
jq -c 'select(.phase != "healthy" or .index != 9)' "$tmp/valid.jsonl" > "$tmp/nine-healthy.jsonl"

failures=0
expect() {  # expect <PASS|FAIL> <fixture>
  local got=FAIL why
  why="$(bash "$validator" "$tmp/$2.jsonl" 2>&1 >/dev/null | head -1)" && got=PASS
  [ -n "$why" ] || got=PASS
  if [ "$got" = "$1" ]; then echo "  ok   $2 -> $got${why:+ ($why)}"; else echo "  BAD  $2 -> $got (expected $1)"; failures=$((failures + 1)); fi
}
expect PASS valid
for f in missing-body fractional-index fractional-status negative-elapsed missing-loss-identity \
         missing-recovery-identity extra-body-field wrong-503-body extra-key over-deadline \
         changed-identity secret-like nine-healthy; do
  expect FAIL "$f"
done
[ "$failures" -eq 0 ] || fail "observation validator self-test: $failures unexpected result(s)"
pass "observation validator self-test: valid fixture PASS, 13 invalid fixtures FAIL"
