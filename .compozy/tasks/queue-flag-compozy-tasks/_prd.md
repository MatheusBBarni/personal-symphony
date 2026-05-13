# Queue Flag With Compozy Tasks

## Overview

Personal Symphony should let a **Workspace Repository** operator queue known **Compozy PRD Runs** by passing bare slugs to `--queue` when `.symphony/settings.json` selects the Compozy-backed **Issue Tracker**.

Today, the operator must translate a known run name such as `queue-flag-with-compozy-tasks` into the stable selector form `compozy:queue-flag-with-compozy-tasks`. The proposed product change shortens that step for ad hoc local terminal use while preserving the current **Ordered Queue** contract, selected-tracker validation rules, and canonical internal identifiers.

The value is simple: make a frequent operator command faster and more natural without broadening the product into a general selector redesign.

## Goals

- Reduce the command length and cognitive overhead for queuing known **Compozy PRD Runs** from the terminal.
- Preserve the current meaning of **Ordered Queue** and keep queue validation aligned with the selected **Issue Tracker**.
- Make the Compozy-backed queue experience feel native to `.compozy/tasks/<slug>/` naming rather than requiring manual selector translation.
- Keep existing GitHub, minibeads, and canonical Compozy queue behavior stable.
- Provide clear feedback when an operator tries to use bare Compozy slugs while another tracker mode is selected.

## User Stories

- As a solo operator using a Compozy-backed **Workspace Repository**, I want to type known run slugs directly into `--queue` so that I can start an ad hoc run with less friction.
- As a solo operator who already recognizes `.compozy/tasks/<slug>/` names, I want the queue command to match those names so that I do not need to mentally translate them into another format.
- As a solo operator working in the terminal, I want queue input errors to explain tracker mismatch clearly so that I can correct the command quickly.
- As a maintainer of existing Symphony workflows, I want this improvement to leave other tracker modes and existing canonical selectors unchanged so that current usage does not regress.

## Core Features

- **Compozy bare-slug queue entry**  
  When the selected **Issue Tracker** is the Compozy-backed tracker, `--queue` accepts a comma-separated list of bare **Compozy PRD Run** slugs.

- **Tracker-aware eligibility**  
  The shorter queue format is only available when the active tracker mode is Compozy-backed, keeping the user-facing rule aligned with the selected **Issue Tracker**.

- **Guided mismatch feedback**  
  If an operator uses bare Compozy slugs while another tracker mode is selected, Symphony explains the mismatch and points the operator to the correct selector style.

- **Fail-fast queue acceptance**  
  The queue is accepted only when every supplied slug is valid for the active Compozy-backed tracker context and each referenced run is eligible for dispatch.

- **Compatibility preservation**  
  Existing canonical Compozy selectors and non-Compozy queue flows remain supported with their current behavior.

- **Documentation refresh**  
  User-facing examples for `--queue` and Compozy-backed tracking explain the shorter input path and its boundaries.

## User Experience

The primary journey is an ad hoc local terminal flow.

1. The operator works in a **Workspace Repository** that already uses the Compozy-backed **Issue Tracker**.
2. They know the names of one or more **Compozy PRD Runs** from `.compozy/tasks/<slug>/`.
3. They run a short queue command using those slugs separated by commas.
4. Symphony evaluates the request in the context of the active tracker mode.
5. If the input is valid, the **Ordered Queue** starts with the same queue-order behavior operators already expect.
6. If the input is invalid, Symphony stops early and explains the issue in language that helps the operator recover quickly.

The UX priority is speed and clarity for a known command, not discoverability through a new interface. Documentation and CLI messaging should make the boundary obvious: bare slugs are a Compozy-backed queue shortcut, not a universal selector format.

Accessibility and usability considerations:

- Error feedback should be short, explicit, and readable in a terminal context.
- Queue input rules should be easy to understand from CLI help and README examples.
- Operators should not need to inspect internals to understand why a bare slug was rejected.

