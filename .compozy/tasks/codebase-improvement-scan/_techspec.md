# Codebase Improvement Scan TechSpec

## Executive Summary

The implementation will produce a non-runnable Evidence-First Backlog in `.compozy/tasks/codebase-improvement-scan/_tasks.md`. MVP uses `_tasks.md` as a discovery artifact, not as an executable Compozy Task Step list. The backlog uses a standard summary table for scanability and per-finding detail sections for complete metadata.

Primary trade-off: this design preserves maintainer review quality before execution, but it intentionally defers automated Compozy validation and executable `task_NN.md` generation to Phase 2.

## System Architecture

### Component Overview

| Component | Purpose | Boundary |
| --- | --- | --- |
| `_tasks.md` discovery backlog | Stores 15+ findings and all required metadata | Compozy PRD Run artifact, non-runnable in MVP |
| Finding detail sections | Preserve evidence, acceptance targets, verification expectations, and runtime impact | Markdown contract consumed by maintainers and future task generation |
| Manual metadata checklist | Ensures MVP completeness without new tooling | TechSpec-defined review gate |
| Phase 2 conversion path | Converts selected findings into executable `task_NN.md` files | Deferred Compozy compatibility work |

Data flow: PRD and ADRs define the backlog contract -> the MVP scan produces `_tasks.md` -> maintainer reviews finding quality -> Phase 2 converts selected findings into executable Compozy Task Steps.

## Implementation Design

### Core Interfaces

The finding schema is documented as a Go struct to make the required fields unambiguous for future validators and task-generation tooling.

```go
type Finding struct {
	ID                      string
	Title                   string
	Category                string
	Boundary                string
	Priority                string
	Evidence                []string
	AcceptanceTarget        string
	VerificationExpectation []string
	RuntimeSemanticsImpact  string
	GuardrailCandidate      bool
	DeferredFollowUp        bool
}
```

### Data Models

Each finding uses a stable `F-001` style identifier.

Required fields:
- `id`
- `title`
- `category`
- `boundary`
- `priority`
- `evidence`
- `acceptance_target`
- `verification_expectation`
- `runtime_semantics_impact`
- `guardrail_candidate`
- `deferred_follow_up`

Allowed categories:
- `defect`
- `maintainability`
- `polish`
- `security/blast-radius`
- `docs hygiene`
- `Runtime Contract drift`
- `agent-readiness risk`

Allowed boundaries:
- `Runtime Contract`
- `Runtime Home`
- `Runtime State`
- `Terminal Console`
- `Web Dashboard`
- `Compozy PRD Run`
- `Compozy Task Step`
- `docs`
- `CLI`
- `backend`
- `frontend`
- `maintainer workflow`

Allowed runtime-semantics impact:
- `none`
- `Runtime Contract`
- `Runtime Home`
- `Runtime State`
- `Task Branch`
- `Bootstrap`
- `other`

### `_tasks.md` Format

The file starts with an explicit warning:

> This MVP `_tasks.md` is non-runnable discovery output. Do not run `compozy tasks validate` against it until Phase 2 converts selected findings into executable `task_NN.md` files.

Summary table:

| ID | Title | Category | Boundary | Priority | Guardrail | Deferred |
| --- | --- | --- | --- | --- | --- | --- |

Per-finding detail section:

```markdown
## F-001: Finding Title

- Category:
- Boundary:
- Priority:
- Evidence:
  - `path:line` — note
- Acceptance target:
- Verification expectation:
- Runtime semantics impact:
- Guardrail candidate:
- Deferred follow-up:
```

### API Endpoints

No API endpoints are introduced. MVP is an artifact-generation and planning workflow.

## Integration Points

