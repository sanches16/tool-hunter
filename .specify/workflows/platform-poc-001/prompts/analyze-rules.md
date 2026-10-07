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

Read-only: do not modify any file.
