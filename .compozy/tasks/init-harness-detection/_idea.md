# Init Harness Detection

## Overview

Symphony should reduce first-run setup friction by making `symphony init` generate `.symphony/settings.json` from a narrow local Agent Harness detection pass when the Runtime Contract does not already exist. The feature is for individual developers creating a new Workspace Repository who want Bootstrap to produce usable Runtime Settings without manually editing Harness routes first.

V1 should detect supported installed and authenticated Harnesses, select one reasonable default, explain the selected/default Harness, and show install or authentication guidance when no usable Harness is found. Detection seeds the missing Runtime Contract only; runtime readiness remains authoritative before dispatch.

## Problem

Bootstrap currently writes a static Runtime Settings template when `.symphony/settings.json` is missing. The template defines Codex, Claude, Cursor, Cursor direct-write, and PI Agent Harnesses, then routes planner work to Codex, engineer work to Claude, and reviewer work to PI. That shape is valid, but it can make a new Workspace Repository look broken on a developer machine that has only one supported Harness installed.

The friction appears at the worst moment: before the operator understands Harness definitions, Logical Agents, Stage Agent routing, or readiness gaps. The user's real goal is to start orchestration, not debug why a static first-run template selected a Harness they cannot run.

### Market Data

AI coding agents are now a multi-tool local CLI market. OpenAI Codex CLI, Claude Code, Cursor CLI, and OpenCode all expose distinct local install and auth flows. A 2026 empirical study reports 932,791 agent-authored PRs across 116,211 repositories and 72,189 developers, while a task-stratified comparison finds no single coding agent dominates every task type. Symphony should therefore adapt first-run defaults to the operator's available local Harness instead of hardcoding one universal winner.

## Summary / Differentiator

Most coding-agent CLIs configure one tool. Symphony can configure orchestration across multiple local Harnesses while preserving its existing separation between Agent Harnesses, Logical Agents, Stage Agents, Runtime Settings, and runtime readiness.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Local Harness detection | Critical | Detect supported usable Harnesses during Bootstrap without writing secrets or mutating existing Runtime Contract files. |
| F2 | Generated selected default | Critical | Generate missing Runtime Settings so default Logical Agents point at a reasonable detected Harness. |
| F3 | Bootstrap explanation | High | Print which Harness was selected, why it was selected, and what remains provisional until runtime readiness validates it. |
| F4 | No-Harness guidance | High | If no supported usable Harness is found, still create settings and show concrete install/auth remediation. |
| F5 | Idempotency preservation | Critical | Never overwrite existing `.symphony/settings.json`, prompt, agent files, `.env`, or user edits. |
| F6 | Deterministic test seam | High | Support fake probe results in tests so Bootstrap behavior does not depend on the test runner's machine. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| `Runtime_home.bootstrap` | Replace static settings creation with generated JSON only when settings are missing. |
| `Config` readiness helpers | Reuse or extract supported Harness command/auth checks without making Bootstrap dispatch authority. |
| Runtime Settings `harnesses` / `agents` | Keep Harness definitions separate from Logical Agent selection. |
| Stage Agents | Continue routing by Logical Agent name, never by stage-level Harness shortcuts. |
| README and ADR 0021 | Document adaptive Bootstrap once implementation proceeds. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| First-run usable settings | >= 90% | New init runs on machines with one supported authenticated Harness have no selected-Harness install/auth readiness gap. |
| Manual Harness edits | -70% | Compare support notes or telemetry-free local test scenarios requiring immediate Harness edits after init. |
| No-Harness remediation | 100% | Tests assert no-Harness Bootstrap prints install/auth guidance for supported Harnesses. |
| Idempotency | 100% | Tests assert existing `.symphony/settings.json` is byte-preserved on repeated Bootstrap. |
| Scenario coverage | >= 6 cases | Backend tests cover Codex-only, Claude-only, Cursor-only, PI-only, multi-Harness, and no-Harness scenarios. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| Impact | How much more valuable does this make the product? | Strong |
| Reach | What % of users would this affect? | Strong |
| Frequency | How often would users encounter this value? | Maybe |
| Differentiation | Does this set us apart or just match competitors? | Strong |
| Defensibility | Is this easy to copy or does it compound over time? | Maybe |
| Feasibility | Can we actually build this? | Strong |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Ship adaptive Bootstrap as a provisional, auditable seed for missing Runtime Settings.
- **Key trade-offs:** Detection improves activation but can become stale; generated defaults must remain explainable and repairable.
- **Risks identified:** PATH spoofing, secret leakage, stale auth, overconfident "ready" language, and boundary drift between Harnesses and Logical Agents.
- **Mitigations:** Use allowlisted local detection, write no credential data, keep runtime readiness authoritative, and preserve normal Runtime Settings semantics.
- **Stretch goal (V2+):** Add a separate Harness setup doctor that detects stale settings and suggests repairs without rewriting the Runtime Contract automatically.

## Out of Scope (V1)

- **Dynamic per-task Harness routing** - Changes runtime semantics and makes dispatch harder to debug.
- **Team Harness policy** - Useful later, but V1 targets an individual developer's local first run.
- **Full interactive setup wizard** - Larger scope and more secret-adjacent UX than needed for first-run activation.
- **Automatic rewrites of existing settings** - Violates Idempotent Bootstrap and risks overwriting user intent.
- **Secret or token persistence** - Runtime Settings must reference env var names only, never secret values.

## Architecture Decision Records

- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) - Bootstrap may use local detection to seed missing Runtime Settings while preserving runtime readiness authority.

## Open Questions

- What deterministic fallback order should select the default when multiple Harnesses are usable?
- Should unavailable supported Harness definitions remain in generated settings for editability, or should V1 include only detected Harnesses?
- What exact no-Harness guidance should be printed for Codex, Claude, Cursor, and PI?
