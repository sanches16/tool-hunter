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
- `implement-commit` (shell): diff/secret-checked commit + push of the tested tree.
- `ci` (shell): observe the GitHub Actions run of that commit.
- `record-results` + `results-commit` (shell): write tested SHA, tool versions,
  commands, results, timings and criterion mapping (local, Docker, CI) into
  `docs/poc/PLATFORM-POC-001-RESULT.md`; separate records-only commit.
- `converge` (Codex) and `critic` (Grok, optional, read-only): revision-linked
  reports in `reviews/`, linked from RESULT by the workflow.
- `metrics-gate` + `metrics-record` (Human values, shell writes): FR-013 counts,
  six 1–5 ratings and platform decision into RESULT.
- `final-gate` (Human decision), after RESULT is complete.

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
implementer leaves empty: the workflow writes marked evidence blocks there.

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
