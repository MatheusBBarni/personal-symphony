---
status: completed
title: Wire Adaptive Settings Into Idempotent Bootstrap
type: backend
complexity: high
dependencies:
  - task_02
  - task_03

---

# Task 4: Wire Adaptive Settings Into Idempotent Bootstrap

## Overview
Wire detection and structured settings generation into Runtime Home Bootstrap while preserving the existing no-overwrite contract. Bootstrap should use adaptive settings only when `.symphony/settings.json` is absent and must byte-preserve existing Runtime Contract files on repeated runs.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST call Bootstrap Harness detection and structured settings generation only when `.symphony/settings.json` is missing.
- R2 MUST preserve all existing `Runtime_home.bootstrap` idempotency guarantees for `.symphony/settings.json`, `.symphony/prompt.md`, `.symphony/agents/*`, `.symphony/.env`, and ignored Runtime Home directories.
- R3 MUST keep Workspace Repository root validation unchanged.
- R4 MUST keep Runtime Settings parsing and runtime readiness authority in `Config`; Bootstrap detection must not bypass readiness gaps.
- R5 MUST expose enough Bootstrap metadata for Task 5 to render selected-Harness, no-Harness, and existing-settings guidance without re-probing.
- R6 MUST keep existing callers compiling, either by a compatible wrapper or by updating direct call sites in the same patch.
</requirements>

## Subtasks
- [ ] 4.1 Update `Runtime_home.bootstrap` to decide whether settings generation is needed before writing the settings file.
- [ ] 4.2 Use the default local probe and settings builder for missing settings.
- [ ] 4.3 Preserve the existing file report statuses and add guidance metadata for later rendering.
- [ ] 4.4 Add idempotency tests for new settings, existing settings, and no-Harness generation.
- [ ] 4.5 Confirm runtime readiness still reports selected-Harness gaps through existing `Config` logic.

## Implementation Details
Modify `apps/backend/lib/runtime_home.ml` surgically around the current `settings_json`, `ensure_file`, and `bootstrap` flow. The settings write should remain an `ensure_file`-style operation: absent files are created, existing files are skipped without reading or rewriting their contents. Reference the TechSpec "Integration Points" and "Impact Analysis" sections for the intended boundary between Bootstrap observation and runtime readiness.

### Relevant Files
- `apps/backend/lib/runtime_home.ml` — Owns Runtime Home paths, idempotent file creation, and Bootstrap return data.
- `apps/backend/lib/bootstrap_harness_detection.re` — Provides local detection and guidance-ready metadata.
- `apps/backend/lib/bootstrap_settings.re` — Produces the settings JSON written only when settings are absent.
- `apps/backend/lib/runtime_startup.re` — Direct Bootstrap caller that may need return type updates.
- `apps/backend/bin/main.ml` — Explicit `symphony init` caller that may need return type updates.
- `apps/backend/test/test_backend.ml` — Existing Bootstrap idempotency and default contract tests should be extended.

### Dependent Files
- `README.md` — Docs must describe missing-settings-only adaptive Bootstrap after rendering exists.
- `docs/adr/0021-agent-harness-runtime-settings.md` — Project ADR must reflect generated default semantics after implementation settles.
- `CONTEXT.md` — Update only if durable domain language changes.

### Related ADRs
- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) — Requires missing-settings-only generation and no overwrites.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) — Requires existing settings preservation to be explicit.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) — Requires `Runtime_home.bootstrap` to remain the file-creation owner.

## Deliverables
- Bootstrap integration that generates adaptive settings only for missing `.symphony/settings.json`.
- Preserved existing Runtime Contract files across repeated Bootstrap runs.
- Bootstrap metadata for selected, no-Harness, and existing-settings states.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for Runtime Home Bootstrap settings shape and idempotency **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Missing settings with a selected fake Harness writes settings where Logical Agents route to that Harness.
  - [ ] Missing settings with no usable fake Harness writes valid fallback settings.
  - [ ] Existing `.symphony/settings.json` is byte-preserved and reports skipped status.
  - [ ] Existing prompt and agent prompt files remain byte-preserved.
  - [ ] Bootstrap metadata distinguishes settings-created from settings-preserved cases.
  - [ ] Generated or preserved settings text does not contain secret markers.
- Integration tests:
  - [ ] `Config.from_settings_file` parses settings produced by Runtime Home Bootstrap.
  - [ ] Existing readiness tests still report selected Claude, Cursor, and PI install/auth gaps through `Config.readiness_gaps`.
  - [ ] Root validation still rejects non-root Workspace Repository invocation before Bootstrap.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Bootstrap remains idempotent for every Runtime Contract and Local Environment file.
- Adaptive settings are generated only when settings are absent.
- Runtime readiness remains the dispatch authority after Bootstrap completes.
