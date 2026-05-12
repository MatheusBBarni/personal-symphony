# Mosaic Terminal Console PRD

## Overview

The Mosaic Terminal Console gives solo developers a richer default **Terminal Console** for active Personal Symphony runs in a **Workspace Repository**. It replaces the current static-feeling terminal experience with a read-first command center focused on active work status, safe local aids, and fast comprehension.

The MVP solves one primary problem: during active orchestration, users should understand what Symphony is doing without switching to the **Web Dashboard** or reading raw Runtime Home files and logs. The default home view should show active work at a glance: running work, retrying work, attention conditions, next work, Readiness Gaps, Ordered Queue progress, and Compozy PRD Run progress when present.

The MVP is conservative by design. It may provide safe local aids such as refresh, navigation, filtering, opening the Web Dashboard, and opening relevant local surfaces. It must not mutate task lifecycle state. The product promise is faster understanding first, not a new orchestration control model.

## Goals

- Make the richer Terminal Console the default experience when a user runs `symphony`.
- Help users understand active orchestration state in under 15 seconds.
- Reduce unnecessary Web Dashboard fallback during active runs by giving users the key state they need in the terminal.
- Provide safe local aids that reduce friction without changing task lifecycle state.
- Preserve existing Personal Symphony semantics for the Runtime Contract, Issue Tracker behavior, Task Branch behavior, Task Branch cleanup, auto-merge, Stage Push, Batch Pull Request behavior, and package behavior.
- Keep the Web Dashboard as the deeper browser surface rather than requiring feature parity in the Terminal Console MVP.

## User Stories

### Primary Persona: Solo Developer Running Symphony Locally

- As a solo developer, I want the default Terminal Console to show active work immediately so that I can understand the current run without opening a browser.
- As a solo developer, I want to see running, retrying, attention-needed, and next work in one view so that I can decide whether to keep working or intervene.
- As a solo developer, I want Readiness Gaps and remediation text to stay visible so that I can fix blocked dispatch without hunting through logs.
- As a solo developer, I want compact Ordered Queue and Compozy PRD Run progress so that I can see how much work remains.
- As a solo developer, I want fast navigation and filtering so that I can inspect the relevant task or status without losing active-run context.
- As a solo developer, I want one-step access to the Web Dashboard or relevant local surfaces so that I can continue deeper inspection when the terminal view is not enough.
- As a solo developer, I want the Terminal Console to avoid task lifecycle mutation in MVP so that I can trust it as a safe default surface.

### Secondary Persona: Power User Supervising Several Local Tasks

- As a power user, I want dense but readable status summaries so that I can monitor multiple running or retrying items.
- As a power user, I want the Terminal Console to show state using existing Symphony language so that it matches the Web Dashboard and documentation.
- As a power user, I want clear boundaries for unavailable lifecycle actions so that I know which actions remain outside the MVP.

## Core Features

### F1. Active Work Home View

The default view shows active orchestration status at a glance. It prioritizes running work, retrying work, attention conditions, next queued work, token totals, and last state update context. This is the MVP’s most important feature because the primary success gate is understanding active state in under 15 seconds.

### F2. Readiness and Attention Visibility

The Terminal Console shows **Readiness Gaps**, remediation text, and task attention conditions without preventing the Terminal Console from opening. Users can distinguish dispatch-blocking readiness problems from retrying work that Symphony can still handle.

### F3. Ordered Queue and Compozy PRD Run Progress

When an **Ordered Queue** exists, users can see entry progress, skipped entries, completed entries, running entries, retrying entries, and next work. When the tracker is a Compozy-backed Local Issue Tracker, users can see **Compozy PRD Run** progress including current step and completed, failed, skipped, and total step counts.

### F4. Task Detail Inspection

Users can inspect task-level information that helps explain active orchestration: issue identifier, title, current state, stage states, running or retrying status, Goal Usage when available, context status when available, and current error summaries. Task detail inspection supports understanding and triage, not lifecycle mutation.

### F5. Safe Local Aids

The MVP includes safe local aids only. Supported aids may include refresh, navigation, filtering, opening the Web Dashboard, and opening relevant local surfaces. These aids improve flow without changing task lifecycle state.

