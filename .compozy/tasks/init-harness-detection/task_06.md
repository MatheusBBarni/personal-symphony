---
status: pending
title: Document Adaptive Bootstrap Semantics
type: docs
complexity: medium
dependencies:
  - task_05
---

# Task 6: Document Adaptive Bootstrap Semantics

## Overview
Update user-facing and architecture documentation to describe adaptive missing-settings Bootstrap, selected-Harness guidance, and the runtime-readiness boundary. The docs should align with the implemented CLI output and avoid introducing new domain terms unless they are added to `CONTEXT.md`.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST update `README.md` setup and Harness guidance to explain adaptive settings generation only when `.symphony/settings.json` is missing.
- R2 MUST update `docs/adr/0021-agent-harness-runtime-settings.md` to record the amended Bootstrap semantics and readiness boundary.
- R3 MUST update `CONTEXT.md` only if the implementation introduces durable domain language not already covered by Bootstrap, Runtime Settings, Agent Harness, Logical Agent, or Idempotent Bootstrap.
- R4 MUST keep docs secret-free by referencing environment variable names only, never token values or assignment examples.
- R5 MUST document that all supported Harness definitions remain available while default Logical Agents route to the selected Harness when one is detected.
- R6 MUST document that existing Runtime Contract files are preserved and not reinterpreted by repeated Bootstrap.
- R7 MUST keep doc assertions in `apps/backend/test/test_backend.ml` aligned with the final documentation.
</requirements>

## Subtasks
- [ ] 6.1 Update README setup text for selected-Harness, no-Harness, and existing-settings outcomes.
- [ ] 6.2 Update the Agent Harness Runtime Settings ADR with the new Bootstrap amendment.
- [ ] 6.3 Review `CONTEXT.md` for whether any glossary or relationship update is necessary.
- [ ] 6.4 Extend docs tests for adaptive Bootstrap semantics and secret-free examples.
- [ ] 6.5 Run docs and backend validation commands required by the changed assertions.

## Implementation Details
Keep the documentation tied to the behavior implemented in Task 5. `README.md` should help a first-run individual developer understand what `symphony init` generated and what readiness still validates. The ADR should capture the architectural decision as an amendment to the existing Agent Harness Runtime Settings record rather than creating a competing runtime contract document.

### Relevant Files
- `README.md` — User-facing setup, Runtime Settings, and Harness guidance.
- `docs/adr/0021-agent-harness-runtime-settings.md` — Existing accepted ADR for Harness and Logical Agent Runtime Settings.
- `CONTEXT.md` — Domain glossary and relationships; update only for durable language changes.
- `apps/backend/test/test_backend.ml` — Docs assertion tests for README, CONTEXT, ADR content, and secret-free documentation.
- `.compozy/tasks/init-harness-detection/_prd.md` — Product wording and user experience requirements.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Implemented Bootstrap behavior the docs must describe.
- `apps/backend/bin/main.ml` — Final guidance wording the docs should not contradict.
- `docs/adr/0028-runtime-owned-goal-loop.md` — Existing docs tests combine it with secret-free checks; avoid accidental regressions.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Feature-level decision behind the docs.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) — Product-level guidance emphasis.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Architecture-level implementation boundary.

## Deliverables
- README update for adaptive missing-settings Bootstrap and Harness guidance.
- ADR amendment for Bootstrap-generated Runtime Settings semantics.
- CONTEXT update if and only if durable domain language changes.
- Updated docs assertions and secret-free documentation checks.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documentation assertions and docs validation **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] README assertion covers adaptive Bootstrap when settings are missing.
  - [ ] README assertion covers existing settings preservation on repeated Bootstrap.
  - [ ] ADR assertion covers selected-Harness guidance and runtime readiness authority.
  - [ ] CONTEXT assertion is updated only if a glossary or relationship entry changes.
  - [ ] Secret-free docs test still rejects token marker examples and secret assignments.
- Integration tests:
  - [ ] `pnpm test` passes after docs assertion updates.
  - [ ] `pnpm docs:test` passes if the repository exposes that command for doc assertions.
  - [ ] `compozy tasks validate --name init-harness-detection` passes for the completed task bundle.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Documentation matches the final CLI and Terminal Console guidance semantics.
- Existing Runtime Contract preservation is documented clearly.
- Docs describe Bootstrap detection as onboarding guidance, not dispatch readiness authority.
