---
status: completed
title: Add Structured Bootstrap Settings Builder
type: backend
complexity: medium
dependencies:
  - task_01

---

# Task 3: Add Structured Bootstrap Settings Builder

## Overview
Replace the static settings template concept with a structured Runtime Settings builder that can consume a Bootstrap detection result. The builder must preserve the existing Runtime Contract shape while routing default Logical Agents to the selected Harness when one exists.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST add `apps/backend/lib/bootstrap_settings.re` as a ReasonML settings-generation helper.
- R2 MUST generate structured `Yojson.Safe` Runtime Settings instead of assembling selected-Harness JSON through ad hoc string replacement.
- R3 MUST keep all supported Harness definitions: `codex`, `claude`, `cursor`, `cursor-force`, and `pi`.
- R4 MUST route `agents.planner`, `agents.engineer`, and `agents.reviewer` to the selected Harness when detection selects one.
- R5 MUST preserve the current static example Logical Agent routes when no supported usable Harness is selected, while allowing guidance to explain that no Harness was found.
- R6 MUST preserve Stage Agent routing by Logical Agent name and must not emit stage-level Harness selection.
- R7 MUST generate settings that parse through `Config.from_settings_file` and contain no secret values.
</requirements>

## Subtasks
- [x] 3.1 Create the structured settings builder module.
- [x] 3.2 Preserve existing tracker, project, polling, workspace, sandbox, Git, pull request, stage, agent, and server defaults.
- [x] 3.3 Generate all supported Harness definitions with the existing command and loop defaults.
- [x] 3.4 Route Logical Agents to the selected Harness or preserve no-Harness fallback routes.
- [x] 3.5 Add tests that parse generated settings through `Config.from_settings_file`.

## Implementation Details
Create `apps/backend/lib/bootstrap_settings.re` and model the current default Runtime Settings from `apps/backend/lib/runtime_home.ml` as structured JSON. Reference the TechSpec "Data Models" and "Integration Points" sections for the selected-Harness routing behavior. Tests should assert shape and parser compatibility rather than comparing a large raw JSON string byte-for-byte.

### Relevant Files
- `apps/backend/lib/bootstrap_settings.re` — New structured Runtime Settings generator.
- `apps/backend/lib/bootstrap_harness_detection.re` — Provides selected-Harness result data consumed by the builder.
- `apps/backend/lib/runtime_home.ml` — Current static `settings_json` source of defaults to preserve.
- `apps/backend/lib/config.ml` — Parser and readiness model used to validate generated settings.
- `apps/backend/test/test_backend.ml` — Existing `test_bootstrap_default_runtime_contract_shape` is the closest shape-test anchor.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Later task uses this builder when `.symphony/settings.json` is missing.
- `apps/backend/lib/runtime_startup.re` — Later task carries settings-generation guidance through startup.
- `README.md` — Later docs task updates examples if generated defaults change.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Requires generated settings to keep Harness and Logical Agent boundaries.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Assigns structured JSON generation to a Reason helper.

## Deliverables
- New `Bootstrap_settings` module that emits valid Runtime Settings JSON.
- Parser-compatible generated settings for selected-Harness and no-Harness cases.
- Shape tests for all supported Harness definitions and Logical Agent routing.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for generated settings parsing through `Config.from_settings_file` **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Generated settings include exactly the five supported Harness definitions.
  - [ ] Selected `claude`, `cursor`, `pi`, and `codex` cases route all default Logical Agents to that selected Harness.
  - [ ] No-Harness generation preserves current planner, engineer, and reviewer example routes.
  - [ ] `cursor-force` remains defined but is never assigned to a Logical Agent by automatic generation.
  - [ ] Stage Agents contain `agent` mappings and do not contain steady-state `harness` fields.
  - [ ] Generated text omits token-like marker strings and secret assignment examples.
- Integration tests:
  - [ ] Each generated settings variant parses through `Config.from_settings_file`.
  - [ ] Parsed settings expose five Harness definitions, three Logical Agents, and disabled sandbox defaults.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Settings generation preserves the accepted Runtime Contract shape.
- Selected-Harness routing affects only Logical Agents, not Stage Agent mappings.
- Generated settings remain valid even when no usable Harness is detected.