### F6. Keyboard-First Navigation

Users can reach primary panels and safe local aids quickly from the default view. The UI should make shortcuts visible, keep focus behavior predictable, and avoid hiding critical state behind deep navigation.

### F7. Consistent Symphony Language

The Terminal Console uses established Personal Symphony language: Workspace Repository, Runtime Home, Runtime Contract, Runtime State, Terminal Console, Web Dashboard, Live Dashboard Connection, Readiness Gap, Ordered Queue, Compozy PRD Run, Agent Worktree, and Task Branch. The user-facing product should not introduce conflicting terms such as a separate TUI product name.

### F8. Web Dashboard Fallback

The Terminal Console makes it easy to open the Web Dashboard for deeper inspection. MVP success does not require full Web Dashboard parity.

## User Experience

### First Run Experience

1. The user runs `symphony` from a Workspace Repository.
2. The richer Terminal Console opens as the default mode.
3. The home view immediately shows whether Symphony is ready, actively running, retrying, blocked by Readiness Gaps, or idle.
4. If setup is incomplete, the user sees each Readiness Gap with remediation guidance.
5. If work is active, the user sees running and retrying counts, current tasks, next work, and relevant progress summaries.

### Active Monitoring Flow

1. The user keeps the Terminal Console open while Symphony orchestrates work.
2. The user watches active work status, Ordered Queue progress, Compozy PRD Run progress, and attention signals.
3. The user filters or navigates to a task when a summary needs explanation.
4. The user refreshes or opens a related local surface if deeper context is needed.
5. The user opens the Web Dashboard only when browser-level inspection is more useful.

### Attention Flow

1. The Terminal Console shows an attention condition or Readiness Gap.
2. The user reads the requirement and remediation text in the terminal.
3. The user uses safe local aids to inspect related context.
4. The user resolves the issue outside the MVP Terminal Console if resolution requires task lifecycle mutation or broader orchestration action.

### UX Requirements

- The default home view must answer “what is happening now” without requiring navigation.
- Running, retrying, attention, readiness, and idle states must be visually distinct.
- Critical remediation text must remain readable in narrow terminal widths.
- Keyboard shortcuts must be discoverable from the Terminal Console.
- The Terminal Console must avoid overwhelming users with full logs by default.
- The Terminal Console must preserve accessibility basics: readable contrast, no reliance on color alone, and useful plain-text labels.

## High-Level Technical Constraints

- The Terminal Console must use existing **Runtime State** semantics as the product source of truth for visible orchestration state.
- The MVP must preserve the existing meaning of the **Live Dashboard Connection** as a state stream rather than a command channel.
- The MVP must not change Runtime Contract defaults, tracker behavior, Task Branch cleanup, auto-merge defaults, Stage Push behavior, Batch Pull Request behavior, or package behavior.
- The MVP must not expose secret values such as `GITHUB_TOKEN` or `GH_TOKEN`.
- The MVP must treat issue titles, branch names, task text, and agent output as untrusted display content.
- The Terminal Console should remain useful when Readiness Gaps prevent dispatch.

## Non-Goals (Out of Scope)

- Task lifecycle mutation from the MVP Terminal Console.
- Retrying tasks, pausing dispatch, resuming dispatch, changing tracker status, merging Task Branches, pushing Task Branches, opening pull requests, or changing cleanup behavior from the MVP Terminal Console.
- Full Web Dashboard replacement or visual parity.
- New Runtime Contract defaults or Bootstrap behavior changes.
- Tracker model replacement.
- Live Dashboard Connection command transport.
- Custom layout systems, plugin support, user themes, or broad personalization.
- Mobile, remote, or multi-user collaboration workflows.
- Changes to npm package files, launcher behavior, or packaged-binary behavior.

## Phased Rollout Plan

### MVP (Phase 1)

- Default rich Terminal Console for normal `symphony` runs.
- Active Work Home View.
- Readiness and Attention Visibility.
- Ordered Queue and Compozy PRD Run Progress.
- Task Detail Inspection for active, retrying, and attention-needed work.
- Safe Local Aids limited to read, refresh, navigation, filtering, and opening related surfaces.
- Web Dashboard fallback path.

