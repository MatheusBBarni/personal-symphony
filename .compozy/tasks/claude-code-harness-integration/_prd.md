# Claude Code Harness Integration PRD

## Overview

Claude Code Harness Integration makes Symphony's Runtime Settings easier to understand and safer to extend. It introduces a clear product distinction between execution Harnesses and logical agents:

- `harnesses` defines non-interactive execution backends such as Codex, Claude, and PI.
- `agents` defines logical agents such as planner, engineer, and reviewer, each selecting a Harness and execution overrides.
- `stageAgents` continues to route project states to logical agents.

The first release optimizes for operator configuration clarity. Claude Code support is included, but the product outcome is broader than adding one provider: operators should be able to configure mixed-Harness agent workflows without confusing agent roles, execution commands, and loop behavior.

## Goals

- Let operators configure planner, engineer, and reviewer across different Harnesses without ambiguity.
- Make `harnesses` the only first-class location for execution backend definitions.
- Make `agents` the first-class location for logical agent execution selection.
- Add Claude Code as a selectable Harness using CLI `stream-json`.
- Make Harness loop behavior explicit through `loop.enabled` and `loop.command`.
- Block ambiguous legacy harness-shaped `agents.*` configuration with clear readiness remediation.
- Preserve Workspace Repository ownership of the Runtime Contract and Bootstrap idempotency.

## User Stories

**Agent platform operator**

- As an agent platform operator, I want to see execution backends under `harnesses` so that I know where Codex, Claude, and PI commands belong.
- As an agent platform operator, I want planner, engineer, and reviewer under `agents` so that I can assign each role to the right Harness.
- As an agent platform operator, I want a readiness error when old `agents.*` Harness settings are present so that I can migrate before dispatch behaves ambiguously.
- As an agent platform operator, I want Claude available as a Harness so that I can route selected agent roles to Claude Code.

**Workspace Repository maintainer**

- As a Workspace Repository maintainer, I want existing Runtime Contract files preserved during Bootstrap so that my local settings are not overwritten.
- As a Workspace Repository maintainer, I want clear examples for mixed-Harness configuration so that I can review changes without reading backend source code.

**Task supervisor**

- As a task supervisor, I want running work to show which Harness was selected so that I can understand task behavior when agents differ by provider.
- As a task supervisor, I want unsupported loop behavior surfaced before dispatch so that failed assumptions do not become task retries.

## Core Features

### F1: First-Class Harness Definitions

Runtime Settings must provide `harnesses` as the product home for execution backends. Harness definitions cover provider identity, command text, and loop behavior.

Expected user capability:

- Define `harnesses.codex`, `harnesses.claude`, and `harnesses.pi`.
- Read examples that show execution commands only under `harnesses`.
- Understand that provider secrets are referenced by environment variable names only, not stored as values.

### F2: Logical Agent Definitions

Runtime Settings must provide `agents` as the product home for logical agent execution selection.

Expected user capability:

- Define `agents.planner`, `agents.engineer`, and `agents.reviewer`.
- Assign each logical agent to a Harness.
- Override model, reasoning effort, and timeout settings per logical agent.
- Keep stage/status routing separate from agent execution selection.

### F3: Harness Loop Configuration

Harness loop behavior must be configurable instead of Codex-specific.

Expected user capability:

- Enable Codex loop behavior with `loop.enabled: true` and `loop.command: "/goal"`.
- Keep Claude loop behavior disabled by default.
- Configure a future Claude loop command if Anthropic introduces one.

### F4: Claude Harness V1

Claude Code must be available as a selectable Harness.

Expected user capability:

- Route a logical agent, such as `engineer`, to the Claude Harness.
- Use Claude CLI `stream-json` for non-interactive task execution.
- See clear readiness errors for missing Claude command/authentication expectations.

### F5: Migration Readiness Diagnostics

Legacy harness-shaped `agents.*` settings must not silently continue.

Expected user capability:

- Receive a blocking readiness error when old `agents.codex`, `agents.pi`, or similar Harness definitions remain in `agents`.
- See remediation that tells the operator to move execution definitions into `harnesses`.
- Avoid silent precedence rules between `harnesses.*` and legacy `agents.*`.

### F6: Documentation And Examples

Runtime Contract docs must teach the new model directly.

Expected user capability:

- Copy a complete `harnesses` example.
- Copy a complete `agents` example.
- Understand how `stageAgents` relates to logical agents.
- Understand that exact Runtime State/dashboard naming changes are deferred to the TechSpec.

## User Experience

1. An operator opens `.symphony/settings.json`.
2. They see `harnesses` with provider execution definitions for Codex, Claude, and PI.
3. They see `agents` with planner, engineer, and reviewer entries that each select a Harness and set execution preferences.
4. They see `stageAgents` routing project states to logical agent names.
5. If old harness-shaped `agents.*` entries remain, Symphony reports a readiness error before dispatch.
6. The readiness message points to the migration: move execution fields into `harnesses`, keep logical agent selection in `agents`.
7. When tasks run, the operator can identify which Harness was selected for each logical agent.

