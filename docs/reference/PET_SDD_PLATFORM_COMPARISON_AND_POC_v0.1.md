# PET SDD PLATFORM — Candidate Comparison & PoC Architecture

**Version:** 0.1.0-draft  
**Status:** proposal for first experimental build  
**Goal:** create a reusable development framework for pet projects using existing open-source tooling instead of a custom orchestrator.

---

# 1. Decision summary

Use **GitHub Spec Kit as the core SDD/process framework**.

Use native coding-agent CLIs as execution lanes:

- **Codex CLI** — architect / spec / plan / convergence/review lane.
- **Claude Code** — primary implementer lane.
- **Grok Build** — optional independent reviewer / critic lane.

Use:
- **Git** as the artifact/history bus.
- **GitHub Actions** as deterministic CI.
- **Human gates** before implementation and before merge.

Do **not** build a custom TaskPacket/ResultPacket orchestrator now.
Do **not** adopt Cline Teams or Ruflo as mandatory infrastructure in v0.
Evaluate them only after the native Spec Kit pipeline has been tested on 2–3 real changes.

---

# 2. Why this stack

The core requirement is not “run many agents”.

It is:
1. preserve intent;
2. develop via SDD;
3. let different strong models do different jobs;
4. keep deterministic tests outside the LLM;
5. minimize manual copy/paste;
6. retain human control;
7. reuse mature upstream tooling;
8. use existing ChatGPT / Claude / Grok subscriptions where possible.

Spec Kit already provides:
- constitution;
- specify;
- clarify;
- plan;
- checklist;
- tasks;
- analyze;
- implement;
- converge;
- resumable workflows;
- human gates;
- shell steps;
- per-step agent integrations;
- Codex, Claude Code and Grok Build integrations.

Therefore it should be the process layer.

---

# 3. Candidate comparison

## Candidate A — GitHub Spec Kit

### Strengths
- SDD is the core product.
- Markdown artifacts are first-class.
- Supports constitution → spec → plan → tasks → implement → converge.
- Human gates.
- Resumable workflow state.
- Workflow steps can select different integrations.
- First-class integrations for Codex CLI, Claude Code, Grok Build, Cline and others.
- Low lock-in: intent remains in Git/Markdown.
- No need to invent our own agent state machine.

### Weaknesses
- Not primarily a swarm framework.
- We still need to define role ownership.
- CI remains a separate deterministic layer.

### Fit
**Best foundation for our platform.**

---

## Candidate B — Cline Teams

### Strengths
- CLI and headless mode.
- Persistent multi-agent teams.
- Shared task board and mailbox.
- SDK and provider abstraction.
- ChatGPT subscription can be used through OpenAI Codex OAuth.
- Claude Code provider exists.
- Good candidate for one unified local operator/runtime later.

### Weaknesses
- SDD is not the primary abstraction.
- We would still want Spec Kit on top.
- xAI/Grok in Cline is API-key based, so it does not maximize an existing Grok consumer subscription.
- Claude Code provider currently has compatibility/permission friction reported in the project.
- Adds another runtime layer between agent and repository.

### Fit
**Good Phase-2 experiment, not the core framework.**

---

## Candidate C — Ruflo

### Strengths
- Native Claude Code orchestration.
- Codex adapter.
- Dual Claude/Codex mode.
- Persistent memory.
- Swarms.
- Worktree coordination.
- Large MCP/plugin ecosystem.
- Strong long-running autonomy.

### Weaknesses
- Much heavier than our current need.
- Adds daemon, memory, routing, hooks and swarm semantics.
- Higher operational complexity.
- Risks becoming a second product to maintain.
- SDD is not its main abstraction.

### Fit
**Potential Phase-3 option only if we genuinely need autonomous swarms.**

---

# 4. Weighted assessment

