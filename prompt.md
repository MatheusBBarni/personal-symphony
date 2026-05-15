/goal {"kind":"Stage Goal Context","issue_identifier":"compozy:queue-flag-compozy-tasks","title":"Compozy PRD run: queue-flag-compozy-tasks","description":null,"comments":[],"url":null,"current_project_status":"in_review","labels":[],"priority":null,"blocker_references":[],"attempt":1,"stage_agent_name":"reviewer"}

---

You are the Reviewer agent for the Symphony Orchestrator Repository.

Review completed engineer work before it moves to Done.

Review focus:
- Correctness, regressions, missing tests, readiness gaps, race conditions, and edge cases.
- Compliance with CONTEXT.md terminology and AGENTS.md boundaries.
- Runtime Contract safety, Idempotent Bootstrap behavior, Protected Trunk Branch behavior, Task Branch cleanup, Stage Commit, Stage Push, and Batch Pull Request semantics when relevant.
- Secret handling: GITHUB_TOKEN and GH_TOKEN names are allowed, token values and local environment contents are not.
- Frontend source hygiene: .res edits only, no committed generated .res.js files.
- Protected-path scope: release/package paths must not change unless explicitly authorized by the issue.

Run focused checks when practical. If blocking findings remain, comment clearly and move the issue to Human attention. If no blocking findings remain, summarize residual risk and allow the issue to move to Done.

---

Stage agent: reviewer

# Compozy PRD Run Stage

Run: compozy:queue-flag-compozy-tasks
PRD directory: queue-flag-compozy-tasks
Task step status: completed
Completed task steps: 4/4

## Completed Compozy Task Steps

- task_01.md: Add tracker-aware Ordered Queue resolution primitives
- task_02.md: Wire readiness-first queue diagnostics for bare Compozy slugs
- task_03.md: Refactor Ordered Queue orchestration to use raw state and resolved identifiers
- task_04.md: Update queue shortcut docs and CLI help

## PRD (`_prd.md`)

# Queue Flag With Compozy Tasks

## Overview

Personal Symphony should let a **Workspace Repository** operator queue known **Compozy PRD Runs** by passing bare slugs to `--queue` when `.symphony/settings.json` selects the Compozy-backed **Issue Tracker**.

Today, the operator must translate a known run name such as `queue-flag-with-compozy-tasks` into the stable selector form `compozy:queue-flag-with-compozy-tasks`. The proposed product change shortens that step for ad hoc local terminal use while preserving the current **Ordered Queue** contract, selected-tracker validation rules, and canonical internal identifiers.

The value is simple: make a frequent operator command faster and more natural without broadening the product into a general selector redesign.

## Goals

- Reduce the command length and cognitive overhead for queuing known **Compozy PRD Runs** from the terminal.
- Preserve the current meaning of **Ordered Queue** and keep queue validation aligned with the selected **Issue Tracker**.
- Make the Compozy-backed queue experience feel native to `.compozy/tasks/<task_name>/` naming rather than requiring manual selector translation.
- Keep existing GitHub, minibeads, and canonical Compozy queue behavior stable.
- Provide clear feedback when an operator tries to use bare Compozy slugs while another tracker mode is selected.

## User Stories

- As a solo operator using a Compozy-backed **Workspace Repository**, I want to type known run slugs directly into `--queue` so that I can start an ad hoc run with less friction.
- As a solo operator who already recognizes `.compozy/tasks/<task_name>/` names, I want the queue command to match those names so that I do not need to mentally translate them into another format.
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
2. They know the names of one or more **Compozy PRD Runs** from `.compozy/tasks/<task_name>/`.
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

## TechSpec (`_techspec.md`)

# Queue Flag With Compozy Tasks TechSpec

## Executive Summary

Implement the PRD by keeping `Ordered_queue.parse` tracker-agnostic, then adding a shared post-settings queue-resolution step that interprets bare Compozy slugs only when `.symphony/settings.json` selects `tracker.kind = "compozy_tasks"`. The queue keeps the operator-facing identifier text for state and resume, while readiness, lookup, and dispatch operate on ephemeral canonical identifiers.

