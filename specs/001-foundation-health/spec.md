# Feature Specification: PLATFORM-POC-001 — Foundation Health

**Feature Branch**: `poc/platform-poc-001`

**Created**: 2026-10-07

**Status**: Draft — awaiting HUMAN GATE #1

**Input**: [PLATFORM-POC-001 authoritative intent](../../docs/poc/PLATFORM-POC-001.md),
version 1.0, and the human's specification instructions of 2026-10-07.
Validate the SDD process through the first real Tool Hunter foundation slice:
a developer starts the local application and its required database, then uses
GET /api/health to distinguish application availability from full dependency-backed health.
Technology choices in the source are reserved for the later technical plan.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Determine Full Foundation Health (Priority: P1)

A developer starts the local foundation and checks whether the application and its required
database are both available, without mistaking a running application for a fully healthy system.

**Why this priority**: Reliable dependency-backed health is the core outcome of the PoC.

**Independent Test**: Start the foundation with valid configuration and a reachable database,
request GET /api/health, then make the database unavailable without stopping the application.
Compare the two observable results.

**Acceptance Scenarios**:

1. **Given** valid environment configuration and a running application with an available database,
   **When** a developer requests GET /api/health, **Then** an actual database operation succeeds
   and the response is HTTP 200 with overall status `ok`, application status `ok`,
   and database status `ok`.
2. **Given** the endpoint previously reported full health and the application process is still
   running, **When** the database becomes unavailable and a new health request is made after
   that loss, **Then** the request completes within five seconds with HTTP 503, overall status
   `degraded`, application status `ok`, and database status `unavailable`.
3. **Given** a running application whose configured database cannot be reached, **When** a
   developer requests health without any earlier successful database check, **Then** the
   response has the same unavailable result as scenario 2, never a full-health result.
4. **Given** database connectivity has been restored after a failure, **When** a new request
   successfully verifies that connectivity, **Then** the response reports full health again
   without requiring an application restart.
5. **Given** the application is stopped, **When** a developer attempts the health request,
   **Then** no health response is available; the documented instructions explain that this means
   application availability has not been established.

---

### User Story 2 - Start From a Fresh Checkout (Priority: P2)

A developer uses repository documentation and safe configuration examples to start the local
application and database without needing the original agent conversation.

**Why this priority**: Repeatable startup makes the first slice usable and independently verifiable.

**Independent Test**: Give a developer a fresh checkout and the documented prerequisites.
Have them configure, start, check, and stop the foundation using only repository instructions.

**Acceptance Scenarios**:

1. **Given** a fresh checkout with documented prerequisites satisfied, **When** a developer follows
   the documented configuration and startup commands, **Then** the required database and
   application start and scenario 1 of Story 1 can be performed.
2. **Given** safe environment examples and locally supplied connection values, **When** the
   foundation starts, **Then** those values select the required database without source edits.
3. **Given** missing or invalid required database configuration, **When** startup or health is
   attempted, **Then** either startup fails with an actionable configuration error or the
   running application reports the unavailable health result; full health is never reported.
4. **Given** a completed local run, **When** the developer follows the documented shutdown commands,
   **Then** the started foundation services stop.
5. **Given** the proposed repository contents and a health failure, **When** they are inspected,
   **Then** local secret files are excluded from version control, the committed environment
   example contains only safe values, and responses and shared diagnostic output expose no secrets.

---

### User Story 3 - Verify and Resume the SDD Experiment (Priority: P2)

An implementer, reviewer, or human decision maker can resume the feature from repository artifacts,
repeat its verification, identify remaining gaps, and control implementation and final promotion.

**Why this priority**: The PoC validates an evidence-based development process as well as the slice.

**Independent Test**: Give a reviewer the repository and verification records, without chat history.
Have them identify the approved scope, work status, repeatable checks, and pending human decision.

**Acceptance Scenarios**:

