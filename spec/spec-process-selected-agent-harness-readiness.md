---
title: Selected Agent Harness Readiness
version: 1.0
date_created: 2026-05-07
last_updated: 2026-05-07
owner: Product Repository maintainers
tags: [process, runtime-contract, agent-harness, readiness, pi, issue-70]
---

# Introduction

This specification defines how Personal Symphony readiness validation must treat optional Agent Harness definitions. A Workspace Repository must be able to run with only a Codex Harness, only a PI Harness, or a mixed set of Agent Harnesses without unused harness definitions blocking dispatch.

Source issue: [#70 Pi configuration shouldn't be required](https://github.com/MatheusBBarni/symphony-orchestrator/issues/70).

## 1. Purpose & Scope

The purpose is to make readiness validation depend on Agent Harnesses that enabled Stage Agent mappings can actually select for dispatch.

This specification applies to Product Repository backend readiness validation, Runtime Settings parsing behavior needed to identify selected harnesses, and backend tests. It does not change Agent Harness launch behavior, Runtime Contract defaults, or Stage Agent dispatch semantics.

In scope:

- Determine which Agent Harnesses are selected by enabled Stage Agent mappings.
- Apply PI executable and PI authentication readiness checks only to selected PI Harnesses.
- Preserve missing-harness readiness gaps for enabled Stage Agent mappings.
- Preserve structural validation for selected Agent Harness definitions.
- Support Codex-only, PI-only, and mixed Runtime Settings.

Out of scope:

- Changing Task Branch cleanup or auto-merge defaults.
- Replacing the GitHub Tracker or GitHub Issues + Projects model.
- Changing npm package files, `bin/symphony.js`, or packaged-binary behavior.
- Changing Bootstrap defaults in `apps/backend/lib/runtime_home.ml`.
- Adding cross-harness Stage Goal Handoff.
- Adding PI RPC mode, PI session resume, or PI-specific usage accounting.

## 2. Definitions

- **Workspace Repository**: The repository where a user runs Personal Symphony and where runtime configuration and state are created.
- **Product Repository**: The repository that contains the Personal Symphony source code.
- **Runtime Home**: The `.symphony/` directory that contains Personal Symphony configuration and runtime-owned files for a Workspace Repository.
- **Runtime Contract**: Repository-owned files inside the Runtime Home that define Personal Symphony behavior for a Workspace Repository.
- **Runtime Settings**: The `settings.json` portion of the Runtime Contract that defines tracker, project, orchestration, agent, server, and path configuration.
- **Stage Agent**: A Runtime Settings mapping from project statuses to a named agent instruction file, Agent Harness selection, and optional stage behavior.
- **Agent Harness**: A named Runtime Settings launch configuration that tells Symphony which non-interactive agent tool to run for a Stage Agent.
- **Codex Harness**: An Agent Harness whose launch semantics target Codex non-interactive execution.
- **PI Harness**: An Agent Harness whose launch semantics target PI non-interactive execution.
- **Stage Goal Handoff**: A stage-specific Codex handoff that sets a Codex goal when Symphony launches an agent for that stage.
- **Readiness Gap**: A configuration or environment problem that prevents dispatch while still allowing operator inspection.

## 3. Requirements, Constraints & Guidelines

- **REQ-001**: Readiness validation MUST identify Agent Harnesses selected by enabled Stage Agent mappings.
- **REQ-002**: When `stageAgents.enabled` is `false`, readiness validation MUST NOT require PI installation or PI authentication for any PI Harness solely because it is defined in Runtime Settings.
- **REQ-003**: When `stageAgents.enabled` is `true`, readiness validation MUST apply PI executable checks only to Agent Harnesses selected by enabled Stage Agent mappings whose `kind` is `pi`.
- **REQ-004**: When `stageAgents.enabled` is `true`, readiness validation MUST apply PI authentication checks only to Agent Harnesses selected by enabled Stage Agent mappings whose `kind` is `pi`.
- **REQ-005**: Readiness validation MUST preserve missing-harness gaps when an enabled Stage Agent mapping selects an Agent Harness that is not defined.
- **REQ-006**: Readiness validation MUST preserve the Stage Goal Handoff gap when an enabled Stage Agent mapping enables Stage Goal Handoff and selects a non-Codex harness.
- **REQ-007**: A Codex-only Runtime Contract MUST NOT require `pi` to be installed, PI authentication to exist, or `agents.pi` to be defined.
- **REQ-008**: A PI-only Runtime Contract MUST NOT require Codex installation or Codex authentication for dispatch when every enabled Stage Agent mapping selects a valid PI Harness.
- **REQ-009**: A mixed Runtime Contract MAY define both Codex and PI harnesses. Readiness validation MUST validate each enabled Stage Agent mapping against the Agent Harness it selects.
- **REQ-010**: If an unused PI Harness is invalid only because its executable is missing or PI authentication is missing, readiness validation MUST NOT report `agents.<name>.install` or `agents.<name>.auth` gaps for that unused PI Harness.
- **REQ-011**: If a selected PI Harness has missing executable or missing PI authentication, readiness validation MUST report the existing install or auth Readiness Gap for that selected PI Harness.
- **REQ-012**: Runtime Settings parsing MUST continue to support the legacy `codex` block as a Codex Harness fallback when `agents.codex` is absent.
- **CON-001**: The implementation MUST NOT change Runtime Contract defaults in `apps/backend/lib/runtime_home.ml`.
- **CON-002**: The implementation MUST NOT change Task Branch cleanup or auto-merge defaults.
- **CON-003**: The implementation MUST NOT replace the GitHub Tracker or GitHub Issues + Projects model.
- **CON-004**: The implementation MUST NOT change npm package files, `bin/symphony.js`, or packaged-binary behavior.
- **SEC-001**: Documentation, tests, and examples MUST NOT include secret values, token values, webhook URLs, or local `.env` contents.
- **GUD-001**: Documentation and tests SHOULD use the glossary terms Agent Harness, Codex Harness, PI Harness, Stage Agent, Runtime Settings, Runtime Contract, and Readiness Gap.
- **PAT-001**: Tests SHOULD exercise readiness behavior through public configuration parsing and readiness APIs rather than private helper behavior.

## 4. Interfaces & Data Contracts

### Runtime Settings Harness Selection

An enabled Stage Agent mapping selects its Agent Harness with this precedence:

1. `stageAgents.stages[].harness`, when present and non-empty.
2. `stageAgents.stages[].agent`, for legacy Runtime Settings compatibility.

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
    "enabled": true,
    "stages": [
      {
        "states": ["Todo"],
        "agent": "engineer",
        "harness": "codex"
      }
    ]
  }
}
```

In this example, `agents.codex` is selected and `agents.pi` is unused. Missing PI installation or PI authentication must not block dispatch.

### Readiness Gap Requirements

| Scenario | Required readiness behavior |
| --- | --- |
| Codex-only Runtime Settings with legacy `codex` block | Do not report PI install/auth gaps. |
| Codex-selected Stage Agents plus unused `agents.pi` | Do not report PI install/auth gaps for `agents.pi`. |
| PI-selected Stage Agent with missing PI executable | Report the existing `agents.<name>.install` gap. |
| PI-selected Stage Agent with missing PI authentication | Report the existing `agents.<name>.auth` gap. |
| Stage Agent selects missing harness | Report the existing `stageAgents.<agent>.harness` gap. |
| PI-selected Stage Agent enables Stage Goal Handoff | Report the existing `stageAgents.<agent>.goal` gap. |

### Backend Implementation Boundary

The primary implementation boundary is `apps/backend/lib/config.ml`.

Expected responsibilities:

- Resolve selected Agent Harness names from enabled Stage Agent mappings.
- Look up selected Agent Harness definitions.
- Apply PI install/auth environment validation only for selected PI Harness definitions.
- Keep existing readiness gap messages unless wording must be corrected for accuracy.

## 5. Acceptance Criteria

- **AC-001**: Given Runtime Settings with only the legacy `codex` block and enabled Codex-backed Stage Agents, When readiness is evaluated, Then no PI install or PI authentication Readiness Gap is reported.
- **AC-002**: Given Runtime Settings with `agents.codex` selected by every enabled Stage Agent and an unused `agents.pi`, When `pi` is not installed, Then readiness does not report `agents.pi.install`.
- **AC-003**: Given Runtime Settings with `agents.codex` selected by every enabled Stage Agent and an unused `agents.pi`, When PI authentication is missing, Then readiness does not report `agents.pi.auth`.
- **AC-004**: Given an enabled Stage Agent selects `harness: "pi"`, When the PI executable is missing, Then readiness reports the existing PI install Readiness Gap for the selected PI Harness.
- **AC-005**: Given an enabled Stage Agent selects `harness: "pi"`, When PI authentication is missing, Then readiness reports the existing PI authentication Readiness Gap for the selected PI Harness.
- **AC-006**: Given an enabled Stage Agent selects a missing harness, When readiness is evaluated, Then readiness reports the existing missing-harness gap.
- **AC-007**: Given Runtime Settings are PI-only for all enabled Stage Agents, When the selected PI Harness is valid, Then readiness does not require Codex installation, Codex authentication, or a usable legacy Codex command path.
- **AC-008**: Given a PI-backed Stage Agent enables Stage Goal Handoff, When readiness is evaluated, Then readiness reports the existing non-Codex Stage Goal Handoff gap.
- **AC-009**: Given `stageAgents.enabled` is `false`, When Runtime Settings define an unauthenticated PI Harness, Then readiness does not report PI install or PI authentication gaps for that harness.
- **AC-010**: Given implementation is complete, When backend tests run, Then focused tests cover Codex-only, PI-only, mixed selected, and mixed unused-PI configurations.

## 6. Test Automation Strategy

- **Test Levels**: Backend unit and integration-style tests using temporary Workspace Repository fixtures.
- **Frameworks**: OCaml Alcotest through `pnpm test`.
- **Test Data Management**: Use temporary Runtime Home directories and synthetic `.symphony/settings.json` files. Use fake harness commands where command execution is not the behavior under test.
- **CI/CD Integration**: Run targeted backend tests after touching `apps/backend/lib/config.ml`; run `pnpm test` before merging.
- **Coverage Requirements**: Cover Codex-only readiness, PI-only readiness, selected PI readiness, unused PI readiness, disabled Stage Agent readiness, missing harness readiness, and PI Stage Goal Handoff readiness.
- **Performance Testing**: Not required.

## 7. Rationale & Context

PI support is optional. Treating every configured PI Harness as an active dependency makes Runtime Settings examples and mixed-harness configurations fragile because an unused PI definition can block a Codex-only run.

The correct readiness boundary is the Stage Agent mapping because dispatch happens through a Stage Agent. Environment checks for a concrete launch tool are useful only when that launch tool can be selected for work. This keeps Codex-only, PI-only, and mixed Runtime Contracts valid without weakening validation for selected PI Harnesses.

## 8. Dependencies & External Integrations

### External Systems

- **EXT-001**: GitHub Issues + Projects - Supplies issue records and project status transitions for the GitHub Tracker path.
- **EXT-002**: Git - Supplies Workspace Repository branch state, Agent Worktrees, and Task Branches.

### Third-Party Services

- **SVC-001**: Codex CLI - Required only when a selected Codex Harness dispatches work.
- **SVC-002**: PI CLI - Required only when a selected PI Harness dispatches work.

### Infrastructure Dependencies

- **INF-001**: Runtime Home - Stores Runtime Contract files, Runtime State, Agent Worktrees, and Runtime Diagnostics.

### Technology Platform Dependencies

- **PLT-001**: OCaml backend - Owns Runtime Settings parsing, readiness validation, and orchestration.
- **PLT-002**: Shell-compatible command execution - Required for existing Agent Harness command templates.

### Data Dependencies

- **DAT-001**: `.symphony/settings.json` - Defines Agent Harnesses and Stage Agent mappings.
- **DAT-002**: `.symphony/agents/*` - Defines Stage Agent prompt files referenced by Stage Agent mappings.

### Compliance Dependencies

- **COM-001**: Context glossary alignment - Use existing domain terms from `CONTEXT.md`.
- **COM-002**: Secret handling - Do not commit token values, webhook URLs, or local `.env` contents.

## 9. Examples & Edge Cases

### Codex Selected, PI Unused

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
      "command": "/missing/pi --print",
      "model": "openai/gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    }
  },
  "stageAgents": {
    "enabled": true,
    "stages": [
      {
        "states": ["Todo"],
        "agent": "engineer",
        "harness": "codex"
      }
    ]
  }
}
```

Expected result: no `agents.pi.install` or `agents.pi.auth` readiness gap, because `agents.pi` is not selected by any enabled Stage Agent mapping.

### PI Selected

```json
{
  "agents": {
    "pi": {
      "kind": "pi",
      "command": "/missing/pi --print",
      "model": "openai/gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    }
  },
  "stageAgents": {
    "enabled": true,
    "stages": [
      {
        "states": ["Todo"],
        "agent": "engineer",
        "harness": "pi"
      }
    ]
  }
}
```

Expected result: `agents.pi.install` readiness gap when `/missing/pi` is unavailable. If the executable is available but PI authentication is absent, report `agents.pi.auth`.

### Edge Cases

- A Stage Agent mapping omits `harness`: select the Agent Harness whose name matches `agent`.
- A Stage Agent mapping selects an unknown harness: report the existing missing-harness gap.
- A Stage Agent mapping selects a PI Harness and enables Stage Goal Handoff: report the existing non-Codex goal gap.
- `stageAgents.enabled` is `false`: do not perform selected-harness environment checks because no Stage Agent mapping can dispatch.
- An unused PI Harness has an unknown `kind` or blank required fields: implementation may keep structural validation if the Product Repository already treats all malformed harness definitions as invalid Runtime Settings.

## 10. Validation Criteria

- `spec/spec-process-selected-agent-harness-readiness.md` exists and follows the repository specification format.
- The issue description for issue #70 contains the current PRD followed by this SPEC content.
- Issue #70 no longer has the `Need SPEC` label.
- Backend tests are added or updated during implementation to prove selected-harness readiness behavior.
- `pnpm test` passes before implementation is merged.

## 11. Related Specifications / Further Reading

- [Agent Harness Runtime Settings](./spec-architecture-agent-harness-runtime-settings.md)
- [Agent Harness Runtime Settings ADR](../docs/adr/0021-agent-harness-runtime-settings.md)
- [Personal Symphony Context Glossary](../CONTEXT.md)
