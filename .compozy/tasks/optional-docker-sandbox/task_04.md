---
status: pending
title: Extend Runtime State With Sandbox Launch Metadata
type: backend
complexity: medium
dependencies:
  - task_03
---

# Task 04: Extend Runtime State With Sandbox Launch Metadata

## Overview
Extend backend runtime snapshots with moderate sandbox visibility so operators can tell whether running work is sandboxed, which provider is active, and whether the runtime created, reused, or recreated the container. This task keeps the backend snapshot contract ahead of any frontend rendering work.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- Running-state payloads MUST include moderate sandbox metadata for enabled/provider/reuse outcome.
- Existing readiness gap and runtime snapshot semantics MUST remain full-snapshot based and backward compatible for non-sandboxed runs.
- The backend MUST surface sandbox metadata through both HTTP state and live snapshot paths.
- No detailed lifecycle history or reset diagnostics should be added in V1 beyond the approved moderate visibility scope.
</requirements>

## Subtasks
- [ ] 4.1 Add sandbox metadata fields to backend runtime-state running rows.
- [ ] 4.2 Populate sandbox metadata during sandboxed launch tracking.
- [ ] 4.3 Extend JSON snapshot serialization for HTTP and live state consumers.
- [ ] 4.4 Preserve empty or omitted sandbox metadata for non-sandboxed runs.
- [ ] 4.5 Add backend tests for runtime-state and server snapshot coverage.

## Implementation Details
Reference the TechSpec sections "Runtime State Additions", "API Endpoints", and "Monitoring and Observability". This task should stop at backend snapshot shape and not implement dashboard rendering.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_state.ml` — owns running-state record fields and JSON serialization.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/server.ml` — exposes `/api/v1/state` and `/api/v1/state/live`.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/orchestrator.ml` — source of running-row metadata to propagate into runtime state.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — includes runtime-state and server snapshot test coverage to extend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/frontend/lib/ocaml/RuntimeStateSnapshot.res` — frontend snapshot mapping depends on the new backend fields.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_05.md` — dashboard work depends on stable backend snapshot fields.

### Related ADRs
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — Requires visible blocking/readiness semantics.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Defines moderate running-state visibility for enabled/provider/reuse outcome.

## Deliverables
- Backend runtime-state fields for sandbox visibility.
- HTTP and live snapshot propagation of sandbox metadata.
- Backend tests covering snapshot shape and non-sandbox backward compatibility.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for runtime snapshot surfaces **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Running-state JSON includes sandbox fields for sandboxed launches.
  - [ ] Running-state JSON omits or nulls sandbox fields for non-sandboxed launches.
  - [ ] Reuse outcome values serialize as expected for `created`, `reused`, and `recreated`.
- Integration tests:
  - [ ] `/api/v1/state` includes sandbox metadata for a sandboxed running issue.
  - [ ] `/api/v1/state/live` emits sandbox metadata in live snapshots.
  - [ ] Existing readiness snapshot tests still pass without requiring frontend changes.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Backend runtime snapshots carry moderate sandbox metadata without regressing non-sandbox behavior.
- HTTP and live runtime-state surfaces remain consistent for sandboxed and non-sandboxed runs.