Success criteria to proceed:

- Users can identify active orchestration state in under 15 seconds during usability checks.
- MVP safe aids do not create task lifecycle mutation paths.
- Users can distinguish Readiness Gaps, retrying work, attention conditions, and idle state.
- The default Terminal Console remains useful when dispatch is blocked.

### Phase 2

- Improve task detail depth based on MVP feedback.
- Add clearer history or recent-change summaries if users still need logs for basic understanding.
- Consider additional safe aids that preserve the no lifecycle mutation boundary.
- Tighten Web Dashboard handoff based on actual fallback reasons.

Success criteria to proceed:

- Web Dashboard fallback during active monitoring drops by at least 60% for users who adopt the rich Terminal Console.
- Common safe-aid actions complete within five keystrokes from the home view.
- Users report that the Terminal Console is the primary active-run monitoring surface.

### Phase 3

- Re-evaluate broader command-center capabilities after the MVP proves comprehension and safe-aid value.
- Consider task lifecycle actions only with explicit product approval, clear safety expectations, and preserved orchestration semantics.
- Explore optional customization only after core active-run monitoring is stable.

Long-term success criteria:

- The Terminal Console becomes the trusted default surface for local active orchestration.
- The Web Dashboard remains a complementary deeper inspection surface rather than a required active-run monitor.
- Broader command capabilities, if added, preserve user trust and do not create a parallel orchestration model.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Active state comprehension time | < 15 seconds | User can identify running, retrying, attention, readiness, and next work from the home view. |
| Web Dashboard fallback reduction | >= 60% | Compare active monitoring sessions before and after MVP adoption. |
| Safe-aid action speed | <= 5 keystrokes | Count keystrokes for refresh, filtering, navigation, and opening related surfaces from the home view. |
| Default Terminal Console adoption | >= 50% of local active runs | Count runs where users keep the rich Terminal Console open for active monitoring. |
| Attention-state clarity | >= 90% successful classification | User can correctly classify Readiness Gap, retrying work, Task Needs Attention, and idle states in evaluation scenarios. |
| MVP boundary integrity | 0 task lifecycle mutations from MVP controls | Product review confirms that MVP controls do not retry, pause, resume, merge, push, or update task status. |

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Users expect a command center to mutate task state | Frustration or confusion when MVP excludes lifecycle actions | Use clear labels, visible non-goals, and strong framing that MVP is read-first with safe local aids. |
| Default rich console disrupts users who prefer simple output | Reduced adoption among existing users | Keep the home view fast, predictable, and focused; preserve a clear fallback if needed. |
| The Terminal Console duplicates the Web Dashboard without enough unique value | Weak differentiation and wasted effort | Optimize for terminal-native active-run speed, keyboard navigation, and local workflow continuity. |
| Users still open the Web Dashboard for basic active-run understanding | MVP fails the core value proposition | Make the home view answer active state first and use fallback reasons to improve Phase 2. |
| Safety concerns reduce trust in the default surface | Users avoid the Terminal Console during important runs | Keep no task lifecycle mutation as an MVP boundary and show state changes transparently. |
| Market expectations for rich dashboards outpace the conservative MVP | Perceived feature gap versus other agent dashboards | Position MVP as a trustworthy local operations surface and reserve broader controls for validated later phases. |

## Architecture Decision Records

- [ADR-001: Scope Mosaic Terminal Console as a Runtime State command center](adrs/adr-001.md) — V1 is read-first over Runtime State with only narrow safe controls through explicit command boundaries.
- [ADR-002: Make the read-first Terminal Console with safe local aids the MVP approach](adrs/adr-002.md) — The richer Terminal Console is the default experience for `symphony` runs, with no task lifecycle mutation in MVP.

## Open Questions

- What fallback should exist for users who need the prior static Terminal Console experience.
- Which local surfaces should safe local aids open in MVP.
- Which terminal sizes and accessibility expectations define launch readiness.
- What wording should explain unavailable task lifecycle actions without implying broken functionality.
- What usage signal should count as keeping the rich Terminal Console open for active monitoring.