## High-Level Technical Constraints

- The feature must remain rooted in the **Workspace Repository** runtime model and selected **Issue Tracker** semantics.
- The product must preserve the existing **Ordered Queue** behavior around order, readiness validation, and queue resume expectations.
- The change must not weaken existing compatibility for GitHub or minibeads tracker modes.
- Queue validation must continue to protect operators from starting a run with invalid or ineligible queue entries.
- User-facing documentation must avoid secret values and preserve existing Runtime Contract boundaries.

## Non-Goals (Out of Scope)

- Simplifying selector input for GitHub or minibeads tracker modes.
- Redesigning selector behavior across all selector-based flows.
- Changing **Task Branch**, retry, dispatch, completion, or **Runtime State** semantics.
- Adding partial-success queue behavior for invalid mixed input.
- Introducing a new UI surface for building queues.
- Expanding MVP scope beyond `--queue` to other operator commands.

## Phased Rollout Plan

### MVP (Phase 1)

- Support bare Compozy slugs in `--queue` for the Compozy-backed **Issue Tracker**.
- Keep the MVP focused on ad hoc local terminal use.
- Provide guided mismatch feedback when the wrong tracker mode is active.
- Preserve current behavior for all existing non-MVP queue inputs.

Success criteria to proceed:

- Operators can queue known **Compozy PRD Runs** with shorter commands.
- Existing queue behavior remains stable for current users.
- Documentation clearly explains when the shortcut does and does not apply.

### Phase 2

- Evaluate whether the same ergonomics should apply to other selector-based Compozy flows.
- Refine error guidance based on real operator confusion patterns.
- Improve documentation examples for mixed Symphony environments with different tracker kinds.

Success criteria to proceed:

- Real usage shows that operators want the same shorthand beyond `--queue`.
- Support questions or dogfood feedback indicate recurring confusion worth smoothing.

### Phase 3

- Consider a broader product decision on whether selector ergonomics should become more uniform across Compozy-backed flows.
- Reassess whether the product should offer saved or previewable queue inputs for repeat use.

Long-term success criteria:

- Selector ergonomics feel consistent where consistency adds value, without weakening tracker-specific clarity.

## Success Metrics

- Queue command brevity for Compozy-backed ad hoc runs improves by at least 15% for multi-run commands.
- Operators can successfully queue known **Compozy PRD Runs** using bare slugs in the primary local terminal flow.
- Queue-entry attempts involving bare slugs fail with guided mismatch feedback when the wrong tracker mode is active.
- Existing non-Compozy queue flows show no user-facing regression.
- Documentation examples for Compozy-backed queue usage remain accurate and easy to follow.

## Risks and Mitigations

- **Risk: Users assume bare slugs should work everywhere.**  
  Mitigation: Make the Compozy-only boundary explicit in CLI help, README examples, and error messages.

- **Risk: The feature feels too small to justify product attention.**  
  Mitigation: Keep the PRD tightly scoped and tie success directly to a high-frequency operator workflow.

- **Risk: Operators remain unsure which queue syntax to use in multi-tracker contexts.**  
  Mitigation: Use guided mismatch feedback that explains the active tracker context and the expected input style.

- **Risk: Future requests expand scope prematurely into a larger selector redesign.**  
  Mitigation: Preserve the MVP narrative as a focused queue shortcut and defer broader selector consistency work to later phases.

## Architecture Decision Records

- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Scopes bare Compozy slug support to `compozy_tasks` queue input while preserving canonical internal identifiers.
- [ADR-002: Focused Compozy Queue Shortcut](adrs/adr-002.md) — Chooses a narrow `--queue` shortcut MVP over a broader selector simplification effort.

## Open Questions

- Should bare Compozy slugs remain `--queue`-only after MVP, or later extend to other selector-based flows?
- What documentation example set best prevents confusion for operators who switch between Compozy-backed and non-Compozy tracker modes?
