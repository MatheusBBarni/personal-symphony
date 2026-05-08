# TechSpec: minibeads Local Issue Tracker

## Executive Summary

The implementation will add a shared `Issue_tracker` boundary with two concrete adapters: the existing GitHub behavior wrapped as the default adapter, and a new minibeads adapter that integrates through the `mb` CLI. The selected tracker will drive readiness, candidate fetches, issue lookups, status updates, active/terminal checks, Ordered Queue validation, Manual Task Merge validation, and tracker poll error classification.

The primary trade-off is a larger refactor up front in exchange for avoiding a long-lived GitHub-shaped orchestration core. V1 will keep dashboard changes narrow: expose the selected tracker kind in Runtime State and replace GitHub/project-specific wording, but defer richer local metadata rendering. minibeads comments/notes are out of V1 because the selected integration uses `mb` CLI behavior and no stable native comments contract is assumed.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Config` | Parse tracker kind and tracker-specific settings from Runtime Settings. Preserve GitHub defaults. | Owns validated runtime config only; no tracker I/O. |
| `Issue_tracker` | Runtime-selected tracker contract for shared orchestration flows. | Hides GitHub/minibeads differences from Orchestrator, queue, merge, and readiness code. |
| `Github_tracker` adapter | Wrap existing GitHub Issues + Projects behavior behind `Issue_tracker`. | Keeps current GraphQL behavior and rate-limit handling. |
| `Minibeads_tracker` adapter | Invoke `mb` from the Workspace Repository, map command output into `Issue.t`, and update local task status through `mb`. | Treats CLI output as untrusted and reports deterministic diagnostics. |
| `Ordered_queue` | Parse and validate GitHub numeric identifiers plus `mb-<number>` identifiers. | Initial parsing rejects malformed selectors; selected tracker validates existence and dispatchability. |
| `Manual_merge` | Resolve selected identifiers through the selected tracker and preserve existing Task Branch Integration behavior. | Does not require GitHub Project membership for minibeads. |
| `Orchestrator` | Poll selected tracker, update Runtime State, dispatch work, and write tracker status transitions. | Depends on `Issue_tracker`, not `Github_tracker.t`, for shared tracker operations. |
| `Runtime_state` | Include selected tracker kind in snapshots. | Existing issue fields remain mostly unchanged in V1. |
| Web Dashboard | Use tracker-neutral wording based on Runtime State. | No rich local metadata card expansion in V1. |

Data flow:

1. Runtime Settings choose `tracker.kind`.
2. `Issue_tracker.make config` selects GitHub or minibeads.
3. Readiness checks combine shared config gaps and selected tracker gaps.
4. Orchestrator polls `Issue_tracker.fetch_candidates`.
5. Issues map into `Issue.t` and Runtime State.
6. Dispatch/status transitions call `Issue_tracker.update_status`.
7. Ordered Queue and Manual Task Merge validate identifiers through the selected tracker.

## Implementation Design

### Core Interfaces

The concrete code will be OCaml. The following Go-shaped interface captures the primary contract other components depend on, per TechSpec template requirements:

```go
type IssueTracker interface {
    Kind() string
    FetchCandidates() ([]Issue, error)
    FetchByIdentifiers(ids []string) (map[string]*Issue, error)
    UpdateStatus(issue Issue, status string) error
    ReadinessGaps() []ReadinessGap
    NormalizeIdentifier(raw string) (string, error)
    IsActive(status string) bool
    IsTerminal(status string) bool
}
```

OCaml sketch:

```ocaml
type poll_error = Rate_limited of string * int | Failed of string

