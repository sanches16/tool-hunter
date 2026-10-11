#!/usr/bin/env bash
# Пошаговый mailbox для одного smoke-круга AGENT-LOOP.
# Не запускает Claude, Codex и watcher. Не меняет конфиг kit. Не мержит PR.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Почтовый ящик одного smoke-круга. Watcher по-прежнему kit 1.3.1 на Mac.

  scripts/agent-loop-smoke/smoke.sh show
  scripts/agent-loop-smoke/smoke.sh open
  scripts/agent-loop-smoke/smoke.sh apps
  scripts/agent-loop-smoke/smoke.sh set-reviewer ИМЯ
  scripts/agent-loop-smoke/smoke.sh preflight
  scripts/agent-loop-smoke/smoke.sh create-pr
  scripts/agent-loop-smoke/smoke.sh negative-probes
  SMOKE_LIVE_HANDOFF=yes scripts/agent-loop-smoke/smoke.sh handoff
  scripts/agent-loop-smoke/smoke.sh status
  scripts/agent-loop-smoke/smoke.sh watch
  scripts/agent-loop-smoke/smoke.sh close
  scripts/agent-loop-smoke/smoke.sh abort

PR #2 и ветки poc/* не используются. Скрипт не публикует REVIEW_DECISION:
это делает reviewer через kit.
EOF
}

cmd_show() {
  file="$(smoke_ensure_preflight_file)"
  reviewer="$(smoke_field_value "$file" reviewer)"
  smoke_say "Файл формы:"
  smoke_say "$file"
  smoke_say "-----"
  cat -n "$file"
  smoke_say "-----"
  smoke_say "Строка reviewer сейчас: ${reviewer:-пусто}"
  case "$reviewer" in
    ""|pending|PENDING|replace-with-app-slug|your-app-slug|sanches16)
      smoke_say "Это заглушка из шаблона. Вручную её заменять не нужно, и TextEdit можно закрыть без сохранения."
      smoke_say "Строка token_file: SET в этом же шаблоне ещё не значит, что файл token создан."
      smoke_say "Пока в kit нет GitHub App для ревьюера, preflight обязан останавливаться."
      ;;
  esac
}

cmd_open() {
  file="$(smoke_ensure_preflight_file)"
  reviewer="$(smoke_field_value "$file" reviewer)"
  case "$reviewer" in
    ""|pending|PENDING|replace-with-app-slug|your-app-slug|sanches16)
      cmd_show
      smoke_say "Редактор не открываю: сейчас в строке reviewer нечего исправлять."
      return 0
      ;;
  esac
  cmd_show
  if [ -n "${SMOKE_OPEN_CMD:-}" ]; then
    "$SMOKE_OPEN_CMD" "$file"
    smoke_say "Открыл файл командой SMOKE_OPEN_CMD."
    return 0
  fi
  if command -v open >/dev/null 2>&1; then
    open -e "$file"
    smoke_say "Открыл файл в TextEdit. После правки сохрани его клавишами Cmd+S."
    return 0
  fi
  if [ -n "${EDITOR:-}" ]; then
    "$EDITOR" "$file"
    return 0
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$file"
    return 0
  fi
  smoke_say "Отдельный редактор не найден. Текст файла напечатан выше."
}

cmd_apps() {
  smoke_require_tools
  err="$(smoke_state_dir)/apps.err"
  mkdir -p "$(smoke_state_dir)"
  if ! slugs="$(gh api user/installations --jq '.installations[].app_slug' 2>"$err")"; then
    if grep -q '403' "$err"; then
      smoke_block "Обычный вход gh не может показать список GitHub App, сервер ответил 403. Это ограничение входа, не ошибка формы. Аудит kit от 11 октября говорит, что reviewer app ещё не создан. Строку reviewer заполнять нечем. TextEdit закрой без сохранения."
    fi
    smoke_die "Не удалось получить список GitHub App. Текст ошибки записан в $err"
  fi
  if [ -z "$slugs" ]; then
    smoke_block "GitHub App не найден. Пока его нет, строку reviewer заполнять нечем и preflight обязан останавливаться."
  fi
  smoke_say "Имена, которые можно записать в reviewer:"
  printf '%s\n' "$slugs"
  smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh set-reviewer ИМЯ"
}

