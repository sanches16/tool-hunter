# Tool Hunter Constitution

## Core Principles

### I. SPEC BEFORE CODE

Implementation MUST NOT begin until the active specification and implementation plan have been
reviewed by a human. The review record MUST identify the reviewer, date, and reviewed artifact
revisions. Agents MUST confirm that the review covers the active revisions before implementing.
Changes that invalidate the reviewed scope or approach MUST receive renewed human review.

### II. PATCH THE CANONICAL REPOSITORY

Agents MUST modify the existing canonical Tool Hunter repository. Before making changes, agents
MUST inspect its current state and applicable accepted artifacts. Changes MUST be reviewable as
patches against that state. Agents MUST NOT reconstruct accepted behavior from memory or silently
replace previously accepted artifacts. A proposed replacement MUST identify the affected artifact
and behavior and receive explicit human approval before replacement.

### III. DETERMINISTIC EVIDENCE OVER AGENT CLAIMS

A task MUST NOT be marked complete solely because an AI agent says it is complete. Completion
MUST be demonstrated by deterministic commands, tests, CI, or other reproducible evidence mapped
to its acceptance criteria. The completion record MUST identify the checked revision, verification
commands or procedure, and observed results. Missing or failing required evidence MUST keep the
task incomplete.

### IV. TESTS MUST BE EXECUTABLE OUTSIDE THE LLM

All required verification, including lint, typecheck, build, tests, and migrations when applicable,
MUST be executable independently of any AI agent. The implementation plan MUST document commands,
prerequisites, and expected pass conditions so a human or deterministic CI can repeat them.
Required checks MUST NOT depend on hidden agent memory, conversational judgment, or an LLM
deciding whether their results passed.

### V. NO SILENT SCOPE EXPANSION

Agents MUST stay inside the active specification. Out-of-scope work MUST receive explicit human
approval before execution unless it is strictly necessary to satisfy an existing acceptance
criterion. Any such exception MUST be documented before execution with the affected criterion,
why the work is necessary, and the exact added scope, and MUST be disclosed in review.
Convenience or anticipated future needs MUST NOT qualify as necessity.

### VI. HUMAN PROMOTION GATE

No AI agent may automatically merge or promote changes to the canonical branch. Final merge or
promotion MUST receive explicit human approval identifying the reviewed changes and verification
evidence. Task completion, passing CI, and prior permission to implement MUST NOT count as merge
or promotion approval. Any agent-executed promotion MUST stay within the specific recorded human
authorization.

### VII. SECRETS MUST NEVER ENTER GIT

Credentials, API keys, tokens, cookies, passwords, private authentication material, and local
environment secrets MUST NOT be committed. Only safe templates such as `.env.example`, containing
non-sensitive example values, may be version-controlled. Before committing, the proposed diff
and staged file set MUST be checked for secret material; a detected secret MUST block the commit.
Local secret files MUST remain outside version control.

### VIII. NO CUSTOM ORCHESTRATION IN PLATFORM-POC-001

PLATFORM-POC-001 MUST reuse GitHub Spec Kit, Git, native agent CLIs, and deterministic CI.
It MUST NOT introduce a custom orchestrator, task queue, agent database, memory server, LLM
gateway, Cline, or Ruflo. Every PoC specification, plan, and review MUST check proposed tooling
and dependencies against this restriction. A conflict MUST stop implementation until explicitly
resolved under Governance.

## Project Scope and Constraints

This constitution governs Tool Hunter, including PLATFORM-POC-001. It establishes governance
and does not authorize application implementation, a PoC run, Next.js, PostgreSQL, Docker Compose,
CI creation, or any product feature. Such work MUST be covered by an active specification and
implementation plan and pass the human review gate before implementation begins.

Agents MUST preserve accepted repository artifacts and expose changes through reviewable diffs.
Tooling choices and scope exceptions MUST comply with all eight principles; workflow shortcuts
MUST NOT bypass them.

## Development Workflow and Review Gates

Every feature specification, implementation plan, and review MUST include an explicit compliance
check against each of the eight principles and Governance. Each check MUST record evidence or a
concrete conflict. An applicable requirement MUST NOT be silently omitted; an inapplicable
requirement MUST include a reason.

Before implementation, the record MUST establish human review of the active specification and
plan, the canonical repository baseline, acceptance criteria, and independently executable
verification procedures. Strictly necessary scope exceptions MUST be documented before their
work begins.

Before reporting completion, the review MUST map acceptance criteria to reproducible evidence,
check the actual diff for scope compliance and prohibited tooling, and check proposed committed
content for secrets. Failing required checks MUST block completion. Passing checks MUST NOT
bypass explicit human approval for final merge or promotion.

## Governance

This constitution takes precedence over conflicting specifications, plans, tasks, and agent
recommendations. If a specification conflicts with the constitution, implementation MUST stop
until the conflict is explicitly resolved. Resolution MUST be recorded as a human-reviewed
specification correction or an explicitly human-approved constitutional amendment. Agents MUST
NOT invent implicit waivers or resolve conflicts by proceeding.

Constitution changes MUST receive explicit human review and approval before adoption. Each
proposed amendment MUST document changed rules, rationale, version impact, affected artifacts,
and any transition requirements. Adoption MUST record the human decision and update the version
and last amended date. The original ratification date MUST remain unchanged.

Constitution versions MUST use semantic versioning:

- MAJOR for backward-incompatible principle or governance removals or redefinitions.
- MINOR for new principles or materially expanded governance guidance.
- PATCH for clarifications, wording corrections, or other non-semantic refinements.

Every feature specification, implementation plan, and review MUST identify the active
constitution version in its compliance record. Amendments MUST trigger renewed compliance review
of affected active artifacts before dependent implementation resumes.

Human decisions override agent recommendations. Agents MUST record and follow explicit human
decisions. When a decision conflicts with this constitution, implementation MUST remain stopped
until the human explicitly resolves the conflict through the process above.

**Version**: 1.0.0 | **Ratified**: 2026-10-07 | **Last Amended**: 2026-10-07