type t = {
  kind : string;
  fetch_candidates : unit -> (Issue.t list, poll_error) result;
  fetch_by_identifiers : string list -> (Issue.t option list, string) result;
  update_status : Issue.t -> string -> (unit, string) result;
  readiness_gaps : unit -> Runtime_state.readiness_gap list;
  normalize_identifier : string -> (string, string) result;
  is_active : string -> bool;
  is_terminal : string -> bool;
}
```

### Data Models

`Issue.t` remains the common issue model. minibeads maps into existing fields:

| `Issue.t` field | minibeads V1 source |
| --- | --- |
| `id` | Canonical minibeads identifier, e.g. `mb-12`. |
| `identifier` | Same canonical minibeads identifier. |
| `title` | `mb` issue title output. |
| `description` | `mb` issue body/description output when available. |
| `comments` | Empty in V1. |
| `priority` | `mb` priority field when available. |
| `state` | `mb` status mapped to Runtime Settings state vocabulary. |
| `branch_name` | Existing Symphony-derived Task Branch, not stored by minibeads. |
| `url` | `None` for local issues. |
| `labels` | `mb` labels/tags output when available. |
| `blocked_by` | minibeads dependency/blocker output. |
| `created_at` | `mb` created timestamp when available. |
| `updated_at` | `mb` updated timestamp when available. |

Runtime State additions:

| Field | Type | Purpose |
| --- | --- | --- |
| `tracker_kind` | string | Lets terminal/dashboard surfaces use tracker-neutral wording and expose selected tracker context. |

Selector rules:

| Tracker | Accepted input | Canonical identifier |
| --- | --- | --- |
| GitHub | `20`, `#20` | `#20` |
| minibeads | `mb-20` | `mb-20` |

Rejected selector inputs include empty values, URLs, cross-repository references, and local identifiers that do not match `mb-<number>`.

### API Endpoints

No new HTTP endpoints are required.

Existing endpoints continue serving Runtime State snapshots:

| Method | Path | Change |
| --- | --- | --- |
| `GET` | `/api/v1/state` | Response includes `tracker_kind`. |
| WebSocket | `/api/v1/state/live` | Snapshot payload includes `tracker_kind`. |

## Integration Points

### minibeads CLI

The minibeads adapter invokes `mb` from the Workspace Repository root.

Required command capabilities:

- Confirm minibeads is installed and usable.
- List candidate issues in machine-readable form when available.
- Fetch one or more issues by canonical identifier.
- Expose status, labels/tags, priority, blockers, timestamps, title, and body/description where available.
- Update an issue status idempotently.

Error handling:

- Missing `mb` command becomes a Readiness Gap.
- Missing local issue store becomes a Readiness Gap.
- Invalid command output becomes a deterministic tracker diagnostic.
- Unsupported status values make the issue non-dispatchable.
- Status update failures move through existing retry/attention paths.

### GitHub Remote PR Handoff

Pull request handoff remains independent of tracker kind. For minibeads, PR handoff may continue using existing git remote and PR settings. It must not require GitHub Issues, GitHub Projects, or tracker token settings.

When PR handoff changes task state, the selected tracker status path updates minibeads status.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/config.ml` | modified | Currently rejects non-GitHub tracker kinds and always reads GitHub fields. Risk: default regression. | Add tagged tracker config while preserving GitHub defaults. |
| `apps/backend/lib/github_tracker.ml` | modified | Current module is concrete and public to orchestrator/merge paths. Risk: behavior drift. | Wrap existing behavior behind `Issue_tracker`. |
| `apps/backend/lib/minibeads_tracker.ml` | new | New adapter shells out to `mb`. Risk: CLI output instability. | Add command runner abstraction and strict validation. |
| `apps/backend/lib/issue_tracker.ml` | new | Shared selected-tracker contract. Risk: over-abstraction. | Include only required orchestration operations. |
| `apps/backend/lib/orchestrator.ml` | modified | Uses `Github_tracker.t`, GitHub rate-limit exception, and GitHub wording. Risk: broad shared behavior changes. | Depend on `Issue_tracker.t` and generic poll errors. |
| `apps/backend/lib/ordered_queue.ml` | modified | Numeric GitHub-only parser. Risk: breaking existing `#20` behavior. | Add `mb-<number>` support while preserving numeric GitHub selectors. |
| `apps/backend/lib/manual_merge.ml` | modified | Fetches GitHub project issues and validates Project membership. Risk: hidden GitHub assumptions. | Resolve through selected tracker and skip Project membership for minibeads. |
| `apps/backend/lib/runtime_state.ml` | modified | Runtime snapshots lack tracker kind. | Add `tracker_kind` to JSON with backwards-compatible frontend parsing. |
| `apps/backend/bin/main.ml` | modified | Startup/readiness copy is GitHub-oriented. | Use tracker-neutral terminal wording. |
| `apps/frontend/src/Main.res` | modified | Runtime State type lacks tracker kind. | Parse optional `tracker_kind`. |
| `apps/frontend/src/Pages/Dashboard.res` | modified | UI says "Project board" and "project issues". | Use tracker-neutral labels. |
| `apps/backend/test/test_backend.ml` | modified | Large suite contains config, queue, orchestrator, merge, runtime-state tests. | Add focused tests near related cases; do not split file. |
| `README.md` and tracker docs | modified | Current setup is GitHub-first. | Document GitHub default and minibeads as explicit first-class option. |

