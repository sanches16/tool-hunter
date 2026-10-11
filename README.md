# Tool Hunter

Приватное приложение для управления покупками, каталогом, предложениями marketplace и историей цен. Первый сценарий — инструменты и поиск Avito в Москве.

В рамках проекта также создаётся **переиспользуемая мультиагентная платформа разработки**. Tool Hunter — её первый реальный проект: GPT/Codex готовит требования и review, Claude реализует ограниченные срезы, независимые тесты и CI подтверждают результат, владелец принимает финальное решение.

## Два подробных описания

| Для кого | Документ | Что внутри |
| --- | --- | --- |
| Для человека | [Описание проекта](docs/PROJECT_OVERVIEW_RU.md) | Зачем строим, сценарии, модель продукта, архитектура, история платформы, текущая стадия, подробный бэклог и дорожная карта |
| Для Cursor / AI-разработчика | [Контекст и инструкция](docs/CURSOR_CONTEXT_RU.md) | Branch/SHA, источники и scope, карта кода, contracts, commands, evidence, handoff protocol, ограничения и следующий записанный шаг |

Описания сверены **11 октября 2026** по GitHub, исходным спецификациям и доступным артефактам. Это snapshot; перед работой нужно перечитать текущие refs и последние решения.

## На какой стадии

- Текущий этап — `PLATFORM-POC-001`, проверка технического foundation и SDD-процесса перед продуктовой Iteration 0.
- Health endpoint с настоящим PostgreSQL, Docker, integration tests, startup verifier и CI реализованы в `poc/platform-poc-001-incremental` на `170f838ac583db4de0179450ac3b08c863864e7b`.
- [PR #2](https://github.com/sanches16/tool-hunter/pull/2) открыт и не слит; его base — `poc/platform-poc-001`, не main.
- Последний принятый срез — D3C1; следующий записанный шаг — D3C2, fresh checkout proof без изменений исходников. Final PoC acceptance ещё не подтверждён.
- Главная текущая трудность платформы — автоматизация проверки и передачи шагов **между Claude и GPT**. Экспериментальный workflow 1.2.6 заморожен; agent-loop kit 1.3.1 дошёл до `READY_FOR_SMOKE` в dry-run. Полный live round-trip ещё не доказан.
- Пошаговые команды одноразового smoke-круга, без запуска моделей из репозитория: [scripts/agent-loop-smoke/README.md](scripts/agent-loop-smoke/README.md).
- В main опубликованы документы и reference-источники. Runtime приложения здесь пока отсутствует; эта публикация не сливает PoC и не запускает следующую итерацию.

## Откуда взялась платформа

Выбранная основа: [GitHub Spec Kit](https://github.com/github/spec-kit) + native [Codex CLI](https://github.com/openai/codex), Claude Code и optional Grok Build; Git хранит артефакты, GitHub Actions выполняет независимые проверки. Cline Teams и Ruflo рассматривались как последующие кандидаты.

Подробности выбора и проблемы автоматизации описаны в [истории проекта](docs/PROJECT_OVERVIEW_RU.md#9-история-и-причины-смены-подхода).

## Первичные источники

- [Master-spec продукта 1.0.0-READY](docs/reference/TOOL_HUNTER_MASTER_SPEC_v1.0_READY.md) — исходный документ без изменений; применять для продуктовой Iteration 0 после приёмки PoC.
- [Сравнение платформ и архитектура PoC](docs/reference/PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md) — исторический draft выбора Spec Kit/native lanes.
- [Конституция](.specify/memory/constitution.md).
- [PLATFORM-POC-001](docs/poc/PLATFORM-POC-001.md).
- [Mac setup result](docs/poc/MAC_SETUP_RESULT.md).
- [Runtime README exact candidate](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/README.md) — инструкции запуска кода PoC.
- [Issue #1: PoC handoff/review](https://github.com/sanches16/tool-hunter/issues/1), [Issue #3: agent-loop audit](https://github.com/sanches16/tool-hunter/issues/3).

## Для Cursor

Открой репозиторий и прочитай [docs/CURSOR_CONTEXT_RU.md](docs/CURSOR_CONTEXT_RU.md). Добавлено краткое [project rule](.cursor/rules/tool-hunter-context.mdc) с `alwaysApply: true`, направляющее агента к полному контексту; формат описан в [документации Cursor](https://cursor.com/docs/rules).

Контекст и roadmap не являются разрешением реализовать весь бэклог. Каждая итерация имеет reviewed scope, exact revision, проверки, handoff и stop point. Merge/promotion требует явного решения владельца.