cmd_set_reviewer() {
  slug="${1:-}"
  [ -n "$slug" ] || smoke_block "Напиши имя сразу после команды: scripts/agent-loop-smoke/smoke.sh set-reviewer ИМЯ"
  file="$(smoke_ensure_preflight_file)"
  smoke_set_reviewer_line "$file" "$slug"
  smoke_say "Записал в $file строку reviewer: $slug"
  smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh preflight"
}

cmd_preflight() {
  smoke_require_tools
  owner="$(gh repo view "$SMOKE_GITHUB_REPO" --json nameWithOwner --jq .nameWithOwner)"
  [ "$owner" = "sanches16/tool-hunter" ] || smoke_block "gh не видит sanches16/tool-hunter. Сейчас: ${owner:-пусто}"
  smoke_say "preflight PASS для sanches16/tool-hunter."
  smoke_say "GitHub App ревьюера на этом шаге не нужен."
  smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh create-pr"
}

cmd_create_pr() {
  smoke_require_tools
  smoke_load_state
  if [ -n "$SMOKE_PR" ] && [ "$CLOSED" != "yes" ]; then
    smoke_say "Smoke PR уже есть: $SMOKE_PR_URL"
    smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh negative-probes"
    return 0
  fi
  repo="$(smoke_repo_dir)"
  if git -C "$repo" ls-remote --heads "$SMOKE_REMOTE" "$SMOKE_HEAD_BRANCH" | grep -q .; then
    smoke_block "Ветка $SMOKE_HEAD_BRANCH уже есть на $SMOKE_REMOTE. Выполни abort или close, прежде чем создавать новую."
  fi
  if git -C "$repo" ls-remote --heads "$SMOKE_REMOTE" "$SMOKE_BASE_BRANCH" | grep -q .; then
    smoke_block "Ветка $SMOKE_BASE_BRANCH уже есть на $SMOKE_REMOTE. Выполни abort или close."
  fi
  git -C "$repo" fetch "$SMOKE_REMOTE" main
  WORKTREE="$(smoke_worktree)"
  work="$WORKTREE"
  case "$work" in
    *".."*) smoke_die "Некорректный путь worktree" ;;
    */tool-hunter-agent-loop-smoke) ;;
    *) smoke_die "Некорректный путь worktree" ;;
  esac
  if [ -d "$work" ]; then
    git -C "$repo" worktree remove --force "$work" || rm -rf "$work"
  fi
  git -C "$repo" worktree add --detach "$work" "$SMOKE_REMOTE/main"
  git -C "$work" checkout -B "$SMOKE_BASE_BRANCH"
  git -C "$work" push -u "$SMOKE_REMOTE" "$SMOKE_BASE_BRANCH"
  git -C "$work" checkout -B "$SMOKE_HEAD_BRANCH"
  printf 'base\n' > "$work/SMOKE.txt"
  git -C "$work" add SMOKE.txt
  git -C "$work" diff --check
  git -C "$work" commit -m "test: agent-loop smoke marker"
  git -C "$work" diff --check HEAD^ HEAD
  HEAD_SHA="$(git -C "$work" rev-parse HEAD)"
  git -C "$work" push -u "$SMOKE_REMOTE" "$SMOKE_HEAD_BRANCH"
  body_file="$(smoke_state_dir)/pr-body.txt"
  cat > "$body_file" <<EOF
Throwaway mailbox for AGENT-LOOP $SMOKE_ITERATION.
Do not merge. Head and base are smoke/* branches.
Watcher target, if enabled, must be this PR only.
EOF
  SMOKE_PR_URL="$(gh pr create \
    --repo "$SMOKE_GITHUB_REPO" \
    --base "$SMOKE_BASE_BRANCH" \
    --head "$SMOKE_HEAD_BRANCH" \
    --title "SMOKE-001 agent-loop throwaway" \
    --body-file "$body_file")"
  case "$SMOKE_PR_URL" in
    https://github.com/sanches16/tool-hunter/pull/*) ;;
    *) smoke_die "gh pr create вернул неожиданный URL" ;;
  esac
  SMOKE_PR="${SMOKE_PR_URL##*/}"
  [ "$SMOKE_PR" = "$SMOKE_FORBIDDEN_PR" ] && smoke_block "Создался PR #2. Закрой его без merge. Smoke на этом PR запрещён."
  NEGATIVE_FENCED=""
  NEGATIVE_DUPLICATE=""
  NEGATIVE_ISSUE=""
  HANDOFF_URL=""
  CLOSED=""
  smoke_save_state
  smoke_say "Создан $SMOKE_PR_URL"
  smoke_say "SHA: $HEAD_SHA"
  smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh negative-probes"
}

