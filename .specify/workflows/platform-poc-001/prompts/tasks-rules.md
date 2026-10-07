# Task generation rules for PLATFORM-POC-001

Binding for `speckit.tasks` in this workflow. Source: owner's HUMAN GATE 2B
rejection of candidate 614dde8 (see `docs/poc/PLATFORM-POC-001-RUN-HISTORY.md`).
These rules clarify task boundaries only; they do not change spec.md, the
constitution, the approved plan or HUMAN_GATE_2A.

## 1. Role boundary (checkbox tasks = implementer file edits only)

`speckit-implement` executes every unchecked `- [ ]` task in tasks.md. In this
workflow the implementer (Claude) can only read, create and edit repository
files (plus read-only `git status/diff/log`). It never runs npm/npx/node,
Docker, gh or git push, never commits, never runs Spec Kit converge or the Grok
critic, and never makes or records human decisions or ratings.

Therefore every checkbox task MUST be work completable purely by file edits:
source code, tests, fixtures/helpers, configuration, Dockerfile/Compose files,
the GitHub Actions workflow file, verification scripts, README, and the initial
`docs/poc/PLATFORM-POC-001-RESULT.md` structure with placeholders (which links
`docs/poc/PLATFORM-POC-001-RUN-HISTORY.md` and must not edit it).

No checkbox task may require any of: running npm test or any local
verification, executing a fresh checkout, starting Docker, observing GitHub CI,
committing or pushing, running speckit-converge, running the Grok critic,
making or recording a human decision, obtaining human ratings, final
promotion/merge, or a records-only commit.

Those obligations must not be lost. After the implementation phases add a
plain (non-checkbox) section exactly titled:

`## Workflow-owned verification and human obligations`

containing a traceability matrix table with columns:
requirement / SC | responsible workflow stage | owner (shell / Codex / Grok / Human) | expected evidence artifact

Workflow stages available (step ids in
`.specify/workflows/platform-poc-001/workflow.yml`; use these exact names):

- `implementation-inputs` (shell): read-only resolution of exact npm versions
  and Node 24 / PostgreSQL 17 image digests, handed to the implementer.
- `local-checks` (shell): lockfile generation if missing, then exactly `npm ci`,
  `npm run lint`, `npm run typecheck`, `npm run build`, `npm test`,
  `npm run verify:startup`; sanitized evidence.
- `docker-health` (shell): ephemeral-config production Compose lifecycle —
  startup, exact 200, DB stop → exact 503 ≤5 s, DB start → 200 with unchanged
  app container/process, app stop → no response, cleanup of own resources.
- `safety-review` (shell, after local/Docker checks, before implement-commit):
  approved spec/plan/workflow artifacts unchanged; package.json limited to the
  approved dependency set and no forbidden packages in package-lock.json;
  changed paths free of excluded scope; `.dockerignore` excludes `.env*`,
  `.git`, `node_modules`, `.next`, `.agent-out`; `.env.example` tracked; real
  `.env*` files untracked and ignored; no credential/key material; sanitized
  evidence recorded in RESULT. This is the producer for dependency, Docker
  image/context exclusion, local env and scope reviews (SC-007).
- `implement-commit` (shell): ONLY staged-content secret/credential guard,
  commit, push, and clean-tree / origin verification. Do not attribute
  dependency, image-exclusion, env or scope review to `implement-commit`.
- `ci` (shell): observe GitHub Actions for that commit on BOTH paths — the
  `push` run and the `pull_request` run of an open (or workflow-created draft,
  verification-only) PR from `poc/platform-poc-001` into `main`.
- `fresh-checkout` (shell, no agent, no chat history): fresh clone of the
  canonical repository at the pushed SHA, ignored `.env` from `.env.example`
  with a generated password, documented Compose lifecycle (configure, start,
  inspect, DB loss, recovery, stop), zero source edits, full cleanup.
- `record-results` + `results-commit` (shell): toolchain versions (Spec Kit,
  Codex, Claude, Grok incl. participation, Node, npm, Docker, Compose), tested
  SHA, local/Docker/fresh-checkout/push-CI/PR-CI results with criterion mapping,
  and versioned sanitized evidence files under `docs/poc/evidence/<sha>/` into
  `docs/poc/PLATFORM-POC-001-RESULT.md`; separate records-only commit.
- `verification-enforce` (shell): requires push CI, pull_request CI and fresh
  checkout to have passed.
- `resume-implementer` (fresh Claude process) and `resume-reviewer` (fresh
  Codex process): read-only, repository-only assessments of a fresh clone
  (approved scope, status, evidence, gaps, next action) saved as
  `reviews/RESUME_IMPLEMENTER.md` / `reviews/RESUME_REVIEWER.md` and linked
  from RESULT (SC-006).