The primary trade-off is deliberate: preserving raw bare slugs in queue state makes the shortcut feel native and keeps readiness messages close to what the operator typed, but it means queue resume stays input-style-sensitive. Restarting with `example-feature` is not the same queue run as restarting with `compozy:example-feature`.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Ordered_queue` | Parse structurally valid queue tokens and resolve them against the selected tracker after config load. | Must stay tracker-agnostic at parse time. |
| `Issue_tracker` | Normalize tracker-specific identifiers and validate dispatchability. | Compozy adapter gains bare-slug normalization support; GitHub and minibeads behavior stays stable. |
| `Runtime_readiness` | Surface queue mismatch and invalid-entry feedback as **Readiness Gaps** before orchestration starts. | Owns startup reporting, not dispatch-time recovery. |
| `Orchestrator` | Use resolved canonical identifiers for queue ordering, matching, and dispatch while persisting raw queue identifiers in queue state. | Must preserve current **Ordered Queue** semantics and resume behavior. |
| `Runtime_state` | Keep the existing queue JSON shape while allowing Compozy bare-slug queue entries to appear as typed by the operator. | No new queue fields in MVP. |
| Docs / CLI help | Explain the Compozy-only shortcut and guided mismatch behavior. | Must not imply a global selector redesign. |

Data flow:

1. `parse_ordered_queue_arg` builds a queue from structurally valid raw tokens.
2. Runtime startup loads `.symphony/settings.json` and selects the active tracker.
3. A shared queue-resolution helper uses `tracker.normalize_identifier` to resolve each entry into a canonical identifier or a readiness error.
4. `Runtime_readiness` reports tracker mismatch, mixed-style Compozy input, duplicate resolved identifiers, and undispatchable runs as **Readiness Gaps**.
5. `Orchestrator` uses resolved canonical identifiers for lookup and ordering, while persisted queue state keeps raw queue identifiers.
6. Queue resume compares the raw queue sequence, not the resolved canonical sequence.

## Implementation Design

### Core Interfaces

Actual implementation is OCaml. The Go structs below are compact schema sketches for the key boundary.

```go
type QueueEntry struct {
    QueueIdentifier string
}

