# Claude Code Harness Integration

## Overview

Symphony should make execution Harnesses first-class in Runtime Settings and add Claude Code as a supported Harness. This solves the current configuration ambiguity where `agents` is used for Codex/PI Harness definitions while logical Stage Agents like `planner`, `engineer`, and `reviewer` need to become explicit `settings.json -> agents` definitions.

V1 is a Strategic Bet: introduce `harnesses` as the provider-neutral execution adapter map, define logical agents under `agents`, let each agent select a Harness and override execution parameters, preserve safe legacy compatibility, support Claude through CLI `stream-json`, and make Harness loop behavior explicit instead of Codex-specific.

## Problem

Symphony already has the internal concept of an Agent Harness, but the Runtime Contract vocabulary is overloaded. Operators define Codex and PI under `agents`, while planner/engineer/reviewer are the logical agents that decide what kind of work happens. This makes the Runtime Contract harder to explain and makes every new execution provider feel like an exception.

Issue 52 asks for Claude Code integration, but the real product problem is broader: Workspace Repositories need a clear way to configure multiple execution backends and assign them to logical agents. Claude raises this now because it does not currently share Codex `/goal` loop semantics, so the loop command must become Harness configuration rather than hard-coded Codex behavior.

### Market Data

AI coding tools are moving toward async task execution, worktree isolation, provider choice, visible logs, budget controls, and PR handoff. Claude Code exposes non-interactive CLI modes, `stream-json` output, turn/budget controls, permission modes, hooks, and an Agent SDK for embedding its loop. Competitors such as Copilot agent, Codex, Jules, Devin, Bernstein, and AgentsRoom reinforce provider-neutral orchestration as the emerging expectation.

## Summary / Differentiator

Symphony's differentiator is not "Claude wrapper." It is a Workspace Repository-owned Runtime Contract that routes logical Stage Agents to explicit, bounded execution Harnesses while preserving Task Branch, Agent Worktree, Runtime State, verification, and tracker semantics.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | First-class `harnesses` settings | Critical | Add `harnesses` for execution adapters such as `codex`, `pi`, and `claude`. |
| F2 | Harness loop configuration | Critical | Add per-Harness `loop.enabled` and `loop.command`, allowing Codex to use `/goal` and Claude to start disabled unless a future Claude command is configured. |
| F3 | Settings-level logical agents | Critical | Define logical agents under `settings.json -> agents`; each agent selects a named Harness and can override model/reasoning/timeouts. |
| F4 | Stage Agent binding | Critical | Stages select logical agents; logical agents select Harnesses. |
| F5 | Migration diagnostics | Critical | Preserve legacy `codex`; treat old harness-shaped `agents.*` as migration input, and report readiness errors when users must move definitions to `harnesses`. |
| F6 | Claude Harness V1 | High | Add Claude as a bounded Harness using CLI `stream-json` to perform the same class of non-interactive task execution as `codex exec`. |
| F7 | Runtime Contract documentation | High | Update `CONTEXT.md`, README examples, and ADR references for Agent Harnesses, logical agents, loop configuration, and migration behavior. |
| F8 | Readiness and failure semantics | High | Surface missing executables/authentication, unsupported loop commands, timeouts, and Claude non-parity as readiness gaps or deterministic task failures. |

## Harness Configuration Shape

```json
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
}
```

## Agent Configuration Shape

```json
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
```

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Runtime Settings parser | Parse `harnesses` as execution definitions and `agents` as logical agent definitions. |
| Bootstrap | Create missing defaults idempotently without overwriting user-edited Runtime Contract files. |
| Stage Agents | Preserve stage selection by logical agent while moving logical agent execution settings into `settings.json -> agents`. |
| Orchestrator launch path | Reuse selected Harness command rendering, Agent Worktree isolation, prompt piping, and timeout handling. |
| Stage Goal Handoff | Replace hard-coded Codex loop assumptions with per-Harness `loop` configuration. |
| Runtime State / Dashboard | Show selected Harness identity; exact naming changes are deferred to the TechSpec. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Mixed-Harness adoption | >= 2 Harnesses configured in 1 Workspace Repository | Inspect dogfood Runtime Settings |
| Claude dispatch reliability | >= 90% Claude-selected tasks launch without readiness/config errors | Runtime State issue errors |
| Compatibility preservation | 100% existing Codex/PI fixtures still pass or fail with intentional migration diagnostics | Backend test suite |
| Configuration clarity | >= 80% reduction in ambiguous `agents` examples | Compare old/new Runtime Contract docs |
| Observability coverage | 100% running tasks show selected Harness identity | Runtime State snapshots |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Must do |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Strategic Bet

## Council Insights

- **Recommended approach:** Introduce first-class `harnesses`, make `settings.json -> agents` the home for logical agent definitions, preserve safe legacy compatibility, configure Harness loop behavior explicitly, and ship Claude through `stream-json`.
- **Key trade-offs:** Cleaner Runtime Contract vs migration complexity; explicit Harness loops vs hard-coded Codex behavior; real Claude support vs false `/goal` parity; provider-neutral foundation vs V1 scope.
- **Risks identified:** Claude semantic drift, configuration ambiguity during migration, expanded command execution surface, unsupported loop commands, and unresolved Runtime State/dashboard naming.
- **Stretch goal (V2+):** Define a provider-neutral Harness capability/control-plane model with permissions, budgets, tools, structured output, loop support, and dashboard observability.

## Out of Scope (V1)

- **Simulating Codex `/goal` for Claude** — Claude has no equivalent loop command today; if Anthropic adds one, users can configure it through Harness `loop`.
- **Silent precedence between `harnesses.*` and legacy `agents.*`** — ambiguous mixed configuration should become a readiness error.
- **Harness marketplace or reusable catalog** — useful later, but V1 should validate the Runtime Contract shape first.
- **Provider-specific secret storage in Runtime Settings** — Runtime Settings may reference env var names, never secret values.
- **Runtime State field renaming decisions** — define exact naming and migration in the TechSpec.

## Architecture Decision Records

- [ADR-001: First-Class Harness Runtime Settings](adrs/adr-001.md) — Accepts `harnesses` as the execution adapter map, `agents` as logical agent definitions, explicit Harness loop configuration, readiness errors for ambiguous legacy config, and Claude V1 through CLI `stream-json`.

## Open Questions

- What exact Runtime State/dashboard naming changes belong in the TechSpec?
