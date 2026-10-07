# Shared constants for platform-poc-001 checks. Sourced, not executed.
set -euo pipefail

FEATURE_DIR="specs/001-foundation-health"
REVIEWS_DIR="$FEATURE_DIR/reviews"
POC_BRANCH="poc/platform-poc-001"
APP_URL="${POC_APP_URL:-http://localhost:3000}"

# Artifacts approved at HUMAN GATE #1 (blob ids recorded in HUMAN_GATE_1.md).
APPROVED_BLOBS=(
  ".specify/memory/constitution.md=25080e3ae3be7e6fed9c215999bbeb49f773cfe9"
  "$FEATURE_DIR/spec.md=23cf8c39cbf6e308fc93ab46b05c306fee0eb085"
  "$FEATURE_DIR/checklists/requirements.md=32d170a9eb2316f9630407b5833db8214b33a3de"
)

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# Fails if any HUMAN GATE #1 artifact differs from its approved blob.
check_protected_artifacts() {
  local entry path blob actual
  for entry in "${APPROVED_BLOBS[@]}"; do
    path="${entry%%=*}"; blob="${entry#*=}"
    [ -f "$path" ] || fail "approved artifact missing: $path"
    actual="$(git hash-object "$path")"
    [ "$actual" = "$blob" ] || fail "approved artifact changed: $path ($actual != $blob)"
  done
  pass "constitution, spec.md and requirements checklist match HUMAN GATE #1"
}

# Prints the compose service that runs PostgreSQL (override with POC_DB_SERVICE).
db_service() {
  if [ -n "${POC_DB_SERVICE:-}" ]; then echo "$POC_DB_SERVICE"; return; fi
  local svc
  svc="$(docker compose config --services | grep -iE '^(db|postgres|postgresql|database)$' | head -1 || true)"
  [ -n "$svc" ] || fail "no PostgreSQL service found in docker compose config (set POC_DB_SERVICE)"
  echo "$svc"
}