| Criterion | Weight | Spec Kit | Cline Teams | Ruflo |
|---|---:|---:|---:|---:|
| SDD / intent preservation | 25% | 5.0 | 3.0 | 2.5 |
| Multi-agent / multi-model fit | 20% | 5.0 | 4.5 | 4.5 |
| Existing subscription fit | 15% | 5.0 | 3.5 | 3.5 |
| Human gates / auditability | 15% | 5.0 | 4.0 | 3.5 |
| Setup simplicity | 10% | 4.5 | 3.5 | 1.5 |
| Automation potential | 10% | 4.5 | 4.5 | 5.0 |
| Low lock-in | 5% | 5.0 | 3.5 | 2.5 |
| **Approx. total** | **100%** | **4.9/5** | **3.8/5** | **3.4/5** |

The scores are architectural judgment, not vendor benchmarks.

---

# 5. Grok's role

Use native **Grok Build** in the first PoC.

Recommended role:
- optional independent critic;
- architecture review;
- diff review;
- adversarial review;
- security/readability critique.

Grok should not be a mandatory gate on every tiny change.

---

# 6. Subscription-oriented execution

## Codex CLI
Authenticate with ChatGPT subscription.

Role:
- architect;
- specification;
- plan;
- tasks;
- convergence/review.

## Claude Code
Authenticate with Claude Pro/Max subscription.

Role:
- primary implementation;
- code edits;
- test execution;
- implementation fixes.

## Grok Build
Authenticate with Grok/xAI account.

Role:
- optional independent review.

This avoids building an LLM gateway and avoids API billing as the default path.

---

# 7. Proposed platform architecture

```text
USER
  |
  v
PRODUCT DISCUSSION
(ChatGPT UI can still be used here)
  |
  v
GIT REPOSITORY
  |
  +------------------------------+
  |                              |
  v                              v
SPEC KIT                      GITHUB ACTIONS
(process/state)                (deterministic CI)
  |
  +--> Codex CLI
  |    architect/spec/plan/tasks
  |
  +--> HUMAN GATE
  |
  +--> Claude Code
  |    implementation
  |
  +--> shell / CI
  |
  +--> Codex CLI
  |    converge against spec
  |
  +--> Grok Build [optional]
  |    independent read-only review
  |
  +--> HUMAN GATE
  |
  v
MERGE
```

---

# 8. Reuse vs custom code

## Reuse
- GitHub Spec Kit — SDD process, templates, workflows, gates, convergence.
- Codex CLI — OpenAI execution lane.
- Claude Code — implementation lane.
- Grok Build — optional review lane.
- GitHub Actions — CI.
- Git — history/diff/artifacts.

## Custom code in platform v0
Target: **almost none**.

Allowed:
- one small Spec Kit workflow YAML if needed;
- GitHub Actions workflow;
- project constitution;
- normal project tests.

Not allowed:
- custom orchestrator;
- custom task queue;
- custom agent database;
- custom RPC layer;
- custom LLM gateway;
- custom memory server;
- custom repair-loop engine.

---

# 9. Proposed SDD workflow

1. **Constitution** — once per project.
2. **Specify** — Codex CLI.
3. **Human gate** — approve requirements.
4. **Clarify** — Codex when needed.
5. **Plan** — Codex CLI.
6. **Tasks / Analyze** — Codex CLI.
7. **Implement** — Claude Code.
8. **Deterministic verification** — shell/GitHub Actions.
9. **Converge** — Codex CLI via `speckit.converge`.
10. **Optional Grok review** — read-only independent critique.
11. **Human promotion gate** — final diff/CI/review.
12. **Merge**.

Initial repair policy:
- maximum one repair cycle without new human confirmation.

---

# 10. Abstract repository roles

Use abstract names:
- architect;
- implementer;
- reviewer;
- critic.

Initial mapping:

| Role | Tool |
|---|---|
| architect | Codex CLI |
| implementer | Claude Code |
| reviewer | Codex CLI / Spec Kit converge |
| critic | Grok Build |
| deterministic verifier | GitHub Actions |
| promotion | Human |

---

# 11. First platform PoC

Before full Tool Hunter Iteration 0, run one small **real** change through the complete process.

## PoC feature
“Create the repository foundation with a health endpoint and PostgreSQL connectivity check.”

