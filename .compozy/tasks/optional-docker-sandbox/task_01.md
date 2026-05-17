---
status: completed
title: Add Sandbox Runtime Settings And Readiness Gaps
type: backend
complexity: medium
dependencies: []

---

# Task 01: Add Sandbox Runtime Settings And Readiness Gaps

## Overview
Add the V1 `sandbox` settings block to the repository-owned **Runtime Settings** and validate it only when `sandbox.enabled` is `true`. This task establishes the static contract and strict **Readiness Gap** behavior that blocks orchestration before any sandbox-enabled repository can dispatch agent work.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- Sandbox configuration MUST be modeled as a top-level `sandbox` block in the **Runtime Settings**.
- `sandbox.enabled` MUST be the activation toggle and sandbox validation MUST only run when it is `true`.
- The parser MUST validate the V1 Docker-only fields defined by the TechSpec and emit descriptive sandbox-related **Readiness Gaps** through existing readiness pathways.
- Existing repositories with no `sandbox` block or `sandbox.enabled = false` MUST preserve current behavior without new readiness failures.
</requirements>

## Subtasks
- [x] 1.1 Add typed backend config support for the V1 sandbox settings shape.
- [x] 1.2 Parse sandbox settings from `.symphony/settings.json` using existing top-level parser patterns.
- [x] 1.3 Add sandbox-specific readiness validation and remediation messages gated by `sandbox.enabled`.
- [x] 1.4 Ensure runtime readiness surfaces sandbox gaps consistently in terminal and web readiness states.
- [x] 1.5 Add backend tests covering disabled, valid, and invalid sandbox settings cases.

## Implementation Details
Reference the TechSpec sections "System Architecture", "Implementation Design", and "Testing Approach". This task should stop at config and readiness semantics and must not introduce Docker launch behavior yet.

### Relevant Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/config.ml` — owns typed Runtime Settings parsing and readiness gap generation.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_readiness.ml` — aggregates config-level gaps into runtime readiness state.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/runtime_policy.ml` — blocks orchestration when readiness gaps exist.
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/test/test_backend.ml` — contains config and readiness test coverage clusters to extend.

### Dependent Files
- `/Users/matheusbbarni/projects/symphony-orchestrator/apps/backend/lib/orchestrator.ml` — later launch work depends on the config shape and readiness semantics added here.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_02.md` — Docker runtime helper depends on the parsed sandbox config.
- `/Users/matheusbbarni/projects/symphony-orchestrator/.compozy/tasks/optional-docker-sandbox/task_06.md` — bootstrap/docs updates depend on the finalized config contract.

### Related ADRs
- [ADR-001: Scope V1 Sandbox as an Optional Docker Execution Boundary](../adrs/adr-001.md) — Defines Docker-only V1 and explicit runtime contract fields.
- [ADR-002: Use Repository-Level Opt-In With Strict Sandbox Readiness](../adrs/adr-002.md) — Requires blocking behavior for sandbox-enabled repositories.
- [ADR-003: Model Sandbox as a Repository-Owned Runtime Settings Block With Startup Readiness Gating](../adrs/adr-003.md) — Defines top-level `sandbox` and readiness gating with `sandbox.enabled`.

## Deliverables
- Parsed backend `sandbox` settings model integrated into runtime config loading.
- Sandbox-specific readiness gap validation with clear remediation text.
- Backend tests covering parser and readiness scenarios.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for sandbox readiness behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Parsing a config with no `sandbox` block preserves current defaults and emits no sandbox gaps.
  - [ ] Parsing a config with `sandbox.enabled = false` ignores otherwise incomplete sandbox fields.
  - [ ] Parsing a config with `sandbox.enabled = true` and missing required Docker fields emits named readiness gaps.
  - [ ] Parsing a config with unsupported `sandbox.type` rejects non-Docker values with descriptive errors or gaps.
- Integration tests:
  - [ ] Runtime readiness state includes sandbox-related gaps when `sandbox.enabled = true` and prerequisites are invalid.
  - [ ] Runtime policy serves readiness state instead of running orchestration for sandbox-enabled invalid configs.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Sandbox settings are parsed from the **Runtime Settings** without affecting disabled repositories.
- Sandbox-enabled invalid repositories are blocked through existing readiness mechanisms before dispatch.
