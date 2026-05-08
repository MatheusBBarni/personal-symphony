---
status: completed
title: "Add tracker kind config and minibeads settings"
type: backend
complexity: medium
dependencies: []
---

# Task 01: Add tracker kind config and minibeads settings

## Overview
Add Runtime Settings support for selecting `tracker.kind = "minibeads"` while preserving GitHub as the default Issue Tracker. This task only parses and validates configuration shape; it does not execute `mb` or change Bootstrap defaults.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST preserve omitted `tracker.kind` as `github`.
- R2 MUST accept `tracker.kind = "minibeads"` from `.symphony/settings.json`.
- R3 MUST expose minibeads tracker settings needed by later tasks, including command and local tracker root.
- R4 MUST skip GitHub owner, repo, project number, and token readiness gaps when the selected Issue Tracker is minibeads.
- R5 MUST continue rejecting unsupported tracker kinds with an actionable error.
- R6 MUST NOT change Runtime Contract defaults in `runtime_home.ml`.
</requirements>

## Subtasks
- [x] 1.1 Add the selected tracker kind and minibeads settings to the Runtime Settings model.
- [x] 1.2 Preserve existing GitHub tracker fields and defaults.
- [x] 1.3 Gate GitHub-only readiness gaps behind GitHub tracker selection.
- [x] 1.4 Add config parsing coverage for GitHub defaults and minibeads settings.
- [x] 1.5 Replace the existing non-GitHub rejection test with unsupported-kind coverage.

## Implementation Details
Update the config model and readiness behavior described in TechSpec "Data Models" and "Development Sequencing" step 3. Keep this task focused on parsed settings and readiness gaps; CLI/store validation belongs to task_03.

### Relevant Files
- `apps/backend/lib/config.ml` — Defines `Config.tracker`, parses Runtime Settings, and emits readiness gaps.
- `apps/backend/test/test_backend.ml` — Contains existing config tests, including the current non-GitHub tracker rejection.
- `spec/spec-architecture-minibeads-local-issue-tracker.md` — Shows the target settings shape for `tracker.kind`, `tracker.root`, and `tracker.command`.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Current Bootstrap defaults remain GitHub; do not edit unless separately approved.
- `apps/backend/bin/main.ml` — Later tasks will consume selected tracker settings during startup.
- `apps/backend/lib/orchestrator.ml` — Later tasks will use the selected tracker kind for runtime behavior.

### Related ADRs
- [ADR-001: Scope minibeads as an opt-in local tracker adapter](adrs/adr-001.md) — Establishes minibeads as opt-in.
- [ADR-002: Prioritize a first-class local tracker experience for V1](adrs/adr-002.md) — Requires a clear settings property.
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Config selects the adapter used by the boundary.

## Deliverables
- Runtime Settings parse GitHub and minibeads tracker kinds.
- GitHub readiness requirements remain unchanged for GitHub tracker runs.
- minibeads tracker runs do not emit GitHub owner/repo/project/token readiness gaps.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Settings readiness behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Omitted `tracker.kind` parses as `github`.
  - [x] `tracker.kind = "minibeads"` parses with default or explicit command/root settings.
  - [x] Unsupported tracker kind such as `linear` returns an actionable config error.
  - [x] GitHub tracker with placeholder owner/repo/project/token still emits the existing readiness gaps.
  - [x] minibeads tracker without GitHub owner/repo/project/token emits no GitHub-only readiness gaps.
- Integration tests:
  - [x] Loading a minimal minibeads `.symphony/settings.json` succeeds without requiring a GitHub token.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- GitHub remains the default Issue Tracker when `tracker.kind` is omitted.
- minibeads can be selected in Runtime Settings without GitHub configuration.
