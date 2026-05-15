# Cursor CLI Harness Integration PRD

## Overview

Cursor CLI Harness Integration makes Symphony a clearer provider-choice product for operators who already run agent
work through Cursor. It adds Cursor as a stable first-class `Agent Harness` inside the existing `Runtime Contract`, so
a `Workspace Repository` can route any `Logical Agent` role to Cursor without abandoning Symphony's orchestration
model, `Agent Worktree` isolation, `Task Branch` flow, or Runtime State visibility.

The value is practical rather than aspirational. Operators should be able to complete normal task flows on
Cursor-selected roles using the same product concepts they already understand for other Harnesses. The product outcome
is stronger provider neutrality: Cursor becomes a supported peer to existing Harnesses, while Symphony preserves one
consistent user model for selection, readiness, observability, and rollout.

## Goals

- Make Cursor a stable first-class `Agent Harness` option in Symphony's `Runtime Contract`.
- Let operators assign Cursor to any `Logical Agent` role, not only `engineer`.
- Enable operators who already use Cursor CLI to complete normal Symphony task flows without switching tools.
- Preserve clear product boundaries between `harnesses`, `agents`, and `stageAgents`.
- Strengthen Symphony's repeatable pattern for future Harness additions through a small onboarding or certification
  checklist.

Target outcomes:
- Cursor-selected roles can complete normal task flows reliably enough for routine use.
- Operators understand how to configure Cursor with low ambiguity.
- Symphony's provider-choice story becomes stronger without fragmenting the product model.

## User Stories

**Workspace Repository operator**

- As a `Workspace Repository` operator, I want to select Cursor for any `Logical Agent` role so that Symphony fits the
  agent tool I already use.
- As a `Workspace Repository` operator, I want Cursor to look like a real supported Harness, not a hidden
  compatibility path, so that I can adopt it confidently.
- As a `Workspace Repository` operator, I want clear readiness and setup guidance so that I can get to a successful
  run quickly.

**Task supervisor**

- As a task supervisor, I want Runtime State to show when Cursor is the selected Harness so that I can understand
  which provider is running a task.
- As a task supervisor, I want normal task progress and logs to remain visible when work runs on Cursor so that
  provider choice does not reduce operational trust.

**Product maintainer**

- As a product maintainer, I want Cursor onboarding to follow the same Harness model as existing providers so that
  future Harness additions become easier and less ad hoc.
- As a product maintainer, I want the PRD to define clear non-goals so that provider support does not quietly expand
  into unrelated product commitments.

## Core Features

### F1: Stable First-Class Cursor Harness

Symphony must present Cursor as a supported `Agent Harness` inside `harnesses`, with the same product-level status as
other supported Harnesses.

User capability:
- Operators can define a Cursor Harness in Runtime Settings.
- Cursor appears as a valid execution choice rather than an advanced workaround.
- Product docs teach Cursor through the same Harness model already used elsewhere.

### F2: Any Logical Agent Can Select Cursor

Cursor support must be available to any `Logical Agent` role.

User capability:
- Operators can assign Cursor to `planner`, `engineer`, `reviewer`, or other logical roles they define.
- Symphony does not frame Cursor as an `engineer`-only product path.
- Provider choice remains role-based and explicit.

### F3: Low-Ambiguity Setup Experience

The product must make it clear how an operator gets from Runtime Settings to a successful Cursor-selected run.

User capability:
- Operators know where Cursor belongs in the `Runtime Contract`.
- Operators receive clear readiness or setup feedback when Cursor is selected.
- Operators can reach a first successful run with low configuration ambiguity.

### F4: Normal Task-Flow Support

Cursor-selected roles must be able to participate in the normal Symphony workflow.

User capability:
- Operators can use Cursor-selected roles in routine task execution.
- Provider choice does not break the expected task-flow experience.
- Cursor support is measured by successful use in ordinary work, not by a narrow demo path.

### F5: Provider Visibility In Runtime State

Cursor must be observable as a selected Harness in operator-facing runtime views.

User capability:
- Operators can tell when a task is running on Cursor.
- Provider identity remains visible alongside normal task state.
- Provider choice does not reduce day-to-day operational clarity.

### F6: Cursor Examples In Bootstrap And Docs

Runtime Contract examples must show Cursor as part of the supported Harness story.

User capability:
- Operators can copy or adapt a Cursor example from product-owned documentation or seeded defaults.
- Cursor configuration is discoverable without reading backend source.
- Docs reinforce the split between `harnesses`, `agents`, and `stageAgents`.

### F7: Harness Onboarding Checklist

The Cursor effort should leave behind a lightweight reusable checklist for future Harness additions.

User capability:
- Product maintainers can evaluate future Harness candidates against a repeatable set of product expectations.
- Symphony reduces one-off provider decisions over time.
- Cursor becomes a compounding product investment, not just a single-provider feature.

## User Experience

Primary journey:
1. An operator opens `.symphony/settings.json` or related Runtime Contract docs.
2. They see Cursor presented as a supported `Agent Harness` alongside the existing provider model.
3. They assign Cursor to one or more `Logical Agent` roles.
4. Symphony guides them to readiness rather than leaving provider setup ambiguous.
5. They dispatch normal work and observe Cursor-selected execution through the same Runtime State surfaces they already
   use.
6. They continue using Symphony's existing orchestration flow without needing a separate mental model for Cursor.

