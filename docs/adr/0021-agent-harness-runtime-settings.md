# Agent Harness Runtime Settings

## Status

Accepted

## Context

Personal Symphony currently treats Codex as the only concrete non-interactive launch path. Runtime Settings expose a `codex` block, the backend renders `codex exec` commands, timeout handling reads from Codex settings, and Stage Goal Handoff depends on Codex `/goal` behavior.

This blocks Workspace Repository operators from selecting PI for specific Stage Agents while preserving the existing Workspace Repository, Runtime Home, Agent Worktree, Task Branch, Agent Prompt, Stage Commit, Stage Push, retry, and status transition behavior.

## Decision

Runtime Settings will introduce named Agent Harness definitions. Each Agent Harness has a `kind`, `command`, `model`, `reasoningEffort`, `turnTimeoutMs`, `readTimeoutMs`, and `stallTimeoutMs`.

`kind: "codex"` and `kind: "pi"` are distinct harness implementations. Symphony must not infer harness behavior only from the command string.

The legacy Runtime Settings `codex` block remains supported as a backwards-compatible Codex Harness. Existing Workspace Repositories that define only the legacy `codex` block continue to run without migration. When both `agents.codex` and the legacy `codex` block are present, `agents.codex` is canonical and the legacy block is ignored for that harness.

Stage Agent mappings may use `harness` to select the named Agent Harness independently from the `agent` instruction file. Existing Runtime Settings that omit `harness` continue using their `agent` identifier as the harness selector. If a Stage Agent selects an unknown harness, Symphony reports a Readiness Gap instead of dispatching work.

The first PI Harness uses PI non-interactive print mode with the default command shape:

```sh
pi --model <model> --thinking <reasoning> --print --no-session
```

Command rendering replaces `<model>` and `<reasoning>` tokens for all supported harnesses. Codex keeps its existing command rendering behavior for legacy command shapes.

Agent Harness launches run in their own process group. When a turn or stall timeout fires, Symphony terminates the process group so child agent processes do not survive and continue writing to the Agent Worktree after the task has moved to retry.

Stall timeout activity is measured from agent output growth and Agent Worktree file modifications. This preserves the stall guard for inactive agents while allowing quiet non-interactive harnesses, such as PI print mode, to continue when they are actively changing files but have not emitted stdout or stderr yet.

Stage Goal Handoff remains Codex Harness-specific for the first PI integration. A Stage Agent that enables Stage Goal Handoff on a non-Codex harness is a Readiness Gap until an equivalent non-Codex goal contract exists.

PI Harness readiness validation checks that the configured command executable is available and that PI has authentication for the configured model provider through a subscription login, stored auth file, command-line API key, or supported environment variable. Missing PI installation or auth is reported as a Readiness Gap before dispatch.

## Consequences

PI can be selected explicitly without pretending to be `codex exec`.

Future Claude Code support can add another Agent Harness kind without changing the Stage Agent mapping model again.

Runtime Settings parsing, readiness validation, launch command rendering, timeout handling, and Runtime State naming need implementation review for Codex-specific assumptions.

The Runtime Contract changes, so Bootstrap must preserve existing user-edited Runtime Settings and create new defaults only when files are missing.