Example target settings shape:

```json
{
  "harnesses": {
    "codex": {
      "kind": "codex",
      "command": "codex exec",
      "loop": {
        "enabled": true,
        "command": "/goal"
      }
    },
    "claude": {
      "kind": "claude",
      "command": "claude -p --output-format stream-json",
      "loop": {
        "enabled": false,
        "command": ""
      }
    },
    "pi": {
      "kind": "pi",
      "command": "pi --model <model> --thinking <reasoning> --print --no-session",
      "loop": {
        "enabled": false,
        "command": ""
      }
    }
  },
  "agents": {
    "planner": {
      "harness": "codex",
      "model": "gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    },
    "engineer": {
      "harness": "claude",
      "model": "opus-4.7",
      "reasoningEffort": "xhigh",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    },
    "reviewer": {
      "harness": "pi",
      "model": "openai-codex/gpt-5.5",
      "reasoningEffort": "high",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    }
  }
}
```

## High-Level Technical Constraints

- Runtime Settings remain part of the Workspace Repository-owned Runtime Contract.
- Bootstrap must remain idempotent and must not overwrite user-edited Runtime Contract files.
- Runtime Settings may reference secret environment variable names but must not include secret values.
- Claude Code V1 uses CLI `stream-json`.
- Harness loop behavior must be explicit and configurable per Harness.
- Exact Runtime State/dashboard naming changes are deferred to the TechSpec.

## Non-Goals (Out of Scope)

- Simulating Codex `/goal` for Claude.
- Keeping legacy harness-shaped `agents.*` settings running silently.
- Automatically rewriting `.symphony/settings.json`.
- Moving stage/status routing into `agents`.
- Defining agent prompt/instruction file paths inside `agents` for MVP.
- Creating a Harness marketplace or reusable Harness catalog.
- Deciding exact Runtime State/dashboard field renames in the PRD.

## Phased Rollout Plan

### MVP (Phase 1)

- Introduce `harnesses`.
- Introduce logical `agents`.
- Add per-Harness `loop`.
- Add Claude Harness V1 using `stream-json`.
- Add blocking readiness diagnostics for legacy harness-shaped `agents.*`.
- Update Runtime Contract docs and examples.

Success criteria:

- A Workspace Repository can configure planner, engineer, and reviewer with different Harnesses.
- Legacy harness-shaped `agents.*` produces a clear readiness error.
- Claude can be selected as a Harness for a logical agent.

### Phase 2

- Improve operator-facing observability for selected Harness identity.
- Decide Runtime State/dashboard naming cleanup in the TechSpec.
- Add richer readiness remediation examples.

Success criteria:

- Operators can diagnose mixed-Harness runs from Runtime State and dashboard views without Codex-specific confusion.

### Phase 3

- Evaluate whether provider-neutral Harness capability controls are needed.
- Consider budgets, tool permissions, structured output expectations, and reusable Harness presets.

Success criteria:

- New Harnesses can be added without changing the user's mental model.

## Success Metrics

| Metric | Target | Measurement |
| --- | --- | --- |
| Mixed-Harness configuration clarity | 100% of documented examples separate `harnesses` and `agents` | Documentation review |
| Primary workflow success | Operators can configure planner, engineer, and reviewer across different Harnesses without ambiguity | Dogfood Workspace Repository validation |
| Legacy ambiguity prevention | 100% of legacy harness-shaped `agents.*` configs produce readiness remediation | Backend readiness scenarios |
| Claude selection | Claude can be selected for at least one logical agent | Runtime Settings validation |
| Bootstrap safety | 0 overwritten user-edited Runtime Contract files | Bootstrap behavior verification |

## Risks and Mitigations

- **Migration friction:** Blocking readiness errors may interrupt existing users.
  - Mitigation: make remediation direct and include before/after examples.

- **Claude expectation mismatch:** Users may expect Claude to support Codex `/goal`.
  - Mitigation: make loop behavior visible in `harnesses` and default Claude loop to disabled.

- **Configuration sprawl:** Adding both `harnesses` and logical `agents` may feel like more settings.
  - Mitigation: keep MVP `agents` small and limited to Harness selection plus execution overrides.

- **Provider headline dilution:** Users asking for Claude may perceive the Runtime Contract work as indirect.
  - Mitigation: include Claude Harness V1 in the MVP and show a concrete engineer-on-Claude example.

## Architecture Decision Records

- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Accepts `harnesses` as the execution adapter map, `agents` as logical agent definitions, explicit Harness loop configuration, readiness errors for ambiguous legacy config, and Claude V1 through CLI `stream-json`.
- [ADR-002: Clarity-First PRD Scope](adrs/adr-002.md) — Selects configuration clarity as the PRD's primary product outcome and rejects warning-based legacy compatibility for harness-shaped `agents.*`.

## Open Questions

- What exact Runtime State/dashboard naming changes belong in the TechSpec?
- What exact remediation text should the readiness error show for old harness-shaped `agents.*` settings?
- Should the docs include a "minimal single-Harness" example in addition to the mixed-Harness example?
