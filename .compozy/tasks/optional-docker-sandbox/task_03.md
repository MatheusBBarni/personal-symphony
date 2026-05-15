---
status: pending
title: Wire Sandbox Launch Into Orchestrator
type: backend
complexity: high
dependencies:
  - task_01
  - task_02
---

# Task 03: Wire Sandbox Launch Into Orchestrator

## Overview
Integrate sandbox-aware execution at the existing orchestrator launch seam so sandbox-enabled repositories run the selected **Agent Harness** inside Docker without changing orchestration ownership. This task is the core execution switch and must preserve existing **Agent Worktree**, prompt archive, stdout/stderr, retry, and Task Branch behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- The orchestrator MUST keep using the current launch seam and MUST not introduce a new orchestration subsystem.
- Sandbox-enabled repositories MUST execute the selected **Agent Harness** through Docker while preserving prompt input and `stdout.log` / `stderr.log` output under the **Agent Worktree**.
- Disabled repositories MUST continue using existing host execution behavior unchanged.
- Launch integration MUST preserve retry behavior, session tracking, process-group semantics, and protected path invariants.
</requirements>

## Subtasks
- [ ] 3.1 Connect orchestrator launch planning to the Docker sandbox runtime helper when sandboxing is enabled.
- [ ] 3.2 Preserve Agent Worktree-based prompt and log file semantics under sandboxed execution.
- [ ] 3.3 Preserve host execution behavior for repositories without sandboxing enabled.
- [ ] 3.4 Ensure launch failures and retries continue to flow through current orchestrator behavior.
- [ ] 3.5 Add backend tests covering sandboxed and non-sandboxed launch paths.

## Implementation Details
Reference the TechSpec sections "Data Flow", "Impact Analysis", and "Integration Tests". Do not split quoting, Docker wrapping, and process spawning into separate tasks; the launch seam must remain coherent end-to-end.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/orchestrator.ml` — owns launch composition, prompt files, logs, sessions, retries, and child lifecycle.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/workspace.ml` — preserves Agent Worktree assumptions used by launch.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml` — provides selected harness config and enabled sandbox settings.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — contains launch and orchestrator behavior tests to extend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_state.ml` — later runtime visibility depends on launch outcomes and sandbox metadata.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_04.md` — runtime-state work depends on the sandbox launch integration being real.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_06.md` — docs/bootstrap must reflect final launch behavior.

### Related ADRs
- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](../adrs/adr-001.md) — Sandbox changes execution only, not orchestration ownership.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — No fallback to host execution for enabled repositories.
- [ADR-004: Attach Sandboxing at the Launch Boundary With Reusable Repository-Scoped Containers](../adrs/adr-004.md) — Requires launch-boundary integration and repository-scoped reuse.

## Deliverables
- Sandbox-aware orchestrator launch integration using the existing launch seam.
- Preserved Agent Worktree prompt/log/session semantics under Docker execution.
- Backend tests covering host and sandbox launch behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for orchestrator launch behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Sandbox-disabled repositories still build the existing host launch command.
  - [ ] Sandbox-enabled repositories select the Docker-backed launch plan instead of host execution.
  - [ ] Prompt path and stdout/stderr paths remain under the **Agent Worktree** for sandboxed runs.
- Integration tests:
  - [ ] Sandbox-enabled launch still records selected **Agent Harness** identity and starts from the expected worktree.
  - [ ] Sandbox launch failure enters existing retry or attention behavior without corrupting Task Branch state.
  - [ ] Existing non-sandbox orchestrator launch tests continue to pass unchanged.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Sandbox-enabled repositories execute through Docker at the launch boundary without changing orchestration ownership.
- Existing host launch behavior and retry semantics remain intact for repositories without sandboxing enabled.