type ResolvedQueueEntry struct {
    QueueIdentifier     string
    CanonicalIdentifier string
}
```

```go
type QueueResolver interface {
    Resolve(queue []QueueEntry) ([]ResolvedQueueEntry, error)
}
```

### Data Models

#### Ordered Queue Entry

Keep the existing queue-state shape conceptually centered on one identifier field, but change its meaning for the Compozy shortcut path:

- For GitHub and minibeads inputs, the stored identifier remains the canonical queue identifier as today.
- For bare Compozy slug input, the stored identifier remains the original slug text.
- Downstream canonical issue identity is resolved separately and never inferred from persisted queue state alone.

#### Resolved Queue Entry

Add an internal resolved queue representation used only after tracker selection:

| Field | Type | Purpose |
| --- | --- | --- |
| `queue_identifier` | string | Raw or queue-state identifier shown to the operator |
| `canonical_identifier` | string | Canonical tracker identifier used for lookup and dispatch |

#### Compozy Normalization Rules

When `tracker.kind = "compozy_tasks"`:

- `example-feature` resolves to `compozy:example-feature`
- `compozy:example-feature` remains a valid legacy canonical selector
- mixed bare and canonical Compozy selectors in the same queue are rejected in MVP
- task-step-like selectors such as `compozy:task_01` remain invalid at the **Compozy PRD Run** boundary

When `tracker.kind != "compozy_tasks"`:

- bare opaque tokens fail readiness with a guided tracker-mismatch message
- existing GitHub and minibeads normalization rules remain unchanged

#### Runtime State

No new queue JSON fields are required. Existing `ordered_queue.entries[].issue_identifier` remains the serialized field, but for Compozy bare-slug queues it now contains the raw slug text. This preserves the approved queue-state behavior and keeps existing frontend/backend parsing compatible.

### API Endpoints

No new HTTP endpoint is required.

Existing Runtime State endpoints continue to expose ordered queue state:

| Method | Path | Change |
| --- | --- | --- |
| GET | `/api/v1/state` | Existing queue shape stays intact; Compozy bare-slug queues expose raw slug identifiers in queue entries. |
| GET | `/api/v1/state/live` | Same shape as snapshot state. |

## Integration Points

| Integration Point | Design |
| --- | --- |
| `main.ml` startup path | Parse the queue before config load, then resolve it after tracker selection for readiness and orchestration. |
| `Issue_tracker.normalize_identifier` | Reuse the selected tracker hook as the canonical normalization boundary. |
| `README.md` and CLI help | Update queue examples and mismatch guidance without changing other tracker documentation. |
| Existing queue resume state | Preserve raw sequence matching for bare-slug queue runs. |
| Existing canonical Compozy tests | Keep canonical `compozy:<task_name>` flows valid to avoid regression. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/ordered_queue.ml` | Modified | Current parser assumes canonical identifiers and duplicates are resolved immediately. | Add opaque bare-token support, tracker-aware resolution helpers, and resolved-duplicate checks. |
| `apps/backend/lib/issue_tracker.ml` | Modified | Compozy normalization currently accepts canonical selectors only. | Allow Compozy bare-slug normalization after tracker selection while keeping GitHub/minibeads unchanged. |
| `apps/backend/lib/runtime_readiness.ml` | Modified | Queue validation currently assumes parsed identifiers are already canonical. | Validate through resolved queue entries and emit guided mismatch remediation. |
| `apps/backend/lib/orchestrator.ml` | Modified | Queue ordering and resume currently compare canonical identifiers directly. | Use resolved canonical identifiers for dispatch matching while preserving raw queue state for resume. |
| `apps/backend/bin/main.ml` | Modified | Startup currently separates parse problems from readiness validation. | Keep structural parse failures early and route tracker-aware queue problems into readiness. |
| `apps/backend/lib/cli_command.ml` | Modified | `--queue` help still describes generic issue identifiers only. | Document Compozy bare-slug shortcut scope. |
| `README.md` | Modified | Current docs require `compozy:<task_name>` in selector-based flows. | Add `--queue` MVP shortcut examples and tracker-mismatch guidance. |
| `apps/backend/test/test_backend.ml` | Modified | Existing tests cover canonical queue parsing and canonical queue resume. | Add bare-slug parser, readiness, orchestration, and resume coverage near existing queue tests. |

## Testing Approach

### Unit Tests

- `Ordered_queue.parse` accepts bare opaque tokens while still rejecting empty entries, URLs, and cross-repository references.
- Resolved duplicate detection catches canonical collisions such as `20` and `#20`, `MB-020` and `mb-20`, and repeated bare Compozy slugs.
- Compozy `normalize_identifier` accepts both `example-feature` and `compozy:example-feature`.
- Mixed bare and canonical Compozy queue input is rejected in MVP.
- Guided tracker-mismatch remediation is produced when bare Compozy slugs are used under GitHub or minibeads tracker modes.
- Canonical Compozy queue validation remains unchanged.

### Integration Tests

- A Compozy bare-slug queue validates successfully without GitHub Project membership.
- Orchestrator dispatches a Compozy bare-slug **Ordered Queue** only in the requested order.
- Runtime State persists raw bare-slug queue identifiers during a Compozy queue run.
- Restarting with the same bare-slug queue resumes queue progress.
- Restarting with canonical Compozy selectors after a bare-slug run starts a new queue run rather than resuming.
- A bare-slug queue under a non-Compozy tracker reports a **Readiness Gap** and does not begin orchestration.
- Existing canonical `compozy:<task_name>` queue tests continue to pass.

## Development Sequencing

### Build Order