cmd_negative_probes() {
  smoke_require_tools
  smoke_require_open_smoke
  state_dir="$(smoke_state_dir)"
  if [ "$NEGATIVE_FENCED" != "posted" ]; then
    smoke_render_fenced "$HEAD_SHA" > "$state_dir/probe-fenced.txt"
    gh pr comment "$SMOKE_PR" --repo "$SMOKE_GITHUB_REPO" --body-file "$state_dir/probe-fenced.txt" >/dev/null
    NEGATIVE_FENCED="posted"
    smoke_save_state
    smoke_say "Опубликован fenced probe."
  fi
  if [ "$NEGATIVE_DUPLICATE" != "posted" ]; then
    smoke_render_duplicate "$HEAD_SHA" > "$state_dir/probe-duplicate.txt"
    gh pr comment "$SMOKE_PR" --repo "$SMOKE_GITHUB_REPO" --body-file "$state_dir/probe-duplicate.txt" >/dev/null
    NEGATIVE_DUPLICATE="posted"
    smoke_save_state
    smoke_say "Опубликован duplicate probe."
  fi
  if [ "$NEGATIVE_ISSUE" != "posted" ] && [ "$NEGATIVE_ISSUE" != "skipped-permission" ]; then
    smoke_render_issue_probe "$HEAD_SHA" > "$state_dir/probe-issue.txt"
    if gh issue comment 1 --repo "$SMOKE_GITHUB_REPO" --body-file "$state_dir/probe-issue.txt" >/dev/null 2>"$state_dir/issue-probe.err"; then
      NEGATIVE_ISSUE="posted"
      smoke_say "Опубликован fenced probe в Issue #1."
    else
      NEGATIVE_ISSUE="skipped-permission"
      smoke_say "Issue #1 не принял комментарий. Probe пропущен, текст ошибки в .agent-loop-smoke/issue-probe.err"
    fi
    smoke_save_state
  fi
  smoke_say "Пока dry_run=true, watcher не должен запускать Claude или GPT из-за этих комментариев. Проверь лог kit."
  smoke_say "Дальше переключи live-цель kit только на PR #$SMOKE_PR, сохрани doctor-live.txt и выполни handoff."
}

cmd_handoff() {
  smoke_require_tools
  smoke_require_open_smoke
  [ "${SMOKE_LIVE_HANDOFF:-}" = "yes" ] || smoke_block "handoff публикует рабочую команду. Повтори с SMOKE_LIVE_HANDOFF=yes после проверки doctor-live.txt"
  [ "$NEGATIVE_FENCED" = "posted" ] || smoke_block "Сначала negative-probes: нет fenced probe"
  [ "$NEGATIVE_DUPLICATE" = "posted" ] || smoke_block "Сначала negative-probes: нет duplicate probe"
  if [ -n "$HANDOFF_URL" ]; then
    smoke_say "HANDOFF уже опубликован: $HANDOFF_URL"
    smoke_say "Дальше: scripts/agent-loop-smoke/smoke.sh watch"
    return 0
  fi
  smoke_check_live_doctor "$(smoke_state_dir)/doctor-live.txt" "$SMOKE_PR"
  work="$(smoke_worktree)"
  case "$work" in
    *".."*) smoke_die "Некорректный путь worktree" ;;
    */tool-hunter-agent-loop-smoke) ;;
    *) smoke_die "Некорректный путь worktree" ;;
  esac
  [ -d "$work" ] || smoke_die "Нет worktree $work. Не публикую HANDOFF без повторной проверки diff."
  git -C "$work" diff --check HEAD^ HEAD || smoke_die "git diff --check не PASS, HANDOFF не опубликован"
  current="$(git -C "$work" rev-parse HEAD)"
  [ "$current" = "$HEAD_SHA" ] || smoke_die "SHA worktree не совпадает со state. HANDOFF не опубликован."
  body="$(smoke_state_dir)/handoff.txt"
  smoke_render_handoff "$HEAD_SHA" > "$body"
  if grep -q '```' "$body"; then
    smoke_die "Текст HANDOFF содержит fence. Публикация отменена."
  fi
  HANDOFF_URL="$(gh pr comment "$SMOKE_PR" --repo "$SMOKE_GITHUB_REPO" --body-file "$body")"
  case "$HANDOFF_URL" in
    https://github.com/sanches16/tool-hunter/*) ;;
    *) smoke_die "gh pr comment вернул неожиданный URL" ;;
  esac
  smoke_save_state
  smoke_say "HANDOFF опубликован: $HANDOFF_URL"
  smoke_say "Дальше ничего не пересылай Claude и GPT. Запусти: scripts/agent-loop-smoke/smoke.sh watch"
}

