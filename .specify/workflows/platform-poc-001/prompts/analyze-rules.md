# Analyze rules for PLATFORM-POC-001

Binding for `speckit.analyze` in this workflow, in addition to the standard
cross-artifact analysis. Read `prompts/tasks-rules.md` next to this file first.

Report explicitly, each as PASS or FINDING with file:line evidence:

1. Every BUILDABLE requirement (FR/SC that needs repository code, tests,
   configuration, CI workflow file, scripts or docs) is covered by at least one
   checkbox implementation task.
2. Process-only verification and human requirements (running checks, Docker
   verification, CI observation, convergence, critique, human decisions and
   ratings) may be covered by the `## Workflow-owned verification and human
   obligations` traceability section instead of checkbox tasks; check that each
   such requirement appears there with stage, owner and evidence artifact.
3. No unchecked implementation task requires shell, Codex, Grok or Human
   action (see the forbidden list in tasks-rules.md section 1).
4. No human decision, approval or rating is delegated to an agent.
5. I1: only T001 edits package.json; T002/T003 touch only their own config;
   no task asks the implementer to create package-lock.json.
6. A1: T010 states the 5-repetition / 1000 ms grace / own-active-sockets /
   baseline / <= 5000 ms HTTP deadline parameters without changing the HTTP
   contract.

7. Workflow-stage reality: every stage named in the `Workflow-owned
   verification and human obligations` matrix exists as a step id in
   `.specify/workflows/platform-poc-001/workflow.yml` (read it), and the
   responsibility attributed to it matches what that step's script does:
   - `checks/local-checks.sh` runs exactly npm ci, lint, typecheck, build, test
     and verify:startup (the five core checks plus install);
   - `checks/docker-health.sh` covers Compose startup, exact 200, DB stop → 503
     within 5 s, DB restart → 200 with unchanged app container/process, app stop
     → no response and cleanup;
   - `checks/ci.sh` observes the GitHub Actions run of the tested commit;
   - `checks/record-evidence.sh` (steps `record-results`, `*-record-link`,
     `metrics-record`) writes the evidence the matrix promises into
     `docs/poc/PLATFORM-POC-001-RESULT.md`.
   Report any matrix row whose stage does not exist or whose evidence no step
   produces.
8. T001, T015 and T016 use values supplied by `implementation-inputs` and do
   not ask the implementer to look up versions or digests.
9. Every workflow step that runs `.specify/scripts/bash/check-prerequisites.sh`
   invokes it explicitly through `bash` (the file is tracked as 100644).
10. The matrix has explicit rows for specification review (preflight /
    HUMAN_GATE_1), plan review (plan-approved / HUMAN_GATE_2A) and
    tasks/analyze review (gate-2b + gate-2b-record / HUMAN_GATE_2B_<run>).
11. A tool-version producer exists: `record-evidence.sh toolchain` (steps
    `record-results`, `critic-record-link`) records Spec Kit, Codex, Claude,
    Grok (installed version and participated / not performed), Node, npm,
    Docker and Compose in RESULT.
12. The `fresh-checkout` step exists and `checks/fresh-checkout.sh` clones the
    canonical repository at the pushed SHA, uses only documented configuration,
    runs the Compose lifecycle, proves zero source edits and cleans up.
13. The `resume-implementer` (Claude) and `resume-reviewer` (Codex) steps exist,
    run read-only on fresh clones and produce RESUME_IMPLEMENTER.md /
    RESUME_REVIEWER.md linked from RESULT.
14. Request-level evidence has a producer (tests writing to
    `POC_TEST_EVIDENCE_PATH`, required by tasks), a validator
    (`local-checks.sh` schema and secret checks) and retention
    (`record-evidence.sh results` copies it to `docs/poc/evidence/<sha>/`).
15. CI evidence covers BOTH `push` and `pull_request` runs (`checks/ci.sh`),
    and `verification-enforce` requires both to succeed.
16. Grok participation is decided by structured critic evidence
    (`checks/grok-critic.sh` keeps the exit code, writes `critic.json`, never
    creates GROK_CRITIC.md on failure and removes a stale one;
    `record-evidence.sh critic` maps success + report to participated,
    otherwise not performed) — never by report presence or error text.
17. The request JSONL schema is strict as stated in tasks-rules.md
    (`checks/validate-observations.sh`): exact keys, required body with exact
    200/503 contract, integer index/status, 0..5000 ms, non-empty
    phase/scenario, identity rules; exactly 10/10/10 main-sequence records with
    HTTP 200/503/200 and one unchanged app identity; the validator's negative
    self-test (`checks/selftest-observations.sh`) runs in preflight.
18. The `safety-review` step exists before `implement-commit` and
    `checks/safety-review.sh` actually performs every obligation the matrix
    assigns to it (approved artifacts, dependencies, changed-path scope,
    .dockerignore, env files, credentials, workflow files).
19. The matrix no longer attributes dependency, image-exclusion, env or scope
    review to `implement-commit`; `implement-commit` promises only the staged
    secret guard, commit, push and clean-tree/origin verification that
    `checks/commit-push.sh` performs.
20. RESULT receives all of these evidence paths (toolchain, local, safety review, request
    observations, Docker, fresh checkout, push CI, PR CI, converge/critic/
    resume reports, FR-013 metrics).

Read-only: do not modify any file.
