#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/agent-loop-smoke/smoke.sh"
# shellcheck source=lib.sh
. "$ROOT/scripts/agent-loop-smoke/lib.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_block() {
  label="$1"
  shift
  set +e
  ("$@") >/tmp/smoke-out.txt 2>/tmp/smoke-err.txt
  code=$?
  set -e
  [ "$code" -eq 2 ] || fail "$label завершился с кодом $code, а не 2"
  printf 'ok %s\n' "$label"
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/secret.txt" <<'EOF'
kit_version: 1.3.1
token=ghp_exampleSecretValue
EOF
expect_block "секрет в doctor" smoke_check_preflight_doctor "$tmp/secret.txt"
expect_block "reviewer sanches16" smoke_check_reviewer sanches16
expect_block "reviewer placeholder" smoke_check_reviewer replace-with-app-slug
grep -q 'заглушка' /tmp/smoke-err.txt || fail "сообщение про заглушку reviewer"

cat > "$tmp/preflight.txt" <<'EOF'
kit_version: 1.3.1
dry_run: true
sandbox_required: true
token_file: NOT_SET
reviewer: smoke-reviewer-app
headless_permissions_verified: true
EOF
expect_block "token не задан" smoke_check_preflight_doctor "$tmp/preflight.txt"

sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
handoff="$tmp/handoff.txt"
smoke_render_handoff "$sha" > "$handoff"
grep -q '```' "$handoff" && fail "handoff содержит fence"
grep -q "CANDIDATE_SHA: $sha" "$handoff" || fail "handoff без SHA"
[ "$(smoke_classify_comment "$handoff")" = "handoff" ] || fail "classify handoff"
smoke_render_fenced "$sha" > "$tmp/fenced.txt"
[ "$(smoke_classify_comment "$tmp/fenced.txt")" = "fenced" ] || fail "classify fenced"
smoke_render_duplicate "$sha" > "$tmp/dup.txt"
[ "$(smoke_classify_comment "$tmp/dup.txt")" = "duplicate" ] || fail "classify duplicate"
cat > "$tmp/decision.txt" <<EOF
PROTOCOL: AGENT_LOOP_V1
TYPE: REVIEW_DECISION
REVIEWED_SHA: $sha
DECISION: APPROVE
HUMAN_REQUIRED: false
FINDINGS:
- none
NEXT_ITERATION:
append smoke-ok
NEXT_ACTION:
IMPLEMENT
EOF
[ "$(smoke_classify_comment "$tmp/decision.txt")" = "decision" ] || fail "classify decision"
printf 'ok classify\n'

if grep -v '^#' "$ROOT/scripts/agent-loop-smoke/smoke.sh" "$ROOT/scripts/agent-loop-smoke/lib.sh" | grep -E 'claude|codex|pr merge' >/dev/null; then
  fail "скрипт содержит запуск модели или merge"
fi
printf 'ok script stays a mailbox\n'

show_repo="$tmp/showrepo"
mkdir -p "$show_repo"
(
  export SMOKE_REPO_DIR="$show_repo"
  export SMOKE_OPEN_LOG="$tmp/opened.txt"
  cat > "$tmp/fake-open" <<'EOF'
#!/bin/bash
printf '%s\n' "$1" > "${SMOKE_OPEN_LOG:?}"
EOF
  chmod +x "$tmp/fake-open"
  export SMOKE_OPEN_CMD="$tmp/fake-open"
  "$SCRIPT" show > "$tmp/show.txt"
  "$SCRIPT" open > "$tmp/open.txt"
  "$SCRIPT" set-reviewer smoke-reviewer-app > "$tmp/set-reviewer.txt"
)
grep -q 'doctor-preflight.txt' "$tmp/show.txt" || fail "show не показал путь"
grep -q 'reviewer: pending' "$tmp/show.txt" || fail "show не создал форму"
grep -q 'doctor-preflight.txt' "$tmp/opened.txt" || fail "open не открыл файл"
grep -q 'reviewer: smoke-reviewer-app' "$show_repo/.agent-loop-smoke/doctor-preflight.txt" || fail "set-reviewer не записал имя"
if SMOKE_REPO_DIR="$show_repo" "$SCRIPT" set-reviewer replace-with-app-slug >/tmp/set-bad.txt 2>&1; then
  fail "set-reviewer принял заглушку"
