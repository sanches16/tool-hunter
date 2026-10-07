#!/usr/bin/env bash
# Strict validator for request-level test observations (JSON Lines written by
# npm test to POC_TEST_EVIDENCE_PATH). Exit 0 only if every rule holds:
#  - every record has exactly the keys phase, index, http_status, body,
#    elapsed_ms, scenario, app_container_id, app_started_at (no extras);
#  - phase, scenario: non-empty strings; index: integer >= 0;
#  - http_status: 200 or 503; elapsed_ms: number in [0, 5000];
#  - body: object with exactly status/application/database and the exact
#    contract — 200 → ok/ok/ok, 503 → degraded/ok/unavailable;
#  - phases healthy / database-loss / database-recovery: exactly 10 each,
#    HTTP 200 / 503 / 200, non-empty app_container_id and app_started_at, one
#    identical app identity across all 30; other scenarios: identity string or null;
#  - short plain strings only, no secrets or private connection data.
# Usage: validate-observations.sh <file.jsonl>
source "$(dirname "$0")/lib.sh"
file="${1:?usage: validate-observations.sh <file.jsonl>}"
[ -s "$file" ] || fail "no request observations in $file"
jq -e . "$file" >/dev/null 2>&1 || fail "$file is not valid JSON Lines"

report="$(jq -r -s '
  def keys_ok: (keys == (["app_container_id","app_started_at","body","elapsed_ms","http_status","index","phase","scenario"]));
  def int_ge0: type == "number" and . == floor and . >= 0;
  def nonempty: type == "string" and length > 0;
  def plain: [.. | strings] | all(test("^[A-Za-z0-9_.:+ /-]{1,128}$"));
  def body_ok:
    (.body | type) == "object" and (.body | keys) == ["application","database","status"]
    and ((.http_status == 200 and .body == {status:"ok",application:"ok",database:"ok"})
      or (.http_status == 503 and .body == {status:"degraded",application:"ok",database:"unavailable"}));
  def main: .phase == "healthy" or .phase == "database-loss" or .phase == "database-recovery";
  def identity_ok:
    if main then (.app_container_id | nonempty) and (.app_started_at | nonempty)
    else ((.app_container_id == null or (.app_container_id | nonempty))
      and (.app_started_at == null or (.app_started_at | nonempty))) end;
  def record_errors($i):
    [ (if keys_ok | not then "keys must be exactly the 8 required fields" else empty end),
      (if (.phase | nonempty) | not then "phase must be a non-empty string" else empty end),
      (if (.scenario | nonempty) | not then "scenario must be a non-empty string" else empty end),
      (if (.index | int_ge0) | not then "index must be an integer >= 0" else empty end),
      (if (.http_status == 200 or .http_status == 503) | not then "http_status must be 200 or 503" else empty end),
      (if ((.elapsed_ms | type) == "number" and .elapsed_ms >= 0 and .elapsed_ms <= 5000) | not then "elapsed_ms must be within 0..5000" else empty end),
      (if body_ok | not then "body must be the exact three-field contract for its status" else empty end),
      (if identity_ok | not then "app identity required (non-empty) for main phases, string or null otherwise" else empty end),
      (if plain | not then "strings must be short plain text" else empty end)
    ] | map("record \($i): \(.)");
  . as $all
  | ([range(0; length) as $i | $all[$i] | record_errors($i)] | add // [])
  + ( [["healthy",200],["database-loss",503],["database-recovery",200]] | map(. as [$p, $code]
        | [$all[] | select(.phase == $p)] as $r
        | (if ($r | length) != 10 then "phase \($p): expected exactly 10 records, got \($r | length)" else empty end),
          (if ($r | all(.http_status == $code)) | not then "phase \($p): every record must be HTTP \($code)" else empty end)) )
  + ( [$all[] | select(main) | [.app_container_id, .app_started_at]] | unique
      | if length != 1 then ["main phases: app container id/start time must be identical across healthy, loss and recovery (found \(length) identities)"] else [] end )
  | .[]' "$file")"

if [ -n "$report" ]; then
  printf '%s\n' "$report" | head -20 >&2
  fail "request observations violate the evidence schema"
fi
if has_secret < "$file" >/dev/null || grep -qiE 'password|postgres(ql)?://|secret|token|stack|error:' "$file"; then
  fail "request observations contain credential-like, private connection or raw error data"
fi
pass "request observations valid: $(wc -l < "$file" | tr -d ' ') records, 10/10/10 main phases, one app identity"