| Integration Point | Role |
| --- | --- |
| Compozy PRD Run directory | Hosts `_tasks.md`, `_prd.md`, `_techspec.md`, and ADRs. |
| `CONTEXT.md` | Source of product terminology for boundaries and runtime semantics. |
| Existing validators | Inform manual checklist expectations; no MVP script is added. |
| Phase 2 task generation | Converts selected findings into executable `task_NN.md` files. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `.compozy/tasks/codebase-improvement-scan/_tasks.md` | new | Non-runnable backlog artifact; risk of being mistaken for executable tasks | Add explicit warning and phase boundary |
| `.compozy/tasks/codebase-improvement-scan/_techspec.md` | new | Documents schema, validation, and sequencing | Save after approval |
| `.compozy/tasks/codebase-improvement-scan/adrs/adr-003.md` | new | Records non-runnable discovery decision | Already created |
| Product runtime code | unchanged | MVP avoids backend/frontend/runtime changes | No runtime verification required unless future tasks change code |

## Testing Approach

### Unit Tests

No unit tests are required for MVP because no product code or validation script changes are introduced.

### Integration Tests

No integration tests are required for MVP discovery output. Do not claim `compozy tasks validate --name codebase-improvement-scan` passes until Phase 2 creates executable task files.

### Manual Validation Checklist

- `_tasks.md` contains at least 15 findings.
- 100% of findings include all required fields.
- At least 3 categories are represented.
- At least 3 findings are marked as guardrail candidates.
- At least 4 findings are marked as deferred structural follow-ups.
- Each evidence entry points to a repo-local path with line reference where practical.
- Each finding includes at least one verification expectation.
- Each finding states runtime-semantics impact.
- `_tasks.md` clearly says it is non-runnable MVP discovery output.

## Development Sequencing

### Build Order

1. Define the `_tasks.md` discovery-backlog skeleton - no dependencies.
2. Populate at least 15 findings - depends on step 1.
3. Add per-finding detail sections with complete metadata - depends on step 2.
4. Apply manual metadata checklist - depends on step 3.
5. Review grouping and priority with maintainer - depends on step 4.
6. Defer executable Compozy Task Step conversion to Phase 2 - depends on step 5.

### Technical Dependencies

- Existing `_prd.md`, ADR-001, ADR-002, and ADR-003.
- Product terminology from `CONTEXT.md`.
- Repo-local evidence from current source files.
- No new package scripts, runtime modules, or backend/frontend changes in MVP.

## Monitoring and Observability

MVP has no runtime monitoring. Completion evidence is the reviewed `_tasks.md` discovery backlog and the manual metadata checklist result.

Phase 2 may add a metadata validator that reports counts for total findings, missing fields, category coverage, guardrail candidates, deferred follow-ups, and invalid evidence paths.

## Technical Considerations

### Key Decisions

- **Decision:** Use `_tasks.md` as a non-runnable discovery backlog.
  **Rationale:** The user selected `_tasks.md`, but backlog quality comes before executable task generation.
  **Trade-off:** Clearer planning now, weaker automation until Phase 2.
  **Alternatives rejected:** dedicated `_backlog.md`, immediate executable task files.

- **Decision:** Defer custom metadata validator to Phase 2.
  **Rationale:** The first backlog should prove the schema before new tooling is added.
  **Trade-off:** MVP requires manual checklist validation.
  **Alternatives rejected:** MVP custom validator, Compozy validation only.

- **Decision:** Do not change product runtime code in MVP.
  **Rationale:** The PRD defines discovery and prioritization, not implementation.
  **Trade-off:** Runtime findings remain unresolved until downstream tasks.

### Known Risks

- **Ambiguous `_tasks.md` semantics:** Mitigate with explicit non-runnable warning.
- **Manual validation misses fields:** Mitigate with the checklist and stable schema.
- **Finding catalog becomes too broad:** Mitigate by requiring priority, boundary, and deferred follow-up flags.
- **Phase 2 conversion loses context:** Mitigate with stable IDs and complete per-finding detail sections.

## Architecture Decision Records

- [ADR-001: Use a Scoped Verified Backlog for Codebase Improvement](adrs/adr-001.md) — Keep complete-sweep discovery while requiring independently reviewable findings.
- [ADR-002: Select Evidence-First Backlog PRD Approach](adrs/adr-002.md) — Optimize the PRD around backlog quality and 15+ evidence-backed findings.
- [ADR-003: Use Non-Runnable Discovery Backlog in `_tasks.md` for MVP](adrs/adr-003.md) — Store the MVP backlog in `_tasks.md` while deferring executable Compozy task conversion.
