# Backend TUI JSX Rewrite PRD

## Overview

Rewrite all existing backend Terminal Console UI construction to use the `Tui.Jsx` authoring style from the reusable TUI Toolkit Package. The feature is for Symphony maintainers who review and change Terminal Console views.

The product promise is maintainability: maintainers should read and review Terminal Console view changes with less mental reconstruction while operators continue to see the same Terminal Console behavior and visual hierarchy.

## Goals

- Reach 100% JSX coverage for existing backend Terminal Console UI construction.
- Preserve all existing operator-facing workflows, shortcuts, states, modals, settings behavior, and visual hierarchy.
- Make Terminal Console view changes easier to review by making the rendered tree shape more obvious in source.
- Prove the TUI Toolkit Package JSX authoring path on Symphony's real backend Terminal Console.
- Keep the rewrite scoped to authoring style; no new Runtime State, Runtime Settings, lifecycle, or safe-aid semantics.

## User Stories

- As a Symphony maintainer, I want Terminal Console views written in a tree-shaped style so I can review layout changes faster.
- As a Symphony maintainer, I want one backend Terminal Console authoring model so future view work does not split between direct calls and JSX.
- As a Symphony operator, I want the Terminal Console to behave and look the same so the rewrite does not disrupt my workflow.
- As a TUI Toolkit Package maintainer, I want the product Terminal Console to consume `Tui.Jsx` so the package authoring path is validated by real usage.

## Core Features

1. **Complete JSX Coverage**: All existing backend Terminal Console UI construction uses `Tui.Jsx` as the view authoring style.
2. **Strict Operator Parity**: Existing tabs, shortcuts, modal flows, logs, settings, Readiness Gaps, Ordered Queue display, and safe-aid behavior remain unchanged.
3. **Reviewable Increment Delivery**: Work may land in increments, but product completion requires full existing-surface coverage.
4. **Maintainer Readability Outcome**: The rewritten view layer should make hierarchy, grouping, and nested UI relationships easier to inspect in review.
5. **Docs And Example Alignment**: Documentation should state that the backend Terminal Console now dogfoods the TUI Toolkit Package JSX authoring path.

## User Experience

For operators, the intended user experience is no visible change. The Terminal Console still opens by default for normal `symphony` runs, renders Runtime State snapshots, supports the same local read-only aids, and preserves focused settings behavior.

For maintainers, the experience changes during code review. A Terminal Console view diff should read as a tree of UI elements instead of nested direct component calls. Reviewers should be able to identify structural changes, accidental layout drift, and unsupported behavior changes more quickly.

## High-Level Technical Constraints

- Preserve Terminal Console Runtime State semantics.
- Preserve the boundary between the reusable TUI Toolkit Package and product-specific Terminal Console behavior.
- Do not introduce new Runtime Settings, persisted UI state, lifecycle mutations, or safe-aid capabilities.
- Do not imply React runtime compatibility; this is TUI Toolkit Package JSX over the existing rendered tree model.
- Keep direct TUI package APIs available as lower-level primitives for other callers.

## Non-Goals (Out of Scope)

- Redesigning the Terminal Console UI.
- Adding new Terminal Console actions, settings, shortcuts, or safe aids.
- Changing Web Dashboard handoff behavior.
- Changing Runtime State shape or Runtime Contract defaults.
- Deprecating direct `Tui.Components` or `Tui.Patterns` usage for package users.
- Rewriting unrelated backend runtime, orchestration, or dashboard behavior.

## Phased Rollout Plan

### MVP (Phase 1)

- Convert all existing backend Terminal Console UI construction to JSX.
- Preserve current operator behavior and visual hierarchy.
- Success: 100% JSX coverage for existing backend Terminal Console UI construction with no intentional operator-visible changes.

### Phase 2

- Align docs and examples with the backend Terminal Console dogfooding result.
- Success: maintainers can identify the backend Terminal Console as the production validation case for `Tui.Jsx`.

### Phase 3

- Use the completed rewrite as the default authoring precedent for future Terminal Console view work.
- Success: new Terminal Console UI changes follow the JSX authoring model unless there is a documented reason not to.

## Success Metrics

- JSX coverage: 100% of existing backend Terminal Console UI construction.
- Operator parity: 0 intentional behavior or visual hierarchy changes.
- Runtime safety: 0 new Runtime State fields, Runtime Settings, lifecycle mutations, or safe-aid capabilities.
- Maintainer readability: at least 20% reduction in view-layer nesting or source size for comparable view construction.
- Quality gate: existing Terminal Console behavior coverage remains passing.

## Risks and Mitigations

- **Risk: rewrite churn hides behavior drift.** Mitigation: treat any operator-visible behavior or hierarchy change as out of scope.
- **Risk: increments are mistaken for product completion.** Mitigation: only full existing-surface JSX coverage satisfies V1.
- **Risk: maintainability value is hard to prove.** Mitigation: measure coverage and view-layer readability before claiming completion.
- **Risk: package dogfooding pressures product-specific behavior into the TUI Toolkit Package.** Mitigation: preserve the package/product boundary in requirements.
- **Risk: docs overstate the change as a new operator feature.** Mitigation: frame the work as maintainer-facing authoring convergence.

## Architecture Decision Records

- [ADR-001: Adopt Parity-Gated Backend Terminal Console JSX Migration](adrs/adr-001.md) - Superseded council recommendation.
- [ADR-002: Select Complete Backend Terminal Console JSX Rewrite](adrs/adr-002.md) - Accepted complete V1 scope.
- [ADR-003: Select Complete Coverage With Strict Parity PRD Approach](adrs/adr-003.md) - Accepted PRD product approach.

## Open Questions

- Which representative Terminal Console preview states should be used for before/after parity review?
- Should docs call JSX the required internal pattern for future Terminal Console view work, or only the preferred pattern?
- Should the readability metric use nesting depth, source size, review checklist outcomes, or a combination?

## Research Sources

- [Reason JSX](https://reasonml.github.io/docs/en/jsx)
- [Ink](https://github.com/vadimdemedes/ink)
- [OpenTUI](https://opentui.com/docs/core-concepts/renderer/)
- [State of JS 2025](https://2025.stateofjs.com/en-US/usage/)
- [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/)
