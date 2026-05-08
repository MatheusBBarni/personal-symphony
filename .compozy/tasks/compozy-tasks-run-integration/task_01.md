---
status: pending
title: "Add Compozy tracker Runtime Settings"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Add Compozy tracker Runtime Settings

## Overview
Add Runtime Settings support for selecting the Compozy-backed tracker while keeping GitHub as the default. This task creates the configuration surface used by later tasks but does not implement file parsing or orchestration.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST preserve omitted `tracker.kind` as `github`.
- R2 MUST accept `tracker.kind = "compozy_tasks"` from `.symphony/settings.json`.
- R3 MUST parse Compozy tracker settings for `root` and `maxTaskStepRetries`.
- R4 MUST apply default Compozy settings from the TechSpec when fields are omitted.
- R5 MUST skip GitHub-only owner, repo, project number, and token readiness gaps for Compozy tracker runs.
- R6 MUST continue rejecting unsupported tracker kinds with an actionable error.
- R7 MUST NOT change Bootstrap defaults in `apps/backend/lib/runtime_home.ml`.
</requirements>

## Subtasks
- [ ] 1.1 Extend the Runtime Settings tracker model with Compozy tracker settings.
- [ ] 1.2 Accept `github` and `compozy_tasks` as supported tracker kinds.
- [ ] 1.3 Preserve existing GitHub parsing and defaults when `tracker.kind` is omitted.
- [ ] 1.4 Gate GitHub-only readiness gaps behind GitHub tracker selection.
- [ ] 1.5 Add configuration tests for Compozy defaults, explicit values, and unsupported kinds.

## Implementation Details
Update the configuration model described in TechSpec "Runtime Settings". Keep this task focused on parsed settings and readiness gating; Compozy file validation belongs to later tasks.

### Relevant Files
- `apps/backend/lib/config.ml` — Defines `Config.tracker`, parses settings, and emits readiness gaps.
- `apps/backend/test/test_backend.ml` — Contains config parsing and readiness tests, including the current unsupported tracker-kind case.

### Dependent Files
- `apps/backend/bin/main.ml` — Later tasks will route startup based on the selected tracker kind.
- `apps/backend/lib/orchestrator.ml` — Later tasks will consume Compozy tracker settings.
- `apps/backend/lib/runtime_home.ml` — Must remain unchanged unless separately approved.

### Related ADRs
- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — Establishes Compozy tracking as opt-in.
- [ADR-003: Add a narrow Compozy tracker path](adrs/adr-003.md) — Selects the narrow Compozy path and GitHub default preservation.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Requires a Compozy-specific retry setting.

## Deliverables
- Runtime Settings parse `tracker.kind = "compozy_tasks"`.
- Compozy tracker settings are available to later backend code.
- GitHub default behavior is unchanged.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Settings readiness behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Omitted `tracker.kind` parses as `github`.
  - [ ] `tracker.kind = "compozy_tasks"` parses with default `root` and `maxTaskStepRetries`.
  - [ ] Explicit Compozy `root` and `maxTaskStepRetries` values parse correctly.
  - [ ] Unsupported tracker kind such as `linear` returns an actionable config error.
  - [ ] GitHub tracker with placeholder GitHub fields still emits existing readiness gaps.
- Integration tests:
  - [ ] Minimal Compozy tracker settings load without requiring GitHub owner, repo, project number, or token.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- GitHub remains the default Issue Tracker.
- Compozy tracker settings are parsed without changing Bootstrap defaults.
