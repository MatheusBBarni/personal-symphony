---
title: Agent Harness Runtime Settings
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Product Repository maintainers
tags: [architecture, runtime-contract, agent-harness, pi, issue-59]
---

# Introduction

This specification defines the Runtime Contract changes required to support PI as a first-class Agent Harness for Personal Symphony Stage Agents while preserving existing Codex behavior.

Source issue: [#59 PRD: Add PI as a first-class Stage Agent harness](https://github.com/MatheusBBarni/symphony-orchestrator/issues/59).

## 1. Purpose & Scope

The purpose is to define how Workspace Repository operators configure and select non-interactive agent launch tools through Runtime Settings.

This specification applies to the Product Repository backend implementation, Bootstrap defaults, Runtime Settings parsing, readiness validation, launch command rendering, and tests.

In scope:

- Add PI as a first-class configurable Agent Harness.
- Preserve the legacy Runtime Settings `codex` block.
- Allow Codex and PI harnesses to coexist.
- Keep existing Agent Worktree, Task Branch, Agent Prompt, Stage Commit, Stage Push, retry, and status transition behavior.
- Keep Stage Goal Handoff Codex Harness-specific in the first PI integration.

Out of scope:

- Claude Code integration.
- PI RPC mode.
- PI session resume or fork support.
- PI-specific structured usage accounting.
- Cross-harness Stage Goal Handoff.
- Task Branch cleanup, auto-merge, tracker model, npm package, or packaged-binary behavior changes.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Product Repository**: The repository that contains the Personal Symphony source code.
- **Runtime Home**: The `.symphony/` directory that contains Personal Symphony configuration and runtime-owned files for a Workspace Repository.
- **Runtime Contract**: Repository-owned files inside the Runtime Home that define Personal Symphony behavior.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract.
- **Stage Agent**: A Runtime Settings mapping from project statuses to a named agent instruction file, Agent Harness selection, and optional stage behavior.
- **Agent Harness**: A named Runtime Settings launch configuration that tells Symphony which non-interactive agent tool to run for a Stage Agent.
- **Codex Harness**: An Agent Harness whose launch semantics target Codex non-interactive execution.
- **PI Harness**: An Agent Harness whose launch semantics target PI non-interactive execution.
- **Agent Prompt**: The `prompt.md` Runtime Contract content rendered with issue and stage context for a dispatched task.
- **Agent Worktree**: An Agent Workspace backed by a Git worktree for one dispatched task.
- **Task Branch**: A Git branch created from the Loop-Start Branch for one dispatched task.
- **Stage Goal Handoff**: A stage-specific Codex handoff that sends `/goal` before the normal Agent Prompt.
- **Readiness Gap**: A configuration or environment problem that prevents dispatch while still allowing operator inspection.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Runtime Settings MUST support a named `agents` object keyed by Agent Harness identifier.
- **REQ-002**: Each Agent Harness MUST define `kind`, `command`, `model`, `reasoningEffort`, `turnTimeoutMs`, `readTimeoutMs`, and `stallTimeoutMs`.
- **REQ-003**: Supported initial harness kinds MUST include `codex` and `pi`.
- **REQ-004**: Existing Runtime Settings that only contain the legacy `codex` block MUST continue to work.
- **REQ-005**: Symphony MUST normalize the legacy `codex` block into the default Codex Harness for internal dispatch behavior.
- **REQ-006**: Stage Agent mappings MUST continue using their existing `agent` field as the selected Agent Harness identifier.
- **REQ-007**: PI command rendering MUST replace `<model>` and `<reasoning>` tokens.
- **REQ-008**: The default PI command MUST be `pi --model <model> --thinking <reasoning> --print --no-session`.
- **REQ-009**: PI dispatch MUST pass the rendered Agent Prompt through a PI-supported non-interactive input path.
- **REQ-010**: PI stdout and stderr MUST be captured as agent output and Runtime Diagnostics in the same operational locations as existing launches.
- **REQ-011**: Harness-specific timeout settings MUST control turn, read, and stall timeout behavior for that running task.
- **REQ-012**: Missing harness definitions, unknown harness kinds, blank commands, blank models, and blank reasoning effort values MUST produce Readiness Gaps.
- **REQ-013**: Stage Goal Handoff enabled on a non-Codex harness MUST produce a Readiness Gap in the first PI integration.
- **REQ-014**: Codex command rendering MUST preserve existing legacy command behavior.
- **REQ-015**: Agent Prompt composition MUST remain consistent across Codex and PI harnesses.
- **REQ-016**: Stage Commit, Stage Push, retry, Human Attention Status, Agent Worktree, and Task Branch behavior MUST remain harness-independent.
- **REQ-017**: Runtime State names and dashboard labels SHOULD be reviewed for misleading Codex-specific terminology before exposing PI runs.
- **CON-001**: The implementation MUST NOT change Task Branch cleanup or auto-merge defaults.
- **CON-002**: The implementation MUST NOT replace the GitHub Issues + Projects tracker model.
- **CON-003**: The implementation MUST NOT change npm package files, `bin/symphony.js`, or packaged-binary behavior.
- **CON-004**: Bootstrap MUST preserve existing user-edited Runtime Contract files.
- **SEC-001**: Documentation and examples MUST NOT include secret values, token values, webhook URLs, or local `.env` contents.
- **GUD-001**: Use Agent Harness, Codex Harness, and PI Harness in docs instead of ambiguous phrases such as "agent command."
- **PAT-001**: Prefer external behavior tests for parsing, readiness validation, command rendering, and launch behavior over private implementation tests.

## 4. Interfaces & Data Contracts

### Runtime Settings Shape

```json
{
  "agents": {
    "codex": {
      "kind": "codex",
      "command": "codex exec",
      "model": "gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    },
    "pi": {
      "kind": "pi",
      "command": "pi --model <model> --thinking <reasoning> --print --no-session",
      "model": "openai/gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    }
  },
  "stageAgents": {
    "stages": [
      {
        "states": ["Todo"],
        "agent": "pi"
      }
    ]
  }
}
```

### Legacy Runtime Settings Compatibility

```json
{
  "codex": {
    "command": "codex exec",
    "model": "gpt-5.5",
    "reasoningEffort": "medium"
  }
}
```

The legacy shape MUST behave as if `agents.codex` exists with `kind: "codex"` and default timeout values.

If both `agents.codex` and the legacy `codex` block are present, `agents.codex` MUST be canonical and the legacy `codex` block MUST be ignored for that harness. The legacy block is only a compatibility fallback when `agents.codex` is absent.

### Agent Harness Fields

| Field | Required | Description |
| --- | --- | --- |
| `kind` | Yes | Harness implementation discriminator. Supported values are `codex` and `pi`. |
| `command` | Yes | Shell command template used for non-interactive launch. |
| `model` | Yes | Harness model identifier. PI values may include provider prefixes. |
| `reasoningEffort` | Yes | Harness reasoning or thinking level. |
| `turnTimeoutMs` | Yes | Maximum elapsed time for one agent turn. |
| `readTimeoutMs` | Yes | Polling sleep chunk used while reading agent output. |
| `stallTimeoutMs` | Yes | Maximum elapsed time without stdout or stderr growth. |

## 5. Acceptance Criteria

- **AC-001**: Given legacy Runtime Settings with only `codex`, When Symphony parses settings, Then the default Codex Harness is available and existing Codex launch command rendering is unchanged.
- **AC-002**: Given Runtime Settings with `agents.codex` and `agents.pi`, When a Stage Agent mapping selects `pi`, Then Symphony dispatches that task through the PI Harness.
- **AC-003**: Given a PI Harness command containing `<model>` and `<reasoning>`, When Symphony renders the launch command, Then both tokens are replaced with shell-safe configured values.
- **AC-004**: Given a Stage Agent references an unknown Agent Harness, When readiness is evaluated, Then a Readiness Gap identifies the missing harness.
- **AC-005**: Given an Agent Harness has an unknown `kind`, blank `command`, blank `model`, or blank `reasoningEffort`, When readiness is evaluated, Then a Readiness Gap identifies the invalid field.
- **AC-006**: Given a PI Harness Stage Agent has Stage Goal Handoff enabled, When readiness is evaluated, Then Symphony reports a non-Codex goal handoff Readiness Gap.
- **AC-007**: Given a Codex Harness Stage Agent has Stage Goal Handoff enabled and Codex goal support is configured, When readiness is evaluated, Then existing Codex goal readiness behavior remains valid.
- **AC-008**: Given a PI-launched task exits successfully with code changes, When stage completion runs, Then existing Stage Commit, Stage Push, status transition, and Task Branch behavior applies.
- **AC-009**: Given Bootstrap runs in a Workspace Repository with existing `.symphony/settings.json`, When PI support exists in the Product Repository, Then Bootstrap does not overwrite that file.
- **AC-010**: Given Runtime Settings define both `agents.codex` and the legacy `codex` block, When Symphony parses settings, Then `agents.codex` is used for the Codex Harness and the legacy block is ignored.

## 6. Test Automation Strategy

- **Test Levels**: Backend unit and integration-style tests using temporary Workspace Repository fixtures.
- **Frameworks**: OCaml Alcotest through `pnpm test`.
- **Test Data Management**: Use temporary Runtime Home and fake agent commands that write predictable stdout, stderr, and prompt input.
- **CI/CD Integration**: Run focused backend tests after touching configuration or launch modules; run `pnpm test` before merging implementation.
- **Coverage Requirements**: Cover Runtime Settings parsing, legacy compatibility, command rendering, readiness validation, Stage Goal Handoff gating, and launch output capture.
- **Performance Testing**: Not required for the first PI integration.

## 7. Rationale & Context

Codex is currently embedded as the only launch abstraction. PI support should not be modeled as a special Codex command because PI has different command-line semantics, model naming, and unsupported goal behavior. A named Agent Harness separates Stage Agent selection from concrete command rendering and makes future harness kinds possible without changing the Stage Agent mapping structure again.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - Supplies issue metadata and project status transitions.
- **EXT-002**: Git - Supplies Agent Worktree and Task Branch isolation.

### Third-Party Services

- **SVC-001**: Codex CLI - Required for Codex Harness dispatch.
- **SVC-002**: PI CLI - Required for PI Harness dispatch.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Contract, Runtime State, Agent Worktrees, and Runtime Diagnostics.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Owns Runtime Settings parsing, readiness validation, orchestration, launch, and output capture.
- **PLT-002**: Shell-compatible command execution - Required for existing command template behavior.

### Compliance Dependencies

- **COM-001**: ADR coverage - Required because Agent Harness changes Runtime Contract semantics.
- **COM-002**: Secret handling - Documentation and tests must avoid committed token values.

## 9. Examples & Edge Cases

### PI Command Rendering

```text
Input command:
pi --model <model> --thinking <reasoning> --print --no-session

model:
openai/gpt-5.5

reasoningEffort:
medium

Rendered command:
pi --model 'openai/gpt-5.5' --thinking 'medium' --print --no-session
```

### Edge Cases

- A Workspace Repository has no `agents` object and has a legacy `codex` block: Symphony uses the legacy Codex Harness.
- A Workspace Repository defines both `codex` and `agents.codex`: Symphony uses `agents.codex` as the canonical Codex Harness and ignores the legacy block.
- A Stage Agent selects `pi` but `agents.pi` is missing: readiness blocks dispatch.
- A PI command omits `<model>` and `<reasoning>`: the command is allowed only when non-empty, but no automatic PI argument injection is required beyond token replacement.
- PI writes useful diagnostics to stderr and exits with non-zero status: Symphony captures stderr and applies existing retry behavior.

## 10. Implementation Handoff

Likely backend files:

- `apps/backend/lib/config.ml` for Runtime Settings parsing, Agent Harness normalization, readiness gaps, Stage Goal Handoff gating, and timeout lookup.
- `apps/backend/lib/orchestrator.ml` for harness-specific command rendering, prompt stdin launch, output capture, and per-running-task timeout selection.
- `apps/backend/lib/runtime_home.ml` only if missing-file Bootstrap defaults are intentionally extended; do not overwrite existing Runtime Contract files.
- `apps/backend/lib/runtime_state.ml` and frontend live-state parsing only if Runtime State naming changes are required after reviewing Codex-specific fields.
- `apps/backend/test/test_backend.ml` for focused Alcotest coverage near existing Runtime Settings, launch command, readiness, and Stage Goal Handoff tests.

Implementation risks:

- Accidentally treating `pi` as a Codex-compatible command string instead of a PI Harness kind.
- Applying Stage Goal Handoff readiness globally instead of only to Stage Agents whose selected Agent Harness is a Codex Harness.
- Continuing to read timeout settings from the legacy Codex block for PI-launched tasks.
- Changing Bootstrap defaults in `runtime_home.ml` without preserving Idempotent Bootstrap behavior.
- Renaming Runtime State fields in a way that breaks the Live Dashboard without corresponding parsing updates.

## 11. Validation Criteria

- `CONTEXT.md` defines Agent Harness, Codex Harness, and PI Harness.
- An ADR records the Runtime Contract decision.
- Runtime Settings examples are secret-free.
- Backend tests prove legacy Codex compatibility and PI command rendering.
- Readiness Gaps prevent unsupported Stage Goal Handoff on PI.
- Focused backend tests cover `agents.codex` precedence over the legacy `codex` block.
- `pnpm test` passes after implementation.

## 12. Related Specifications / Further Reading

- [Issue #59](https://github.com/MatheusBBarni/symphony-orchestrator/issues/59)
- [CONTEXT.md](../CONTEXT.md)
- [Agent Harness Runtime Settings ADR](../docs/adr/0021-agent-harness-runtime-settings.md)
- [Stage Goal Handoff ADR](../docs/adr/0007-stage-goal-handoff.md)