Product experience principles:
- Provider choice should feel native, not bolted on.
- Role selection should remain simple and explicit.
- Setup friction should be low enough that current Cursor users can adopt quickly.
- Visibility should remain strong enough that operators trust mixed-Harness environments.
- Discoverability should come from the Runtime Contract and product docs, not from tribal knowledge.

Accessibility and clarity considerations:
- Setup and readiness messages should be understandable by operators who know Symphony but do not know backend
  internals.
- Product wording should distinguish support scope from future ambitions.
- Provider-specific examples should reinforce the same information architecture rather than creating a separate
  Cursor-only UX.

## High-Level Technical Constraints

- Cursor must fit the existing `Workspace Repository`-owned `Runtime Contract`.
- Product examples must preserve the separation between `harnesses`, `agents`, and `stageAgents`.
- Bootstrap must remain idempotent and must not overwrite user-edited runtime files.
- Product guidance must reference only secret environment variable names, never secret values.
- Provider support must preserve existing `Agent Worktree`, `Task Branch`, and Runtime State product semantics.
- Observability must remain available even when provider-specific structured activity is incomplete.

## Non-Goals (Out of Scope)

- Reframing Cursor as a hidden or experimental-only feature.
- Limiting Cursor support to only one `Logical Agent` role in the product story.
- Shipping Cursor background-agent or cloud-agent product behavior in this PRD.
- Creating a broad new provider-capability framework for permissions, autonomy, or enterprise controls.
- Promising complete semantic parity between Cursor and every existing Harness.
- Automatically rewriting user Runtime Contract files.
- Using this PRD to define implementation details, parser strategy, or backend architecture.

## Phased Rollout Plan

### MVP (Phase 1)

- Stable first-class Cursor Harness positioning in the Runtime Contract.
- Cursor available to any `Logical Agent`.
- Clear setup and readiness experience for Cursor-selected roles.
- Normal task-flow support for routine operator use.
- Runtime State provider visibility for Cursor.
- Cursor examples in docs or seeded settings.
- Initial Harness onboarding checklist for future providers.

Success criteria to proceed:
- Operators can complete normal task flows on Cursor-selected roles.
- Setup ambiguity is low enough that existing Cursor operators can adopt without deep source-code reading.
- Runtime State makes Cursor-selected execution understandable in daily use.

### Phase 2

- Improve discoverability and operator guidance for mixed-Harness environments.
- Strengthen the reusable Harness onboarding checklist with examples and validation guidance.
- Expand product documentation around role selection patterns and common provider-choice scenarios.

Success criteria to proceed:
- Operators can confidently mix Cursor with other Harnesses across different roles.
- Product maintainers can use the onboarding checklist to evaluate another Harness candidate with less ad hoc work.

### Phase 3

- Mature Symphony's broader provider-choice narrative using lessons from Cursor adoption.
- Evaluate whether additional provider-facing product surfaces are needed for richer mixed-Harness workflows.
- Extend the onboarding pattern into a more formal provider-support playbook if repeated Harness additions justify it.

Long-term success criteria:
- Symphony can add future Harnesses without reshaping the core product model.
- Provider choice becomes a durable product strength rather than a source of setup complexity.

## Success Metrics

- `>= 90%` of Cursor-selected task runs complete the normal dispatch-to-finish flow without setup or support failure in
  dogfood use.
- `<= 15 minutes` median time from opening Cursor setup docs to first successful Cursor-selected task flow for an
  operator who already has Cursor installed.
- `100%` of Cursor-selected running tasks show provider identity in Runtime State.
- `>= 2` real `Workspace Repositories` adopt Cursor as part of normal role selection within 30 days of release.
- `>= 80%` of surveyed or observed early adopters report that provider choice feels clear rather than ambiguous.

## Risks and Mitigations

- **Adoption risk:** Operators may not trust Cursor if support looks partial or ambiguous.
  - Mitigation: position Cursor as stable first-class support and keep the setup path explicit.

- **Expectation risk:** Stable support language may create stronger expectations than the first rollout can satisfy.
  - Mitigation: keep the supported scope narrow, define clear non-goals, and use phased rollout to control surface
    area.

- **Competitive risk:** If Symphony's provider-choice story feels weaker than other agent orchestration products,
  Cursor support may not change adoption.
  - Mitigation: focus the MVP on normal task-flow completion and operator clarity, not merely checkbox compatibility.

- **Dependency risk:** Product confidence depends partly on external provider behavior and documentation staying usable.
  - Mitigation: base the product promise on documented behaviors, preserve fallback visibility, and avoid
    overspecifying parity claims.

- **Scope creep risk:** Cursor support could quietly grow into unrelated autonomy or provider-platform work.
  - Mitigation: keep future-oriented items explicitly out of scope and use the onboarding checklist to discipline
    expansion.

## Architecture Decision Records

- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Accepts `kind: "cursor"` as a
  first-class `Agent Harness` while keeping scope bounded and reusable.
- [ADR-002: Stable First-Class Cursor Harness Product Posture](adrs/adr-002.md) — Commits the PRD to stable
  first-class support for Cursor across any `Logical Agent` role.

## Open Questions

- What default Cursor example should product docs emphasize first for operator setup clarity?
- How prominently should the Harness onboarding checklist appear in operator-facing docs versus maintainer-facing
  artifacts?
- What product language best distinguishes "stable support" from "full semantic parity" without weakening user
  confidence?
- Are there specific mixed-Harness role combinations that deserve first-class documentation examples in the initial
  release?
