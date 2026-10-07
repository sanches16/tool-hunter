# PLATFORM-POC-001 — Run history

Factual log of Spec Kit workflow runs (`platform-poc-001`) for
`docs/poc/PLATFORM-POC-001-RESULT.md`. Run state lives locally in
`.specify/workflows/runs/<run_id>/` (not committed); decisions and candidates are
in Git as listed.

| # | Run | Workflow | Outcome | Evidence |
|---:|---|---|---|---|
| 1 | `c94f1bef` | 1.2.0 | Plan generated; candidate `088e3a3`; HUMAN GATE 2A **APPROVE** recorded in `e563d82`. Then **FAILED** at `tasks-validate`: verifier false positives in the scope check ("restore DB", "restore the approved behavior", exclusion lists naming auto-merge/backup). Verifier defect, not an agent defect. Owner chose to fix the check and resume from the approved plan. | `reviews/HUMAN_GATE_2A.md`; fix `0579ec5` (workflow 1.2.1) |
| 2 | `45312b2e` | 1.2.1 | Plan stage skipped via the Gate 2A record. Tasks (31) and analyze generated. **FAILED** at `tasks-candidate-commit`: secret scan `sk-…{10,}` matched inside "task-to-implementation". Verifier defect. Nothing committed; generated files discarded. Owner chose to fix the detector and regenerate. | fix `d3892ff` (workflow 1.2.2) |
| 3 | `7eb19156` | 1.2.2 | Plan skipped; tasks (33) + analyze (0 critical/high, 2 medium) committed as candidate `614dde8`. HUMAN GATE 2B **REJECT** recorded in `88cc2ec`; run stopped. Reason: role-boundary mismatch — `speckit-implement` executes every unchecked task, but tasks.md contained shell/Codex/Grok/Human work (verification runs, CI observation, converge, critic, human decisions/ratings, commits). Also I1 (package.json ownership across T001–T003) and A1 (T010 cleanup thresholds unspecified). | `reviews/HUMAN_GATE_2B.md`; fix `4e3e74c` (workflow 1.2.3) |
| 4 | `f081ca83` | 1.2.3 | Plan skipped; tasks (21 implementer checkbox tasks + non-checkbox workflow-owned matrix) and analyze (6/6 PASS) committed as candidate `ea6b58f`. HUMAN GATE 2B **REJECT** recorded in `ccebd1b`; run stopped. Reason: **workflow verifier/evidence mismatch, not a defect of the generated tasks** — the matrix promised `verify:startup` in `local-checks`, ephemeral Docker lifecycle checks and evidence in RESULT that the workflow did not perform or record, and the file-only implementer would have had to look up package versions and image digests itself. | `reviews/HUMAN_GATE_2B_f081ca83.md`; fix workflow 1.2.4 |

Notes for the result:
- Runs 1 and 2 were recovery events caused by operator-written verifier checks;
  each needed one human decision and a new run. They are not implementation
  repair cycles.
- Run 3 was a substantive human gate rejection of generated tasks.
- Run 4 was a human gate rejection of the workflow's verifier/evidence path, not of the generated tasks.
- Spec, constitution, approved plan and HUMAN_GATE_1/2A were not changed by any
  of these corrections.
