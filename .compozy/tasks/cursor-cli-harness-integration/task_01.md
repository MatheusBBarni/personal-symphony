---
status: completed
title: "Add Cursor Harness Kind, Defaults, And Command Rendering"
type: backend
complexity: high
dependencies: []

---

# Task 01: Add Cursor Harness Kind, Defaults, And Command Rendering

## Overview
This task introduces Cursor as a native `Agent Harness` kind in Symphony's Runtime Contract and ensures selected
`Logical Agent` roles can resolve to it cleanly. It lays the foundation for every later Cursor task by defining the
supported contract shape, defaults, and render path without disturbing existing Codex, Claude, and PI behavior.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST allow `cursor` as a valid Harness kind in the Runtime Contract parser and readiness validation.
2. MUST define a Cursor default command and default loop behavior consistent with the approved TechSpec.
3. MUST preserve the existing `harnesses -> agents -> stageAgents` resolution path for Cursor-selected `Logical Agent` roles.
4. MUST render Cursor commands through the same provider-local command path used by other Harnesses, including model or reasoning placeholders when configured.
5. MUST preserve current `codex`, `claude`, and `pi` behavior, including legacy Codex compatibility and existing selected-Harness semantics.
</requirements>

## Subtasks
- [x] 1.1 Add `cursor` to the allowed Harness kind set and default kind/command resolution.
- [x] 1.2 Extend Harness parsing so named Cursor Harness entries load through existing Runtime Settings paths.
- [x] 1.3 Ensure logical-agent override merging works for Cursor-selected roles.
- [x] 1.4 Add or adjust Cursor command rendering coverage so selected commands render deterministically.
- [x] 1.5 Add regression tests proving existing supported Harness kinds still resolve and render unchanged.

## Implementation Details
Modify the shared Harness parser and renderer without introducing a parallel provider model. See TechSpec
"Implementation Design" and "Development Sequencing" for the approved boundaries and the requirement to keep Cursor as a
native provider-specific extension rather than a compatibility shim.

### Relevant Files
- `apps/backend/lib/config.ml` — owns `agent_harness`, allowed Harness kinds, default command selection, and logical-agent resolution.
- `apps/backend/lib/orchestrator.ml` — owns `render_harness_command` and the launch path that consumes selected Harness commands.
- `apps/backend/test/test_backend.ml` — contains existing Harness parsing, resolution, and command-rendering coverage to extend.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — later Bootstrap work depends on the parser and defaults defined here.
- `README.md` — later docs examples must align with the supported Cursor command shape chosen here.
- `CONTEXT.md` — later glossary updates depend on the final supported Cursor Harness semantics.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Establishes `kind: "cursor"` as a first-class Harness.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Chooses native Cursor support over a compatibility shim.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Constrains the default command and loop contract this task prepares.

## Deliverables
- Cursor support added to the shared Harness kind and default-command machinery.
- Selected logical-agent resolution for Cursor-defined Harnesses.
- Cursor command-rendering behavior aligned with the approved TechSpec.
- Regression coverage for existing Codex, Claude, and PI behavior.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Cursor Harness resolution and rendered launch behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Parsing `harnesses.cursor.kind: "cursor"` succeeds.
  - [x] Cursor default command and default loop values are populated when omitted.
  - [x] A `Logical Agent` referencing a Cursor Harness resolves through `Config.selected_agent_harness`.
  - [x] Cursor command rendering substitutes configured placeholders deterministically.
  - [x] Existing Codex, Claude, and PI command-rendering behavior remains unchanged.
- Integration tests:
  - [x] A settings file with a Cursor-selected stage loads and resolves the expected Harness end to end.
  - [x] A fake launch path receives the rendered Cursor command for a selected role without breaking existing Harness flows.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Cursor is accepted as a native Harness kind in Runtime Settings.
- Selected Cursor roles resolve through the same Harness-selection model as other providers.
