---
status: pending
title: Build Docker Sandbox Runtime Helper
type: backend
complexity: high
dependencies:
  - task_01
---

# Task 02: Build Docker Sandbox Runtime Helper

## Overview
Create the Docker-focused runtime helper that owns repository-scoped container identity, reuse decisions, health checks, and first-create bootstrap command handling. This task isolates Docker lifecycle logic from the orchestrator so the riskiest sandbox behavior is implemented behind one focused backend boundary.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- The helper MUST derive one named Docker container identity per **Workspace Repository** using the configured sandbox settings.
- The helper MUST determine `created`, `reused`, or `recreated` outcomes according to repository-scoped reuse rules and health/config changes.
- Bootstrap commands MUST run only on first create or explicit recreation, never on every launch.
- The helper MUST preserve the **Agent Worktree** as the authoritative repository state and MUST not redefine git ownership or Task Branch semantics.
</requirements>

## Subtasks
- [ ] 2.1 Introduce a focused backend helper module for Docker sandbox runtime planning.
- [ ] 2.2 Add repository-scoped container identity and config fingerprint logic.
- [ ] 2.3 Add reuse and recreate decision logic with health checks.
- [ ] 2.4 Add first-create and recreate bootstrap command execution flow.
- [ ] 2.5 Add backend tests for identity, reuse outcomes, and bootstrap gating.

## Implementation Details
Reference the TechSpec sections "Component Overview", "Core Interfaces", "Data Models", and "Known Risks". This task should not change orchestrator launch ownership yet; it should produce a reusable helper that task 03 can call.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml` — provides the sandbox settings shape and shell helper patterns.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/util.ml` — contains shell quoting helpers likely needed for Docker command planning.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/workspace.ml` — preserves workspace root and Agent Worktree safety assumptions.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — likely test home for backend helper behavior if no narrower test module is introduced.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/orchestrator.ml` — task 03 will consume the helper for launch integration.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_state.ml` — task 04 depends on helper outputs such as reuse outcome and provider.

### Related ADRs
- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](../adrs/adr-001.md) — Defines explicit lifecycle and constrained persistence.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Defines repository-scoped named-container reuse and bootstrap semantics.

## Deliverables
- New backend helper module for Docker sandbox planning and reuse.
- Repository-scoped container identity and reuse outcome behavior.
- First-create/recreate bootstrap command support.
- Backend tests covering helper behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for reuse and bootstrap behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] The same **Workspace Repository** and same effective sandbox config derive the same container identity.
  - [ ] Config fingerprint changes force a `recreated` outcome instead of `reused`.
  - [ ] Healthy existing repository container returns `reused`.
  - [ ] Bootstrap commands are skipped on healthy reuse and run on first create.
- Integration tests:
  - [ ] Unhealthy or missing repository-scoped container transitions to create or recreate with the expected reuse outcome.
  - [ ] Bootstrap command failures are surfaced clearly to the caller and do not report a false healthy reuse.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Docker lifecycle decisions are isolated in one helper boundary with repository-scoped identity.
- Bootstrap commands and reuse outcomes behave deterministically for create, reuse, and recreate cases.

