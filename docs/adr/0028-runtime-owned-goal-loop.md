# Runtime-Owned Goal Loop

## Status

Accepted

## Date

2026-05-20

## Context

Personal Symphony already has Stage Goal Handoff, Stage Goal Context, Harness Loop, and Goal Usage.
Those concepts describe launch-time prompt handoff and optional provider-reported usage, not a
Runtime-owned stop model that can say whether a loop reached a goal with evidence.

The built-in agent looper PRD accepts an evidence-first Goal Loop for maintainers supervising Stage
Agents in a Workspace Repository. A loop may stop as Goal met only when deterministic evidence
supports that outcome. Ambiguous, blocked, unverifiable, or budget-exhausted work must stop with a
clear operator-facing reason.

## Decision

Personal Symphony will model Goal Loop as Runtime-owned, Stage Agent-scoped behavior.

Goal Loop configuration belongs to stage behavior rather than Agent Harness definitions. Harness Loop
continues to describe whether the selected Agent Harness can receive a launch-time loop command for
Stage Goal Handoff. Stage Goal Handoff continues to prepend Stage Goal Context before the normal
Agent Prompt and remains non-semantic for retry, completion, delivery, and status authority.

Canonical Goal Loop state will be persisted under `.symphony/state/goal-loops/*.json` and projected
through top-level Runtime State. The state records the loop goal, issue and run identity, selected
Stage Agent, selected Agent Harness identity, attempt count, configured budget, latest bounded
evidence summary, stop outcome, stop reason, next action, updated timestamp, and optional private
diagnostics path. Terminal Console and Web Dashboard surfaces read that Runtime State projection
instead of interpreting provider logs independently.

Goal met requires a successful deterministic evidence command. For Goal Loop-enabled stages, an
agent exit code `0` is not enough to enter completion behavior. Symphony runs the stage-scoped
evidence command from the Agent Worktree before existing completion behavior begins. If the command
succeeds and returns bounded evidence, Goal Loop records Goal met and the existing completion path
continues. If evidence is missing, timed out, invalid, or non-zero, Symphony retries with
missing-evidence guidance while the configured retry budget remains. After retry exhaustion, Symphony
records Needs attention and moves the task to Human Attention before Stage Commit or status changes.
Budget exhaustion records Budget exhausted as the stop outcome.

Goal Loop does not own delivery authority in V1. It must not create commits, push branches, merge
Task Branches, open pull requests, auto-merge work, or change project status outside the existing
orchestrator lifecycle. Stage Commit, Stage Push, Task Branch Integration, Pull Request Mode, and
status transitions remain governed by the existing Runtime Contract and ADRs.

## Alternatives Considered

### Provider prompt loop only

Symphony could have treated Goal Loop as another Stage Goal Handoff command such as `/goal`.
That would be small, but it would leave stop outcomes and evidence outside Runtime State and would
not support shared Terminal Console and Web Dashboard visibility.

### Harness-scoped Goal Loop

Symphony could have put Goal Loop settings under Agent Harness definitions. That would couple loop
behavior to provider selection and conflict with the existing Harness Loop term, which only controls
launch-time Stage Goal Handoff support.

### Completion review loop

Symphony could have introduced an independent reviewer that decides whether work is complete. That
changes completion semantics and remains out of scope for this ADR. V1 requires deterministic
evidence, not model confidence by itself.

## Consequences

Goal Loop gets a stable domain boundary before runtime implementation begins.

Runtime State becomes the authoritative operator-facing source for current and stopped loop status,
including successful Goal met outcomes that would otherwise disappear when active task rows clear.

Goal Loop-enabled stages need an evidence command to reach Goal met. Misconfigured evidence commands
can increase retries or Human Attention outcomes, but they will not allow unverifiable work to pass
as completed.

Future loop recipes can build on the same state and evidence contract without changing delivery
authority in V1.

## References

- `CONTEXT.md`
- `.compozy/tasks/built-in-agent-looper/_prd.md`
- `.compozy/tasks/built-in-agent-looper/_techspec.md`
- `.compozy/tasks/built-in-agent-looper/adrs/adr-001.md`
- `.compozy/tasks/built-in-agent-looper/adrs/adr-002.md`
- `.compozy/tasks/built-in-agent-looper/adrs/adr-003.md`
- `.compozy/tasks/built-in-agent-looper/adrs/adr-004.md`
- `docs/adr/0007-stage-goal-handoff.md`
- `docs/adr/0021-agent-harness-runtime-settings.md`