1. **Given** the documented verification procedure, **When** a developer runs it outside an agent,
   **Then** lint, typecheck, build, integration tests, and local service startup checks produce
   deterministic pass/fail results, including both healthy and unavailable database cases.
2. **Given** a proposed change or pushed revision, **When** deterministic CI runs, **Then** it
   executes the same core checks and publishes their outcomes without agent participation.
   A deliberately incorrect full-health result during database unavailability fails verification.
3. **Given** repository intent artifacts and work records, **When** an implementer or reviewer
   resumes without the original chat, **Then** they can identify the specification, plan, tasks,
   human reviews, implementation-to-task links, verification evidence, gaps, and next action.
4. **Given** completed verification, **When** a reviewer evaluates the implementation against the
   committed specification, plan, and tasks, **Then** remaining gaps are recorded as traceable
   work or the review records that no gaps remain; at most one human-directed repair cycle
   occurs before another explicit human decision.
5. **Given** an optional independent critic, **When** they inspect intent artifacts, diff,
   verification summary, and convergence outcome, **Then** critique is possible with read-only
   access and produces no source changes.
6. **Given** passing checks and a completed review, **When** promotion is considered, **Then**
   a recorded explicit human approval is required; otherwise no merge or promotion occurs.
7. **Given** the experiment is concluded, **When** its outcome is recorded, **Then** the result
   record contains the process and quality measurements required below, and further Tool Hunter
   iteration work waits for explicit human acceptance.

### Edge Cases

- A database listener accepts connections but cannot complete the required database operation:
  report unavailable, not full health.
- Connection refusal, invalid credentials, inaccessible configured destination, or a database
  operation that fails or does not finish within the health deadline: report unavailable.
- Database loss after a prior successful request: the next request MUST use new evidence and
  MUST NOT reuse a previous healthy result.
- Database loss during a check: report unavailable if that request's operation fails or times out.
  A successful operation represents availability at its observation time, not a guarantee of
  future availability.
- A database that intermittently succeeds and fails: each response reflects its own check.
- Missing configuration MUST NOT silently select an unrelated reachable database.
- Error responses and diagnostic records MUST NOT reveal credentials or private connection data.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The foundation MUST provide a locally startable application and required database
  dependency with documented startup and shutdown commands. No product interface is required.
- **FR-002**: The application MUST expose GET /api/health. Each request MUST verify the configured
  database through an actual database operation; process existence, an open port, configuration
  presence, a hard-coded result, or an earlier successful check MUST NOT establish database health.
- **FR-003**: Full health MUST be reported only when the application handles the request and that
  request's database operation succeeds. Its machine-readable response MUST contain fields
  `status: ok`, `application: ok`, and `database: ok`, with HTTP 200.
- **FR-004**: If the running application's database operation fails, cannot connect, or times out,
  GET /api/health MUST return HTTP 503 with machine-readable fields `status: degraded`,
  `application: ok`, and `database: unavailable`. It MUST NOT return a success status or
  full-health body in any such case, including database loss after earlier full health.
- **FR-005**: Every health request handled by the running application MUST finish within five
  seconds in the documented local verification environment. A database that does not answer
  within this deadline MUST be treated as unavailable.
- **FR-006**: Database connection configuration MUST come from environment variables and MUST
  be changeable without source edits. Missing or invalid required values MUST produce an
  actionable startup error or FR-004, never silently fall back to an unrelated database.
- **FR-007**: The repository MUST provide a safe `.env.example` and ignore local `.env` files.
  Credentials, tokens, cookies, passwords, private authentication material, and local secrets
  MUST NOT be committed or exposed in health responses or shared diagnostic output.
- **FR-008**: Fresh-checkout documentation MUST state prerequisites, environment setup, startup,
  health checks with expected healthy/unavailable outcomes, database-loss reproduction while
  the application remains running, verification, and shutdown commands.
