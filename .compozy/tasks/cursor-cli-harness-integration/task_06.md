---
status: pending
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
implementation-process material.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST update `CONTEXT.md` glossary language and invariants for Cursor as a supported `Agent Harness`.
2. MUST update `README.md` Runtime Contract examples and setup guidance so they match implemented Cursor behavior.
3. MUST update the project-level Agent Harness ADR in `docs/adr/` to include Cursor as a supported provider and reflect the final loop/readiness semantics.
4. MUST keep docs secret-free and reference only environment variable names, never secret values.
5. MUST keep the reusable Harness onboarding checklist in maintainer-facing artifacts and backend test coverage, not as operator-facing product documentation.
</requirements>

## Subtasks
- [ ] 6.1 Update `CONTEXT.md` with Cursor Harness terminology, loop semantics, and supported behavior.
- [ ] 6.2 Update `README.md` examples and setup text to match the implemented Cursor Runtime Contract.
- [ ] 6.3 Amend `docs/adr/0021-agent-harness-runtime-settings.md` or add a follow-up project ADR for Cursor support.
- [ ] 6.4 Ensure operator docs do not absorb maintainer-only onboarding checklist content.
- [ ] 6.5 Run final repository verification commands after docs and examples align with implementation.

## Implementation Details
Make the documentation reflect the implemented product contract rather than the pre-implementation plan. See TechSpec
"High-Level Technical Constraints", "Impact Analysis", and "Key Decisions" for the required secret-free examples, the
approved Bootstrap change, and the decision to keep onboarding guidance out of operator-facing docs.

### Relevant Files
- `CONTEXT.md` — domain source of truth for product terms such as `Agent Harness`, `Harness Loop`, and `Logical Agent`.
- `README.md` — operator-facing setup and Runtime Contract example surface.
- `docs/adr/0021-agent-harness-runtime-settings.md` — existing project ADR that records supported Harness semantics.
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
- Updated operator-facing docs and glossary aligned with implemented Cursor support.
- Updated project ADR history reflecting Cursor as a supported Harness.
- Maintainer-facing onboarding guidance kept out of operator docs and enforced through implementation artifacts.
- Final repository verification commands run after docs alignment.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documented examples and final package verification **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] `CONTEXT.md` uses current Cursor Harness terminology and avoids legacy ambiguous wording.
  - [ ] `README.md` examples align with implemented Cursor settings and include no secret values.
  - [ ] Project ADR text matches the implemented supported Harness set and Cursor loop/readiness semantics.
  - [ ] Operator-facing docs do not introduce the maintainer-only onboarding checklist as end-user guidance.
- Integration tests:
  - [ ] `pnpm test` passes after docs and examples are aligned.
  - [ ] `pnpm frontend:test` passes if runtime-state display changes affect frontend live-state expectations.
  - [ ] `pnpm frontend:build` passes after any ReScript-facing example or state changes.
  - [ ] `pnpm backend:build` passes after backend and docs alignment.
  - [ ] `pnpm prepack` passes with the final Runtime Contract examples and package payload.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operator docs, glossary, and project ADRs all describe the same Cursor Harness contract.
- Maintainer-facing onboarding guidance remains out of end-user docs while still being enforced by implementation artifacts.
