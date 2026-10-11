# Один smoke-круг Claude и GPT

Эти команды создают одноразовый pull request и публикуют в нём протокол `AGENT_LOOP_V1`. Запуск Claude, GPT и переключение `dry_run` остаются у kit 1.3.1 на Mac: его программы в этом репозитории нет, и скрипт её не подменяет.

PR #2 и ветки `poc/*` не используются. Merge нет.

## Шаг, который проходит сейчас

GitHub App ревьюера ещё нет, и обычный вход `gh` его список не показывает. Поэтому `preflight` больше не спрашивает форму и имя приложения. Он проверяет только, что репозиторий `sanches16/tool-hunter` доступен.

```bash
scripts/agent-loop-smoke/smoke.sh preflight
scripts/agent-loop-smoke/smoke.sh create-pr
scripts/agent-loop-smoke/smoke.sh negative-probes
```

`create-pr` открывает одноразовый PR между ветками `smoke/agent-loop-*`. `negative-probes` пишет комментарии, которые watcher не должен исполнять. Команда `handoff` по-прежнему ждёт отдельного GitHub App и на этом шаге не запускается.

`negative-probes` пишет три комментария, которые watcher обязан проигнорировать: текст в fence, дубль полей и такой же fence в Issue #1. Пока `dry_run=true`, в логе kit не должно быть запуска Claude или GPT. Если запуск был, остановись на `abort` или `close` и не выполняй `handoff`.

Дальше в kit оставь единственной live-целью номер PR из вывода `create-pr`. Сними `dry_run` только для него. Сохрани новый отчёт:

```bash
cp scripts/agent-loop-smoke/doctor-live.example.txt .agent-loop-smoke/doctor-live.txt
```

В `doctor-live.txt` поставь `dry_run: false`, `headless_permissions_verified: true`, тот же `reviewer` и номер PR из вывода `create-pr` в `live_target_pr`. Затем:

```bash
SMOKE_LIVE_HANDOFF=yes scripts/agent-loop-smoke/smoke.sh handoff
scripts/agent-loop-smoke/smoke.sh watch
```

`watch` только читает PR. Когда reviewer опубликует `REVIEW_DECISION`, kit должен один раз запустить Claude. Успех выглядит так: новый SHA, изменён только `SMOKE.txt`, и есть второй `HANDOFF` с этим SHA. `STOPPED_BY_REVIEWER` тоже успешная остановка: Claude не стартует.

После этого верни в kit `dry_run=true` и выполни:

```bash
scripts/agent-loop-smoke/smoke.sh close
```

`close` закрывает PR без merge и удаляет ветки `smoke/agent-loop-base-001` и `smoke/agent-loop-head-001`.

Каталог `.agent-loop-smoke/` в git не входит. Временный checkout скрипт кладёт в `$TMPDIR/tool-hunter-agent-loop-smoke`.