- **FR-009**: Deterministic verification MUST include independently executable lint, typecheck,
  build, integration tests of actual database-backed health, and local service startup checks.
  At least one integration test MUST cover full health and loss of database availability while
  the application process remains running. A false full-health implementation MUST fail the test.
- **FR-010**: Deterministic CI MUST run on pushes and proposed-change reviews, execute the same
  core checks as local verification, and publish revision-linked pass/fail evidence. Neither
  running checks nor deciding their pass/fail result may require an AI agent.
- **FR-011**: The specification, subsequent plan, tasks, and supporting intent artifacts MUST be
  retained in version control. Implementation changes MUST be traceable to active task IDs.
  Repository records MUST identify reviewed revisions, human decisions, verification results,
  unresolved gaps, and the next action so work can resume without the original chat.
- **FR-012**: The SDD sequence MUST include human specification review, plan/task review before
  implementation, deterministic verification, convergence against committed intent artifacts,
  optional independent read-only critique, and explicit human approval before final promotion.
  Reviews MUST record gaps or evidence of no gaps. Repair MUST NOT be autonomous; a second
  repair cycle requires a new explicit human decision.
- **FR-013**: The experiment MUST record its outcome in
  `docs/poc/PLATFORM-POC-001-RESULT.md`: versions of participating tools; counts of manual
  cross-agent copy/paste operations, context re-explanations, human gates, repair cycles,
  convergence gaps, useful new critic findings, scope deviations, and broken SDD artifacts;
  elapsed time; CI outcome; and 1–5 human ratings for setup difficulty, switching friction,
  artifact clarity, review confidence, resume experience, and willingness to reuse.
  If optional critique is skipped, its findings MUST be recorded as not performed.
- **FR-014**: The PoC MUST use existing approved process tooling, introduce no prohibited
  orchestration components, and perform no automatic merge. After its final result and
  verification/review records are committed, further Tool Hunter iteration work MUST wait
  for explicit human acceptance.

### Key Entities *(include if feature involves data)*

- **Health observation**: A per-request assessment containing overall, application, and required
  database availability states. It represents the current operation's result, not saved history.
- **Environment configuration**: Locally supplied values selecting the required database;
  safe examples are committed, secret values are not.
- **Verification evidence**: Checked revision, repeatable procedure, expected conditions, and
  observed pass/fail results linked to acceptance criteria.
- **SDD work record**: Versioned intent artifacts, task links, review/gap records, human decisions,
  and experiment measurements sufficient for handoff and resumption. No agent database is needed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One developer using a fresh checkout and only repository instructions can configure,
  start, inspect, and stop the foundation with zero source edits and zero chat-history requests.
- **SC-002**: In a repeatable sequence of ten healthy checks, ten checks made after database loss
  with the application still running, and ten checks after restored connectivity, 100% classify
  the observed condition correctly. There are zero full-health reports during database loss.
- **SC-003**: Every health request in the documented healthy, refused-connection, and
  non-responsive-dependency acceptance runs yields its result within five seconds.
- **SC-004**: A human can run all five required verification categories without an AI agent;
  all pass on the accepted revision, and deliberately false full-health behavior fails verification.
- **SC-005**: Every push and proposed-change verification run publishes revision-linked results
  for the same core checks, with zero agent participation required to execute or judge them.
- **SC-006**: One implementer and one reviewer can each identify scope, current work status,
  evidence, remaining gaps, and next action using repository records alone. Every implementation
  change links to a task, and every required human gate has a revision-linked decision record.
- **SC-007**: Final review finds zero committed secrets, zero prohibited scope additions or
  orchestration components, and zero merges/promotions without explicit human approval.
- **SC-008**: Before acceptance, the experiment result contains every FR-013 measurement,
  and the human records accept, request changes, or abort plus whether this process is
  suitable for another iteration. Further iteration work has not started without acceptance.

## Assumptions

