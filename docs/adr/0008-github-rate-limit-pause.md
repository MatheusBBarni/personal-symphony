# GitHub Rate Limit Pause

## Status

Accepted

## Context

GitHub may return API rate-limit errors before Symphony can read candidate issues from the configured GitHub Project. Treating that response like an ordinary poll failure causes the orchestrator to retry on the normal polling interval, which can keep consuming failed requests and keep the terminal or Web Dashboard noisy without operator benefit.

## Decision

GitHub tracker fetches classify rate-limit API responses as a structured tracker rate-limit failure. The orchestrator records a tracker-level pause and skips subsequent GitHub candidate polls while the pause is active.

The initial pause is five minutes. During the pause, the orchestrator still reaps running child agents and updates Runtime State with a `last_error` message that includes the remaining retry time. When the pause expires, the next normal poll attempts GitHub again.

This pause applies to candidate issue polling. It does not change Runtime Settings defaults, Stage Commit, Stage Push, Task Branch cleanup, auto-merge, or per-task retry semantics.

## Consequences

Symphony backs off from GitHub during rate-limit windows instead of retrying every normal poll interval.

Operators still see the rate-limit message and the fact that tracker polling is waiting before retrying.

If GitHub continues returning rate-limit errors after the pause, Symphony starts another five-minute tracker pause.
