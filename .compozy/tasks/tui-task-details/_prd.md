# TUI Task Details PRD

## Overview

Build a status-first inspect mode for the Personal Symphony Terminal Console. The feature helps solo operators diagnose active work, Readiness Gaps, and attention states without leaving the default terminal surface or switching through irrelevant tabs.

V1 applies to every selectable Terminal Console tab except Logs. When no Ordered Queue exists, the Terminal Console starts on Tasks and hides Queue. Inspect mode leads with current state, blockers, errors, remediation, and next operator attention, then shows provenance and progress evidence when relevant.

## Goals

- Reduce diagnosis friction by making key status context reachable in <= 2 interactions.
- Remove irrelevant Queue UI when no Ordered Queue exists.
- Give operators one consistent inspect behavior across non-Logs selectable tabs.
- Preserve Terminal Console as a read-first Runtime State surface.

## User Stories

- As a solo operator, I want Tasks to be the default when no Ordered Queue exists so that I start on live work context.
- As a solo operator, I want to inspect the selected row so that I can see blockers, errors, remediation, and status context quickly.
- As a solo operator, I want progress evidence and provenance available after status context so that I can trust what Symphony is showing.
- As an operator with an Ordered Queue, I want Queue visibility preserved so that queue progress and skipped entries remain explicit.

## Core Features

- **Dynamic Queue visibility:** Hide Queue only when no Ordered Queue exists; keep Queue for present empty, filtered, completed, skipped, failed, and attention states.
- **Status-first inspect mode:** Add a consistent inspect interaction for Tasks, Queue, Readiness, and Needs attention.
- **Tasks default surface:** When Queue is hidden, start on Tasks as the primary live-work scan surface.
- **Prioritized detail order:** Show status, blockers, errors, remediation, and next attention first; show provenance and progress evidence after.
- **Contextual help:** Footer and help copy describe inspect behavior for the active tab, not Queue-only expansion.

## User Experience

The operator opens `symphony` and lands in the Terminal Console. If no Ordered Queue exists, the visible tabs omit Queue and focus starts on Tasks. The operator moves row selection with existing navigation, opens inspect mode, reads status-first details, and closes the detail without changing task lifecycle state.

Inspect mode should feel like progressive disclosure: default rows stay compact; detail appears only after explicit inspection. Logs stay scroll-focused and are excluded from V1 inspect mode.

## High-Level Technical Constraints

- Terminal Console remains read-first and must not mutate task lifecycle state.
- Runtime State remains the source for visible status, queue, readiness, attention, provenance, and progress information.
- Ordered Queue absence must remain distinct from an existing queue with no visible rows.
- No secret values, token values, or local environment content may be exposed.

## Non-Goals (Out of Scope)

- Retrying, pausing, resuming, merging, pushing, opening PRs, or updating tracker status.
- Runtime Contract editing or new settings.
- Web Dashboard changes.
- Inspect mode for Logs.
- Configurable inspect fields or custom layouts.
- Inferring an Ordered Queue from tracker order or active tasks.

## Phased Rollout Plan

### MVP (Phase 1)

- Dynamic Queue visibility.
- Tasks as default when Queue is absent.
- Status-first inspect mode for Tasks, Queue, Readiness, and Needs attention.
- Updated help/footer language.

### Phase 2

- Tune detail density after dogfooding.
- Add clearer empty-state language for edge cases discovered in real runs.
- Consider Web Dashboard parity only after Terminal Console behavior stabilizes.

### Phase 3

- Evaluate whether future non-Logs panels should adopt inspect mode by default.

## Success Metrics

- <= 2 interactions from starting surface to inspected status detail.
- 100% of no-Ordered-Queue snapshots omit Queue.
- 100% of present Ordered Queue snapshots preserve Queue visibility.
- 4 non-Logs selectable tab families support inspect mode in V1.
- 0 lifecycle mutation actions exposed through inspect mode.

## Risks and Mitigations

- **Risk:** Hiding Queue makes absence ambiguous.
  **Mitigation:** Hide only when no Ordered Queue exists; preserve explicit queue empty states.
- **Risk:** Inspect mode becomes too dense.
  **Mitigation:** Keep default rows compact and detail explicit.
- **Risk:** Status-first hides progress evidence.
  **Mitigation:** Include provenance and progress evidence as supporting detail after status context.
- **Risk:** Operators expect inspect mode to perform actions.
  **Mitigation:** Keep language read-only and exclude lifecycle commands.

## Architecture Decision Records

- [ADR-001: Preserve Queue Absence and Add Progressive Task Detail](adrs/adr-001.md) — Superseded narrower scope.
- [ADR-002: Adopt Unified Terminal Console Inspect Mode](adrs/adr-002.md) — Accepted ambitious inspect-mode direction.
- [ADR-003: Use Status-First Inspect Mode for the PRD](adrs/adr-003.md) — Accepted PRD product approach.

## Open Questions

- Should the primary inspect key be Space everywhere, or should another key be introduced while preserving Queue compatibility?
- Should normal progress rows lead with progress evidence when there is no blocker?

## Research Inputs

- [Nx Terminal UI](https://nx.dev/docs/guides/tasks--caching/terminal-ui)
- [Stack Overflow 2025 AI survey](https://survey.stackoverflow.co/2025/ai)
- [DORA AI tensions](https://dora.dev/insights/balancing-ai-tensions/)
