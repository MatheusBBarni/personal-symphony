---
status: completed
title: "Document Compozy lifecycle semantics"
type: docs
complexity: low
dependencies:
  - task_06
  - task_07
---

# Task 08: Document Compozy lifecycle semantics

## Overview
Update user-facing and architecture documentation so operators understand Compozy PRD Run lifecycle, Compozy Task Step progress, PR readiness, and aggregate Batch Pull Request behavior. Documentation must use the project glossary language consistently and stay secret-free.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST explain the difference between Compozy PRD Run lifecycle and Compozy Task Step progress.
- R2 MUST document `in_planning`, `in_execution`, `in_review`, completed, failed, skipped, blocked, not-PR-ready, and pull-request handoff meanings.
- R3 MUST explain why failed, skipped, blocked, or terminal task-step progress does not imply Batch Pull Request readiness.
- R4 MUST document aggregate Batch Pull Request behavior for Compozy PRD Runs and explicitly avoid per-step pull requests.
- R5 MUST update `CONTEXT.md` if new or changed domain language is introduced.
- R6 MUST add or update a repository ADR under `docs/adr/` for runtime semantic changes.
- R7 MUST NOT include secrets, token values, webhook URLs, or local `.env` contents.
</requirements>

## Subtasks
- [x] 8.1 Update README operator documentation for Compozy lifecycle and readiness.
- [x] 8.2 Update `CONTEXT.md` glossary or relationships for any new lifecycle language.
- [x] 8.3 Add or update a repository ADR under `docs/adr/` for persisted run-level lifecycle semantics.
- [x] 8.4 Document disabled, not-ready, ready, and handoff readiness outcomes.
- [x] 8.5 Verify docs use glossary terms consistently and contain no secret values.

## Implementation Details
Follow PRD "Documentation and examples" and TechSpec "Docs and glossary". The feature-level ADRs in `.compozy/tasks/improve-compozy-task-statuses/adrs/` are planning context; repository-level runtime semantics also need `docs/adr/` coverage per project rules.

### Relevant Files
- `README.md` — User-facing Compozy-backed Local Issue Tracker and operator workflow documentation.
- `CONTEXT.md` — Domain glossary and relationships for Compozy PRD Run, Compozy Task Step, Runtime State, Terminal Console, Web Dashboard, Pull Request Policy, and Batch Pull Request.
- `docs/adr/` — Repository architecture decisions for runtime semantics.
- `.compozy/tasks/improve-compozy-task-statuses/_prd.md` — Product requirements to map into documentation.
- `.compozy/tasks/improve-compozy-task-statuses/_techspec.md` — Technical decisions to reference without duplicating implementation details.

### Dependent Files
- `apps/backend/bin/main.ml` — Final Terminal Console labels should match docs.
- `apps/frontend/src/Pages/Dashboard.res` — Final Web Dashboard labels should match docs.
- `.github/project-tracking.md` — May need a terminology note if tracker documentation references Compozy-backed Local Issue Tracker behavior.

### Related ADRs
- [ADR-001: Represent Compozy lifecycle at PRD Run level](adrs/adr-001.md) — Product decision to document lifecycle at PRD Run level.
- [ADR-002: Use full V1 operator trust as the PRD product approach](adrs/adr-002.md) — Product scope for all-surface operator trust.
- [ADR-003: Persist dispatch-aware Compozy lifecycle in Runtime Home](adrs/adr-003.md) — Technical decision that should be reflected in repository ADR documentation.

## Deliverables
- README documentation for Compozy PRD Run lifecycle, task-step progress, not-PR-ready reasons, and aggregate Batch Pull Requests.
- CONTEXT glossary/relationship updates when new domain language is introduced.
- Repository ADR under `docs/adr/` documenting runtime semantic changes.
- Documentation verification notes covering at least 80% of lifecycle and readiness categories **(REQUIRED)**
- Integration checks for documentation consistency and task validation **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Documentation checklist covers at least eight lifecycle categories: pending, in planning, in execution, in review, blocked, completed, failed, skipped, pull-request handoff, and not PR-ready.
  - [x] Documentation checklist covers disabled, not-ready, ready, handoff attempting, handoff completed, and handoff failed readiness outcomes.
  - [x] Glossary scan confirms new or changed product terms are present in `CONTEXT.md` or existing glossary terms are reused unchanged.
  - [x] Secret scan confirms docs do not contain token values, webhook URLs, or local `.env` contents.
- Integration tests:
  - [x] `compozy tasks validate --name improve-compozy-task-statuses` succeeds after documentation task updates.
  - [x] Relevant project verification command runs if documentation examples or generated examples are changed.
- Test coverage target: >=80%
- All tests must pass

## Documentation Verification Notes

- Lifecycle documentation coverage: 10/10 categories covered (`pending`, `in_planning`, `in_execution`, `in_review`, `blocked`, `completed`, `failed`, `skipped`, `not_pr_ready`, and `pr_handoff`) = 100%.
- PR readiness documentation coverage: 6/6 outcomes covered (`disabled`, `not_ready`, `ready`, `handoff_attempting`, `handoff_completed`, and `handoff_failed`) = 100%.
- Glossary scan confirmed `CONTEXT.md` includes Compozy PRD Run, Compozy Task Step, Compozy PRD Run Lifecycle, Compozy PR Readiness, Runtime State, Terminal Console, Web Dashboard, Pull Request Policy, and Batch Pull Request.
- Secret scan over changed docs found no token values, webhook URLs, or local `.env` contents.
- Integration checks passed: `compozy tasks validate --name improve-compozy-task-statuses` and `pnpm test`.

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can understand lifecycle, task-step progress, and PR readiness without reading implementation logs.
- Documentation uses established glossary terms and includes a repository ADR for changed runtime semantics.
