# Codebase Improvement Scan PRD

## Overview

Create a maintainer-facing complete-sweep backlog for the Personal Symphony Product Repository. The PRD defines a product workflow for turning codebase health findings into prioritized, evidence-backed work that maintainers can confidently plan, review, and pass into TechSpec/task generation.

The MVP optimizes for backlog quality. It must produce at least 15 actionable findings across concrete defects, maintainability risks, and product-polish gaps, without becoming a broad cleanup branch.

## Goals

- Produce 15+ evidence-backed findings that are actionable for maintainers.
- Ensure every finding includes category, affected product boundary, priority, acceptance target, verification expectation, and runtime-semantics impact.
- Cover at least defects, maintainability, and product polish.
- Preserve Runtime Contract and Compozy terminology from `CONTEXT.md`.
- Create a PRD foundation suitable for downstream TechSpec and Compozy Task Step generation.

## User Stories

- As a maintainer, I want a prioritized codebase improvement backlog so that I can plan reviewable work instead of sorting through raw scanner output.
- As a maintainer, I want each finding to include evidence and acceptance expectations so that I can judge scope before creating tasks.
- As a maintainer, I want runtime-semantics impact called out so that product behavior changes do not hide inside cleanup work.
- As a future agent consuming task context, I want findings grouped by product boundary so that I can avoid unrelated edits.
- As a solo operator, I want product trust gaps identified so that dashboard, Terminal Console, and documentation signals remain reliable.

## Core Features

| Feature | Priority | Requirement |
| --- | --- | --- |
| Evidence-backed inventory | Critical | The backlog must include 15+ findings with repo-local evidence and maintainer-facing rationale. |
| Risk taxonomy | Critical | Each finding must be classified as defect, maintainability, polish, security/blast-radius, docs hygiene, Runtime Contract drift, or agent-readiness risk. |
| Prioritization model | Critical | Findings must be ranked by maintainer pain, user-visible trust impact, hotspot/churn signal, runtime risk, and fix confidence. |
| Boundary labeling | Critical | Each finding must name the affected product boundary, such as Runtime Contract, Runtime State, Terminal Console, Web Dashboard, Compozy PRD Run, docs, CLI, or maintainer workflow. |
| Acceptance evidence | Critical | Each finding must include an observable acceptance target and verification expectation. |
| Runtime-semantics flag | High | Each finding must state whether it changes Runtime Contract, Runtime Home, Runtime State, Task Branch, Bootstrap, or other runtime behavior. |
| Guardrail candidates | High | The backlog must identify recurring drift that could be prevented by future validation or documentation checks. |
| Follow-up packaging | Medium | Large structural risks must be captured as deferred follow-up packages, not bundled into MVP implementation. |

## User Experience

A maintainer opens the PRD and sees a clear complete-sweep objective, then receives a structured backlog rather than a flat list of issues. Each finding is understandable without re-running the scan: it explains the problem, cites local evidence, states why the issue matters, and names what would count as resolution.

The maintainer can sort findings into downstream TechSpec and task-generation work. High-confidence trust fixes can become early tasks, while large structural items remain explicitly deferred until they have clearer characterization and acceptance boundaries.

## High-Level Technical Constraints

- The PRD must preserve Personal Symphony glossary terms such as Product Repository, Runtime Contract, Runtime State, Compozy PRD Run, and Compozy Task Step.
- V1 must not authorize changing Runtime Contract defaults, Task Branch cleanup behavior, auto-merge defaults, npm package behavior, or backend test-suite structure without explicit approval.
- V1 must treat generated artifacts, secrets, and local environment values as non-commit surfaces.
- V1 must keep the Web Dashboard and Terminal Console framed as Runtime State surfaces, not command channels.

## Non-Goals

- Implementing every finding during PRD creation.
- Creating one large cleanup branch.
- Splitting the backend test suite.
- Decomposing `orchestrator.ml` as part of the MVP.
- Replacing the HTTP/WebSocket server.
- Changing Runtime Contract defaults or Task Branch behavior.
- Defining implementation architecture, parser design, or test structure.

## Phased Rollout Plan

### MVP (Phase 1)

- Produce the 15+ finding Evidence-First Backlog.
- Include complete metadata for every finding.
- Identify at least 3 guardrail candidates.
- Identify at least 4 deferred structural follow-ups.

### Phase 2

- Convert the highest-priority findings into TechSpec-ready scopes.
- Separate fast trust fixes from deeper boundary-hardening work.
- Resolve open priority thresholds after reviewing the MVP backlog.

### Phase 3

- Consider a recurring Codebase Health Console or repeatable scan workflow.
- Track whether prior findings remain fixed and whether new drift appears.

## Success Metrics

| Metric | Target |
| --- | --- |
| Actionable findings | >= 15 |
| Evidence completeness | 100% of findings |
| Boundary labeling | 100% of findings |
| Runtime-semantics impact stated | 100% of findings |
| Coverage breadth | >= 3 categories |
| Guardrail candidates | >= 3 |
| Deferred structural follow-ups | >= 4 |

## Risks and Mitigations

- **Risk:** The backlog becomes a generic issue dump.
  **Mitigation:** Require priority, boundary, evidence, acceptance target, and verification expectation for every finding.
- **Risk:** The PRD drifts into implementation design.
  **Mitigation:** Keep implementation choices for TechSpec and downstream tasks.
- **Risk:** Maintainers treat V1 as permission for one large refactor.
  **Mitigation:** State that V1 is discovery and prioritization only.
- **Risk:** Product polish crowds out runtime correctness.
  **Mitigation:** Require coverage across defects, maintainability, and polish, with runtime-semantics flags.

## Architecture Decision Records

- [ADR-001: Use a Scoped Verified Backlog for Codebase Improvement](adrs/adr-001.md) — Keep complete-sweep discovery while requiring independently reviewable findings.
- [ADR-002: Select Evidence-First Backlog PRD Approach](adrs/adr-002.md) — Optimize the PRD around backlog quality and 15+ evidence-backed findings.

## Open Questions

- What priority threshold should separate MVP findings from V2 findings?
- Should the first downstream implementation wave favor fast trust fixes or high-risk runtime boundaries?
- Should future task generation create one Compozy Task Step per finding or group related findings by product boundary?
- Should ADR numbering drift be fixed immediately or guarded against first?
