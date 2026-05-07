---
title: Runtime Settings Invocation Overrides
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Product Repository maintainers
tags: [tool, cli, runtime-settings, invocation-overrides, issue-66]
---

# Introduction

This specification defines Runtime Settings Invocation Overrides for Personal Symphony. The goal is to let a Workspace Repository operator override selected Runtime Settings values for a single `symphony` command invocation without editing `.symphony/settings.json`.

Source issue: [#66 Add CLI overrides for runtime polling, workspace, and agent settings](https://github.com/MatheusBBarni/symphony-orchestrator/issues/66).

## 1. Purpose & Scope

This specification applies to the default `symphony` runtime command, CLI flag parsing, Runtime Settings loading, runtime configuration validation, help output, backend startup, manual merge mode, Web Dashboard mode, Terminal Console mode, and orchestrator execution.

The intended audience is implementers and reviewers working on the OCaml backend CLI and runtime configuration path.

Out of scope:

- Changing Bootstrap defaults in `apps/backend/lib/runtime_home.ml`.
- Rewriting `.symphony/settings.json`.
- Supporting overrides for legacy positional `WORKFLOW.md` invocation.
- Adding overrides for tracker, project, Git policy, Stage Agent, Agent Harness, server, pull request, or Protected Path Policy settings.
- Changing Task Branch cleanup, auto-merge, Stage Push, Batch Pull Request, or Task Pull Request semantics.

Any implementation that changes runtime semantics MUST add or update an ADR under `docs/adr/`.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Runtime Home**: The `.symphony/` directory that contains Personal Symphony configuration and runtime-owned files for a Workspace Repository.
- **Runtime Contract**: The repository-owned files inside the Runtime Home that define Personal Symphony behavior for a Workspace Repository.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract that defines tracker, project, orchestration, agent, server, and path configuration.
- **Runtime Settings Invocation Override**: A command-line value that replaces one loaded Runtime Settings field for the current Symphony process only.
- **Agent Worktree**: An Agent Workspace backed by a Git worktree for one dispatched task.
- **Terminal Console**: The default terminal interface for operating Personal Symphony in a Workspace Repository.
- **Web Dashboard**: The optional browser interface for operating Personal Symphony in a Workspace Repository.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: The default `symphony` runtime command MUST accept `--polling.intervalMs VALUE`.
- **REQ-002**: The default `symphony` runtime command MUST accept `--workspace.root VALUE`.
- **REQ-003**: The default `symphony` runtime command MUST accept `--agent.maxConcurrentAgents VALUE`.
- **REQ-004**: The default `symphony` runtime command MUST accept `--agent.maxTurns VALUE`.
- **REQ-005**: The default `symphony` runtime command MUST accept `--agent.maxRetryBackoffMs VALUE`.
- **REQ-006**: Each supplied Runtime Settings Invocation Override MUST replace the corresponding loaded Runtime Settings field for the current process only.
- **REQ-007**: Runtime Settings Invocation Overrides MUST NOT write to `.symphony/settings.json`.
- **REQ-008**: Runtime Settings Invocation Overrides MUST NOT change Bootstrap defaults or create different Runtime Contract files.
- **REQ-009**: Runtime Settings Invocation Overrides MUST NOT weaken Workspace Repository root validation.
- **REQ-010**: Runtime Settings Invocation Overrides MUST be applied before readiness checks, startup reporting, Web Dashboard server startup, Terminal Console rendering, manual merge execution, and orchestrator execution.
- **REQ-011**: Positive integer override fields MUST reject zero, negative, and non-integer values with a clear startup failure.
- **REQ-012**: `--workspace.root VALUE` MUST use the same path resolution behavior as `workspace.root` in Runtime Settings, including resolving relative paths from the Workspace Repository root.
- **REQ-013**: `--workspace.root VALUE` MUST control Agent Worktree placement for the current run.
- **REQ-014**: `--agent.maxConcurrentAgents VALUE` MUST control the global maximum number of concurrently running agents for the current run.
- **REQ-015**: `--agent.maxTurns VALUE` MUST control the maximum agent attempts for the current run.
- **REQ-016**: `--agent.maxRetryBackoffMs VALUE` MUST control the retry backoff cap for the current run.
- **REQ-017**: `--polling.intervalMs VALUE` MUST control the orchestrator poll interval for the current run.
- **REQ-018**: `symphony --help` MUST document each new flag and state that it overrides the corresponding Runtime Settings field for the current invocation.
- **REQ-019**: Existing `--port`, `--once`, `--web`, `--queue`, and `--merge` behavior MUST continue to work with Runtime Settings Invocation Overrides.
- **REQ-020**: The `symphony init` and `symphony update` subcommands MUST NOT accept these runtime-only override flags unless a future issue explicitly expands their scope.
- **CON-001**: Override names MUST match the JSON Runtime Settings field casing, including camelCase leaf names such as `intervalMs`.
- **CON-002**: Override implementation MUST preserve `GITHUB_TOKEN` and `GH_TOKEN` secrecy by never logging token values.
- **GUD-001**: Implement overrides as a typed structure passed into Runtime Settings loading or immediately after loading, not as scattered mutations in orchestration code.
- **PAT-001**: Focused backend tests SHOULD live near existing configuration and CLI startup tests in `apps/backend/test/test_backend.ml`.

## 4. Interfaces & Data Contracts

### CLI Flags

| Flag | Value type | Runtime Settings field | Scope |
| --- | --- | --- | --- |
| `--polling.intervalMs VALUE` | positive integer | `polling.intervalMs` | Current process only |
| `--workspace.root VALUE` | path string | `workspace.root` | Current process only |
| `--agent.maxConcurrentAgents VALUE` | positive integer | `agent.maxConcurrentAgents` | Current process only |
| `--agent.maxTurns VALUE` | positive integer | `agent.maxTurns` | Current process only |
| `--agent.maxRetryBackoffMs VALUE` | positive integer | `agent.maxRetryBackoffMs` | Current process only |

### Override Application Contract

The backend SHOULD model overrides as optional values:

```ocaml
type runtime_settings_overrides = {
  polling_interval_ms : int option;
  workspace_root : string option;
  agent_max_concurrent_agents : int option;
  agent_max_turns : int option;
  agent_max_retry_backoff_ms : int option;
}
```

The effective runtime config MUST be equivalent to:

```text
effective_config =
  load .symphony/settings.json from Workspace Repository Runtime Home
  |> apply supplied Runtime Settings Invocation Overrides
  |> run existing readiness and runtime behavior
```

### Path Resolution Contract

Given a Workspace Repository root `/repo`:

| Override value | Effective `config.workspace.root` |
| --- | --- |
| `.symphony/workspaces-fast` | `/repo/.symphony/workspaces-fast` |
| `workspaces` | `/repo/workspaces` |
| `/tmp/symphony-workspaces` | `/tmp/symphony-workspaces` |
| `~/symphony-workspaces` | `$HOME/symphony-workspaces` |

The implementation MUST use the same resolver as Runtime Settings instead of adding a separate path algorithm.

## 5. Acceptance Criteria

- **AC-001**: Given `.symphony/settings.json` has `polling.intervalMs: 30000`, When the operator runs `symphony --polling.intervalMs 1000 --once`, Then startup uses an effective polling interval of `1000` and `.symphony/settings.json` remains unchanged.
- **AC-002**: Given `.symphony/settings.json` has `workspace.root: ".symphony/workspaces"`, When the operator runs `symphony --workspace.root .symphony/workspaces-alt --once`, Then effective Agent Worktree placement resolves under the Workspace Repository root at `.symphony/workspaces-alt`.
- **AC-003**: Given `.symphony/settings.json` has `agent.maxConcurrentAgents: 2`, When the operator runs `symphony --agent.maxConcurrentAgents 4`, Then the orchestrator uses `4` as the global concurrency cap for that process.
- **AC-004**: Given `.symphony/settings.json` has `agent.maxTurns: 10`, When the operator runs `symphony --agent.maxTurns 3`, Then an agent that keeps failing is retried according to the effective maximum attempt count of `3`.
- **AC-005**: Given `.symphony/settings.json` has `agent.maxRetryBackoffMs: 300000`, When the operator runs `symphony --agent.maxRetryBackoffMs 5000`, Then retry delay calculation caps backoff at `5000` milliseconds.
- **AC-006**: Given the operator is outside a Workspace Repository root, When the operator runs `symphony --workspace.root /tmp/workspaces`, Then Symphony exits before Bootstrap with the existing Workspace Repository root validation failure.
- **AC-007**: Given any positive integer override receives `0`, `-1`, `1.5`, `abc`, or an empty value, When the command starts, Then Symphony exits with a clear failure identifying the invalid override field.
- **AC-008**: Given the operator runs `symphony --help`, When help text is printed, Then all five Runtime Settings Invocation Override flags are listed with current-invocation override wording.
- **AC-009**: Given the operator runs `symphony --web --workspace.root /tmp/symphony-workspaces`, When the Web Dashboard starts, Then the effective runtime state and orchestrator use `/tmp/symphony-workspaces` for Agent Worktrees.
- **AC-010**: Given the operator runs `symphony --merge 66 --agent.maxConcurrentAgents 1`, When manual merge mode starts, Then the override is accepted but does not change Manual Task Merge semantics except for the shared effective config fields it already reads.

## 6. Test Automation Strategy

- **Test Levels**: Unit and backend integration tests.
- **Frameworks**: OCaml Alcotest and command-line help/startup tests already used by the Product Repository.
- **Test Data Management**: Temporary Workspace Repository roots with `.symphony/settings.json` fixtures; no real GitHub token values.
- **CI/CD Integration**: Run `pnpm test`.
- **Coverage Requirements**: Cover override parsing, override application, path resolution, validation failures, `--help` output, and unchanged Runtime Contract files.
- **Performance Testing**: Not required for first version.

Required tests:

- Config override application for each supported field.
- Valid positive integer overrides for polling and agent fields.
- Invalid zero, negative, decimal, non-numeric, and missing integer override values.
- `--workspace.root` relative, absolute, and home-relative resolution.
- `symphony --help` contains every new flag and override wording.
- A fixture proving `.symphony/settings.json` content is unchanged after override startup.
- Root validation still fails outside a Workspace Repository even when `--workspace.root` is supplied.

## 7. Rationale & Context

Runtime Settings are repository-owned because they are part of the Runtime Contract. Editing them for one-off local runs creates noisy repository changes and risks committing machine-specific paths or temporary tuning.

The supported first set of overrides is intentionally narrow. Polling cadence, Agent Worktree root, global concurrency, maximum attempts, and retry backoff are operational tuning values that can reasonably differ per invocation. Tracker identity, Git policy, stage transitions, Protected Path Policy, and pull request behavior are contract-level semantics and should stay in Runtime Settings unless a separate issue defines a safe override model.

The Workspace Repository root check must remain earlier than override application because `--workspace.root` controls Agent Worktree placement, not the identity of the Workspace Repository whose Runtime Contract is loaded.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - Runtime readiness and orchestration continue to use configured tracker settings.

### Third-Party Services

- **SVC-001**: Agent Harness executable - Receives launched agent work under the effective runtime configuration.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Provides `.symphony/settings.json`; overrides must not rewrite it.
- **INF-002**: Workspace Repository root validation - Must run before Runtime Settings Invocation Overrides are applied.

### Data Dependencies

- **DAT-001**: Runtime Settings JSON - Provides base values for every override.
- **DAT-002**: CLI argument vector - Provides optional Runtime Settings Invocation Override values.

### Technology Platform Dependencies

- **PLT-001**: OCaml Cmdliner CLI - Defines and validates command-line flags.
- **PLT-002**: OCaml backend config model - Stores effective Runtime Settings values used by readiness checks and orchestration.

### Compliance Dependencies

- **COM-001**: Secret handling - Environment variable values such as `GITHUB_TOKEN` and `GH_TOKEN` must not be logged or written to docs.
- **COM-002**: ADR coverage - Runtime semantic changes require an ADR.

## 9. Examples & Edge Cases

### One-run fast polling

```sh
symphony --polling.intervalMs 1000
```

Expected behavior:

- The current process polls every second.
- `.symphony/settings.json` remains unchanged.
- Future runs without the flag use the Runtime Settings value again.

### Alternate Agent Worktree root

```sh
symphony --workspace.root /tmp/symphony-workspaces --agent.maxConcurrentAgents 1
```

Expected behavior:

- Agent Worktrees for this run are created under `/tmp/symphony-workspaces`.
- The Workspace Repository is still the current directory validated by `Runtime_home.require_workspace_root`.
- Task Branch and Runtime Contract semantics are unchanged.

### Invalid integer

```sh
symphony --agent.maxTurns 0
```

Expected behavior:

- Startup fails clearly.
- No Runtime Contract file is rewritten.
- No agent is dispatched.

Edge cases:

- A relative `--workspace.root` value is resolved relative to the Workspace Repository root, not the Product Repository source checkout.
- Multiple override flags may be supplied together; each supported field uses its supplied value.
- Repeating the same override flag should follow the CLI parser's existing repeated-option behavior. If unspecified by Cmdliner, the implementation MUST document and test the observed behavior.
- Runtime Settings still validates non-overridden required fields. Overrides do not make an incomplete tracker configuration dispatchable.

## 10. Validation Criteria

- `pnpm test` passes after implementation.
- `symphony --help` documents the five override flags.
- Runtime Settings Invocation Overrides affect runtime behavior for one process only.
- `.symphony/settings.json` remains byte-for-byte unchanged after a run that uses overrides.
- Root validation remains unchanged.
- Positive integer validation rejects invalid override values with field-specific errors.
- The implementation includes or updates an ADR for runtime semantics.

## 11. Related Specifications / Further Reading

- [CONTEXT.md](../CONTEXT.md)
- [Issue #66](https://github.com/MatheusBBarni/symphony-orchestrator/issues/66)
- [Runtime Settings Invocation Overrides ADR](../docs/adr/0022-runtime-settings-invocation-overrides.md)
- [Agent Harness Runtime Settings specification](./spec-architecture-agent-harness-runtime-settings.md)
