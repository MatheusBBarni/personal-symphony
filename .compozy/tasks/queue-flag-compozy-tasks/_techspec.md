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