- `converge` (Codex) and `critic` (Grok, optional, read-only): revision-linked
  reports in `reviews/`, linked from RESULT by the workflow.
- `metrics-gate` + `metrics-record` (Human values, shell writes): FR-013 counts,
  six 1–5 ratings and platform decision into RESULT.
- `final-gate` (Human decision), after RESULT is complete.

The matrix MUST contain these explicit review rows (not only narrative
prerequisites):

| requirement / SC | responsible workflow stage | owner | expected evidence artifact |
|---|---|---|---|
| Specification review (FR-012) | `preflight` (verifies HUMAN GATE #1 approval and approved blobs) | Human + shell verification | `reviews/HUMAN_GATE_1.md` with reviewed revision and blob ids |
| Plan review (FR-012) | `plan-approved` (HUMAN GATE #2A record check) | Human + shell verification | `reviews/HUMAN_GATE_2A.md` with reviewed plan revision |
| Tasks/analyze review (FR-012) | `gate-2b` + `gate-2b-record` | Human | renewed `reviews/HUMAN_GATE_2B_<run>.md` (or `HUMAN_GATE_2B.md`) with reviewed candidate SHA |

No checkbox in this section.

## 2. Externally resolved implementation inputs

The implementer cannot look up package versions or image digests. The workflow
step `implementation-inputs` resolves them read-only and passes them to the
implementer. Therefore:

- T001 writes the exact npm versions supplied by `implementation-inputs`.
- T015 uses the supplied Node 24 image reference with digest.
- T016 uses the supplied PostgreSQL 17 image reference with digest.

Tasks must say "use the value supplied by the workflow's implementation inputs"
instead of asking the implementer to choose, look up or verify these values.

T021 creates the initial `docs/poc/PLATFORM-POC-001-RESULT.md` structure with
pending placeholders and a final `## Workflow-recorded evidence` section that the
implementer leaves empty: the workflow writes marked evidence blocks there
(toolchain versions, verification incl. fresh checkout and push/PR CI, review
and resume report links, FR-013 metrics). Placeholders for those items state
that the workflow fills them.

Request-level evidence (data-model): the integration tests (T009/T010) must,
only when the environment variable `POC_TEST_EVIDENCE_PATH` is set, append one
JSON object per timed health request to that file (JSON Lines). Every object
has exactly these keys (no others):

- `phase`: non-empty string. The main 10/10/10 sequence uses exactly
  `healthy`, `database-loss`, `database-recovery` (10 records each).
- `index`: integer >= 0.
- `http_status`: integer 200 or 503 (healthy and database-recovery = 200,
  database-loss = 503).
- `body`: required parsed object with exactly `status`, `application`,
  `database`: 200 → `ok`/`ok`/`ok`; 503 → `degraded`/`ok`/`unavailable`.
- `elapsed_ms`: monotonic number, 0 <= value <= 5000.
- `scenario`: non-empty string.
- `app_container_id`, `app_started_at`: non-empty strings identical across all
  30 main-sequence records; for other fault scenarios the keys are present
  with a string or null.

Values are short plain strings/numbers only: never connection strings,
credentials, raw driver errors or stack traces. Without the variable, tests
write nothing. The workflow validates this with
`checks/validate-observations.sh` (strict schema, self-tested in preflight).

T015 `.dockerignore` must exclude `.env*` (allowing `!.env.example`), `.git`,
`node_modules`, `.next` and `.agent-out`; `safety-review` checks these lines.

## 3. I1 — package.json ownership

- T001 is the only task that creates or edits `package.json`, including all
  npm scripts: `dev`, `start`, `build`, `lint`, `typecheck`, `test`,
  `verify:startup`, and exact (pinned) dependency versions.
- T002 edits only TypeScript configuration; T003 edits only ESLint
  configuration. They may verify compatibility with T001's interfaces but must
  not edit `package.json`. Any needed script change is a correction to T001.
- The implementer must not create `package-lock.json`. After implementation
  the trusted workflow shell creates it with
  `npm install --package-lock-only --ignore-scripts` and then runs `npm ci`.

## 4. A1 — deterministic cleanup assertion for T010 (test-level only)

Do not change the external HTTP contract or the plan. T010's test parameters:

- repeated silent-listener requests: 5;
- after each HTTP 503, at most 1000 ms cleanup grace;
- the test fixture counts only its own ACTIVE accepted sockets;
- within those 1000 ms the active socket count returns to the pre-request
  baseline;
- after all 5 repetitions the active socket count equals the baseline;
- the HTTP response deadline stays <= 5000 ms; the cleanup grace is measured
  after the response and does not extend the HTTP deadline.

This is test determinism, not a new product requirement.
