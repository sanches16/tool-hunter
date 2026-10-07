# PLATFORM-POC-001 — Native Multi-Agent SDD Baseline

**Version:** 1.0  
**Status:** READY FOR EXECUTION  
**Project:** Tool Hunter  
**Purpose:** validate the development platform before full Tool Hunter Iteration 0.

---

## 1. Decision

The first platform build uses existing tooling only:

- GitHub Spec Kit — SDD/process layer;
- Codex CLI — `architect` + `reviewer`;
- Claude Code — `implementer`;
- Grok Build — optional `critic`;
- Git — source/history bus;
- GitHub Actions — deterministic CI;
- Human — specification and merge gates.

No custom orchestrator is permitted in this PoC.

---

## 2. Why this PoC exists

The PoC does **not** test whether LLMs can write code.

It tests whether we can reliably run:

```text
product intent
→ specification
→ plan
→ tasks
→ implementation
→ deterministic verification
→ convergence
→ independent critique
→ human merge
```

with:

- minimal copy/paste;
- no loss of context;
- no custom task queue;
- no custom agent database;
- no custom repair-loop engine.

---

## 3. Real feature used for the experiment

Implement the first real Tool Hunter foundation slice:

> A Next.js + TypeScript application with PostgreSQL in Docker Compose and a `/api/health` endpoint that verifies both application health and actual database connectivity.

This is intentionally small but production-relevant.

---

## 4. In Scope

### Repository
- private Git repository;
- Spec Kit initialized;
- Codex, Claude and Grok integrations installed;
- project constitution committed.

### Application
- Next.js;
- TypeScript;
- minimal application shell;
- `/api/health`.

### Database
- PostgreSQL;
- Docker Compose;
- health endpoint performs an actual DB probe, not a hard-coded `"ok"`.

### Verification
- lint;
- typecheck;
- build;
- integration test for health endpoint;
- Docker Compose startup test;
- GitHub Actions CI.

### Process experiment
- Codex creates/updates specification;
- human approves;
- Codex creates plan/tasks;
- Claude implements;
- deterministic checks run;
- Codex runs Spec Kit convergence;
- Grok performs optional read-only critique;
- human approves/rejects merge.

---

## 5. Out of Scope

Do **not** implement:

- canonical 15 catalog items;
- product UI;
- product images;
- Drizzle schema for Tool Hunter domain;
- backup/restore;
- authentication;
- PWA;
- Avito;
- SearchRun;
- Telegram;
- VPS;
- Caddy;
- Cline;
- Ruflo;
- custom agent orchestration;
- automatic repair loops;
- automatic merge.

---

## 6. Role mapping

Repository roles are abstract.

| Role | PoC implementation |
|---|---|
| architect | Codex CLI |
| implementer | Claude Code |
| reviewer | Codex CLI + Spec Kit `converge` |
| critic | Grok Build |
| deterministic verifier | shell + GitHub Actions |
| promotion gate | Human |

Changing a model/vendor later must not require changing the project methodology.

---

## 7. Constitution principles for the PoC

Create the project constitution with at least these rules:

1. **Spec before code.**
   No implementation begins before the current spec and plan have been reviewed by a human.

2. **Patch, do not rebuild.**
   Agents modify the canonical repository; they do not reconstruct accepted behavior from memory.

3. **Deterministic evidence beats agent claims.**
   A task is not complete because an agent says it is complete.

4. **Tests are outside the LLM.**
   lint/typecheck/build/tests must be executable without an agent.

5. **No silent scope expansion.**
   Anything outside the active spec is out of scope unless required to satisfy an acceptance criterion and documented.

6. **Human promotion gate.**
   No automatic merge.

7. **No secrets in repository.**
   `.env` is ignored; only `.env.example` is committed.

8. **No custom orchestration in PLATFORM-POC-001.**

---

## 8. Feature requirements

### FR-01 Application
A Next.js TypeScript application starts locally.

### FR-02 PostgreSQL
A PostgreSQL service starts through Docker Compose.

### FR-03 Health endpoint
`GET /api/health` returns a successful response only when:
- the application is running;
- a DB probe succeeds.

Suggested response:

```json
{
  "status": "ok",
  "database": "ok"
}
```

The exact response shape may differ if documented in the spec.

### FR-04 DB failure
If PostgreSQL is unavailable, the endpoint must not falsely report full health.

### FR-05 Environment
Database configuration comes from environment variables.

Commit:
- `.env.example`

Do not commit:
- `.env`

### FR-06 Tests
At least one automated integration test proves DB-backed health behavior.

### FR-07 CI
GitHub Actions must run deterministic checks on push/PR.

---

## 9. Non-functional requirements

