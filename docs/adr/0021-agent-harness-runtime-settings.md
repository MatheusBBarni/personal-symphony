# Agent Harness Runtime Settings

## Status

Accepted, amended 2026-05-08 and 2026-05-17

## Context

Personal Symphony currently treats Codex as the only concrete non-interactive launch path. Runtime Settings expose a `codex` block, the backend renders `codex exec` commands, timeout handling reads from Codex settings, and Stage Goal Handoff depends on Codex `/goal` behavior.

This blocks Workspace Repository operators from selecting PI for specific Stage Agents while preserving the existing Workspace Repository, Runtime Home, Agent Worktree, Task Branch, Agent Prompt, Stage Commit, Stage Push, retry, and status transition behavior.

The Claude Code Harness work later exposed a second ambiguity in this ADR's first shape: `agents` was being used for execution Harness definitions even though Stage Agent names such as planner, engineer, and reviewer are logical roles. Runtime Settings now need separate product homes for execution backends and logical agent execution selection.

## Decision

Runtime Settings define named Agent Harness definitions under `harnesses`. Each Agent Harness has a `kind`, `command`, optional execution defaults such as `model`, `reasoningEffort`, `turnTimeoutMs`, `readTimeoutMs`, and `stallTimeoutMs`, plus explicit loop settings under `loop.enabled` and `loop.command`.

Runtime Settings define logical agents under `agents`. A logical agent such as `planner`, `engineer`, or `reviewer` selects a Harness with `harness` and may override Harness execution defaults field by field.

`kind: "codex"`, `kind: "claude"`, `kind: "cursor"`, and `kind: "pi"` are distinct Harness implementations. Symphony must not infer Harness behavior only from the command string.

The legacy Runtime Settings `codex` block remains supported as a backwards-compatible Codex Harness. Existing Workspace Repositories that define only the legacy `codex` block continue to load.

Legacy harness-shaped `agents.*` entries remain migration input, but they are not the steady-state Runtime Contract. When the new `harnesses` shape is in use, harness-shaped `agents.*` entries such as `agents.pi.kind` are blocking Readiness Gaps. The remediation is to move execution definitions into `harnesses.*` and keep `agents.*` for logical agent definitions.

Stage Agent mappings select logical agents with `stageAgents.stages[].agent`. Stage-level `stageAgents.stages[].harness` is legacy input and is a blocking Readiness Gap. The remediation is to move Harness selection to `agents.<logical-agent>.harness`.

Readiness validation uses enabled Stage Agent mappings resolved through logical agents as the dispatch boundary for Agent Harness launch requirements. Required Agent Harness fields and launch environment checks are validated for selected Agent Harnesses; unused Agent Harness definitions do not block dispatch solely because their launch path is unavailable.

The Optional Docker Sandbox remains separate from Agent Harness selection. Runtime Settings may define a top-level `sandbox` block that defaults to disabled. When `sandbox.enabled` is `true`, `sandbox.type` must be `docker`, required sandbox fields and live Docker availability become dispatch-blocking readiness inputs, and Symphony launches the selected Agent Harness through an Agent Worktree-scoped Sandbox container instead of redefining the Harness kind.

The first Claude Harness uses Claude Code non-interactive CLI execution with `stream-json` output:

```sh
claude -p --model <model> --output-format stream-json
```

The first PI Harness uses PI non-interactive print mode with the default command shape:

```sh
pi --model <model> --thinking <reasoning> --print --no-session
```

The first Cursor Harness uses Cursor CLI non-interactive execution with `stream-json` output:

```sh
cursor-agent -p --model <model> --output-format stream-json
```

Bootstrap also includes an explicit direct-write Cursor posture for operators who intentionally want it:

```sh
cursor-agent -p --force --model <model> --output-format stream-json
```

Command rendering replaces `<model>` and `<reasoning>` tokens for all supported harnesses. Codex keeps its existing command rendering behavior for legacy command shapes.

Agent Harness launches run in their own process group. When a turn or stall timeout fires, Symphony terminates the process group so child agent processes do not survive and continue writing to the Agent Worktree after the task has moved to retry.

Stall timeout activity is measured from agent output growth and Agent Worktree file modifications. This preserves the stall guard for inactive agents while allowing quiet non-interactive harnesses, such as PI print mode, to continue when they are actively changing files but have not emitted stdout or stderr yet.

Stage Goal Handoff remains stage-gated by `stageAgents.stages[].goal.enabled`, but actual loop handoff is controlled by the selected Harness. When the selected Harness has `loop.enabled: true` and a non-empty `loop.command`, Symphony prepends that command with Stage Goal Context before the normal Agent Prompt. When loop is disabled or blank, Symphony runs the normal prompt. Bootstrap defaults enable Codex loop with `/goal` and disable Claude, Cursor, and PI loops.

PI Harness readiness validation checks only PI Harnesses selected by enabled Stage Agent mappings. For those selected PI Harnesses, Symphony checks that the configured command executable is available and that PI has authentication for the configured model provider through a subscription login, stored auth file, command-line API key, or supported environment variable. Missing PI installation or auth is reported as a Readiness Gap before dispatch. Unused PI Harness definitions may remain in Runtime Settings without requiring every operator to install or authenticate PI.

Claude Harness readiness validation checks only selected Claude Harnesses. For those selected Claude Harnesses, Symphony checks that the configured command executable is available and that Claude Code authentication is configured through Claude login state, `ANTHROPIC_API_KEY`, or Claude settings such as an API key helper. Runtime Settings and docs must reference only environment variable names, not secret values.

Cursor Harness readiness validation checks only selected Cursor Harnesses. For those selected Cursor Harnesses, Symphony checks that the configured command executable is available and that Cursor CLI status succeeds through browser login or `CURSOR_API_KEY`.

Cursor Harness loop readiness validation checks only selected loop-enabled Cursor Harnesses on stages with Stage Goal Handoff enabled. A selected loop-enabled Cursor Harness must accept its configured `loop.command` from standard input, which keeps plugin-backed Cursor loop entry explicit and prevents a configured command from being treated as working without evidence.

## Consequences

PI, Claude, and Cursor can be selected explicitly without pretending to be `codex exec`.

Stage mappings keep one responsibility: route statuses to logical agents. Logical agents keep one responsibility: select Harnesses and role-level execution overrides. Harnesses keep one responsibility: define provider execution, defaults, and loop capability.

Runtime Settings parsing, readiness validation, launch command rendering, timeout handling, and Runtime State naming need implementation review for Codex-specific assumptions.

Sandbox parsing, readiness validation, and Runtime State metadata are additional Runtime Contract concerns, but Sandbox must not become an Agent Harness kind or a stage-level routing concept.

The Runtime Contract changes, so Bootstrap must preserve existing user-edited Runtime Settings and create new defaults only when files are missing.
