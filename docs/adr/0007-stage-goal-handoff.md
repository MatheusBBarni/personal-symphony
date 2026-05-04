# Stage Goal Handoff

## Status

Accepted

## Context

Some Stage Agents benefit from Codex goal tracking, but making `/goal` a global launch mode would change every agent run and blur the boundary between the Stage Goal Context and the normal Agent Prompt.

Codex goal support also depends on local Codex configuration and stdin slash-command support. Symphony needs to surface missing support before dispatch instead of turning it into a retryable task failure.

## Decision

Runtime Settings configure Stage Goal Handoff per stage with `goal.enabled`. Missing `goal` means disabled, and bootstrapped Runtime Settings include `goal.enabled: false` for every example stage.

When a matching stage enables Stage Goal Handoff, Symphony prepends `/goal` plus deterministic Stage Goal Context before the normal rendered Agent Prompt. Stage Goal Context includes issue identifier, title, description, URL, current project status, labels, priority when present, blocker references when present, attempt, and stage agent name. It does not include issue creation or update timestamps by default.

Symphony treats missing Codex goal support as a Readiness Gap. It checks `~/.codex/config.toml` for:

```toml
[features]
goals = true
```

Symphony also verifies that the configured Codex command supports `/goal` from standard input before treating Stage Goal Handoff as supported. A live stdin probe is available with `SYMPHONY_CODEX_GOAL_STDIN_PROBE=1`; otherwise the readiness check accepts the default `codex exec` command shape without consuming a Codex run during ordinary readiness checks.

Goal Usage is parsed from Codex output only when Codex reports it in a parseable JSON form. Parsed Goal Usage is stored in Runtime State for running, retrying, and attention-needed task details, and is displayed in the Web Dashboard when available.

## Consequences

Stage Goal Handoff supplements the Agent Prompt and does not replace stage agent instructions.

Stage Goal Handoff does not change retry behavior, completion behavior, status transitions, Stage Commit, Stage Push, auto-merge, or Batch Pull Request behavior.

Missing or unparseable Goal Usage does not fail a task.
