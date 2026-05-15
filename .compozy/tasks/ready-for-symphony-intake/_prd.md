# PRD: Ready-for-Symphony Intake

## Overview

Symphony should automatically start newly eligible work from the selected **Issue Tracker** in a **Workspace Repository** without requiring the operator to restart the running process. The MVP uses a standard Symphony-ready status convention as the visible control for when work should begin.

This feature is for self-hosting engineers and small teams who keep Symphony running on a VPS or other long-lived environment. It is valuable because it removes restart friction, makes start timing predictable, and gives GitHub-backed and Compozy-backed workflows one shared product model.

## Goals

- Let Symphony start newly eligible work within one polling interval without restart.
- Make tracker status the primary user-visible control for when work starts.
- Give GitHub-backed and Compozy-backed workflows one consistent Symphony-ready concept.
- Preserve confidence in existing **Task Branch**, **Agent Worktree**, stage, retry, and **Ordered Queue** behavior.
- Keep “no ready work yet” as valid **Orchestration Idle** state rather than a failure condition.

## User Stories

- As a solo self-hosting engineer, I want Symphony to notice newly ready work automatically so that I can leave it running without babysitting restarts.
- As a small-team operator, I want one clear Symphony-ready status so that everyone can predict when work will start.
- As a GitHub-backed operator, I want tracker status to control intake so that I do not need a second readiness mechanism.
- As a Compozy-backed operator, I want local tracked work to follow the same Symphony-ready concept so that the product feels consistent across trackers.
- As an operator who uses `--queue` occasionally, I want routine work to start from status alone while keeping queue-based ordering for exceptions.

## Core Features

| # | Feature | Priority | Product Requirement |
| --- | --- | --- | --- |
| F1 | Standard Symphony-ready status | Critical | Symphony defines one standard ready status concept that means work is eligible to start automatically. |
| F2 | Cross-tracker consistency | Critical | The same Symphony-ready concept applies to both the **GitHub Tracker** and the Compozy-backed **Local Issue Tracker**. |
| F3 | Automatic start without restart | Critical | When a work item reaches the Symphony-ready status and capacity is available, Symphony starts it on a later polling cycle without restart. |
| F4 | Healthy idle behavior | Critical | When no work item is in the Symphony-ready status, Symphony remains in valid **Orchestration Idle** state. |
| F5 | Status-first operator control | High | Operators use tracker status as the main visible control for start timing instead of separate readiness markers. |
| F6 | Queue compatibility | High | `--queue` remains available for exceptional ordering and does not disappear from the product model. |
| F7 | Start-behavior visibility | High | Runtime feedback explains why a work item will start, is waiting, or will not start even when operators believe it is ready. |

## User Experience

A typical operator keeps Symphony running in a **Workspace Repository** while planning and refining work in the selected tracker. When a work item reaches the Symphony-ready status, the operator does not need to restart the process or rebuild routine intake commands. Symphony notices the newly eligible item on a later poll and starts work if capacity and normal dispatch rules allow it.

For day-to-day use, the core experience is predictability. Operators should be able to look at tracker status and understand whether Symphony will pick something up soon, whether it is intentionally idle, or whether another rule is holding work back. This matters most for always-on usage, where the product should feel like a dependable intake loop rather than a command that must be re-triggered manually.

For exceptional cases, operators can still use explicit queue ordering. The MVP should make routine work feel automatic while preserving deliberate control for special sequencing needs.

## High-Level Technical Constraints

- Preserve one selected **Issue Tracker** per **Workspace Repository**.
- Preserve existing **Task Branch**, **Agent Worktree**, stage, retry, and completion behavior after work starts.
- Preserve the distinction between status-based eligibility and queue-based ordering.
- Keep GitHub-backed and Compozy-backed workflows aligned under the same product language.
- Do not require operators to maintain a separate readiness marker for routine intake.

## Non-Goals

- Replacing `--queue` with a fully automatic prioritization system.
- Supporting multiple trackers at the same time in one **Workspace Repository**.
- Adding a second explicit readiness marker beside tracker status.
- Introducing dynamic prioritization, scheduling policies, or auto-ordering in the MVP.
- Changing in-flight work behavior based on new status edits after work has already started.
- Building a broader dashboard control plane as part of this MVP.

## Phased Rollout Plan

### MVP (Phase 1)

- Define a standard Symphony-ready status concept.
- Use tracker status as the main visible control for automatic start.
- Start newly eligible work within one polling interval without restart.
- Treat no ready work as valid **Orchestration Idle** state.
- Preserve `--queue` for exceptional ordering.

Success criteria: operators can leave Symphony running and see newly ready work start automatically without restart.

### Phase 2

- Improve operator-facing explanations for why a work item is waiting or not dispatchable.
- Add clearer project guidance for adopting the Symphony-ready convention across trackers.
- Improve confidence for teams mixing routine automatic intake with occasional queue-based ordering.

Success criteria: operators report that start behavior is predictable from tracker status alone.

### Phase 3

- Add product guidance and reporting around intake quality, routine throughput, and exceptions.
- Explore higher-level workflow improvements that build on the status-driven intake model without collapsing it into a hidden queue system.

Success criteria: Symphony-ready status becomes the default mental model for routine intake across supported trackers.

## Success Metrics

| Metric | Target |
| --- | --- |
| Ready-to-start latency | 90% of newly eligible work starts within one polling interval when capacity is available |
| Restart avoidance | 95% reduction in restart-required admissions for routine work |
| Routine queue avoidance | Most routine intake no longer requires `--queue`, while exceptions still can use it |
| Predictability | Operators can correctly predict start behavior from tracker status in dogfood validation |
| False-positive starts | Fewer than 1 unintended start per 100 Symphony-ready work items |

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Teams resist adopting a Symphony-ready status convention | Allow the product concept to stay stable while providing project-level compatibility guidance |
| Operators expect status to control ordering as well as eligibility | Keep `--queue` as a distinct concept and explain that status controls start eligibility, not sequence |
| Mixed tracker habits create confusion about what “ready” means | Use one shared Symphony-ready product concept across trackers |
| Operators lose trust if a ready-looking item does not start | Improve runtime explanations for waiting, blocking, and non-dispatchable cases |
| Teams overuse the ready status and flood intake | Keep routine intake simple and rely on normal capacity limits plus queue controls for exceptional cases |

## Architecture Decision Records

- [ADR-001: Add explicit tracker-driven ready-for-symphony admission](./adrs/adr-001.md) — Initial idea-phase marker-based admission direction, later superseded.
- [ADR-002: Use a standard Symphony-ready status convention across trackers](./adrs/adr-002.md) — The PRD decision: tracker status becomes the primary intake control.

## Open Questions

- What exact user-facing status wording should Symphony standardize on for the ready state?
- How should Runtime State explain cases where a Symphony-ready item is still not dispatchable because of other existing rules?
- How much project-level compatibility should the MVP allow before the cross-tracker product story becomes too weak?
