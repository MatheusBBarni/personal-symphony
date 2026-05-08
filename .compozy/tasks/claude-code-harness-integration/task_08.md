---
status: completed
title: "Update Runtime Contract Docs, Glossary, And Project ADRs"
type: docs
complexity: medium
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
  - task_05
  - task_06
  - task_07
---

# Task 08: Update Runtime Contract Docs, Glossary, And Project ADRs

## Overview
This task updates repository documentation so the Runtime Contract language matches the implemented `harnesses`, logical `agents`, and Harness loop model. It also records the accepted product architecture change in project ADRs, not only task-local ADRs.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST update `CONTEXT.md` glossary language for Runtime Settings, logical agents, Agent Harness, Claude Harness, and Harness loop behavior.
- MUST update README Runtime Contract examples that currently show Harnesses under `agents`.
- MUST document legacy migration readiness behavior for harness-shaped `agents.*` and stage-level `harness`.
- MUST add or update a project ADR under `docs/adr/` for the runtime semantics change.
- MUST keep docs secret-free and reference only environment variable names.
- MUST include validation that examples are consistent with Bootstrap defaults and parser behavior.
</requirements>

## Subtasks
- [x] 8.1 Update glossary terms and invariants in `CONTEXT.md`.
- [x] 8.2 Replace legacy README `agents.pi` Harness examples with `harnesses` plus logical `agents`.
- [x] 8.3 Document Harness loop behavior and Claude loop defaults.
- [x] 8.4 Document blocking readiness migration behavior.
- [x] 8.5 Add or update the project-level ADR under `docs/adr/`.
- [x] 8.6 Run final full validation commands after docs and examples are aligned.

## Implementation Details
Modify documentation after implementation tasks settle the exact names and readiness text. Reference the TechSpec "Architecture Decision Records" section and task-local ADRs, but write project docs in repository glossary language.

### Relevant Files
- `CONTEXT.md` — domain source of truth for Runtime Contract terms.
- `README.md` — user-facing Runtime Contract setup and examples.
- `docs/adr/0021-agent-harness-runtime-settings.md` — existing project ADR for Agent Harness Runtime Settings.
- `docs/adr/` — location for a new project ADR if updating ADR 0021 is not appropriate.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Bootstrap defaults from task_07 should match docs examples.
- `apps/backend/lib/config.ml` — readiness diagnostics from tasks 01 and 02 should match migration docs.
- `apps/frontend/src/Main.res` and `apps/backend/lib/runtime_state.ml` — Runtime State naming from tasks 05 and 06 should match docs when mentioned.

### Related ADRs
- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Defines the product language shift.
- [ADR-002: Clarity-First PRD Scope](adrs/adr-002.md) — Selects documentation clarity as the primary outcome.
- [ADR-003: Runtime Settings Resolution and Loop Semantics](adrs/adr-003.md) — Defines stage, agent, Harness, and loop semantics.
- [ADR-004: Provider-Neutral Runtime State and Claude Stream Events](adrs/adr-004.md) — Defines provider-neutral Runtime State naming.

## Deliverables
- Updated `CONTEXT.md` with current domain terms and invariants.
- Updated README Runtime Contract examples.
- Project ADR under `docs/adr/` documenting runtime semantic changes.
- Final verification run across backend, frontend, and packaging commands.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documented examples through existing verification **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Documentation examples use `harnesses` for execution backends.
  - [x] Documentation examples use logical `agents` for planner/engineer/reviewer execution selection.
  - [x] Documentation examples do not include secret values.
  - [x] Project ADR references the accepted migration and loop semantics.
- Integration tests:
  - [x] `pnpm test` passes after docs examples and backend fixtures are aligned.
  - [x] `pnpm frontend:test` passes after Runtime State docs and frontend changes are aligned.
  - [x] `pnpm frontend:build` passes after ReScript changes.
  - [x] `pnpm backend:build` passes after backend/docs changes.
  - [x] `pnpm prepack` passes for final package payload verification.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Runtime Contract docs no longer teach Harnesses under `agents`.
- Glossary and project ADRs match implemented Runtime Settings semantics.
