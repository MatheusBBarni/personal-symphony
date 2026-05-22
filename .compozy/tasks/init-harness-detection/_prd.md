# Init Harness Detection PRD

## Overview

Init Harness Detection improves the first `symphony init` experience for an individual developer creating a new Workspace Repository. When `.symphony/settings.json` does not already exist, Bootstrap should use local Agent Harness detection to seed normal Runtime Settings and explain the generated Harness choice.

The MVP optimizes for transparent guidance. The user should understand what Harness Symphony selected, why it selected it, and what still depends on runtime readiness before dispatch can run. Bootstrap must preserve existing Runtime Contract files and must not imply that local detection is permanent runtime truth.

## Goals

- Reduce first-run confusion by making the generated Harness choice visible and explainable.
- Preserve Idempotent Bootstrap behavior for 100% of existing Runtime Contract files.
- Help an individual developer know the next step after init, whether Symphony found a supported Harness or not.
- Keep Runtime Settings aligned with the existing `harnesses` and `agents` model.
- Prevent secret exposure by ensuring Bootstrap output and generated Runtime Settings reference only non-secret guidance.

## User Stories

- As an individual developer creating a Workspace Repository, I want `symphony init` to tell me which Agent Harness it selected so that I know what will run first.
- As an individual developer with one supported local Harness, I want generated settings to reflect that available Harness so that I do not have to edit Harness routes before trying Symphony.
- As an individual developer with no supported usable Harness, I want clear install or authentication guidance so that I know what to fix next.
- As an existing Symphony operator, I want repeated Bootstrap to preserve my Runtime Contract so that my local choices are not overwritten.
- As a maintainer reviewing generated settings, I want Stage Agents, Logical Agents, and Agent Harnesses to remain separate so that the Runtime Contract stays understandable.

## Core Features

| Feature | Priority | Requirement |
| --- | --- | --- |
| Transparent selected-Harness summary | Critical | Bootstrap output must name the selected Harness, explain that it came from local detection, and state that runtime readiness remains the dispatch authority. |
| Missing-settings-only generation | Critical | Bootstrap may generate adaptive Runtime Settings only when `.symphony/settings.json` is absent. Existing Runtime Contract files must remain untouched. |
| Local Harness-aware defaults | High | When one or more supported usable Harnesses are detected, generated Logical Agent defaults should point to the selected Harness while preserving normal Runtime Settings structure. |
| No-Harness next steps | High | When no supported usable Harness is found, Bootstrap must still create the Runtime Contract and show clear install or authentication guidance. |
| Secret-safe messaging | Critical | Generated settings and Bootstrap output must never contain token values, credential contents, webhook URLs, or local `.env` contents. |
| Boundary-preserving Runtime Contract | Critical | Stage Agents must continue routing by Logical Agent name, and Logical Agents must continue selecting Agent Harnesses through `agents.<name>.harness`. |

## User Experience

1. The user runs `symphony init` from the root of a Workspace Repository.
2. If `.symphony/settings.json` is missing, Symphony creates the Runtime Home and generates Runtime Settings from the transparent guidance approach.
3. The command prints a concise Bootstrap report that distinguishes files created from files already present.
4. The command prints a Harness guidance line:
   - selected Harness when one is usable,
   - no supported usable Harness found when none are usable,
   - or existing settings preserved when settings already exist.
5. The output tells the user the next action:
   - run Symphony normally if runtime readiness should confirm the generated settings,
   - authenticate or install a supported Harness if no usable Harness was found,
   - or edit existing Runtime Settings manually when a Runtime Contract already exists.
6. If the user runs Bootstrap again, existing Runtime Contract files are preserved and the output should not suggest that Symphony rewrote Harness settings.

## High-Level Technical Constraints

- Bootstrap must preserve the existing Workspace Repository and Runtime Home model.
- Runtime Settings must continue to use `harnesses` for Agent Harness definitions and `agents` for Logical Agent selections.
- Stage Agent mappings must not select Harnesses directly.
- Runtime readiness remains the authority for whether dispatch can proceed.
- Generated Runtime Settings and output must be secret-free.
- The feature must not require an interactive setup wizard before writing initial settings.
- The feature must not overwrite `.symphony/settings.json`, `.symphony/prompt.md`, `.symphony/agents/*`, `.symphony/.env`, or other user-edited Runtime Contract and Local Environment files.

## Non-Goals (Out of Scope)

- Dynamic per-task or per-stage Harness routing at dispatch time.
- A full interactive setup wizard.
- Team-level Harness policy or shared organization defaults.
- Automatic repair or rewrite of existing `.symphony/settings.json`.
- Secret management, token capture, or credential storage.
- A full Harness setup doctor for stale or broken existing settings.
- Changing Task Branch, Stage Commit, Stage Push, auto-merge, or tracker behavior.

## Phased Rollout Plan

### MVP (Phase 1)

- Generate missing Runtime Settings with transparent local Harness guidance.
- Preserve existing Runtime Contract files without modification.
- Print selected-Harness or no-Harness guidance.
- Keep runtime readiness as the final authority before dispatch.

Success criteria:
- New settings are generated only when missing.
- Existing settings are byte-preserved on repeated Bootstrap.
- Bootstrap output is clear for selected-Harness, no-Harness, and existing-settings cases.

### Phase 2

- Improve guidance copy for stale auth and unsupported local tools.
- Add documentation examples for common Codex, Claude, Cursor, and PI first-run paths.
- Consider a non-mutating diagnostic command for existing Runtime Contracts.

Success criteria:
- Users can distinguish install, auth, and settings-preserved states without reading source docs.
- Common first-run paths are documented without exposing secrets.

### Phase 3

- Explore team-level Harness preference policy or a dedicated setup doctor if first-run support evidence justifies it.

Success criteria:
- Later product work remains separate from Bootstrap and does not weaken Idempotent Bootstrap behavior.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Existing settings preservation | 100% | Repeated Bootstrap leaves existing `.symphony/settings.json` unchanged. |
| Guidance coverage | 100% | Selected-Harness, no-Harness, and existing-settings cases all produce explicit user guidance. |
| Secret safety | 100% | Generated settings and output contain no secret value markers or local `.env` contents. |
| First-run clarity | >= 90% | Review scenarios show users can identify the selected Harness and next action from output alone. |
| Manual Harness edits | -70% | Scenario review shows fewer immediate Harness-route edits are required after init on machines with one usable supported Harness. |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Users believe detection means dispatch is guaranteed ready | Use explicit wording that runtime readiness still validates dispatch. |
| Existing operators worry Bootstrap will change their settings | Make preserved-existing-settings output clear and keep no-overwrite behavior mandatory. |
| No-Harness cases feel like failure even though files were created | Separate file creation success from Harness readiness guidance in the output. |
| Detection selects a Harness that later becomes stale | Present detection as an initial local observation and rely on runtime readiness for future validation. |
| Messaging becomes too verbose | Keep Bootstrap guidance concise and link or point to documentation for details. |

## Architecture Decision Records

- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) - Bootstrap may use local detection to seed missing Runtime Settings while preserving runtime readiness authority.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) - The MVP prioritizes clear selected-Harness and next-step guidance over aggressive auto-selection.

## Open Questions

- What exact order should the selected Harness summary use when multiple supported Harnesses are usable?
- Should generated settings retain all supported unused Harness definitions for editability, or include only detected Harnesses?
- What exact user-facing wording should distinguish "selected by Bootstrap" from "ready for dispatch"?
