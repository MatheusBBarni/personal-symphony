---
status: pending
title: "Update tracker documentation and glossary alignment"
type: docs
complexity: medium
dependencies:
  - task_01
  - task_03
  - task_08
---

# Task 10: Update tracker documentation and glossary alignment

## Overview
Update user-facing documentation so GitHub and minibeads are presented as supported Issue Tracker choices. The docs must explain GitHub as the default, minibeads as the explicit local-first option, and the readiness/setup expectations without exposing secrets.

<critical>
- ALWAYS READ the PRD and TechSpec before starting
- REFERENCE TECHSPEC for implementation details — do not duplicate here
- FOCUS ON "WHAT" — describe what needs to be accomplished, not how
- MINIMIZE CODE — show code only to illustrate current structure or problem areas
- TESTS REQUIRED — every task MUST include tests in deliverables
</critical>

<requirements>
- R1 MUST document GitHub as the default Issue Tracker.
- R2 MUST document minibeads as an equal first-class option when explicitly selected.
- R3 MUST explain the `settings.json` tracker selection property and minibeads command/root settings.
- R4 MUST document readiness diagnostics for missing `mb` command or local issue store.
- R5 MUST keep examples secret-free and mention only secret variable names where needed.
- R6 MUST update `CONTEXT.md` only if domain language changes or needs clarification.
</requirements>

## Subtasks
- [ ] 10.1 Update README setup sections to distinguish GitHub Tracker and Local Issue Tracker.
- [ ] 10.2 Add minibeads settings examples without secret values.
- [ ] 10.3 Document readiness guidance for local tracker prerequisites.
- [ ] 10.4 Review `.github/project-tracking.md` for GitHub-specific scope language.
- [ ] 10.5 Update `CONTEXT.md` only if glossary language needs refinement.

## Implementation Details
Follow PRD "First-class documentation" and TechSpec "Monitoring and Observability". Keep GitHub token documentation intact for GitHub tracker users.

### Relevant Files
- `README.md` — Main setup and operation documentation.
- `CONTEXT.md` — Domain glossary source of truth.
- `.github/project-tracking.md` — GitHub-specific tracker setup notes.
- `.compozy/tasks/minibeads-local-issue-tracker/_prd.md` — Product documentation requirements.
- `.compozy/tasks/minibeads-local-issue-tracker/_techspec.md` — Technical constraints and readiness names.

### Dependent Files
- `apps/backend/lib/runtime_home.ml` — Default settings examples remain GitHub unless separately approved.
- `docs/adr/0023-minibeads-local-issue-tracker.md` — Existing architecture decision for minibeads direction.

### Related ADRs
- [ADR-001: Scope minibeads as an opt-in local tracker adapter](adrs/adr-001.md) — Docs must preserve opt-in scope.
- [ADR-002: Prioritize a first-class local tracker experience for V1](adrs/adr-002.md) — Docs must present minibeads as first-class.
- [ADR-004: Use the mb CLI as the minibeads integration boundary](adrs/adr-004.md) — Docs must describe `mb` prerequisite.

## Deliverables
- README explains tracker choice and minibeads setup.
- GitHub-specific docs remain accurate and scoped.
- Glossary remains consistent with `CONTEXT.md`.
- Unit tests with 80%+ coverage **(REQUIRED)**
- Integration tests for documentation examples **(REQUIRED)**

## Tests
- Unit tests:
  - [ ] Documentation examples contain no token values, webhook URLs, or local `.env` contents.
  - [ ] Settings examples use `tracker.kind = "github"` or `tracker.kind = "minibeads"` consistently.
  - [ ] Glossary terms match `CONTEXT.md` terminology.
- Integration tests:
  - [ ] Run repository documentation validation command if one exists; otherwise perform manual docs review against the PRD and TechSpec.
- Test coverage target: >=80%
- All tests must pass

## Success Criteria
- All tests passing
- Test coverage >=80%
- Operators can understand when and how to select GitHub or minibeads without reading source code.
