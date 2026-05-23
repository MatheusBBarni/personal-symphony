---
status: completed
title: Thread And Render Bootstrap Guidance
type: backend
complexity: medium
dependencies:
  - task_04

---

# Task 5: Thread And Render Bootstrap Guidance

## Overview
Expose the adaptive Bootstrap decision to users through explicit CLI and Terminal Console startup guidance. The output should explain selected Harness, no usable Harness, or preserved existing settings without implying that Bootstrap detection guarantees dispatch readiness.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST thread Bootstrap guidance metadata through `Runtime_startup.prepare_runtime` for implicit startup.
- R2 MUST render the same concise guidance for explicit `symphony init` and normal startup when Bootstrap creates or preserves settings.
- R3 MUST include Terminal Console initial log lines for guidance emitted during implicit startup.
- R4 MUST make existing-settings output clear that settings were preserved and not reinterpreted or rewritten.
- R5 MUST make selected-Harness output clear that the choice came from local Bootstrap detection and runtime readiness remains the dispatch authority.
- R6 MUST make no-Harness output clear that Runtime Contract files were still created and what install or auth action the user should take next.
- R7 MUST keep all output secret-free and avoid printing raw probe command output.
</requirements>

## Subtasks
- [x] 5.1 Extend `Runtime_startup.prepared_runtime` to carry Bootstrap guidance.
- [x] 5.2 Add renderer helpers for selected-Harness, no-Harness, and existing-settings cases.
- [x] 5.3 Render guidance in explicit `symphony init`.
- [x] 5.4 Render guidance during implicit startup and append it to Terminal Console initial logs.
- [x] 5.5 Add output tests for wording, no-secret behavior, and readiness-authority phrasing.

## Implementation Details
Modify `apps/backend/lib/runtime_startup.re` and `apps/backend/bin/main.ml` around the existing `prepared_runtime`, `bootstrap_report_log_lines`, `render_bootstrap_report`, and `init` flows. The existing startup code already carries Bootstrap report lines into `terminal_console_initial_logs`; append guidance lines in the same pipeline. Reference the TechSpec "Monitoring and Observability" section for required output cases.

### Relevant Files
- `apps/backend/lib/runtime_startup.re` — Carries Bootstrap guidance through implicit startup.
- `apps/backend/bin/main.ml` — Renders guidance for `symphony init`, normal startup, and Terminal Console initial logs.
- `apps/backend/lib/runtime_home.ml` — Supplies guidance metadata from Task 4.
- `apps/backend/test/test_backend.ml` — Startup and CLI output tests should cover the new guidance cases.
- `.compozy/tasks/init-harness-detection/_prd.md` — Defines the user-facing experience and output expectations.

### Dependent Files
- `README.md` — Docs task must match the final output semantics.
- `docs/adr/0021-agent-harness-runtime-settings.md` — Docs task must describe readiness authority consistently.
- `CONTEXT.md` — Update only if output introduces durable product terms.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Requires detection to remain provisional.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) — Requires transparent guidance as the MVP focus.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Requires rendering to stay outside detection and settings helpers.

## Deliverables
- Guidance rendering for explicit init, implicit startup, and Terminal Console initial logs.
- Output copy that names the selected Harness or no-Harness state and points back to runtime readiness.
- Tests for selected-Harness, no-Harness, existing-settings, and no-secret output cases.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for CLI/startup guidance surfaces **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Guidance renderer for selected Harness includes Harness name, local detection provenance, and runtime readiness authority.
  - [x] Guidance renderer for no usable Harness includes clear install or auth next steps.
  - [x] Guidance renderer for existing settings says settings were preserved and not regenerated.
  - [x] Guidance lines omit token-like markers and raw command output.
- Integration tests:
  - [x] Explicit `symphony init` path renders selected-Harness guidance when settings are created.
  - [x] Explicit `symphony init` path renders existing-settings guidance on the second run.
  - [x] Implicit startup path carries guidance in `Runtime_startup.prepare_runtime` results.
  - [x] Terminal Console initial logs include Bootstrap guidance before the startup-completed line.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Users can identify the generated Harness choice and next action from output alone.
- Output does not imply dispatch readiness until runtime readiness confirms it.
- Terminal Console and CLI startup surfaces present consistent Bootstrap guidance.
