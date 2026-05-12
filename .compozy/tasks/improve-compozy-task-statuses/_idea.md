# Idea: Improve Compozy Task Lifecycle Statuses

## Overview

Compozy-backed Symphony workflows need trustworthy lifecycle visibility. Today, operators can see Compozy Task Step progress, but they cannot reliably tell whether the overall Compozy PRD Run is being planned, executed, reviewed, blocked, failed, or ready for a Batch Pull Request. The result is operational ambiguity: users inspect logs, branches, and task files to understand what Symphony should already report.

This idea creates a run-level lifecycle model for Compozy PRD Runs. It keeps Compozy Task Step statuses simple and execution-focused while adding durable lifecycle states such as `in_planning` and `in_review` at the Compozy PRD Run boundary. V1 is a strategic bet: it should fix the current workflow reliability gap, make status transitions auditable, and preserve the product promise that one Compozy PRD Run produces one aggregate Batch Pull Request after successful completion.

## Problem

Operators running `tracker.kind = "compozy_tasks"` need to know what is happening inside a Compozy PRD Run without reading logs or manually checking task files. Current Compozy Task Step statuses show local execution facts: `pending`, `in_progress`, `completed`, `failed`, and `skipped`. They do not clearly identify planner-stage work, reviewer-stage work, blocked transitions, or pull-request readiness.

The current Compozy Local Issue Tracker also does not persist stage-level status transitions at the Compozy PRD Run boundary. A Stage Agent can move through planner, engineer, or reviewer behavior, but the visible Compozy lifecycle can still look like generic task progress. This weakens Runtime State, Terminal Console, and Web Dashboard trust.

The pull-request behavior is part of the same pain. The operator expectation is not “open a PR for every task step.” The expectation is: when all work in one Compozy PRD Run is successfully complete and safely integrated, Symphony should open or reuse one aggregate Batch Pull Request according to the existing Pull Request Policy.

### Market Data

Workflow automation is a large and growing category. Search results surfaced estimates such as USD 18.67B in 2024 growing to USD 45.49B by 2032, and USD 23.77B in 2025 growing to USD 40.77B by 2031. Competing workflow tools normalize explicit state: Jira and Linear support workflow statuses, GitHub Projects automates status around pull-request readiness, Temporal exposes workflow execution states, and AI observability tools such as LangSmith, Langfuse, and Phoenix focus on agent/workflow tracing.

AI-assisted development adoption is high, but trust remains a differentiator. GitHub survey coverage reports that more than 97% of respondents had used AI coding tools at work. DORA 2024 reports productivity and satisfaction gains from AI adoption while warning about delivery stability and throughput trade-offs. Symphony can differentiate by making agentic workflow state reliable, local, and tied to deterministic Git and pull-request semantics.

### Summary / Differentiator

