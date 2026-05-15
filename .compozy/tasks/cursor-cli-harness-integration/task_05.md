---
status: pending
title: "Update Bootstrap Runtime Contract Defaults For Cursor"
type: backend
complexity: medium
dependencies:
  - task_01
  - task_02
  - task_03
  - task_04
---

# Task 05: Update Bootstrap Runtime Contract Defaults For Cursor

## Overview
This task updates the default Runtime Contract created by Bootstrap so new `Workspace Repositories` see Cursor as part
of the supported Harness story from the start. It must preserve idempotent Bootstrap behavior, remain secret-free, and
reflect the approved Cursor command posture without overwriting any user-edited runtime files.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
1. MUST update bootstrapped `.symphony/settings.json` so Cursor appears as part of the default supported Harness model.
2. MUST keep bootstrapped examples valid under the current parser and selected-Harness semantics.
3. MUST represent the approved non-`--force` and `--force` Cursor command postures explicitly in the bootstrapped examples.
4. MUST keep provider secrets out of bootstrapped Runtime Contract files.
5. MUST preserve Bootstrap idempotency and avoid overwriting existing user-edited runtime files, prompts, or agent files.
</requirements>

## Subtasks
- [ ] 5.1 Update the bootstrapped settings JSON to include Cursor support.
- [ ] 5.2 Reflect the approved Cursor command postures in valid example settings.
- [ ] 5.3 Keep existing `agents` and `stageAgents` Bootstrap behavior aligned with the Cursor-enabled parser.
- [ ] 5.4 Preserve idempotent skip behavior for existing runtime files.
- [ ] 5.5 Add Bootstrap and settings-load tests for the new default examples.

## Implementation Details
Constrain this task to the Bootstrap-owned Runtime Contract defaults and their verification. See TechSpec "Impact
Analysis", "Technical Dependencies", and "Key Decisions" for the explicit user-approved Bootstrap change and the need
to keep examples parseable, idempotent, and secret-free.

### Relevant Files
- `apps/backend/lib/runtime_home.ml` — owns the `settings_json` Bootstrap payload and idempotent runtime-file creation.
- `apps/backend/test/test_backend.ml` — contains Bootstrap and settings-load verification patterns that should be extended.
- `apps/backend/lib/config.ml` — parser behavior from earlier tasks must load the new Cursor examples successfully.

### Dependent Files
- `README.md` — operator-facing examples should align with the bootstrapped default Runtime Contract.
- `CONTEXT.md` — glossary and invariants should remain consistent with what Bootstrap now seeds.
- `docs/adr/0021-agent-harness-runtime-settings.md` — project architecture docs should reflect the new supported default example set.

### Related ADRs
- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Requires Bootstrap examples to preserve the provider-neutral model.
- [ADR-002: Stable First-Class Cursor Harness Product Posture](adrs/adr-002.md) — Commits the product to stable first-class Cursor support.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Requires bootstrapped examples to reflect the approved Cursor command posture.

## Deliverables
- Bootstrapped settings JSON updated with Cursor examples.
- Cursor example shapes that remain parseable and secret-free.
- Bootstrap idempotency preserved for existing runtime-owned files.
- Bootstrap and settings-load tests covering the new examples.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for bootstrapped settings loading and idempotent behavior **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Bootstrapped settings contain a valid Cursor Harness example.
  - [ ] Bootstrapped settings reflect both approved Cursor command postures without secret values.
  - [ ] Existing bootstrapped `agents` and `stageAgents` entries remain present and valid.
  - [ ] Existing `.symphony/settings.json` files are not overwritten.
  - [ ] Existing `.symphony/prompt.md` and `.symphony/agents/*.md` idempotency remains unchanged.
- Integration tests:
  - [ ] A freshly bootstrapped settings file loads through `Config.from_settings_file` with Cursor examples present.
  - [ ] Re-running Bootstrap on an existing Runtime Home leaves user-edited files untouched.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- New `Workspace Repositories` receive Cursor-aware default Runtime Contract examples.
- Existing runtime-owned files remain untouched on repeated Bootstrap runs.
