# Cursor CLI Harness Integration

## Overview

Symphony should add Cursor CLI as a new `Agent Harness` so `Workspace Repositories` can route `Logical Agents` to
Cursor inside the existing provider-neutral `Runtime Contract`. This is for operators who already use Cursor CLI and
want real provider choice without giving up `Agent Worktree`, `Task Branch`, readiness gating, Runtime State
visibility, or Bootstrap ownership of settings.

V1 should be a bounded quick win: complete enough for day-to-day attended use, but narrow enough to avoid redesigning
the broader Harness system around one provider. The hybrid scope adds one small compounding asset alongside the Cursor
integration itself: a reusable Harness onboarding checklist or certification path so future Harness additions do not
repeat the same discovery work from scratch.

## Problem

Symphony already has the product model needed for multiple execution backends. `stageAgents` route statuses, `agents`
select execution roles, and `harnesses` own provider launch behavior. In practice, though, the current Runtime
Contract only ships first-class defaults for `codex`, `claude`, and `pi`. That leaves a gap for operators who already
standardized on Cursor CLI and want Symphony to orchestrate work through the tool they actually use.

The product problem is not "add another command string." It is "preserve a coherent `Agent Harness` model while
expanding provider choice." If Cursor is bolted on as a compatibility shortcut, Symphony weakens readiness,
observability, and operator trust. If Cursor is treated as a broader platform redesign trigger, a targeted operator
request turns into a larger architecture project and loses the quick-win learning loop.

For the target user, the current workaround is poor. They can either stay outside Symphony's orchestrated workflow, or
try to approximate Cursor support through unsupported command-level customization that does not express Cursor-specific
auth, output, or reliability expectations. That creates ambiguity in the `Runtime Contract` and makes provider choice
look more mature than it is.

### Market Data

Official Cursor documentation positions `cursor-agent` as a terminal agent for non-interactive scripting and CI, with
`--print`, `json`, and `stream-json` output modes, project rule loading via `AGENTS.md`, and browser-login or API-key
authentication. Cursor also documents permission controls, direct file modification in scripted mode with `--force`,
and a broader product direction toward cloud and background agents. That indicates two things: operator demand for
Cursor-based workflows is real, and the execution surface is powerful enough that Symphony should model Cursor
explicitly rather than hide it behind a generic shell command.

Relevant sources:
- Cursor CLI overview: <https://docs.cursor.com/en/cli/overview>
- Cursor CLI parameters: <https://docs.cursor.com/en/cli/reference/parameters>
- Cursor CLI output formats: <https://docs.cursor.com/en/cli/reference/output-format>
- Cursor CLI authentication: <https://docs.cursor.com/en/cli/reference/authentication>
- Cursor CLI headless mode: <https://docs.cursor.com/en/cli/headless>
- Cursor permissions: <https://docs.cursor.com/cli/reference/permissions>
- Cursor background agents: <https://docs.cursor.com/en/background-agents>
- Cursor pricing: <https://cursor.com/pricing>

## Summary / Differentiator

