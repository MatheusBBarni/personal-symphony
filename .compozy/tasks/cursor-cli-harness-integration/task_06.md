---
status: completed
title: "Update Docs, Glossary, Project ADR, And Harness Onboarding Guidance"
type: docs
complexity: medium
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
  - task_05



---

# Task 06: Update Docs, Glossary, Project ADR, And Harness Onboarding Guidance

## Overview
This task aligns operator docs, glossary language, and the project-level architecture record with the implemented
Cursor Harness behavior. It also preserves the chosen boundary for the reusable Harness onboarding checklist by keeping
that guidance in maintainer-facing artifacts and backend test coverage rather than expanding operator docs with
implementation-process material. Treat the implementation and seeded Runtime Contract examples as the source of truth:
this task should finish documentation alignment, not reopen Cursor runtime behavior or Bootstrap defaults unless a real
contradiction forces Human attention.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST use `CONTEXT.md` domain language consistently, including `Agent Harness`, `Logical Agent`, `Harness Loop`,
   `Stage Goal Handoff`, and `Readiness Gap`, and remove provider-ambiguous wording where Cursor support is described.
2. MUST update `README.md` Runtime Contract examples and setup guidance so they match the implemented Cursor
   `harnesses -> agents -> stageAgents` model, selected-Harness readiness semantics, and loop-disabled-by-default
   behavior.
3. MUST update `docs/adr/0021-agent-harness-runtime-settings.md` so the project-level Agent Harness ADR records
   Cursor as a supported Harness kind and reflects the final loop/readiness semantics.
4. MUST keep docs secret-free and reference only environment variable names, never secret values.
5. MUST keep the reusable Harness onboarding checklist in maintainer-facing artifacts and backend test coverage, not as operator-facing product documentation.
6. MUST NOT expand this task into new runtime behavior or additional Bootstrap default changes. If docs accuracy would
   require further edits to `apps/backend/lib/runtime_home.ml` beyond the approved task_05 scope, stop and request
   Human attention because that file remains an `Ask First` boundary.
</requirements>

## Subtasks
- [x] 6.1 Reconcile `README.md` Harness examples with the implemented `harnesses -> agents -> stageAgents` Cursor
      wiring, including the approved Cursor command posture already reflected by task_05.
- [x] 6.2 Align `README.md` readiness and Stage Goal Handoff guidance with implemented Cursor selected-only checks,
      CLI-driven readiness, and plugin-gated loop semantics.
- [x] 6.3 Confirm and, where needed, finalize `CONTEXT.md` glossary and invariants so Cursor wording matches the
      implemented Runtime Contract and avoids provider-ambiguous language.
- [x] 6.4 Amend `docs/adr/0021-agent-harness-runtime-settings.md` so the project ADR and operator docs describe the
      same supported Harness set and Cursor loop semantics.
- [x] 6.5 Keep maintainer-only Harness onboarding guidance in task/ADR/test artifacts rather than expanding
      `README.md` or `CONTEXT.md` with implementation-process checklist content.
- [x] 6.6 Run the final verification commands required by the touched surfaces and report any commands intentionally
      skipped because the final diff stayed docs-only.

## Implementation Details
Make the documentation reflect the implemented product contract rather than the pre-implementation plan. See TechSpec
"High-Level Technical Constraints", "Impact Analysis", and "Key Decisions" for the required secret-free examples, the
approved Bootstrap change, and the decision to keep onboarding guidance out of operator-facing docs. The main planning
risk here is documentation drift: `README.md`, `CONTEXT.md`, `docs/adr/0021-agent-harness-runtime-settings.md`, and
the bootstrapped settings examples in `apps/backend/lib/runtime_home.ml` must describe the same Cursor contract. Treat
`apps/backend/lib/runtime_home.ml` as a reference point in this task, not an automatic edit target, because it remains
an `Ask First` boundary outside the already-approved task_05 scope.

### Relevant Files
- `CONTEXT.md` — domain source of truth for product terms such as `Agent Harness`, `Harness Loop`, and `Logical Agent`.
- `README.md` — operator-facing setup and Runtime Contract example surface.
- `docs/adr/0021-agent-harness-runtime-settings.md` — existing project ADR that records supported Harness semantics.
- `.compozy/tasks/cursor-cli-harness-integration/task_05.md` — the approved Bootstrap-example scope this task must
  align with rather than silently reopening.
- `.compozy/tasks/cursor-cli-harness-integration/adrs/adr-004.md` — records the final Cursor output, readiness, and
  loop contract the docs must teach accurately.
- `apps/backend/test/test_backend.ml` — backend verification and Bootstrap/parser tests should act as the maintainer-facing enforcement point for the onboarding checklist.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — bootstrapped examples from task_05 must match documented examples.
- `apps/backend/lib/config.ml` — provider semantics and readiness names from tasks 01-03 must match the final docs wording.
- `apps/backend/lib/orchestrator.ml` — loop and activity behavior from tasks 03-04 must match docs and ADR language.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Defines the Cursor product boundary and provider-neutral model.
- [ADR-002: Stable First-Class Cursor Harness Product Posture](adrs/adr-002.md) — Requires stable first-class documentation for Cursor.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Explains the native technical path docs must not contradict.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Defines output, readiness, and loop semantics the docs must teach accurately.

## Deliverables
- Updated `README.md` examples and setup guidance aligned with implemented Cursor support.
- Updated glossary and project ADR wording aligned with the same Cursor Harness contract.
- Maintainer-facing onboarding guidance kept out of operator docs and enforced through implementation artifacts.
- Final verification commands run for the touched surfaces, with any intentionally skipped frontend commands called out
  explicitly.
- No new runtime-behavior or Bootstrap-scope change introduced through docs cleanup.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documented examples and final package verification **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Existing backend tests still cover the bootstrapped Cursor example shape, selected-Harness readiness, and
        Cursor loop-gating semantics referenced by the docs.
  - [x] `README.md` examples use `kind: "cursor"` under `harnesses` and route selection through
        `agents.<name>.harness`, not legacy `agents.*.kind` or `stageAgents.stages[].harness` shapes.
  - [x] `README.md`, `CONTEXT.md`, and `docs/adr/0021-agent-harness-runtime-settings.md` all describe Cursor loop as
        disabled by default and describe loop-enabled Cursor as a stdin-validated, plugin-gated path.
  - [x] Operator-facing docs mention only environment variable names and do not introduce the maintainer-only
        onboarding checklist as end-user guidance.
- Integration tests:
  - [x] Backend tests pass after docs and examples are aligned via `opam exec -- dune runtest --root .`; direct
        `pnpm test` was blocked by pnpm's package-manager fetch before the test script executed.
  - [x] Backend build passes via `opam exec -- dune build --root . @all`; direct `pnpm backend:build` was blocked by
        the same pnpm fetch.
  - [ ] `pnpm prepack` passes with the final Runtime Contract examples and package payload. Not run in this stage
        because pnpm fetch failed before scripts executed and running the package-binary copy directly would mutate
        protected package payload files outside this scoped change.
  - [x] `pnpm frontend:test` and `pnpm frontend:build` were not required because the final diff does not touch
        frontend/runtime-state display files; direct pnpm commands were also blocked by the pnpm fetch issue.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- `README.md`, `CONTEXT.md`, `docs/adr/0021-agent-harness-runtime-settings.md`, and the task_05 Bootstrap examples
  all describe the same Cursor Harness contract.
- Maintainer-facing onboarding guidance remains out of end-user docs while still being enforced by implementation artifacts.
- No additional `Ask First` runtime-default decision is taken silently inside this docs task.
