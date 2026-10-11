# Один smoke-круг Claude и GPT

Эти команды создают одноразовый pull request и публикуют в нём протокол `AGENT_LOOP_V1`. Запуск Claude, GPT и переключение `dry_run` остаются у kit 1.3.1 на Mac: его программы в этом репозитории нет, и скрипт её не подменяет.

PR #2 и ветки `poc/*` не используются. Merge нет.

## Что сделать один раз на Mac

Файл `.agent-loop-smoke/doctor-preflight.txt` — это короткая форма. Её читает `preflight`. В неё переносятся шесть фактов из doctor kit, без значения token.

Аудит 11 октября уже фиксирует четыре из них: версия `1.3.1`, `dry_run` включён, sandbox обязателен, headless ещё не проверен. Их можно оставить как в шаблоне. Две строки kit ещё не закрыл: token file был `NOT_SET`, reviewer app не был задан. Пока они такие, `preflight` останавливается. Это правильная остановка, а не ошибка скрипта.

Когда doctor kit перестанет писать `NOT_SET`, замени `token_file` на слово `SET`. Когда появится slug GitHub App ревьюера, запиши его в `reviewer`. Логин `sanches16` туда не подходит: watcher не отличит его от оператора.

Команду doctor бери из `VALIDATION` в каталоге kit 1.3.1. Этот каталог лежит на Mac вне репозитория. Найти его можно так:

```bash
find "$HOME" -maxdepth 5 -type f -name 'VALIDATION*' 2>/dev/null
```

## Шесть команд

Из каталога со скриптами форма открывается так:

```bash
scripts/agent-loop-smoke/smoke.sh show
scripts/agent-loop-smoke/smoke.sh open
```

`show` печатает файл в терминале. Пока в строке `reviewer` заглушка, `open` редактор не запускает: править TextEdit не нужно. Если файла ещё не было, команда создаёт его из шаблона.

Имя reviewer, если GitHub App уже установлен:

```bash
scripts/agent-loop-smoke/smoke.sh apps
scripts/agent-loop-smoke/smoke.sh set-reviewer ИМЯ_ИЗ_СПИСКА
```

На копии шаблона `preflight` останавливается: token file ещё `NOT_SET`, reviewer ещё не задан. После замены этих двух строк выполни:

```bash
scripts/agent-loop-smoke/smoke.sh preflight
scripts/agent-loop-smoke/smoke.sh create-pr
scripts/agent-loop-smoke/smoke.sh negative-probes
```

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
