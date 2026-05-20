# Built-In Agent Looper PRD

## Overview

Personal Symphony should add an evidence-first **Goal Loop** that lets a maintainer supervise agent work with higher trust and less manual continuation. A maintainer should be able to see what goal an agent is pursuing, why the loop continued, what evidence supports completion, and why the loop stopped.

V1 focuses on trust and visibility. A loop may stop as **Goal met** only when deterministic evidence supports that outcome. Ambiguous, blocked, or unverifiable work stops as **Needs attention** with clear guidance. Budget exhaustion stops predictably and visibly.

## Goals

- Let maintainers trust loop outcomes across multiple **Stage Agents** in a **Workspace Repository**.
- Make **Goal met** an evidence-backed stop outcome, not an agent confidence claim.
- Reduce manual "continue working" nudges while preserving operator control.
- Expose loop goal, status, stop reason, latest evidence, and next action through existing operator surfaces.
- Preserve existing lifecycle boundaries for status transitions, Stage Commit, Stage Push, merge, PR, and delivery behavior.

## User Stories

- As a maintainer, I want to see the active goal for each looped task so that I know what the agent is trying to complete.
- As a maintainer, I want **Goal met** to require visible deterministic evidence so that I can trust completed loop outcomes.
- As a maintainer, I want blocked or ambiguous loops to stop as **Needs attention** so that I can intervene with the missing decision or context.
- As a maintainer, I want budget exhaustion to be explicit so that long-running loops do not silently burn time or usage.
- As a maintainer, I want the same loop status in Runtime State, Terminal Console, and Web Dashboard so that I do not reconcile conflicting views.

## Core Features

| Feature | Priority | Requirement |
|---|---|---|
| Goal Loop status | Critical | Show the current loop goal, state, attempt count, stop budget, latest evidence, and next action. |
| Evidence-backed completion | Critical | Allow **Goal met** only when deterministic evidence is present for the claimed completion. |
| Attention stop outcome | Critical | Stop ambiguous, blocked, or missing-evidence work as **Needs attention** with a concise reason. |
| Budget stop outcome | Critical | Stop predictably when configured time, turn, or usage limits are exhausted. |
| Shared operator visibility | High | Present the same authoritative loop status through existing operator surfaces. |
| Lifecycle boundary protection | High | Keep delivery behavior under existing Symphony rules; the loop does not gain commit, push, merge, PR, or status authority. |
| Future recipe readiness | Medium | Preserve product language that can later support named reusable loop recipes without expanding V1 scope. |

## User Experience

A maintainer starts or observes a task using a loop-capable stage. The operator surface shows the active goal and current loop state. During execution, the maintainer can see whether the loop is still working, what changed recently, and what evidence is available.

When the loop stops, the outcome is one of three primary user-facing states:

- **Goal met**: deterministic evidence supports the completion claim.
- **Needs attention**: the loop is blocked, ambiguous, or missing required evidence.
- **Budget exhausted**: time, turn, or usage limits stopped the loop.

The maintainer should never need to infer whether "done" means verified, guessed, or merely claimed.

## High-Level Technical Constraints

- Must preserve established Symphony domain language and update `CONTEXT.md` when final terms are accepted.
- Must remain Workspace Repository scoped.
- Must not expose secrets, token values, local environment contents, or full hidden prompts in operator-facing evidence.
- Must not change existing Stage Commit, Stage Push, merge, PR, auto-merge, or status-transition behavior in V1.
- Must coexist with current **Stage Goal Handoff**, **Harness Loop**, **Goal Usage**, **Runtime State**, **Terminal Console**, and **Web Dashboard** semantics.

## Non-Goals (Out of Scope)

- Full autonomous delivery authority.
- Independent completion review after agent exit.
- Multi-goal orchestration.
- Recipe marketplace or broad loop configuration UI.
- Provider-specific global lifecycle hooks.
- Qualitative-only completion claims counted as **Goal met** in V1.

## Phased Rollout Plan

### MVP (Phase 1)

- Define evidence-first Goal Loop product behavior.
- Show active goal, loop state, stop outcome, latest evidence, budget status, and next action.
- Support **Goal met**, **Needs attention**, and **Budget exhausted** as clear stop outcomes.
- Preserve all existing delivery lifecycle rules.

### Phase 2

- Add reusable loop recipes once V1 proves maintainers trust the loop state.
- Improve dashboard and console summaries for historical loop outcomes.
- Add richer attention categorization for missing evidence, blocked dependency, and budget exhaustion.

### Phase 3

- Explore cross-harness loop behavior and broader workflow reuse.
- Consider independent completion review only through a separate ADR and PRD.
- Add aggregate loop reliability and cost trend reporting.

## Success Metrics

| Metric | Target |
|---|---:|
| Stop explanation coverage | >= 90% of stopped loops include outcome, reason, latest evidence, and next action. |
| Evidence-backed success | 100% of **Goal met** outcomes include deterministic evidence. |
| Manual continuation reduction | >= 50% fewer maintainer continuation nudges on loop-enabled tasks. |
| Attention clarity | >= 80% of **Needs attention** outcomes identify the missing evidence, blocker, or decision. |
| Lifecycle boundary violations | 0 loop-driven commit, push, merge, PR, or status changes outside existing rules. |

## Risks and Mitigations

- **False completion**: Require deterministic evidence for **Goal met**.
- **Operator fatigue from attention outcomes**: Make attention reasons concise and actionable.
- **Reduced automation feel**: Position V1 as trust-first; completion without evidence is not a success.
- **Scope creep into platform features**: Defer recipes, multi-goal orchestration, and completion review.
- **Confusing overlap with Stage Goal Handoff**: Define Goal Loop as the user-facing loop outcome model, while Stage Goal Handoff remains launch-time behavior.

## Architecture Decision Records

- [ADR-001: Goal Loop Runtime Scope](adrs/adr-001.md) — Accepts a narrow Goal Loop V1 with platform-shaped Runtime contracts.
- [ADR-002: Evidence-First Goal Loop Approach](adrs/adr-002.md) — Selects evidence-backed completion as the PRD approach.

## Open Questions

- What final domain term should be accepted in `CONTEXT.md`: **Goal Loop**, **Agent Loop Run**, or another term?
- Should V1 expose loop history beyond the latest stop outcome?
- Which user-facing evidence categories should count as deterministic for the first release?
- Should budget settings be described as per stage, per agent role, or per loop run in the next TechSpec?