## Testing Approach

### Unit Tests

- `Config` parses omitted `tracker.kind` as GitHub and `tracker.kind = "minibeads"` without GitHub owner/repo/project/token requirements.
- `Issue_tracker` selects the correct adapter from config.
- `Minibeads_tracker` maps valid `mb` output into `Issue.t`.
- `Minibeads_tracker` reports missing CLI, missing store, duplicate IDs, unsupported status, malformed output, and blocked dependencies deterministically.
- `Minibeads_tracker.update_status` invokes the expected `mb` status transition and treats repeated transitions as idempotent success.
- `Ordered_queue` accepts `20`, `#20`, and `mb-20`; rejects URLs, cross-repository references, and malformed local identifiers.
- `Manual_merge` normalizes and validates `mb-20` selectors through the selected tracker.
- `Runtime_state.to_yojson` includes `tracker_kind`.

### Integration Tests

- End-to-end orchestrator test with minibeads adapter stub: one active local issue dispatches, starts, completes, and writes status without GitHub settings or token.
- Blocked local issue test: issue with non-terminal blocker is visible but not dispatched.
- PR handoff test for minibeads: existing PR handoff path remains available and status updates go through selected tracker.
- GitHub regression tests: existing GitHub config, readiness, queue, manual merge, rate-limit, and orchestrator behavior continue to pass.

### Frontend Verification

- ReScript build after `.res` changes.
- Frontend live-state tests if existing fixtures assert Runtime State parsing.
- Manual dashboard check only if UI copy changes are substantial.

## Development Sequencing

### Build Order

1. Add `Issue_tracker` types and adapter selection skeleton - no dependencies.
2. Wrap `Github_tracker` behind `Issue_tracker` - depends on step 1.
3. Split tracker config parsing for GitHub vs minibeads while preserving GitHub default - depends on step 1.
4. Add minibeads adapter command runner and readiness gaps - depends on steps 1 and 3.
5. Implement minibeads candidate fetch, lookup, blocker mapping, and status update - depends on step 4.
6. Update Orchestrator to use `Issue_tracker` operations and generic poll errors - depends on steps 2 and 5.
7. Update Ordered Queue parser and validation for `mb-<number>` - depends on steps 1 and 3.
8. Update Manual Task Merge to resolve through selected tracker - depends on steps 1, 3, and 7.
9. Add `tracker_kind` to Runtime State and terminal wording - depends on step 3.
10. Update ReScript Runtime State parsing and dashboard wording - depends on step 9.
11. Preserve PR handoff for minibeads and route status updates through selected tracker - depends on steps 6 and 8.
12. Update README/docs for GitHub default and minibeads first-class option - depends on steps 3, 4, and 9.
13. Add focused backend/frontend tests and run verification - depends on all implementation steps.

### Technical Dependencies

- Confirm installed `mb` CLI command shape and machine-readable output for list, lookup, status, labels/tags, priority, blockers, and timestamps.
- Keep commands rooted in the Workspace Repository.
- Do not change Runtime Contract defaults in `runtime_home.ml` without explicit approval.
- Do not split `apps/backend/test/test_backend.ml`.

