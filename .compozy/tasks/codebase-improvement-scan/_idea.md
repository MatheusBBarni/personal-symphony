# Codebase Improvement Scan Idea

## Overview

Create a maintainer-facing complete-sweep backlog for the Personal Symphony Product Repository. The sweep identifies concrete defects, maintainability risks, and product-polish gaps that make future agent and maintainer work slower, riskier, or more ambiguous.

V1 should be broad in discovery but disciplined in delivery: it produces a prioritized, evidence-backed backlog rather than one large cleanup branch. Each finding must include repo-local evidence, affected product boundary, risk category, acceptance target, verification command, and whether it changes runtime semantics.

## Summary / Differentiator

Most code quality tools produce issue volume. This idea turns codebase health findings into reviewable Symphony work: scoped Compozy Task Steps with product-language alignment, Runtime Contract awareness, and verification evidence.

## Problem

The current verification baseline is healthy: `pnpm docs:test`, `pnpm frontend:test`, `pnpm backend:build`, and `pnpm test` pass. That makes the main problem subtler than a broken build. The Product Repository has several high-context maintenance hotspots where future agents can make locally reasonable edits that weaken Runtime Contract semantics, Runtime State truthfulness, or cross-surface consistency.

The scan found concentrated risk in large shared modules, a 20k-line backend test suite, Runtime Contract parsing/default seams, duplicated Compozy task parsing behavior, Terminal Console and Web Dashboard projection gaps, generated frontend artifact noise, duplicate ADR numbering, legacy-centered dev scripts, and unsafe or unclear control-flow/protocol surfaces.

### Market Data

- [Sonar State of Code 2026](https://www.sonarsource.com/blog/state-of-code-developer-survey-report-the-current-reality-of-ai-coding/) frames AI coding as a verification and code-quality challenge, not only a productivity gain.
- [Qodo State of AI Code Quality 2025](https://www.qodo.ai/reports/state-of-ai-code-quality/) emphasizes review burden and correctness risk around AI-generated code.
- [CodeScene technical debt guidance](https://codescene.io/docs/guides/technical/prioritize-technical-debt.html) supports hotspot-based prioritization instead of flat issue lists.
- [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/) shows agentic and AI-assisted workflows increasing software activity, which raises the value of durable review boundaries.
- [DORA 2025](https://dora.dev/dora-report-2025/) and [DORA AI tensions](https://dora.dev/insights/balancing-ai-tensions/) warn that AI amplifies existing engineering strengths and weaknesses.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Evidence-backed inventory | Critical | Produce a complete backlog of defects, maintainability risks, and product-polish gaps with file evidence and rationale. |
| F2 | Risk taxonomy | Critical | Classify each item by defect, maintainability, polish, security/blast-radius, docs hygiene, Runtime Contract drift, or agent-readiness risk. |
| F3 | Prioritization model | Critical | Rank findings by maintainer pain, runtime risk, churn/hotspot weight, user-visible trust impact, and fix confidence. |
| F4 | Verification matrix | Critical | Attach required commands and acceptance evidence to every backlog item. |
| F5 | Runtime semantics flag | High | Mark whether a fix changes Runtime Contract, Runtime Home, Runtime State, Task Branch, or Bootstrap behavior. |
| F6 | Cross-surface consistency audit | High | Identify mismatches between Terminal Console, Web Dashboard, Runtime State, docs, and CLI scripts. |
| F7 | Drift guardrail candidates | High | Identify validators/tests that would prevent recurrence, such as ADR numbering and glossary/runtime terminology checks. |
| F8 | Hotspot follow-up packages | Medium | Convert major structural risks into separately scoped follow-up candidates with characterization needs. |

## Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Compozy PRD Run | Use the backlog as input for future `_prd.md`, `_techspec.md`, and task generation. |
| Runtime Contract | Require each finding to state whether it changes runtime semantics. |
| Terminal Console and Web Dashboard | Include cross-surface truthfulness and Runtime State projection checks. |
| Documentation validation | Extend existing docs validators where drift is detectable. |
| Backend test suite | Use current tests as the verification baseline while identifying follow-up split opportunities. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Actionable findings | >= 15 findings | Count backlog items with evidence, category, priority, and verification command. |
| Coverage breadth | >= 3 categories | Confirm defects, maintainability, and polish all have prioritized findings. |
| Evidence completeness | 100% | Every item has repo-local evidence and an affected boundary. |
| Verification completeness | 100% | Every item lists required checks such as `pnpm test`, `pnpm frontend:test`, or targeted validators. |
| Guardrail candidates | >= 3 | Count proposed validators/tests that prevent recurrence. |
| Structural deferrals | >= 4 | Major refactors are captured as follow-ups with characterization needs, not bundled into V1 implementation. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Strong |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Strong |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Strong |

Leverage type: Compounding Feature

## Council Insights

- **Recommended approach:** Keep the complete-sweep discovery scope, but deliver it as a scoped, verified backlog. Do not turn V1 into one broad refactor.
- **Key trade-offs:** Broad discovery improves coverage, but broad implementation creates review risk. Boundary-hardening preserves coherence, but each item still needs independent acceptance evidence.
- **Risks identified:** Scope sprawl, semantic regressions, over-indexing on cosmetic polish, and hiding architecture disagreements inside cleanup work.
- **Stretch goal (V2+):** A recurring Codebase Health Console that ranks hotspots, detects Runtime Contract drift, and generates Compozy-ready task candidates.

## Out of Scope (V1)

- **Implementing every fix** — V1 produces the verified backlog and prioritization; implementation belongs in follow-up PRD/task work.
- **Large backend test-suite split** — valid follow-up, but requires explicit approval and careful characterization.
- **Major `orchestrator.ml` decomposition** — too risky for a discovery-stage sweep without scoped contracts.
- **HTTP/WebSocket server replacement** — protocol hardening can be captured, but replacement is a separate architecture decision.
- **Changing Runtime Contract defaults** — project rules require asking first.
- **Task Branch cleanup or auto-merge default changes** — project rules require asking first.

## Architecture Decision Records

- [ADR-001: Use a Scoped Verified Backlog for Codebase Improvement](adrs/adr-001.md) — Keep complete-sweep discovery, but require independently reviewable backlog items with evidence and verification.

## Open Questions

- What minimum priority score should qualify a finding for V1 vs V2?
- Should the first implementation wave favor fast trust fixes or high-risk runtime boundaries?
- Should future PRD generation create one task per finding or group related findings by boundary?
- Should ADR numbering drift be fixed immediately or only guarded against first?
