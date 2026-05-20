---
status: completed
title: "Add evidence command runner and diagnostics"
type: backend
complexity: high
dependencies:
  - task_03
  - task_04

---

# Task 06: Add evidence command runner and diagnostics

## Overview
This task adds the deterministic evidence command path required before Goal Loop completion can succeed. The runner follows Context Command conventions for structured input, temp-file path environment variables, bounded output, timeout, diagnostics, and secret-safe summaries.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST run a configured evidence command for Goal Loop-enabled stages.
- REQ-02 MUST pass structured JSON on stdin and expose the same JSON through a temp-file path environment variable.
- REQ-03 MUST capture bounded stdout as evidence summary and stderr as diagnostics.
- REQ-04 MUST record timeout, exit code, byte counts, truncation flags, and diagnostics path.
- REQ-05 MUST not persist secrets, local environment contents, or full hidden prompts in Runtime State.
</requirements>

## Subtasks
- [ ] 6.1 Define the evidence command input payload.
- [ ] 6.2 Add temp-file input and environment variable behavior matching Context Command conventions.
- [ ] 6.3 Capture bounded stdout evidence summaries and diagnostic metadata.
- [ ] 6.4 Add timeout, missing executable, non-zero exit, and oversized output handling.
- [ ] 6.5 Add unit and integration tests with temp evidence scripts.

## Implementation Details
Use the TechSpec "Implementation Design" and ADR-004. Prefer reusing existing Context Command helper patterns where practical, but keep evidence command semantics separate because evidence gates completion.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — contains Context Command temp-dir, diagnostics, bounded output, and command execution patterns.
- `apps/backend/lib/config.ml` — provides validated evidence command settings from task_03.
- `apps/backend/lib/runtime_state.ml` — task_05 exposes diagnostics path and evidence summaries.
- `apps/backend/test/test_backend.ml` — existing Context Command and temp script tests.

### Dependent Files
- `apps/backend/lib/orchestrator.ml` — task_08 calls the evidence runner before completion.
- `.symphony/state/goal-loops/*.json` persistence helpers from task_04 — evidence results update canonical loop state.
- `CONTEXT.md` and README — task_11 documents the command contract.

### Related ADRs
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Defines the evidence command gate.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Requires diagnostics and latest evidence to update canonical state.

## Deliverables
- Evidence command runner with structured input and diagnostics.
- Bounded evidence summary capture.
- Secret-safe diagnostic metadata.
- Unit tests with 80%+ coverage **(REQUIRED)**.
- Integration tests using temp scripts **(REQUIRED)**.

## Tests
- Unit tests:
  - [ ] Evidence command input JSON includes issue, goal, stage agent, harness identity, attempt, budget, and workspace context.
  - [ ] Successful command exit `0` returns a bounded evidence summary.
  - [ ] Non-zero exit returns an evidence failure with diagnostics.
  - [ ] Timeout returns an evidence failure with timeout metadata.
  - [ ] Oversized stdout is truncated and marked as truncated.
- Integration tests:
  - [ ] Temp evidence script receives stdin JSON and temp-file path env var.
  - [ ] Missing executable produces a controlled evidence failure.
  - [ ] Secret-like values are not exposed in Runtime State evidence summaries.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Evidence command results can reliably feed Goal Loop transitions.
- Diagnostics are bounded, private, and safe for operator surfaces.
