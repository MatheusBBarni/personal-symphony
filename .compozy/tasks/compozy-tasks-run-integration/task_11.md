---
status: completed
title: "Update tracker documentation and examples"
type: docs
complexity: medium
dependencies:
  - task_01
  - task_06
  - task_09
  - task_10
---

# Task 11: Update tracker documentation and examples

## Overview
Document the Compozy-backed Local Issue Tracker workflow after the runtime behavior is defined. The documentation must explain GitHub default preservation, PRD-run semantics, task-step progress, retry behavior, and selector support without including secrets.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST document `tracker.kind = "compozy_tasks"` as opt-in.
- R2 MUST state that GitHub remains the default Issue Tracker.
- R3 MUST describe `.compozy/tasks/<task_name>/` as one PRD-run work item.
- R4 MUST explain task-step frontmatter progress and `maxTaskStepRetries`.
- R5 MUST document `compozy:<task_name>` selector behavior where supported.
- R6 MUST avoid token values, webhook URLs, and local `.env` contents.
- R7 MUST use glossary terms from `CONTEXT.md` consistently.
</requirements>

## Subtasks
- [x] 11.1 Update README or tracker documentation with Compozy tracker setup.
- [x] 11.2 Add secret-free Runtime Settings examples.
- [x] 11.3 Document PRD-run versus task-step semantics.
- [x] 11.4 Document retry, failed/skipped, and progress visibility behavior.
- [x] 11.5 Review glossary usage and update `CONTEXT.md` only if new domain language is introduced.
- [x] 11.6 Add documentation verification checks.

## Implementation Details
Use TechSpec "Development Sequencing" and "Monitoring and Observability" as source material. If documentation introduces a new term beyond existing glossary terms, update `CONTEXT.md` per repository rules.

### Relevant Files
- `README.md` — Main runtime setup and tracker documentation.
- `.github/project-tracking.md` — GitHub-specific tracker notes may need clarification that GitHub is one tracker option.
- `CONTEXT.md` — Domain glossary source of truth if new terms are introduced.
- `.compozy/tasks/compozy-tasks-run-integration/_prd.md` — Product requirements for documentation messaging.
- `.compozy/tasks/compozy-tasks-run-integration/_techspec.md` — Technical details to summarize without over-specifying.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Must not be changed unless separately approved.
- `.symphony/settings.json` examples in docs — Must remain secret-free.

### Related ADRs
- [ADR-001: Scope Compozy tasks as a local tracker adapter](adrs/adr-001.md) — Establishes opt-in tracker framing.
- [ADR-002: Treat a Compozy PRD run as the local issue](adrs/adr-002.md) — Defines user-facing PRD-run semantics.
- [ADR-006: Configure task-step retries in Compozy tracker settings](adrs/adr-006.md) — Documents retry setting.

## Deliverables
- Documentation for Compozy-backed Local Issue Tracker setup and operation.
- Secret-free settings examples.
- Glossary alignment or explicit note that no new glossary terms were added.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documentation/link validation **(REQUIRED)**

## Tests
- Unit tests:
  - [x] Documentation examples include `tracker.kind = "compozy_tasks"` and no secret values.
  - [x] Documentation uses **Issue Tracker**, **GitHub Tracker**, **Local Issue Tracker**, and **Runtime Settings** consistently.
  - [x] No generated `.res.js` files are included by documentation-only changes.
- Integration tests:
  - [x] `rg "WORKFLOW.md|WORKFLOW.example.md" README.md .github/project-tracking.md docs` does not introduce legacy tracker references.
  - [x] Focused documentation checks or link checks pass where available.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can understand when and how to select Compozy-backed local tracking.
- Documentation preserves GitHub default expectations and contains no secrets.
