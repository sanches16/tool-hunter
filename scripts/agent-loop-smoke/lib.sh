# Mailbox helper for one throwaway AGENT-LOOP smoke PR.
# Does not launch Claude, Codex, or the kit watcher and does not edit kit config.

smoke_block() {
  printf 'СТОП: %s\n' "$1" >&2
  exit 2
}

smoke_die() {
  printf 'ОШИБКА: %s\n' "$1" >&2
  exit 1
}

smoke_say() {
  printf '%s\n' "$1"
}

SMOKE_GITHUB_REPO="${SMOKE_GITHUB_REPO:-sanches16/tool-hunter}"
SMOKE_REMOTE="${SMOKE_REMOTE:-origin}"
SMOKE_BASE_BRANCH="smoke/agent-loop-base-001"
SMOKE_HEAD_BRANCH="smoke/agent-loop-head-001"
SMOKE_FORBIDDEN_PR="2"
SMOKE_ITERATION="SMOKE-001"

smoke_repo_dir() {
  if [ -n "${SMOKE_REPO_DIR:-}" ]; then
    (cd "$SMOKE_REPO_DIR" && pwd)
    return
  fi
  (cd "$(dirname "$0")/../.." && pwd)
}

smoke_state_dir() {
  printf '%s/.agent-loop-smoke\n' "$(smoke_repo_dir)"
}

smoke_state_file() {
  printf '%s/state.env\n' "$(smoke_state_dir)"
}

smoke_worktree() {
  if [ -n "${WORKTREE:-}" ]; then
    printf '%s\n' "$WORKTREE"
    return
  fi
  printf '%s/tool-hunter-agent-loop-smoke\n' "${TMPDIR:-/tmp}"
}

smoke_require_tools() {
  command -v git >/dev/null 2>&1 || smoke_die "git не найден"
  command -v gh >/dev/null 2>&1 || smoke_die "gh не найден"
  command -v jq >/dev/null 2>&1 || smoke_die "jq не найден"
}

smoke_field_value() {
  file="$1"
  key="$2"
  awk -v key="$key" '
    $0 ~ ("^" key ":[[:space:]]*$") { getline; gsub(/\r/, ""); print; exit }
    $0 ~ ("^" key ":[[:space:]]+") {
      sub("^" key ":[[:space:]]+", "")
      gsub(/\r/, "")
      print
      exit
    }
  ' "$file"
}

smoke_reject_secret_file() {
  file="$1"
  if grep -E -q 'ghp_|github_pat_|sk-|AKIA|BEGIN [A-Z ]*PRIVATE KEY|token=[^[:space:]]+|bearer[[:space:]]+[A-Za-z0-9._~+/-]+=*' "$file"; then
    smoke_block "В $file есть похожая на секрет строка. Удали файл и сохрани отчёт doctor без значения token."
  fi
}

smoke_check_reviewer() {
  reviewer="$1"
  case "$reviewer" in
    ""|pending|PENDING|none|NONE|unknown|UNKNOWN|sanches16|replace-with-app-slug|your-app-slug|*"<"*|*">"*|*[!A-Za-z0-9._-]*)
      smoke_block "reviewer должен быть slug GitHub App из checklist kit, не логин sanches16 и не пустое значение. Сейчас: ${reviewer:-пусто}"
      ;;
  esac
}