The differentiator is not adding more labels. The differentiator is a reliable local orchestration lifecycle: one Compozy PRD Run, multiple internal Compozy Task Steps, clear Stage Agent phase visibility, and one aggregate Batch Pull Request only when the run is truly ready.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Run-level lifecycle status | Critical | Persist and expose Compozy PRD Run lifecycle states such as planning, execution, review, blocked/attention, completed, failed, and skipped without converting Compozy Task Steps into separate issues. |
| F2 | Stage Agent phase visibility | Critical | Show planner activity as `in_planning` and reviewer activity as `in_review` at the run boundary so operators know which Stage Agent owns the current work. |
| F3 | Aggregate Batch Pull Request readiness gate | Critical | Ensure batch-mode PR creation stays aggregate-only and becomes eligible only after successful Compozy PRD Run completion plus safe final Task Branch Integration. |
| F4 | Transition diagnostics | High | Surface missing, invalid, blocked, or skipped lifecycle transitions with enough explanation for operators to answer “where did this run stop?” within one poll cycle. |
| F5 | Runtime State and dashboard alignment | High | Make Runtime State, Terminal Console, and Web Dashboard show run lifecycle and task-step progress as distinct but connected signals. |
| F6 | Backward-compatible task-step progress | High | Preserve existing task-step statuses and counts so current Compozy PRD Run progress, retry, failed, and skipped semantics remain stable. |
| F7 | Documentation and examples | Medium | Document the lifecycle model, PR readiness rules, and V1 boundaries using the established Product Repository glossary. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Compozy-backed Local Issue Tracker | Replace no-op run status behavior with durable Compozy PRD Run lifecycle updates. |
| Compozy Task Step frontmatter | Keep current execution statuses and retry metadata as task-step progress, not Stage Agent lifecycle. |
| Stage Agents | Map planner and reviewer activity into run-level lifecycle states without changing Stage Agent routing semantics. |
| Runtime State | Expose lifecycle phase, current step, counts, and diagnostics as compatible snapshot fields. |
| Batch Pull Request | Preserve one aggregate PR in batch mode and gate it on successful run completion plus safe final integration. |
| Web Dashboard / Terminal Console | Render lifecycle state and task progress separately so operators do not confuse review readiness with step completion. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Valid lifecycle coverage | 100% of Compozy PRD Runs expose one valid run-level lifecycle state during active orchestration | Backend tests and Runtime State snapshots for planner, engineer, reviewer, terminal, and attention cases |
| Aggregate PR correctness | 0 per-step PRs and exactly 1 eligible Batch Pull Request per successfully completed Compozy PRD Run when PR automation is enabled | Pull-request handoff tests and Runtime State handoff records |
| Invalid transition visibility | 100% of invalid, missing, or blocked lifecycle transitions produce diagnostics within 1 poll cycle | Integration tests that inject skipped/failed/blocked transition scenarios |
| Operator time-to-answer | Under 2 minutes to answer “where is this run stuck?” in self-dogfooding workflows | Manual dogfood checks or scripted QA scenarios using Runtime State and dashboard output |
| Backward compatibility | 0 regressions in existing Compozy Task Step counts and terminal state tests | Existing backend test suite plus new Compozy lifecycle regression tests |
| PR readiness clarity | 100% of failed/skipped/attention Compozy PRD Runs show “not PR-ready” state or diagnostics | Tests for failed, skipped, merge-attention, and PR handoff failure paths |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Represent lifecycle at the Compozy PRD Run level. Keep Compozy Task Step statuses as internal execution facts. Gate one aggregate Batch Pull Request on successful run completion plus safe final Task Branch Integration.
- **Key trade-offs:**
  - A small V1 ships faster, but lifecycle labels must still have explicit transition and failure semantics.
  - “All steps are terminal” is not the same as “PR-ready”; failed or skipped terminal states must block PR readiness.
  - Adding a run-level lifecycle layer improves clarity but requires UI/API labeling so users do not confuse lifecycle state with task-step progress.
- **Risks identified:**
  - Decorative statuses could create false confidence. Mitigation: define allowed transitions, failure reasons, and attention states in the PRD/TechSpec.
  - PR readiness could be misread. Mitigation: state that successful run completion and safe final integration are required.
  - Scope could expand into a configurable workflow platform. Mitigation: defer custom lifecycle schemas, analytics, and repair automation to V2+.
- **Stretch goal (V2+):** A Compozy Run Control Plane with lifecycle history, transition timeline, bottleneck analytics, and guided repair actions.

## Out of Scope (V1)

- **Per-step Symphony issues** — Compozy Task Steps remain internal to one Compozy PRD Run to preserve Agent Worktree and Task Branch semantics.
- **Per-step pull requests** — V1 preserves aggregate Batch Pull Request behavior and avoids task-level PR noise.
- **Configurable lifecycle schemas** — Custom status workflows are deferred until the built-in lifecycle proves reliable.
- **Lifecycle analytics and bottleneck dashboards** — Useful later, but V1 focuses on correctness and operator trust.
- **Automatic repair actions** — V1 may explain invalid or blocked states, but it should not introduce new mutation controls for repair.
- **Changing Pull Request Policy defaults** — Automatic PR creation remains disabled by default and follows existing policy semantics.
- **Protected Trunk Branch auto-merge changes** — V1 does not change protected branch safety rules.

## Architecture Decision Records

- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Lifecycle status belongs to the Compozy PRD Run, while Compozy Task Step statuses remain execution progress; aggregate Batch Pull Requests require successful run completion plus safe final integration.

## Open Questions

- What exact lifecycle vocabulary should V1 expose beyond `in_planning` and `in_review`?
- Should failed and skipped Compozy PRD Runs use separate run-level terminal states or share one attention-oriented state with detailed diagnostics?
- Where should lifecycle transition history be visible first: Runtime State only, Terminal Console, Web Dashboard, or all three in V1?
- What operator-facing text should explain “all steps terminal but not PR-ready”?
- Should PR handoff failures remain solely pull-request Runtime State, or should they also update Compozy PRD Run lifecycle diagnostics?