- Developers have the documented local prerequisites and permission to start and stop services.
  Dependency installation time is outside health-response timing; no startup-time target is imposed.
- Five seconds is a proposed local health-response deadline, selected to prevent indefinite waits;
  it is a human-reviewable default, not an unstated production performance commitment.
- The source permits a documented response shape. The three status fields and HTTP 200/503
  outcomes above are behavioral defaults selected to distinguish application availability
  from full health unambiguously.
- Availability means a successful operation against the configured database at check time.
  Recovery is assessed after connectivity is genuinely restored. The PoC makes no durability,
  domain-schema, load, production-deployment, or future-availability guarantee.
- Architecture and already-approved technology choices from the authoritative source belong
  to the later plan. The current command creates specification artifacts only.
- The existing private canonical repository and initialized process integrations are prerequisites,
  not requests to reconstruct the repository or reinstall tooling. Tool-specific role assignments
  from the source remain context for the later plan.
- Independent critique is optional. All other evidence and human gates remain required.

## Scope Boundaries

In scope: the local foundation, its required database, truthful health behavior, environment-driven
configuration, safe setup documentation, deterministic verification and CI, and repository-based
SDD handoff, review, and experiment evidence.

Out of scope: the Tool Hunter catalog and canonical 15 items; product UI and images;
Tool Hunter domain schema; authentication; PWA; Avito; SearchRun; backup/restore; Telegram;
VPS; Caddy; production deployment; Cline; Ruflo; custom orchestration; custom task queues;
agent databases; memory servers; LLM gateways; autonomous repair loops; and auto-merge.
Future platform experiments mentioned in the source do not authorize work in this PoC.

## Constitution Compliance

**Active constitution**: [Tool Hunter constitution](../../.specify/memory/constitution.md), v1.0.0.
This is specification compliance review, not proof of implementation or human approval.

| Principle | Specification compliance and required evidence |
| --- | --- |
| I. SPEC BEFORE CODE | Draft awaits HUMAN GATE #1; FR-012 requires review of specification and later plan/tasks before implementation. Reviewer, date, and reviewed revisions MUST be recorded. |
| II. PATCH THE CANONICAL REPOSITORY | Existing branch and repository are retained; only feature artifacts and the active-feature pointer are created. Later changes MUST remain reviewable patches against accepted artifacts. |
| III. DETERMINISTIC EVIDENCE OVER AGENT CLAIMS | FR-009–FR-011 and SC-004–SC-006 require repeatable results tied to revisions and criteria. Checklist completion does not assert feature completion. |
| IV. TESTS MUST BE EXECUTABLE OUTSIDE THE LLM | FR-009–FR-010 require independent verification and CI; executable procedures belong to the later plan and implementation. |
| V. NO SILENT SCOPE EXPANSION | FR-014 and Scope Boundaries limit work. Out-of-scope additions require human approval unless strictly necessary for an existing criterion; any exception MUST be documented before execution and disclosed in review. |
| VI. HUMAN PROMOTION GATE | FR-012 and FR-014 require explicit human approval; SC-007 checks for zero unauthorized promotions. |
| VII. SECRETS MUST NEVER ENTER GIT | FR-007 requires safe examples and ignored local secrets. Proposed diffs and staged files MUST be checked before commits; detected secrets block committing. |
| VIII. NO CUSTOM ORCHESTRATION | FR-014 and Scope Boundaries prohibit all restricted components. The process MUST reuse GitHub Spec Kit, Git, native agent CLIs, and deterministic CI. |
| Governance | No conflict identified in this specification. Source readiness wording does not bypass human gates. Each later plan and review MUST check all principles and Governance against v1.0.0. Conflicts MUST stop implementation until explicitly resolved by a human-reviewed correction or approved amendment. Human decisions override agent recommendations. |

Constitution changes require explicit human review and approval with semantic versioning.
No implementation or planning approval is inferred from this specification's quality result.