fi
printf 'ok show open set-reviewer\n'

bin="$tmp/bin"
mkdir -p "$bin" "$tmp/bodies"
cat > "$bin/gh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${GH_LOG:?}"
prev=""
body_file=""
for arg in "$@"; do
  if [ "$prev" = "--body-file" ]; then
    body_file="$arg"
  fi
  prev="$arg"
done
if [ -n "$body_file" ]; then
  count_file="${GH_BODIES}/count"
  count=0
  if [ -f "$count_file" ]; then
    count="$(cat "$count_file")"
  fi
  count=$((count + 1))
  printf '%s\n' "$count" > "$count_file"
  cp "$body_file" "${GH_BODIES}/body-${count}.txt"
fi
case "$1" in
  api)
    case "$2" in
      user) printf 'sanches16\n' ;;
      repos/*/compare/*) printf '%s\n' "${GH_COMPARE_FILES:-SMOKE.txt}" ;;
      *) printf 'unexpected api %s\n' "$2" >&2; exit 1 ;;
    esac
    ;;
  pr)
    case "$2" in
      create) printf 'https://github.com/sanches16/tool-hunter/pull/99\n' ;;
      comment) printf 'https://github.com/sanches16/tool-hunter/pull/99#issuecomment-10\n' ;;
      view) cat "${GH_PR_VIEW:?}" ;;
      close) printf 'closed\n' ;;
      *) printf 'unexpected pr %s\n' "$2" >&2; exit 1 ;;
    esac
    ;;
  issue)
    [ "$2" = "comment" ] || exit 1
    printf 'https://github.com/sanches16/tool-hunter/issues/1#issuecomment-11\n'
    ;;
  *) printf 'unexpected %s\n' "$1" >&2; exit 1 ;;
esac
EOF
chmod +x "$bin/gh"

repo="$tmp/repo"
remote="$tmp/remote.git"
git init -q -b main "$repo"
git init -q --bare "$remote"
git -C "$repo" config user.email "test@example.com"
git -C "$repo" config user.name "test"
echo init > "$repo/README"
git -C "$repo" add README
git -C "$repo" commit -q -m init
git -C "$repo" remote add origin "$remote"
git -C "$repo" push -q -u origin main

export PATH="$bin:$PATH"
export GH_LOG="$tmp/gh.log"
export GH_BODIES="$tmp/bodies"
export SMOKE_REPO_DIR="$repo"
export TMPDIR="$tmp/tmpdir"
mkdir -p "$TMPDIR"
: > "$GH_LOG"

mkdir -p "$repo/.agent-loop-smoke"
cat > "$repo/.agent-loop-smoke/doctor-preflight.txt" <<'EOF'
kit_version: 1.3.1
dry_run: true
sandbox_required: true
token_file: SET
reviewer: smoke-reviewer-app
headless_permissions_verified: true
EOF

"$SCRIPT" preflight >/tmp/smoke-preflight.txt
grep -q 'preflight PASS' /tmp/smoke-preflight.txt || fail "preflight"
"$SCRIPT" create-pr >/tmp/smoke-create.txt
grep -q 'https://github.com/sanches16/tool-hunter/pull/99' /tmp/smoke-create.txt || fail "create-pr"
git -C "$repo" ls-remote --heads origin smoke/agent-loop-head-001 | grep -q . || fail "head branch missing"
[ -f "$TMPDIR/tool-hunter-agent-loop-smoke/SMOKE.txt" ] || fail "SMOKE.txt missing"

"$SCRIPT" negative-probes >/tmp/smoke-neg.txt
grep -q 'fenced probe' /tmp/smoke-neg.txt || fail "negative probes"
if "$SCRIPT" handoff >/tmp/smoke-handoff-block.txt 2>&1; then
  fail "handoff без подтверждения должен остановиться"
fi

cat > "$repo/.agent-loop-smoke/doctor-live.txt" <<'EOF'
kit_version: 1.3.1
dry_run: false
sandbox_required: true
token_file: SET
reviewer: smoke-reviewer-app
headless_permissions_verified: true
live_target_pr: 2
EOF
if SMOKE_LIVE_HANDOFF=yes "$SCRIPT" handoff >/tmp/smoke-live-block.txt 2>&1; then
  fail "live target PR 2 должен быть запрещён"
fi
grep -q 'PR #2' /tmp/smoke-live-block.txt || fail "нет сообщения про PR 2"

cat > "$repo/.agent-loop-smoke/doctor-live.txt" <<'EOF'
kit_version: 1.3.1
dry_run: false
sandbox_required: true
token_file: SET
reviewer: smoke-reviewer-app
headless_permissions_verified: true
live_target_pr: 99
EOF
before="$(grep -c 'pr comment' "$GH_LOG" || true)"
SMOKE_LIVE_HANDOFF=yes "$SCRIPT" handoff >/tmp/smoke-handoff.txt
grep -q 'HANDOFF опубликован' /tmp/smoke-handoff.txt || fail "handoff"
after="$(grep -c 'pr comment' "$GH_LOG" || true)"
[ "$after" -eq $((before + 1)) ] || fail "handoff не опубликовал ровно один комментарий"
SMOKE_LIVE_HANDOFF=yes "$SCRIPT" handoff >/tmp/smoke-handoff-2.txt
again="$(grep -c 'pr comment' "$GH_LOG" || true)"
[ "$again" -eq "$after" ] || fail "повторный handoff опубликовал второй комментарий"
grep -q '```' "$repo/.agent-loop-smoke/handoff.txt" && fail "опубликованный handoff в fence"
printf 'ok roundtrip mailbox\n'

# shellcheck disable=SC1091
. "$repo/.agent-loop-smoke/state.env"
head_sha="$HEAD_SHA"
other="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
cat > "$tmp/pr.json" <<EOF
{"state":"OPEN","url":"https://github.com/sanches16/tool-hunter/pull/99","headRefOid":"$head_sha","comments":[]}
EOF
export GH_PR_VIEW="$tmp/pr.json"
"$SCRIPT" status >/tmp/smoke-status.txt
grep -q 'результат: WAITING_FOR_REVIEWER' /tmp/smoke-status.txt || fail "status waiting"

cat > "$tmp/pr.json" <<EOF
{"state":"OPEN","url":"https://github.com/sanches16/tool-hunter/pull/99","headRefOid":"$head_sha","comments":[{"body":"PROTOCOL: AGENT_LOOP_V1\nTYPE: REVIEW_DECISION\nREVIEWED_SHA: $head_sha\nHUMAN_REQUIRED: true\nNEXT_ACTION:\nSTOP\n"}]}
EOF
SMOKE_WATCH_LIMIT=1 SMOKE_WATCH_INTERVAL=0 "$SCRIPT" watch >/tmp/smoke-stop.txt
grep -q 'результат: STOPPED_BY_REVIEWER' /tmp/smoke-stop.txt || fail "stopped"

cat > "$tmp/pr.json" <<EOF
{"state":"OPEN","url":"https://github.com/sanches16/tool-hunter/pull/99","headRefOid":"$other","comments":[{"body":"PROTOCOL: AGENT_LOOP_V1\nTYPE: REVIEW_DECISION\nREVIEWED_SHA: $head_sha\nHUMAN_REQUIRED: false\nNEXT_ACTION:\nIMPLEMENT\n"},{"body":"PROTOCOL: AGENT_LOOP_V1\nTYPE: HANDOFF\nCANDIDATE_SHA: $other\nNEXT_ACTION:\nREVIEW\n"}]}
EOF
export GH_COMPARE_FILES="SMOKE.txt"
"$SCRIPT" status >/tmp/smoke-advanced.txt
grep -q 'результат: ADVANCED' /tmp/smoke-advanced.txt || fail "advanced"
printf 'ok status\n'

"$SCRIPT" close >/tmp/smoke-close.txt
grep -q 'закрыт без merge' /tmp/smoke-close.txt || fail "close"
grep -q 'pr merge' "$GH_LOG" && fail "close вызвал merge"
git -C "$repo" ls-remote --heads origin main | grep -q . || fail "main удалён"
if git -C "$repo" ls-remote --heads origin smoke/agent-loop-head-001 | grep -q .; then
  fail "head branch осталась"
fi
printf 'ok close\n'
printf 'ALL PASS\n'