smoke_load_state() {
  SMOKE_PR=""
  SMOKE_PR_URL=""
  HEAD_SHA=""
  NEGATIVE_FENCED=""
  NEGATIVE_DUPLICATE=""
  NEGATIVE_ISSUE=""
  HANDOFF_URL=""
  CLOSED=""
  WORKTREE=""
  state_file="$(smoke_state_file)"
  [ -f "$state_file" ] || return 0
  while IFS='=' read -r key value; do
    case "$key" in
      \#*|"") continue ;;
    esac
    case "$key" in
      SMOKE_PR) SMOKE_PR="$value" ;;
      SMOKE_PR_URL) SMOKE_PR_URL="$value" ;;
      HEAD_SHA) HEAD_SHA="$value" ;;
      NEGATIVE_FENCED) NEGATIVE_FENCED="$value" ;;
      NEGATIVE_DUPLICATE) NEGATIVE_DUPLICATE="$value" ;;
      NEGATIVE_ISSUE) NEGATIVE_ISSUE="$value" ;;
      HANDOFF_URL) HANDOFF_URL="$value" ;;
      CLOSED) CLOSED="$value" ;;
      WORKTREE) WORKTREE="$value" ;;
      *) smoke_die "неизвестное поле в $state_file: $key" ;;
    esac
  done < "$state_file"
  if [ -n "$SMOKE_PR" ]; then
    case "$SMOKE_PR" in
      ''|*[!0-9]*) smoke_die "SMOKE_PR в state повреждён" ;;
    esac
    [ "$SMOKE_PR" = "$SMOKE_FORBIDDEN_PR" ] && smoke_block "PR #2 запрещён для smoke"
  fi
  if [ -n "$HEAD_SHA" ]; then
    case "$HEAD_SHA" in
      [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
      *) smoke_die "HEAD_SHA в state повреждён" ;;
    esac
  fi
  if [ -n "$SMOKE_PR_URL" ]; then
    case "$SMOKE_PR_URL" in
      https://github.com/sanches16/tool-hunter/pull/*) ;;
      *) smoke_die "SMOKE_PR_URL в state повреждён" ;;
    esac
  fi
  if [ -n "$WORKTREE" ]; then
    case "$WORKTREE" in
      *".."*) smoke_die "WORKTREE в state повреждён" ;;
      */tool-hunter-agent-loop-smoke) ;;
      *) smoke_die "WORKTREE в state повреждён" ;;
    esac
  fi
}

smoke_save_state() {
  state_dir="$(smoke_state_dir)"
  mkdir -p "$state_dir"
  tmp="$(mktemp "$state_dir/state.XXXXXX")"
  {
    printf 'SMOKE_PR=%s\n' "$SMOKE_PR"
    printf 'SMOKE_PR_URL=%s\n' "$SMOKE_PR_URL"
    printf 'HEAD_SHA=%s\n' "$HEAD_SHA"
    printf 'NEGATIVE_FENCED=%s\n' "$NEGATIVE_FENCED"
    printf 'NEGATIVE_DUPLICATE=%s\n' "$NEGATIVE_DUPLICATE"
    printf 'NEGATIVE_ISSUE=%s\n' "$NEGATIVE_ISSUE"
    printf 'HANDOFF_URL=%s\n' "$HANDOFF_URL"
    printf 'CLOSED=%s\n' "$CLOSED"
    printf 'WORKTREE=%s\n' "$WORKTREE"
  } > "$tmp"
  mv "$tmp" "$(smoke_state_file)"
}

smoke_check_preflight_doctor() {
  file="$1"
  [ -f "$file" ] || smoke_block "Нет $file. Скопируй scripts/agent-loop-smoke/doctor-preflight.example.txt в этот путь и подставь строки из doctor kit 1.3.1. Значение token не записывай."
  smoke_reject_secret_file "$file"
  version="$(smoke_field_value "$file" kit_version)"
  [ "$version" = "1.3.1" ] || smoke_block "kit_version в doctor-preflight должен быть 1.3.1. Сейчас: ${version:-пусто}"
  dry="$(smoke_field_value "$file" dry_run)"
  [ "$dry" = "true" ] || smoke_block "Для preflight, create-pr и negative-probes dry_run должен быть true. Сейчас: ${dry:-пусто}"
  sandbox="$(smoke_field_value "$file" sandbox_required)"
  [ "$sandbox" = "true" ] || smoke_block "sandbox_required должен быть true. Сейчас: ${sandbox:-пусто}"
  token_file="$(smoke_field_value "$file" token_file)"
  [ "$token_file" = "SET" ] || smoke_block "token_file должен быть SET без самого значения. Сейчас: ${token_file:-пусто}. Создай token file по checklist kit и повтори doctor."
  reviewer="$(smoke_field_value "$file" reviewer)"
  smoke_check_reviewer "$reviewer"
  headless="$(smoke_field_value "$file" headless_permissions_verified)"
  case "$headless" in
    true) ;;
    false)
      smoke_say "Предупреждение: headless_permissions_verified=false. create-pr и negative-probes можно выполнить. handoff будет запрещён, пока kit не подтвердит headless."
      ;;
    *) smoke_block "headless_permissions_verified должен быть true или false. Сейчас: ${headless:-пусто}" ;;
  esac
}

