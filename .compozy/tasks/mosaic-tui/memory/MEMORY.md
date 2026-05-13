# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions
- `Terminal_console_model` mode precedence is `attention` > `retrying` > `running` > `readiness_blocked` > `ready` > `idle`; `ready` represents a pending Ordered Queue with no active work or Readiness Gaps.
- `Terminal_console_runtime` handoff uses latest-state semantics, not event-log semantics; updates published before UI subscription are coalesced to the latest Runtime State snapshot.

## Shared Learnings
- In this environment, npm package export validation may fail before repository checks because user npm config sets `before=null`; run `pnpm npm:validate` with `NPM_CONFIG_USERCONFIG=/dev/null` to isolate that user config when validating this workflow.

## Open Risks

## Handoffs
