---
status: pending
title: "Prove Runtime Consumers Observe Effective Config"
type: backend
complexity: medium
dependencies:
  - task_04
---

# Task 05: Prove Runtime Consumers Observe Effective Config

## Overview
This task adds focused coverage proving existing runtime consumers observe the effective config produced by invocation overrides. It verifies polling, Agent Worktree placement, global concurrency, and retry backoff through existing behavior without adding retry-stop semantics for `agent.maxTurns`.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- MUST prove effective polling interval is used by orchestration.
- MUST prove effective Agent Worktree root is used by orchestration or Manual Task Merge.
- MUST prove effective global concurrency is used by dispatch capacity.
- MUST prove effective retry backoff cap is used by retry scheduling.
- MUST document that `--agent.maxTurns` is effective as config only in this TechSpec and does not add retry-stop semantics.
</requirements>

## Subtasks
- [ ] 5.1 Add or extend polling interval coverage using effective config.
- [ ] 5.2 Add or extend Agent Worktree root coverage using effective config.
- [ ] 5.3 Add or extend global concurrency coverage using effective config.
- [ ] 5.4 Add or extend retry backoff cap coverage using effective config.
- [ ] 5.5 Add a regression assertion that `agent.max_turns` can be overridden in config without claiming retry-stop behavior.

## Implementation Details
Reference the TechSpec "Known Risks" section before working on `agent.maxTurns`; this task must not silently add retry-stop semantics. Prefer focused tests near existing orchestrator and manual merge coverage instead of broad end-to-end tests that are hard to diagnose.

### Relevant Files
- `apps/backend/lib/orchestrator.ml` — consumes polling interval, global concurrency, retry backoff, and Agent Worktree root.
- `apps/backend/lib/manual_merge.ml` — consumes workspace root during Manual Task Merge preflight.
- `apps/backend/test/test_backend.ml` — existing dispatch, retry/backoff, Agent Worktree, and Manual Task Merge tests live here.

### Dependent Files
- `apps/backend/lib/runtime_state.ml` — test assertions may inspect running or retrying rows.
- `apps/backend/lib/workspace.ml` — workspace path sanitization affects Agent Worktree assertions.
- `apps/backend/lib/config.ml` — effective config fields must come from task_04's runtime wiring.

### Related ADRs
- [ADR-002: Full Issue-66 Runtime Override Scope](adrs/adr-002.md) — Includes all five flags in the MVP.
- [ADR-003: Post-Load Runtime Override Application](adrs/adr-003.md) — States that `agent.maxTurns` is config-effective only in this TechSpec.

## Deliverables
- Focused runtime consumer tests for effective config values.
- Explicit max-turn config-only coverage aligned with the TechSpec.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for runtime consumers observing effective config **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Effective `agent.max_concurrent_agents = 1` limits dispatch to one running task when multiple issues are eligible.
  - [ ] Effective `agent.max_retry_backoff_ms = 5000` caps retry scheduling delay at 5000 ms.
  - [ ] Effective `agent.max_turns` field changes are visible in config-level assertions without adding retry-stop expectations.
- Integration tests:
  - [ ] Effective `workspace.root` places an Agent Worktree or Manual Task Merge workspace under the override path.
  - [ ] Effective `polling.interval_ms` is used by orchestrator loop timing or a testable scheduling seam.
  - [ ] Runtime consumer tests continue to pass when no overrides are supplied.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Existing runtime consumers observe effective config values.
- No task in this set adds unapproved retry-stop semantics for `agent.maxTurns`.
