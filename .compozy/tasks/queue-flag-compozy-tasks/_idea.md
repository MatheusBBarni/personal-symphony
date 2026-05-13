# Queue Flag With Compozy Tasks

## Overview

Personal Symphony should let a **Workspace Repository** operator pass bare **Compozy PRD Run** slugs to `--queue` when `.symphony/settings.json` selects `tracker.kind = "compozy_tasks"`.

Instead of requiring canonical selectors like `compozy:queue-flag-with-compozy-tasks`, the operator should be able to run `--queue queue-flag-with-compozy-tasks,claude-code-harness-integration`. Symphony should split the input on `,`, check the selected tracker kind from `settings.json`, and normalize each slug to the existing canonical identifier form before validation and dispatch.

V1 should be a Quick Win: reduce queue-entry friction for the solo operator, preserve existing **Ordered Queue** semantics, and reject the entire queue when any supplied slug is malformed, missing, terminal, or not dispatchable.

## Problem

Personal Symphony already supports **Ordered Queue** execution through `--queue`, and the current Compozy-backed path already accepts canonical selectors such as `compozy:<slug>`. The product gap is narrower than "add Compozy queue support": Compozy users already have support, but they must translate known `.compozy/tasks/<slug>/` directory names into a prefixed selector syntax every time they queue work.

For a solo operator running a Compozy-backed **Local Issue Tracker**, that translation adds repeated command-line friction without adding meaning. The operator already thinks in terms of **Compozy PRD Runs** identified by slug. Requiring the `compozy:` prefix in this tracker mode makes the CLI feel more mechanical than the underlying workflow.

The current solution is also inconsistent with how developers expect high-frequency CLI selection to work. When the active **Issue Tracker** is already `compozy_tasks`, a bare slug is unambiguous in operator intent. The missing capability is not broader queue flexibility. It is a tracker-scoped convenience that aligns the CLI with the operator's mental model while preserving canonical internal identifiers.

### Market Data

Developer workflow tools increasingly optimize for compact, repeatable CLI selectors. Nx documents comma- or space-delimited project lists for multi-project runs, GitHub CLI uses compact field lists for structured command output, and Turborepo supports multi-target filtering. That pattern matters because these commands are used repeatedly, often inside scripts or quick local invocations.

GitHub's 2025 workflow reporting highlighted 986 million code pushes in the prior year, reinforcing how much developer work now flows through repeated command-line operations. JetBrains' 2025 CI/CD survey reported GitHub Actions usage at 62% for personal projects and 41% in organizations, which points to a large market of developers who expect workflow commands to be concise, scriptable, and low-friction.

### Summary / Differentiator

The differentiator is not a new selector language. The differentiator is a context-aware Compozy convenience: bare slugs become valid only when the selected **Issue Tracker** already declares that Compozy PRD Runs are the tracked work item, while Symphony still preserves canonical internal identifiers and existing tracker boundaries.

## Core Features

| # | Feature | Priority | Description |
| --- | --- | --- | --- |
| F1 | Tracker-aware comma-separated slug input | Critical | When `.symphony/settings.json` sets `tracker.kind = "compozy_tasks"`, `--queue` accepts a comma-separated list of bare **Compozy PRD Run** slugs. |
| F2 | Canonical identifier normalization | Critical | Each accepted bare slug normalizes to the existing canonical `compozy:<slug>` identifier before runtime dispatch logic uses it. |
| F3 | Fail-fast queue validation | Critical | If any supplied slug is malformed, missing, terminal, or not dispatchable, Symphony rejects the entire **Ordered Queue** before side effects begin. |
| F4 | Compatibility preservation | Critical | Existing GitHub numeric selectors, minibeads selectors, and canonical `compozy:<slug>` selectors continue to work unchanged. |
| F5 | Dual-surface diagnostics | High | Validation errors surface both as direct CLI feedback and as **Readiness Gaps** when applicable. |
| F6 | Runtime Contract documentation updates | High | CLI help, README examples, and glossary-adjacent docs explain that bare slugs are a `compozy_tasks`-only **Ordered Queue** affordance. |