- Node.js 24 LTS baseline unless the generated plan documents a better compatible reason.
- No unnecessary dependencies.
- No ORM required for this PoC unless the plan proves it is needed.
- No production deployment.
- Repository must be understandable by a human without agent chat history.
- All SDD artifacts remain in Git.

---

## 10. Acceptance Criteria

### AC-01
A fresh local checkout can be started using documented commands.

### AC-02
`docker compose up -d` starts PostgreSQL and any containerized service required by the selected implementation.

### AC-03
`GET /api/health` succeeds while PostgreSQL is available.

### AC-04
The health endpoint detects PostgreSQL unavailability and does not return false full-health.

### AC-05
Lint passes.

### AC-06
Typecheck passes.

### AC-07
Build passes.

### AC-08
Integration tests pass.

### AC-09
GitHub Actions runs the same core deterministic checks.

### AC-10
The generated Spec Kit spec, plan and tasks are committed.

### AC-11
Claude implementation is traceable to those tasks.

### AC-12
Codex convergence evaluates the implementation against the committed artifacts.

### AC-13
Grok can review the implementation without modifying source files.

### AC-14
No custom orchestrator/task queue/agent DB is introduced.

### AC-15
No automatic merge occurs.

---

## 11. SDD execution sequence

### Phase A — Architect lane

Use Codex CLI.

1. Create/update constitution.
2. Run Spec Kit `specify`.
3. Human reviews generated spec.
4. Run `plan`.
5. Run `tasks`.
6. Run `analyze`.
7. Human reviews plan/tasks.
8. Commit the planning baseline.

Expected artifacts:
- constitution;
- feature `spec.md`;
- `plan.md`;
- `tasks.md`;
- any generated supporting artifacts.

### Phase B — Implementer lane

Switch active Spec Kit integration to Claude.

Use Claude Code.

Run Spec Kit `implement`.

Claude:
- implements only the active tasks;
- runs relevant tests;
- documents any deviation;
- stops after implementation.

### Phase C — Deterministic verification

Run outside the agent:

```bash
npm run lint
npm run typecheck
npm test
npm run build
docker compose up -d --build
curl -fsS http://localhost:3000/api/health
docker compose down
```

Exact scripts may differ, but equivalent deterministic commands must exist and be documented.

### Phase D — Reviewer lane

Switch Spec Kit integration back to Codex.

Run `speckit-converge`.

Expected:
- no unresolved spec/implementation gaps;
- or new traceable tasks are produced.

Allow at most one implementation repair cycle without a new human decision.

### Phase E — Independent critic

Use Grok Build as read-only critic.

The critic reviews:
- spec;
- plan;
- tasks;
- diff;
- deterministic test summary;
- convergence outcome.

The critic must not edit source files.

### Phase F — Human gate

Human decides:
- APPROVE;
- REQUEST CHANGES;
- ABORT.

Only APPROVE allows merge.

---

## 12. Metrics to record

Create `docs/poc/PLATFORM-POC-001-RESULT.md` and record:

### Setup
- Codex version;
- Claude Code version;
- Grok Build version;
- Spec Kit version;
- Docker version;
- Node version.

### Process
- number of manual copy/paste operations between agents;
- number of times context had to be re-explained;
- number of human gates;
- number of repair cycles;
- total elapsed time.

### Quality
- CI result;
- number of gaps found by Codex converge;
- number of useful findings from Grok not already found by Codex/CI;
- any scope creep by implementer;
- any broken SDD artifacts.

### Subjective
Score 1–5:
- setup difficulty;
- switching friction;
- artifact clarity;
- confidence in review;
- resume/recovery experience;
- willingness to reuse for another pet project.

---

## 13. Success criteria for the platform itself

The platform baseline is accepted if:

1. the real feature reaches green CI;
2. no full chat transcript is needed to move between Codex and Claude;
3. all intent artifacts are committed;
4. Claude can implement using repo context alone;
5. Codex can review/converge using repo context alone;
6. Grok can produce an independent critique without write access;
7. human can stop the process before code and before merge;
8. a paused run can be understood later from Git + Spec Kit artifacts;
9. no custom orchestration application was written;
10. the same approach is plausible for the next Tool Hunter iteration.

---

## 14. Stop condition

After:
- green deterministic checks;
- Codex convergence;
- optional Grok review;
- `PLATFORM-POC-001-RESULT.md`;
- final commit;

STOP.

Do not begin Tool Hunter `SPEC-ITER0-FINAL` until the human explicitly accepts the PoC.

---

## 15. Decision after PoC

### If native stack is comfortable
Keep:

```text
Spec Kit
+ Codex CLI
+ Claude Code
+ Grok Build optional
+ GitHub Actions
```

Do not add another framework.

### If agent switching is still painful
Run a separate Cline Teams experiment.

### If real autonomous parallelism is required
Only then evaluate Ruflo.