smoke_collect_status() {
  smoke_require_tools
  smoke_require_open_smoke
  view="$(smoke_state_dir)/pr-view.json"
  gh pr view "$SMOKE_PR" --repo "$SMOKE_GITHUB_REPO" --json state,url,headRefOid,comments > "$view"
  comments_dir="$(smoke_state_dir)/comments"
  rm -rf "$comments_dir"
  mkdir -p "$comments_dir"
  count="$(jq '.comments | length' "$view")"
  i=0
  fenced=0
  duplicate=0
  handoffs=0
  decisions=0
  decision_action=""
  decision_human=""
  decision_sha=""
  handoff_shas=""
  while [ "$i" -lt "$count" ]; do
    jq -r ".comments[$i].body" "$view" > "$comments_dir/$i.txt"
    kind="$(smoke_classify_comment "$comments_dir/$i.txt")"
    case "$kind" in
      fenced) fenced=$((fenced + 1)) ;;
      duplicate) duplicate=$((duplicate + 1)) ;;
      handoff)
        handoffs=$((handoffs + 1))
        sha="$(smoke_field_value "$comments_dir/$i.txt" CANDIDATE_SHA)"
        handoff_shas="$handoff_shas $sha"
        ;;
      decision)
        decisions=$((decisions + 1))
        decision_action="$(smoke_field_value "$comments_dir/$i.txt" NEXT_ACTION)"
        decision_human="$(smoke_field_value "$comments_dir/$i.txt" HUMAN_REQUIRED)"
        decision_sha="$(smoke_field_value "$comments_dir/$i.txt" REVIEWED_SHA)"
        ;;
      other) ;;
    esac
    i=$((i + 1))
  done
  current_sha="$(jq -r '.headRefOid' "$view")"
  pr_state="$(jq -r '.state' "$view")"
  result="WAITING_FOR_REVIEWER"
  if [ "$decisions" -gt 1 ]; then
    result="DUPLICATE_DECISION"
  elif [ "$decisions" -eq 1 ] && [ "$decision_sha" != "$HEAD_SHA" ]; then
    result="DECISION_SHA_MISMATCH"
  elif [ "$decisions" -eq 1 ] && { [ "$decision_human" = "true" ] || [ "$decision_action" = "STOP" ] || [ "$decision_action" = "HUMAN_GATE" ]; }; then
    result="STOPPED_BY_REVIEWER"
  elif [ "$decisions" -eq 1 ] && [ "$decision_action" = "IMPLEMENT" ] && [ "$current_sha" = "$HEAD_SHA" ]; then
    result="WAITING_FOR_IMPLEMENTER"
  elif [ "$decisions" -eq 1 ] && [ "$decision_action" = "IMPLEMENT" ] && [ "$current_sha" != "$HEAD_SHA" ]; then
    files="$(gh api "repos/$SMOKE_GITHUB_REPO/compare/${HEAD_SHA}...${current_sha}" --jq '[.files[].filename] | join(" ")')"
    extra=""
    for name in $files; do
      [ "$name" = "SMOKE.txt" ] || extra="$extra $name"
    done
    second=0
    for sha in $handoff_shas; do
      [ "$sha" = "$current_sha" ] && second=1
    done
    if [ -n "$extra" ]; then
      result="FILES_OUTSIDE_SMOKE"
    elif [ "$second" -eq 1 ]; then
      result="ADVANCED"
    else
      result="WAITING_FOR_SECOND_HANDOFF"
    fi
  fi
  smoke_say "PR: $(jq -r '.url' "$view") ($pr_state)"
  smoke_say "исходный SHA: $HEAD_SHA"
  smoke_say "текущий SHA: $current_sha"
  smoke_say "комментарии: fenced=$fenced duplicate=$duplicate handoff=$handoffs decision=$decisions"
  if [ "$decisions" -eq 1 ]; then
    smoke_say "decision: NEXT_ACTION=$decision_action HUMAN_REQUIRED=$decision_human REVIEWED_SHA=$decision_sha"
  fi
  smoke_say "результат: $result"
  SMOKE_STATUS_RESULT="$result"
}