### Integration with Existing Features

| Integration Point | How |
| --- | --- |
| Ordered Queue | Preserve **Ordered Queue** as the product-level queue concept while accepting Compozy bare slugs only in Compozy tracker mode. |
| Issue Tracker boundary | Keep Compozy-specific slug interpretation inside the selected **Issue Tracker** path rather than turning bare slugs into a generic cross-tracker syntax. |
| Runtime State | Preserve canonical `compozy:<slug>` identity in persisted **Runtime State** and queue resume behavior. |
| Readiness validation | Reject invalid queue entries before dispatch side effects, consistent with existing **Readiness Gap** expectations. |
| Documentation | Update examples so Compozy-backed operators see the shorter queue syntax without weakening existing selector guidance. |

## KPIs

| KPI | Target | How to Measure |
| --- | --- | --- |
| Queue command brevity | >= 15% fewer characters for 2+ run Compozy queue commands | Compare documented and fixture commands before and after the feature. |
| Validation latency | < 1s for a queue of up to 20 Compozy slugs | Backend tests that validate a representative Compozy queue against fixture task directories. |
| Invalid queue protection | 100% of malformed, missing, terminal, or non-dispatchable bare-slug queues rejected before dispatch | Backend tests covering each failure mode and asserting no dispatch side effects. |
| Regression control | 0 regressions in existing GitHub, minibeads, and canonical Compozy Ordered Queue tests | Full backend test suite plus targeted Ordered Queue and Compozy tracker coverage. |

## Feature Assessment

| Criteria | Question | Score |
| --- | --- | --- |
| **Impact** | How much more valuable does this make the product? | Strong |
| **Reach** | What % of users would this affect? | Maybe |
| **Frequency** | How often would users encounter this value? | Strong |
| **Differentiation** | Does this set us apart or just match competitors? | Maybe |
| **Defensibility** | Is this easy to copy or does it compound over time? | Maybe |
| **Feasibility** | Can we actually build this? | Must do |

Leverage type: Quick Win.

## Council Insights

- **Recommended approach:** Accept bare Compozy slugs only when the selected **Issue Tracker** is `compozy_tasks`, normalize them to canonical `compozy:<slug>` identifiers, and keep generic **Ordered Queue** semantics intact.
- **Key trade-offs:** Better operator ergonomics versus tracker-specific CLI behavior; early diagnostics versus strict parser purity; fail-fast queue acceptance versus partial enqueue convenience.
- **Risks identified:** Users may expect bare selectors to work in non-Compozy tracker modes; unclear diagnostics could make fail-fast behavior frustrating; mixed selector styles may need explicit normalization rules.
- **Stretch goal (V2+):** Add a tracker-aware queue preview or saved queue capability for repeated Compozy PRD Run batches.

## Out of Scope (V1)

- **Bare selectors for GitHub or minibeads trackers** — V1 only shortens queue input for the Compozy-backed **Issue Tracker**.
- **Changing Runtime Contract defaults** — Existing Bootstrap and default tracker behavior remain unchanged.
- **Partial queue acceptance** — V1 rejects the entire **Ordered Queue** when any supplied slug is invalid.
- **A new generic selector language** — Bare slugs are a tracker-scoped convenience, not a cross-tracker identity format.
- **Changing Task Branch, retry, or completion semantics** — Queue input ergonomics must not alter orchestration lifecycle behavior.
- **Expanding scope to other selector-based flows** — V1 addresses `--queue`, not every existing selector surface.

## Architecture Decision Records

- [ADR-001: Compozy Queue Slug Scope](adrs/adr-001.md) — V1 scopes bare Compozy slug support to `compozy_tasks` queue input, preserves canonical internal identifiers, and keeps validation all-or-nothing.

## Open Questions

- Whether bare Compozy slugs should remain `--queue`-only or later extend to other selector-based flows is still undecided.
