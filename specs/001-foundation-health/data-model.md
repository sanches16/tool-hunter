# Data Model: PLATFORM-POC-001 — Foundation Health

Basis: approved [spec.md](spec.md), constitution v1.0.0 and [plan.md](plan.md).
No domain schema, ORM, application tables or migrations. PostgreSQL is a probed dependency;
health observations remain transient. Process records are files and Git history, not an agent DB.

## Health observation

| Field | Type | Allowed value / validation |
| --- | --- | --- |
| status | string | `ok` only after this request's successful SQL operation; otherwise `degraded` |
| application | string | `ok` whenever this running application returns a health response |
| database | string | `ok` after successful SQL; otherwise `unavailable` |

Only two valid combinations: HTTP 200 + `ok/ok/ok`, or HTTP 503 +
`degraded/ok/unavailable`. No additional JSON fields, diagnostics, timestamps or configuration.
[OpenAPI contract](contracts/health.openapi.yaml) specifies exact bodies and no-store behavior.
The client-side observation of an unreachable application is not a JSON observation returned by
this endpoint; no application-unavailable response can be promised by a stopped process.

Each request follows: received → configuration validation → connecting → querying →
healthy or unavailable → response. Validation failure can go directly to unavailable.
Errors/deadlines from any pending probe phase go to unavailable. Success requires `SELECT 1`
completion and expected result before the total probe deadline. Timed-out observations never become
healthy due to late completion. Clients/timers are reclaimed, with no saved observation history.
A subsequent request starts a new observation and may recover independently.

## Environment configuration

| Field | Type | Validation / relationship |
| --- | --- | --- |
| POSTGRES_HOST | string | Required, nonempty, explicit destination; Compose app uses `db` |
| POSTGRES_PORT | integer text | Required, digits only, range 1–65535; Compose app uses `5432` |
| POSTGRES_DB | string | Required, nonempty; same database initialized by Compose |
| POSTGRES_USER | string | Required, nonempty; same local role initialized by Compose |
| POSTGRES_PASSWORD | private string | Required, nonempty; locally supplied, never versioned or echoed |

Host/db/user values are also private connection information in diagnostics. Validate required strings
without silently changing passwords or selecting fallback values. Keep credentials local to `.env`
or the CI job environment. Only non-sensitive examples are versioned; `.env.example` has empty
password. Configuration is read server-side at runtime; build does not require it.
See [runtime contract](contracts/runtime.md) for startup and command behavior.
Each health observation uses one configuration snapshot and exactly its selected database.
Changing configuration may require app restart; database recovery with unchanged configuration must not.

## Verification evidence (versioned record)

Required fields: checked commit SHA, branch, date, verifier/human identity where applicable,
prerequisites/tool versions, exact commands/procedure, expected conditions, observed exit codes and
sanitized outputs, criterion IDs, CI job URL/status when applicable, unresolved gaps and next action.
Request evidence includes phase, request index, HTTP code, parsed three-field body and monotonic
elapsed time; loss/recovery evidence includes unchanged app identity/process start time.
Evidence references one checked revision and one or more FR/SC criteria. A passing check covers only
its criteria/revision; failures or missing checks leave related work incomplete. Do not store raw
connection errors, env files, credentials or private connection strings in evidence.

## SDD work record (files and Git)

- Intent: constitution version, spec/plan/tasks paths and reviewed Git revisions/blob identifiers.
- Work: task IDs linked to implementation changes/commits; deviations and gaps with criterion IDs.
- Decisions: gate number, reviewer, date, reviewed revision/artifacts, approve/request changes/abort,
  authorized next action. Planning approval is distinct from implementation and promotion approval.
- Reviews: convergence revision, evidence and remaining gaps or evidence of no gaps; optional critic
  identity, read-only outcome/new useful findings or explicitly `not performed`.
- Experiment result: `docs/poc/PLATFORM-POC-001-RESULT.md`, with participating Codex/Claude/Grok/Spec Kit/
  Docker/Node versions; manual cross-agent copy/paste, context re-explanation, human gate and repair
  counts; elapsed time; CI outcome; convergence gap, useful critic finding, scope deviation and broken
  artifact counts; human 1–5 ratings for setup difficulty, switching friction, artifact clarity,
  review confidence, resume experience and willingness to reuse. Optional nonparticipation is explicit.

Relationships: decisions identify artifact revisions; task-linked patches implement criteria;
evidence evaluates those patches; convergence links gaps to criteria/tasks; the result references
all gates, evidence and final decision. No hidden conversational state is needed for resumption.

Process transitions: approved spec → plan/tasks/analysis → HUMAN GATE #2 → committed reviewed
baseline → task implementation → deterministic checks → convergence → optional read-only critique
→ human promotion decision → final result/records and stop. Repair requires human direction;
a second cycle requires another explicit decision. A changed reviewed scope/approach returns to
human review. No transition auto-merges or authorizes a further Tool Hunter iteration.