## Monitoring and Observability

- Log selected tracker kind at startup.
- Report local tracker readiness gaps with requirements such as `tracker.minibeads.command`, `tracker.minibeads.store`, or `tracker.minibeads.status`.
- Runtime State exposes `tracker_kind`.
- Status update failures include issue identifier, target status, tracker kind, and sanitized command failure summary.
- Poll failures distinguish rate-limited GitHub behavior from minibeads command failures.
- Dashboard and terminal surfaces avoid GitHub-specific wording for local tracker runs.

## Technical Considerations

### Key Decisions

- Decision: Use a shared `Issue_tracker` boundary.
  - Rationale: It preserves one orchestration model across GitHub and minibeads.
  - Trade-off: More refactoring before visible local dispatch works.
  - Alternatives rejected: direct minibeads conditionals and config-only staging.

- Decision: Use `mb` CLI for minibeads reads and writes.
  - Rationale: It keeps minibeads storage semantics owned by minibeads.
  - Trade-off: V1 depends on CLI availability and stable machine-readable output.
  - Alternatives rejected: direct frontmatter parsing and hybrid direct writes.

- Decision: Keep PR handoff independent of tracker kind.
  - Rationale: Issue tracking and PR handoff are separate operator workflows.
  - Trade-off: Existing PR code must be audited for tracker field coupling.
  - Alternatives rejected: disabling PR handoff for minibeads or requiring new remote settings.

- Decision: Constrain local selectors to `mb-<number>` in V1.
  - Rationale: It keeps queue and merge parsing predictable.
  - Trade-off: Other possible minibeads identifier shapes are deferred.
  - Alternatives rejected: accepting arbitrary strings.

- Decision: Add only `tracker_kind` and dashboard wording changes for V1 visibility.
  - Rationale: It satisfies selected V1 dashboard scope while keeping frontend changes small.
  - Trade-off: Rich local metadata rendering is deferred.
  - Alternatives rejected: full local metadata cards in V1.

### Known Risks

- `mb` CLI output may not expose all metadata required by the PRD.
  - Mitigation: Treat missing metadata as unsupported in V1 unless required for dispatch/status; document gaps.

- Existing PR handoff may rely on `config.tracker.owner` or `config.tracker.repo`.
  - Mitigation: Audit PR handoff paths and derive remote context outside Issue Tracker fields for minibeads.

- Status writes can conflict with user edits or agent changes to Local Issue Files.
  - Mitigation: Use `mb` for writes, keep writes in the Workspace Repository root, and route failures to attention/retry behavior.

- GitHub behavior can regress during boundary refactor.
  - Mitigation: Keep GitHub adapter thin and preserve existing tests.

- Ordered Queue and Manual Task Merge may have hidden numeric assumptions.
  - Mitigation: Add explicit selector tests for GitHub and minibeads forms.

## Architecture Decision Records

- [ADR-001: Scope minibeads as an opt-in local tracker adapter](adrs/adr-001.md) — V1 uses minibeads as an opt-in Local Issue Tracker for Symphony's existing orchestration model.
- [ADR-002: Prioritize a first-class local tracker experience for V1](adrs/adr-002.md) — V1 emphasizes visible, documented, operator-usable local tracking, not only backend dispatch.
- [ADR-003: Introduce a shared Issue Tracker boundary](adrs/adr-003.md) — Shared orchestration paths depend on a selected tracker adapter instead of `Github_tracker.t`.
- [ADR-004: Use the mb CLI as the minibeads integration boundary](adrs/adr-004.md) — minibeads reads and writes go through `mb`, with Symphony validating returned data.
- [ADR-005: Keep PR handoff independent of tracker kind](adrs/adr-005.md) — PR handoff remains available for minibeads runs and status changes update the selected tracker.
- [ADR-006: Constrain V1 local identifiers and dashboard impact](adrs/adr-006.md) — V1 supports `mb-<number>` selectors and limits dashboard changes to tracker-neutral wording plus tracker kind.