1. Add queue-resolution data types and helper functions in `Ordered_queue` - no dependencies.
2. Update `Ordered_queue.parse` to accept opaque bare tokens while preserving current structural rejection rules - depends on step 1.
3. Extend Compozy tracker normalization to accept bare slugs after tracker selection - depends on step 1.
4. Route queue validation through resolved queue entries in `Runtime_readiness` - depends on steps 1 and 3.
5. Update `main.ml` startup wiring so tracker-aware queue failures surface as readiness output - depends on steps 2 and 4.
6. Refactor `Orchestrator` queue matching and ordering to use resolved canonical identifiers while persisting raw queue state - depends on steps 1, 3, and 4.
7. Update CLI help and README examples for the Compozy shortcut - depends on steps 4 and 6.
8. Add unit coverage for parse, resolution, and readiness cases - depends on steps 2 through 5.
9. Add end-to-end orchestration and resume coverage for bare-slug queues - depends on steps 6 and 8.
10. Run focused backend verification - depends on steps 1 through 9.

### Technical Dependencies

- Existing `Issue_tracker.normalize_identifier` contract remains the selected-tracker normalization boundary.
- Existing **Runtime State** queue schema remains in place; no frontend schema migration is required for MVP.
- Existing queue resume behavior in `Orchestrator` must be updated carefully because it currently assumes canonical identifier sequences.
- Work stays inside the current backend module layout; no new package or directory is required.

## Monitoring and Observability

- Startup readiness output should distinguish structural parse errors from tracker-aware queue mismatch errors.
- Queue-related logs should include both the queue-state identifier and the resolved canonical identifier when a Compozy bare slug is resolved.
- Ordered queue skipped or invalid-entry output should continue to show the operator-facing queue identifier.
- Existing Runtime State queue projections remain the primary operator-visible queue status surface.

## Technical Considerations

### Key Decisions

- Decision: keep `Ordered_queue.parse` generic and move Compozy meaning behind post-settings queue resolution.  
  Rationale: matches the selected tracker boundary and avoids Compozy-specific parser logic.  
  Trade-off: queue validation becomes two-phase instead of parse-only.

- Decision: preserve raw bare-slug text in queue state and resume keys.  
  Rationale: keeps state aligned with what the operator typed and with the approved terminal-first workflow.  
  Trade-off: equivalent raw and canonical selector forms no longer resume the same queue run.

- Decision: emit guided bare-slug tracker mismatch as a **Readiness Gap**.  
  Rationale: readiness has the selected tracker context and already owns startup blocking feedback.  
  Trade-off: some invalid inputs now fail at readiness rather than parse time.

- Decision: add end-to-end orchestration coverage, including resume behavior for bare-slug queues.  
  Rationale: the change touches parser, readiness, runtime state, and dispatch matching in one flow.  
  Trade-off: broader test setup than a parser-only change.

### Known Risks

- Raw queue state and resolved canonical identifiers may drift if resolution logic is duplicated.  
  Mitigation: use one shared resolution helper from readiness and orchestration.

- Mixed-style Compozy queue input could confuse operators and complicate duplicate rules.  
  Mitigation: reject mixed bare and canonical Compozy input in MVP.

- Preserving raw queue identifiers may surprise operators who expect bare and canonical restarts to resume the same queue.  
  Mitigation: document the resume behavior explicitly and cover it with end-to-end tests.

## Architecture Decision Records

- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — Scopes bare Compozy slug support to `compozy_tasks` queue input while preserving downstream canonical identifiers.
- [ADR-002: Focused Compozy Queue Shortcut](adrs/adr-002.md) — Chooses a narrow `--queue` shortcut MVP over a broader selector simplification effort.
- [ADR-003: Tracker-Aware Ordered Queue Resolution](adrs/adr-003.md) — Separates raw queue state from post-settings canonical resolution and preserves raw input for resume.
- [ADR-004: Readiness-First Queue Diagnostics](adrs/adr-004.md) — Places guided tracker-mismatch feedback in startup readiness instead of parse-time or dispatch-time failures.