The differentiator is not "Symphony can launch Cursor." The differentiator is that Symphony remains a
`Workspace Repository`-owned orchestrator with explicit `Agent Harness` boundaries, selected-Harness readiness,
`Agent Worktree` isolation, `Task Branch` semantics, and product-owned Runtime State across multiple providers.
Cursor support becomes evidence that the Runtime Contract is truly provider-neutral.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Cursor Harness kind | Critical | Add `kind: "cursor"` under `harnesses` so operators can define Cursor as a first-class `Agent Harness`. |
| F2 | Selected-Harness readiness | Critical | Validate Cursor install and authentication only when a selected `Logical Agent` resolves to a Cursor Harness. |
| F3 | Cursor command rendering | Critical | Support a documented non-interactive Cursor command shape with provider-local rendering for model and related execution fields where applicable. |
| F4 | Structured output and raw-log fallback | Critical | Parse documented Cursor print-mode output when available, but preserve raw stdout and stderr logs as the fallback observability path. |
| F5 | Runtime State Harness visibility | High | Surface Cursor Harness identity in running-task views the same way Symphony already does for other Harnesses. |
| F6 | Bootstrap and docs examples | High | Add Cursor examples to Bootstrap defaults and Runtime Contract docs without changing the `harnesses` / `agents` / `stageAgents` separation. |
| F7 | Bounded safety defaults | High | Ship Cursor support with conservative defaults and clear scope boundaries for attended day-to-day use rather than broad unattended autonomy claims. |
| F8 | Harness onboarding checklist | Medium | Add a small reusable checklist or certification path for future Harness additions so Cursor onboarding compounds into a repeatable product pattern. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Runtime Settings parser | Parse `kind: "cursor"` inside the existing `harnesses` map. |
| `Logical Agent` selection | Allow `agents.<name>.harness` to reference a Cursor Harness exactly like `codex`, `claude`, or `pi`. |
| Orchestrator launch path | Reuse prompt piping, `Agent Worktree` execution, process-group control, and stdout/stderr capture. |
| Readiness model | Extend selected-Harness readiness checks with Cursor install/auth validation and deterministic remediation. |
| Runtime State | Reuse existing Harness identity fields so Cursor appears as another selected execution backend. |
| Bootstrap | Seed optional Cursor examples without overwriting user-edited Runtime Contract files. |
| Protected Path Policy | Preserve existing pre-commit and pre-integration protections for Cursor-produced edits. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Cursor dispatch success rate | >= 90% | Percentage of Cursor-selected tasks that pass readiness and launch without configuration failure in dogfood runs. |
| Time to first successful Cursor run | <= 15 minutes | Measure from operator opening Runtime Contract docs to first successful Cursor-selected dispatch in a prepared `Workspace Repository`. |
| Structured observability coverage | >= 80% | Percentage of successful Cursor runs that populate structured activity fields beyond raw logs. |
| Harness identity visibility | 100% | Every running Cursor-selected task shows `harness_name` and `harness_kind` in Runtime State snapshots. |
| Early operator adoption | >= 2 Workspace Repositories in 30 days | Count real repositories that configure and use a Cursor Harness after release. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Quick Win

## Council Insights

- **Recommended approach:** Add Cursor as a bounded first-class `Agent Harness`, keep Cursor-specific behavior inside
  the Harness boundary, and label support conservatively enough to account for beta CLI churn.
- **Key trade-offs:** fast provider-choice validation vs beta-contract instability; day-to-day usability vs
  conservative security posture; first-class Harness clarity vs the temptation to ship a weaker compatibility shim.
- **Risks identified:** Cursor CLI contract drift, over-promising unattended autonomy, weak auth/readiness probes, and
  provider-specific behavior leaking into generic Runtime Settings.
- **Stretch goal (V2+):** turn the Cursor work into a formal Harness onboarding or certification path that future
  providers can follow.

## Out of Scope (V1)

- **Cursor background or cloud-agent orchestration** — Symphony should not absorb remote-agent semantics before
  validating the local CLI Harness path.
- **Broad provider-capability redesign** — permissions, autonomy, and enterprise controls should not become new
  top-level Runtime Contract abstractions based on one provider.
- **Codex-style loop-parity claims** — Cursor should not be treated as having `Harness Loop` semantics unless the
  documented CLI behavior proves it.
- **Automatic Runtime Contract migration** — Symphony should surface readiness remediation, not silently rewrite
  user-edited settings.
- **Unbounded unattended execution claims** — V1 should support attended day-to-day operator workflows, not market
  Cursor as a fully autonomous safe executor.

## Architecture Decision Records

- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Accepts `kind: "cursor"` as a
  first-class `Agent Harness` while keeping scope bounded and reusable.

## Open Questions

- What exact default Cursor command shape should Bootstrap and docs recommend for the first supported
  non-interactive path?
- Should Cursor structured-output parsing target `stream-json` first, `json` first, or both with one canonical
  fallback order?
- What is the minimum acceptable auth-readiness probe that is deterministic without becoming provider-fragile?
- Should Cursor V1 ship with an explicitly "experimental" support label in docs and Runtime State messaging, or is
  narrow scope alone enough?
- How much of the Harness onboarding checklist belongs in product docs versus test fixtures and backend verification?
