# Treat PI print mode as deferred output for stall timeout

## Status

Accepted

## Context

The PI Harness uses PI non-interactive print mode for the first integration. In this mode, a valid
long-running invocation may produce no stdout or stderr until the model finishes and the process
exits.

Symphony previously applied the same output-stall watchdog to every Agent Harness. That watchdog is
appropriate for streaming Harnesses, where stdout, stderr, or Agent Worktree changes are expected
progress signals. For PI print mode, silence is not a reliable stall signal. In practice, reviewer
stage PI runs could be killed after `stallTimeoutMs` even though the configured `turnTimeoutMs` still
allowed the run to continue.

## Decision

Symphony will keep enforcing the Harness `turnTimeoutMs` for PI, but it will not treat missing
streamed output as a PI stall. PI completion is decided by process exit, the existing turn timeout,
Goal Loop budget exhaustion, and downstream completion/evidence gates.

Streaming Harnesses keep the output-stall watchdog. Claude `stream-json`, Cursor `stream-json`, and
other output-producing Harnesses still use stdout, stderr, and Agent Worktree activity as progress
signals.

## Consequences

PI runs that are silent while the model is working are no longer moved to retry or Human Attention
solely because stdout and stderr did not change for `stallTimeoutMs`.

A genuinely hung PI process can now run until `turnTimeoutMs` or a configured Goal Loop budget limit.
Operators should size PI `turnTimeoutMs` according to the maximum acceptable wall-clock duration for a
single PI turn.

The Runtime Contract shape is unchanged. This is a runtime interpretation change for PI Harness
monitoring, not a Bootstrap default change.
