# Terminal Console Elegance Redesign

## Overview

The **Terminal Console Elegance Redesign** makes the default **Terminal Console** easier to scan, calmer to use, and more effective during active orchestration. The MVP is for the heavy daily operator who keeps Personal Symphony open for long sessions inside a **Workspace Repository** and needs to understand live work at a glance without routine fallback to the **Web Dashboard**.

This PRD prioritizes active-run monitoring over startup recovery, while still improving readiness-blocked states enough to keep the product coherent. The redesign is intended to ship as the default **Terminal Console** experience once ready, not as a side preview.

## Goals

- Make the default **Terminal Console** the primary live-monitoring surface for heavy daily operators.
- Reduce visual clutter and weak hierarchy that currently make the console feel noisy.
- Improve active-run comprehension speed so operators can recognize what matters immediately.
- Reduce routine **Web Dashboard** fallback for basic monitoring and triage.
- Preserve trust by keeping the **Terminal Console** read-first and clearly non-mutating.

## User Stories

- As a heavy daily operator, I want the active-run view to show what is happening now so that I can keep the **Terminal Console** open as my main monitoring surface.
- As a heavy daily operator, I want the most important active work and attention signals to stand out so that I do not scan through equal-weight panels.
- As a heavy daily operator, I want selected detail to appear nearby so that I can understand a task or readiness issue without leaving the terminal for routine questions.
- As a heavy daily operator, I want startup and readiness states to feel clearly different from live monitoring so that the product matches the question I am trying to answer.
- As a user who trusts the terminal as a safe surface, I want the redesigned **Terminal Console** to stay obviously read-only so that elegance does not feel like hidden authority.

## Core Features

- **Active-run first monitoring surface**
  The MVP centers on live orchestration visibility: active work, retrying work, attention conditions, next work, **Ordered Queue** context, and **Compozy PRD Run** progress when relevant.

- **Real top-level mode separation**
  The product introduces distinct top-level **Terminal Console** modes so startup/readiness and active monitoring are no longer flattened into the same visual experience.

- **Stronger information hierarchy**
  The redesigned surface emphasizes primary information first and supporting context second, replacing the current equal-weight panel feeling.

- **Curated secondary detail pane**
  The product shows bounded, read-only detail for the current selection so the operator can answer routine “why is this happening” questions without switching surfaces.

- **Contextual guidance and discoverability**
  The **Terminal Console** makes relevant keyboard actions and mode-specific affordances more discoverable in context instead of presenting one generic command layer.

- **Cross-mode attention carryover**
  The redesign keeps urgent signals legible even when the user is focused on the other top-level mode, so separation improves clarity without creating blind spots.

## User Experience

- On launch, the operator should immediately understand whether Personal Symphony is actively orchestrating, blocked by **Readiness Gaps**, or idle.
- During long runs, the operator should be able to keep their attention on one dominant monitoring surface rather than mentally reconciling several equally loud panels.
- When something needs explanation, the operator should get nearby, readable detail before needing to open the **Web Dashboard**.
- When the product cannot or should not answer more deeply, the handoff to the **Web Dashboard** should feel intentional rather than like a failure of the terminal surface.
- The MVP should feel calmer and more legible at first glance, not merely denser or more decorative.

## High-Level Technical Constraints

- Visible orchestration truth must remain aligned with existing **Runtime State** semantics.
- The redesigned **Terminal Console** must preserve the read-first, non-mutating product boundary.
- `symphony --web` and `symphony --once` remain separate product modes.
- The redesigned surface must stay useful when **Readiness Gaps** prevent dispatch.
- The product must not expose secret values or make sensitive details more visible by default.

## Non-Goals

- Task lifecycle mutation from the **Terminal Console**.
- Full **Web Dashboard** replacement or parity.
- A long-term dual experience where old and new Terminal Console modes coexist indefinitely.
- Broad customization, plugin systems, or theme systems in MVP.
- Package, launcher, or **Runtime Contract** behavior changes.
- A broader operator cockpit with new control authority in MVP.

## Phased Rollout Plan

### MVP (Phase 1)

- Ship the redesigned **Terminal Console** as the default experience.
- Prioritize active-run monitoring, real top-level mode separation, stronger hierarchy, contextual guidance, and a curated detail pane.

Success criteria:

- Heavy daily operators can understand active-run state quickly.
- Visual clutter is materially reduced.
- Routine **Web Dashboard** fallback drops for monitoring use cases.

### Phase 2

- Improve readiness-mode depth and refine cross-mode attention visibility based on real usage.
- Tighten detail content and handoff behavior based on what users still need from the **Web Dashboard**.

Success criteria:

- Users rarely need browser fallback for routine startup or live-triage questions.
- The inactive mode still communicates urgent state clearly enough to prevent missed issues.

### Phase 3

- Consider broader history, richer inspection, or more ambitious operator-surface ideas only after the MVP proves adoption and trust.

Success criteria:

- The **Terminal Console** is widely treated as the trusted default monitoring surface.
- Future expansion does not weaken the read-first product promise.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Active-run comprehension time | < 10 seconds | User can identify what is running, retrying, blocked, or needing attention from the default live-monitoring surface. |
| Routine Web Dashboard fallback | Reduce by >= 40% | Compare sessions that open the **Web Dashboard** for basic monitoring before and after rollout. |
| Default Terminal Console retention | >= 70% of runs longer than 5 minutes | Measure how often users keep the redesigned **Terminal Console** open through long orchestration sessions. |
| First-session clarity for primary persona | >= 90% success | Heavy daily operators can navigate the main monitoring flow and inspect detail without outside guidance. |
| Visual hierarchy satisfaction | >= 80% favorable feedback | Collect structured feedback on whether the redesign feels calmer and easier to scan than the prior experience. |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| The redesign looks nicer but does not improve monitoring speed | Weak product value | Anchor MVP success to active-run comprehension and fallback reduction, not aesthetic preference alone. |
| Startup/readiness feels underweighted | Uneven product quality | Keep readiness-mode improvements in MVP and refine them in Phase 2 without diluting the active-run-first focus. |
| Mode separation hides urgent signals | Missed operator attention | Require persistent cross-mode attention carryover in the product design. |
| Existing users resist the default change | Reduced adoption or trust | Keep the redesign predictable, clearly safer, and grounded in familiar Personal Symphony language. |
| The MVP drifts into decorative polish instead of operational value | Wasted effort | Evaluate every feature against the heavy daily operator’s monitoring workflow. |

## Architecture Decision Records

- [ADR-001: Scope the Terminal Console elegance redesign as a two-mode presentation refactor](./adrs/adr-001.md) — Keep the redesign read-first, mode-aware, and primarily inside the presentation layer.
- [ADR-002: Prioritize active-run elegance as the MVP product approach](./adrs/adr-002.md) — Optimize the MVP for heavy daily operators during live orchestration.
- [ADR-003: Ship the Terminal Console redesign as the default experience](./adrs/adr-003.md) — Treat the redesign as the intended default product surface, not a preview-only path.

## Open Questions

- What final user-facing labels should the two top-level **Terminal Console** modes use?
- Which signals must always remain globally visible even when the user is focused on the other mode?
- What exact operator behavior should count as successful “retention” of the redesigned **Terminal Console** during long runs?
- How much readiness-mode depth belongs in MVP versus Phase 2 refinement?
- What is the clearest way to explain that deeper inspection still belongs in the **Web Dashboard** for some cases?
