---
status: pending
title: "Codify Goal Loop domain language and runtime ADR"
type: docs
complexity: medium
dependencies: []
---

# Task 01: Codify Goal Loop domain language and runtime ADR

## Overview
This task establishes the repository-level language and architecture decision for Goal Loop before code changes begin. It prevents Goal Loop from being confused with existing Harness Loop, Stage Goal Handoff, Stage Goal Context, and Goal Usage semantics.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- REQ-01 MUST add accepted Goal Loop glossary language to `CONTEXT.md`.
- REQ-02 MUST distinguish Goal Loop from Harness Loop, Stage Goal Handoff, Stage Goal Context, and Goal Usage.
- REQ-03 MUST add a repository ADR under `docs/adr/` for Runtime-owned Goal Loop semantics before implementation begins.
- REQ-04 MUST keep Stage Goal Handoff non-semantic and preserve existing delivery lifecycle boundaries in the docs.
- REQ-05 SHOULD update docs tests that assert domain language when applicable.
</requirements>

## Subtasks
- [ ] 1.1 Review `_prd.md`, `_techspec.md`, and ADR-001 through ADR-004.
- [ ] 1.2 Add Goal Loop glossary entries and avoid-list language to `CONTEXT.md`.
- [ ] 1.3 Add a repo-level ADR describing Runtime-owned Goal Loop semantics and lifecycle boundaries.
- [ ] 1.4 Update README references only where needed to introduce the new terms.
- [ ] 1.5 Add or update documentation assertions in backend tests.

## Implementation Details
Use the TechSpec "Integration Points" and "Technical Considerations" sections for the accepted language and boundaries. The repository ADR should summarize the stage-scoped configuration, persisted Runtime State model, evidence command gate, and no-delivery-authority constraint without duplicating every task detail.

### Relevant Files
- `CONTEXT.md` — domain source of truth for Personal Symphony terms.
- `docs/adr/0007-stage-goal-handoff.md` — accepted non-semantic Stage Goal Handoff boundary.
- `docs/adr/0021-agent-harness-runtime-settings.md` — accepted Harness Loop and Agent Harness runtime settings language.
- `docs/agent-context/codex-loop-context-management.md` — prior analysis warning against global Codex hook semantics.
- `README.md` — operator documentation that already explains Goal Usage and Stage Goal Handoff.
- `apps/backend/test/test_backend.ml` — contains documentation language assertions.

### Dependent Files
- `apps/backend/lib/config.ml` — later tasks add stage-scoped Goal Loop settings using these terms.
- `apps/backend/lib/runtime_state.ml` — later tasks expose Goal Loop Runtime State using these terms.
- `apps/backend/lib/orchestrator.ml` — later tasks preserve lifecycle boundaries described here.

### Related ADRs
- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Defines the narrow Runtime-owned Goal Loop scope.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Requires deterministic evidence for Goal met.
- [ADR-003: Stage-Scoped Goal Loop Runtime State](adrs/adr-003.md) — Chooses stage-scoped config and top-level Runtime State.
- [ADR-004: Evidence Command Completion Gate](adrs/adr-004.md) — Requires evidence before completion.

## Deliverables
- Updated `CONTEXT.md` glossary and avoid-list language.
- New repo-level ADR under `docs/adr/`.
- Minimal README update if operator-facing terminology is missing.
- Unit/documentation tests with 80%+ coverage for changed doc assertions **(REQUIRED)**.
- Integration tests are not required unless documentation assertions currently run through an integration-style backend test **(REQUIRED if applicable)**.

## Tests
- Unit tests:
  - [ ] `apps/backend/test/test_backend.ml` asserts Goal Loop terms exist in `CONTEXT.md`.
  - [ ] `apps/backend/test/test_backend.ml` asserts Stage Goal Handoff remains described as launch-time behavior.
  - [ ] `apps/backend/test/test_backend.ml` asserts Goal Usage is not described as completion evidence.
- Integration tests:
  - [ ] Existing docs/test command for repository documentation passes after the ADR and glossary update.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Goal Loop terminology is accepted in `CONTEXT.md`.
- A repo-level ADR exists before runtime semantics are implemented.
- Existing Harness Loop and Stage Goal Handoff meanings are preserved.