cmd_status() {
  smoke_collect_status
}

cmd_watch() {
  limit="${SMOKE_WATCH_LIMIT:-30}"
  interval="${SMOKE_WATCH_INTERVAL:-30}"
  n=0
  while [ "$n" -lt "$limit" ]; do
    smoke_collect_status
    case "$SMOKE_STATUS_RESULT" in
      ADVANCED|STOPPED_BY_REVIEWER)
        return 0
        ;;
      DUPLICATE_DECISION|DECISION_SHA_MISMATCH|FILES_OUTSIDE_SMOKE)
        return 1
        ;;
    esac
    n=$((n + 1))
    if [ "$n" -lt "$limit" ]; then
      smoke_say "жду ${interval}с, проверка $n из $limit"
      sleep "$interval"
    fi
  done
  smoke_block "За отведённое время круг не завершился. Это наблюдение: скрипт никого не дозапускает."
}

cmd_close() {
  smoke_require_tools
  smoke_load_state
  [ -n "$SMOKE_PR" ] || smoke_block "Нет smoke PR в state"
  gh pr close "$SMOKE_PR" --repo "$SMOKE_GITHUB_REPO" --comment "SMOKE-001 finished. This PR must stay unmerged." >/dev/null || true
  repo="$(smoke_repo_dir)"
  git -C "$repo" push "$SMOKE_REMOTE" --delete "$SMOKE_HEAD_BRANCH" || true
  git -C "$repo" push "$SMOKE_REMOTE" --delete "$SMOKE_BASE_BRANCH" || true
  work="$(smoke_worktree)"
  case "$work" in
    */tool-hunter-agent-loop-smoke)
      if [ -d "$work" ]; then
        git -C "$repo" worktree remove --force "$work" || true
      fi
      ;;
  esac
  CLOSED="yes"
  smoke_save_state
  smoke_say "PR #$SMOKE_PR закрыт без merge, smoke-ветки удалены, если remote это позволил."
  smoke_say "Верни в kit dry_run=true и убери этот PR из live-целей."
}

cmd_abort() {
  smoke_require_tools
  smoke_load_state
  if [ -n "$SMOKE_PR" ] && [ "$CLOSED" != "yes" ]; then
    smoke_block "PR уже создан. Используй close, чтобы закрыть его без merge."
  fi
  repo="$(smoke_repo_dir)"
  git -C "$repo" push "$SMOKE_REMOTE" --delete "$SMOKE_HEAD_BRANCH" || true
  git -C "$repo" push "$SMOKE_REMOTE" --delete "$SMOKE_BASE_BRANCH" || true
  work="$(smoke_worktree)"
  case "$work" in
    */tool-hunter-agent-loop-smoke)
      if [ -d "$work" ]; then
        git -C "$repo" worktree remove --force "$work" || true
      fi
      ;;
  esac
  smoke_say "Локальный worktree и удалённые smoke-ветки очищены, если они существовали. PR не создавался или уже закрыт."
}

command_name="${1:-help}"
shift || true
case "$command_name" in
  help|-h|--help) usage ;;
  show) cmd_show ;;
  open) cmd_open ;;
  apps) cmd_apps ;;
  set-reviewer) cmd_set_reviewer "${1:-}" ;;
  preflight) cmd_preflight ;;
  create-pr) cmd_create_pr ;;
  negative-probes) cmd_negative_probes ;;
  handoff) cmd_handoff ;;
  status) cmd_status ;;
  watch) cmd_watch ;;
  close) cmd_close ;;
  abort) cmd_abort ;;
  *)
    usage >&2
    smoke_die "неизвестная команда: $command_name"
    ;;
esac