### In scope
- Next.js/TypeScript bootstrap;
- app container;
- PostgreSQL container;
- `/api/health`;
- health check verifies application and DB connectivity;
- lint;
- typecheck;
- one integration test;
- README start instructions.

### Out of scope
- canonical 15 items;
- images;
- backup;
- catalog UI;
- Avito;
- auth.

This slice is only to validate the **development platform**.

---

# 12. Experiment A — recommended baseline

1. Install and authenticate Codex CLI, Claude Code, Grok Build.
2. Install Spec Kit.
3. Initialize repo with Spec Kit.
4. Codex creates/refines spec.
5. Human approves spec.
6. Codex creates plan/tasks.
7. Claude Code implements.
8. Tests/CI execute.
9. Codex runs convergence.
10. Grok performs read-only review.
11. Human decides.

Measure:
- manual copy/paste count;
- artifact quality;
- context loss;
- regressions;
- elapsed time;
- subscription usage;
- resume experience.

---

# 13. Experiment B — Cline Teams

Only after Experiment A.

Evaluate:
- does the team UI reduce friction?
- can it reliably use our subscription-backed agents?
- does it preserve SDD artifacts better than native integrations?
- do Claude Code provider permission issues matter?
- does the runtime improve or worsen observability?

Do not migrate the project to Cline during this experiment.

---

# 14. Experiment C — Ruflo

Run only if A/B reveal a real need for:
- background multi-agent workers;
- persistent cross-session shared memory;
- automatic worktree/swarm coordination;
- parallel execution at scale.

If there is no measured need, do not adopt Ruflo.

---

# 15. PoC acceptance criteria

The framework is accepted if:

1. One real Tool Hunter feature passes from spec to implementation.
2. No long prompt needs to be manually copied between Codex and Claude.
3. Spec/plan/tasks remain in Git.
4. Claude implementation is reviewable against exactly the same artifacts.
5. CI is deterministic and agent-independent.
6. Grok can provide useful independent review without write access.
7. Human can stop/reject before implementation and before merge.
8. Failed work can resume without reconstructing context from chat history.
9. No custom orchestration program was required.
10. The process is understandable enough to reuse for a second pet project.

---

# 16. Decision rules after PoC

## Keep only Spec Kit + native CLIs if
- process is comfortable;
- friction is low;
- artifacts provide enough context;
- gates/workflows are sufficient.

**This is the preferred outcome.**

## Add Cline if
- one dashboard/team runtime materially reduces friction;
- subscription-backed integrations are stable;
- it does not add auth/tooling problems.

## Add Ruflo if
- we need real concurrent swarms;
- we need persistent shared agent memory;
- we need automatic worktree/worker coordination;
- measured pain justifies the complexity.

---

# 17. Initial Mac toolchain

Install:

1. Git
2. GitHub CLI
3. Docker Desktop
4. `uv`
5. GitHub Spec Kit / `specify`
6. Codex CLI
7. Claude Code
8. Grok Build

Authenticate each native CLI with its native account.

Then initialize one Spec Kit repository.

Preferred default integration:
- Codex.

Install additional integrations:
- Claude.
- Grok.

Verify with:
- `specify integration list`.

Do not add Cline or Ruflo until the baseline PoC is complete.

---

# 18. Final recommendation

## Selected foundation
**GitHub Spec Kit + native Codex CLI + native Claude Code + native Grok Build + GitHub Actions**

## Deferred candidate
**Cline Teams**
Evaluate after baseline.

## Deferred advanced candidate
**Ruflo**
Adopt only after a measured orchestration need appears.

---

# 19. Next step

Create:

`PLATFORM-POC-001.md`

Its only goal is to initialize the SDD platform and run:

**Codex → human spec gate → Claude Code → tests → Codex convergence → optional Grok review → human merge gate**

on the real Tool Hunter health-endpoint/database foundation slice.

Only after this PoC succeeds should `TOOL_HUNTER SPEC-ITER0-FINAL` begin.