smoke_check_live_doctor() {
  file="$1"
  pr="$2"
  [ -f "$file" ] || smoke_block "Нет $file. После переключения kit на этот PR сохрани новый отчёт doctor в этот путь. Шаблон: scripts/agent-loop-smoke/doctor-live.example.txt"
  smoke_reject_secret_file "$file"
  version="$(smoke_field_value "$file" kit_version)"
  [ "$version" = "1.3.1" ] || smoke_block "kit_version в doctor-live должен быть 1.3.1. Сейчас: ${version:-пусто}"
  dry="$(smoke_field_value "$file" dry_run)"
  [ "$dry" = "false" ] || smoke_block "Для handoff dry_run в doctor-live должен быть false и только для smoke PR. Сейчас: ${dry:-пусто}"
  sandbox="$(smoke_field_value "$file" sandbox_required)"
  [ "$sandbox" = "true" ] || smoke_block "sandbox_required должен быть true. Сейчас: ${sandbox:-пусто}"
  token_file="$(smoke_field_value "$file" token_file)"
  [ "$token_file" = "SET" ] || smoke_block "token_file должен быть SET. Сейчас: ${token_file:-пусто}"
  reviewer="$(smoke_field_value "$file" reviewer)"
  smoke_check_reviewer "$reviewer"
  headless="$(smoke_field_value "$file" headless_permissions_verified)"
  [ "$headless" = "true" ] || smoke_block "headless_permissions_verified должен быть true перед live handoff. Сейчас: ${headless:-пусто}"
  target="$(smoke_field_value "$file" live_target_pr)"
  case "$target" in
    ''|*[!0-9]*) smoke_block "live_target_pr должен быть номером smoke PR. Сейчас: ${target:-пусто}" ;;
  esac
  [ "$target" = "$SMOKE_FORBIDDEN_PR" ] && smoke_block "live_target_pr не может быть PR #2"
  [ "$target" = "$pr" ] || smoke_block "live_target_pr ($target) не совпадает со smoke PR ($pr)"
}

smoke_render_handoff() {
  sha="$1"
  cat <<EOF
PROTOCOL: AGENT_LOOP_V1
TYPE: HANDOFF
STATUS: READY_FOR_REVIEW
ITERATION: $SMOKE_ITERATION
BRANCH: $SMOKE_HEAD_BRANCH
CANDIDATE_SHA: $sha

CHANGED_FILES:
- SMOKE.txt
CHECKS:
- git diff --check: PASS, tested revision $sha
IMPLEMENTED:
- smoke file with a single line
DEVIATIONS:
- none
DEFECTS_FOUND:
- none
BLOCKERS:
- none
NEXT_ACTION:
REVIEW
EOF
}

smoke_render_fenced() {
  sha="$1"
  printf 'SMOKE NEGATIVE PROBE fenced\nЭтот комментарий внутри fence и не является командой.\n\n```text\n'
  smoke_render_handoff "$sha"
  printf '```\n'
}

smoke_render_duplicate() {
  sha="$1"
  smoke_render_handoff "$sha"
  printf '\n'
  smoke_render_handoff "$sha"
}

smoke_render_issue_probe() {
  sha="$1"
  printf 'SMOKE NEGATIVE PROBE issue-1\nIssue #1 не является каналом watcher.\n\n```text\n'
  smoke_render_handoff "$sha"
  printf '```\n'
}

smoke_classify_comment() {
  file="$1"
  if grep -q '```' "$file"; then
    printf 'fenced\n'
    return
  fi
  protocol_count="$(grep -c '^PROTOCOL:' "$file" || true)"
  if [ "$protocol_count" -gt 1 ]; then
    printf 'duplicate\n'
    return
  fi
  protocol="$(smoke_field_value "$file" PROTOCOL)"
  type="$(smoke_field_value "$file" TYPE)"
  if [ "$protocol" = "AGENT_LOOP_V1" ] && [ "$type" = "HANDOFF" ]; then
    printf 'handoff\n'
    return
  fi
  if [ "$protocol" = "AGENT_LOOP_V1" ] && [ "$type" = "REVIEW_DECISION" ]; then
    printf 'decision\n'
    return
  fi
  printf 'other\n'
}

smoke_require_open_smoke() {
  smoke_load_state
  [ -n "$SMOKE_PR" ] || smoke_block "Сначала выполни create-pr"
  [ "$CLOSED" != "yes" ] || smoke_block "Smoke PR уже закрыт"
  [ -n "$HEAD_SHA" ] || smoke_die "В state нет HEAD_SHA"
}

smoke_gh() {
  gh "$@"
}
