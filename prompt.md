You are the Engineer agent for the Symphony Orchestrator Repository.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Responsibilities:
- Implement only the scoped issue.
- Use CONTEXT.md terms and follow AGENTS.md.
- Prefer existing module boundaries and tests over new abstractions.
- Preserve Runtime Contract semantics unless the issue explicitly asks to change them.
- Do not touch protected release/package paths unless the issue explicitly authorizes that scope.
- Edit ReScript .res sources only; never commit generated .res.js files.
- Keep examples secret-free and refer only to GITHUB_TOKEN or GH_TOKEN variable names.
- Run focused verification, then broader checks when shared orchestration/config/runtime behavior changes.

Stage Commit is enabled for this stage. Leave the worktree ready for a local commit boundary before review.

---

Stage agent: engineer

# Compozy PRD Run Stage

Run: compozy:cursor-cli-harness-integration
PRD directory: cursor-cli-harness-integration
Task step status: completed
Completed task steps: 6/6

## Completed Compozy Task Steps

- task_01.md: Add Cursor Harness Kind, Defaults, And Command Rendering
- task_02.md: Add Cursor CLI Install And Auth Readiness Checks
- task_03.md: Implement Cursor Loop Readiness And Goal Handoff Support
- task_04.md: Add Cursor Stream-JSON Activity Parsing And Runtime Visibility
- task_05.md: Update Bootstrap Runtime Contract Defaults For Cursor
- task_06.md: Update Docs, Glossary, Project ADR, And Harness Onboarding Guidance

## PRD (`_prd.md`)

# Cursor CLI Harness Integration PRD

## Overview

Cursor CLI Harness Integration makes Symphony a clearer provider-choice product for operators who already run agent
work through Cursor. It adds Cursor as a stable first-class `Agent Harness` inside the existing `Runtime Contract`, so
a `Workspace Repository` can route any `Logical Agent` role to Cursor without abandoning Symphony's orchestration
model, `Agent Worktree` isolation, `Task Branch` flow, or Runtime State visibility.

The value is practical rather than aspirational. Operators should be able to complete normal task flows on
Cursor-selected roles using the same product concepts they already understand for other Harnesses. The product outcome
is stronger provider neutrality: Cursor becomes a supported peer to existing Harnesses, while Symphony preserves one
consistent user model for selection, readiness, observability, and rollout.

## Goals

- Make Cursor a stable first-class `Agent Harness` option in Symphony's `Runtime Contract`.
- Let operators assign Cursor to any `Logical Agent` role, not only `engineer`.
- Enable operators who already use Cursor CLI to complete normal Symphony task flows without switching tools.
- Preserve clear product boundaries between `harnesses`, `agents`, and `stageAgents`.
- Strengthen Symphony's repeatable pattern for future Harness additions through a small onboarding or certification
  checklist.

Target outcomes:
- Cursor-selected roles can complete normal task flows reliably enough for routine use.
- Operators understand how to configure Cursor with low ambiguity.
- Symphony's provider-choice story becomes stronger without fragmenting the product model.

## User Stories

**Workspace Repository operator**

- As a `Workspace Repository` operator, I want to select Cursor for any `Logical Agent` role so that Symphony fits the
  agent tool I already use.
- As a `Workspace Repository` operator, I want Cursor to look like a real supported Harness, not a hidden
  compatibility path, so that I can adopt it confidently.
- As a `Workspace Repository` operator, I want clear readiness and setup guidance so that I can get to a successful
  run quickly.

**Task supervisor**

- As a task supervisor, I want Runtime State to show when Cursor is the selected Harness so that I can understand
  which provider is running a task.
- As a task supervisor, I want normal task progress and logs to remain visible when work runs on Cursor so that
  provider choice does not reduce operational trust.

**Product maintainer**

- As a product maintainer, I want Cursor onboarding to follow the same Harness model as existing providers so that
  future Harness additions become easier and less ad hoc.
- As a product maintainer, I want the PRD to define clear non-goals so that provider support does not quietly expand
  into unrelated product commitments.

## Core Features

### F1: Stable First-Class Cursor Harness

Symphony must present Cursor as a supported `Agent Harness` inside `harnesses`, with the same product-level status as
other supported Harnesses.

User capability:
- Operators can define a Cursor Harness in Runtime Settings.
- Cursor appears as a valid execution choice rather than an advanced workaround.
- Product docs teach Cursor through the same Harness model already used elsewhere.

### F2: Any Logical Agent Can Select Cursor

Cursor support must be available to any `Logical Agent` role.

User capability:
- Operators can assign Cursor to `planner`, `engineer`, `reviewer`, or other logical roles they define.
- Symphony does not frame Cursor as an `engineer`-only product path.
- Provider choice remains role-based and explicit.

### F3: Low-Ambiguity Setup Experience

The product must make it clear how an operator gets from Runtime Settings to a successful Cursor-selected run.

User capability:
- Operators know where Cursor belongs in the `Runtime Contract`.
- Operators receive clear readiness or setup feedback when Cursor is selected.
- Operators can reach a first successful run with low configuration ambiguity.

### F4: Normal Task-Flow Support

Cursor-selected roles must be able to participate in the normal Symphony workflow.

User capability:
- Operators can use Cursor-selected roles in routine task execution.
- Provider choice does not break the expected task-flow experience.
- Cursor support is measured by successful use in ordinary work, not by a narrow demo path.

### F5: Provider Visibility In Runtime State

Cursor must be observable as a selected Harness in operator-facing runtime views.

User capability:
- Operators can tell when a task is running on Cursor.
- Provider identity remains visible alongside normal task state.
- Provider choice does not reduce day-to-day operational clarity.

### F6: Cursor Examples In Bootstrap And Docs

Runtime Contract examples must show Cursor as part of the supported Harness story.

User capability:
- Operators can copy or adapt a Cursor example from product-owned documentation or seeded defaults.
- Cursor configuration is discoverable without reading backend source.
- Docs reinforce the split between `harnesses`, `agents`, and `stageAgents`.

### F7: Harness Onboarding Checklist

The Cursor effort should leave behind a lightweight reusable checklist for future Harness additions.

User capability:
- Product maintainers can evaluate future Harness candidates against a repeatable set of product expectations.
- Symphony reduces one-off provider decisions over time.
- Cursor becomes a compounding product investment, not just a single-provider feature.

## User Experience

Primary journey:
1. An operator opens `.symphony/settings.json` or related Runtime Contract docs.
2. They see Cursor presented as a supported `Agent Harness` alongside the existing provider model.
3. They assign Cursor to one or more `Logical Agent` roles.
4. Symphony guides them to readiness rather than leaving provider setup ambiguous.
5. They dispatch normal work and observe Cursor-selected execution through the same Runtime State surfaces they already
   use.
6. They continue using Symphony's existing orchestration flow without needing a separate mental model for Cursor.

Product experience principles:
- Provider choice should feel native, not bolted on.
- Role selection should remain simple and explicit.
- Setup friction should be low enough that current Cursor users can adopt quickly.
- Visibility should remain strong enough that operators trust mixed-Harness environments.
- Discoverability should come from the Runtime Contract and product docs, not from tribal knowledge.

Accessibility and clarity considerations:
- Setup and readiness messages should be understandable by operators who know Symphony but do not know backend
  internals.
- Product wording should distinguish support scope from future ambitions.
- Provider-specific examples should reinforce the same information architecture rather than creating a separate
  Cursor-only UX.

## High-Level Technical Constraints

- Cursor must fit the existing `Workspace Repository`-owned `Runtime Contract`.
- Product examples must preserve the separation between `harnesses`, `agents`, and `stageAgents`.
- Bootstrap must remain idempotent and must not overwrite user-edited runtime files.
- Product guidance must reference only secret environment variable names, never secret values.
- Provider support must preserve existing `Agent Worktree`, `Task Branch`, and Runtime State product semantics.
- Observability must remain available even when provider-specific structured activity is incomplete.

## Non-Goals (Out of Scope)

- Reframing Cursor as a hidden or experimental-only feature.
- Limiting Cursor support to only one `Logical Agent` role in the product story.
- Shipping Cursor background-agent or cloud-agent product behavior in this PRD.
- Creating a broad new provider-capability framework for permissions, autonomy, or enterprise controls.
- Promising complete semantic parity between Cursor and every existing Harness.
- Automatically rewriting user Runtime Contract files.
- Using this PRD to define implementation details, parser strategy, or backend architecture.

## Phased Rollout Plan

### MVP (Phase 1)

- Stable first-class Cursor Harness positioning in the Runtime Contract.
- Cursor available to any `Logical Agent`.
- Clear setup and readiness experience for Cursor-selected roles.
- Normal task-flow support for routine operator use.
- Runtime State provider visibility for Cursor.
- Cursor examples in docs or seeded settings.
- Initial Harness onboarding checklist for future providers.

Success criteria to proceed:
- Operators can complete normal task flows on Cursor-selected roles.
- Setup ambiguity is low enough that existing Cursor operators can adopt without deep source-code reading.
- Runtime State makes Cursor-selected execution understandable in daily use.

### Phase 2

- Improve discoverability and operator guidance for mixed-Harness environments.
- Strengthen the reusable Harness onboarding checklist with examples and validation guidance.
- Expand product documentation around role selection patterns and common provider-choice scenarios.

Success criteria to proceed:
- Operators can confidently mix Cursor with other Harnesses across different roles.
- Product maintainers can use the onboarding checklist to evaluate another Harness candidate with less ad hoc work.

### Phase 3

- Mature Symphony's broader provider-choice narrative using lessons from Cursor adoption.
- Evaluate whether additional provider-facing product surfaces are needed for richer mixed-Harness workflows.
- Extend the onboarding pattern into a more formal provider-support playbook if repeated Harness additions justify it.

Long-term success criteria:
- Symphony can add future Harnesses without reshaping the core product model.
- Provider choice becomes a durable product strength rather than a source of setup complexity.

## Success Metrics

- `>= 90%` of Cursor-selected task runs complete the normal dispatch-to-finish flow without setup or support failure in
  dogfood use.
- `<= 15 minutes` median time from opening Cursor setup docs to first successful Cursor-selected task flow for an
  operator who already has Cursor installed.
- `100%` of Cursor-selected running tasks show provider identity in Runtime State.
- `>= 2` real `Workspace Repositories` adopt Cursor as part of normal role selection within 30 days of release.
- `>= 80%` of surveyed or observed early adopters report that provider choice feels clear rather than ambiguous.

## Risks and Mitigations

- **Adoption risk:** Operators may not trust Cursor if support looks partial or ambiguous.
  - Mitigation: position Cursor as stable first-class support and keep the setup path explicit.

- **Expectation risk:** Stable support language may create stronger expectations than the first rollout can satisfy.
  - Mitigation: keep the supported scope narrow, define clear non-goals, and use phased rollout to control surface
    area.

- **Competitive risk:** If Symphony's provider-choice story feels weaker than other agent orchestration products,
  Cursor support may not change adoption.
  - Mitigation: focus the MVP on normal task-flow completion and operator clarity, not merely checkbox compatibility.

- **Dependency risk:** Product confidence depends partly on external provider behavior and documentation staying usable.
  - Mitigation: base the product promise on documented behaviors, preserve fallback visibility, and avoid
    overspecifying parity claims.

- **Scope creep risk:** Cursor support could quietly grow into unrelated autonomy or provider-platform work.
  - Mitigation: keep future-oriented items explicitly out of scope and use the onboarding checklist to discipline
    expansion.

## Architecture Decision Records

- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Accepts `kind: "cursor"` as a
  first-class `Agent Harness` while keeping scope bounded and reusable.
- [ADR-002: Stable First-Class Cursor Harness Product Posture](adrs/adr-002.md) — Commits the PRD to stable
  first-class support for Cursor across any `Logical Agent` role.

## Open Questions

- What default Cursor example should product docs emphasize first for operator setup clarity?
- How prominently should the Harness onboarding checklist appear in operator-facing docs versus maintainer-facing
  artifacts?
- What product language best distinguishes "stable support" from "full semantic parity" without weakening user
  confidence?
- Are there specific mixed-Harness role combinations that deserve first-class documentation examples in the initial
  release?

## TechSpec (`_techspec.md`)

# Cursor CLI Harness Integration TechSpec

## Executive Summary

This change adds Cursor as a native `kind: "cursor"` `Agent Harness` inside Symphony's existing multi-Harness
architecture. The implementation reuses the established `harnesses -> agents -> stageAgents` resolution path,
selected-Harness readiness model, shell-based launch flow, Runtime State Harness identity, and Bootstrap-owned Runtime
Contract examples. Cursor-specific behavior stays inside the same provider seams already used for Claude and PI.

The primary technical trade-off is explicit provider support versus shared-module complexity. A native Cursor Harness
gives clear behavior, readiness, and observability without inventing a second provider system, but it adds new
provider-specific branches to already dense backend modules such as `config.ml`, `orchestrator.ml`, and
`test_backend.ml`. The design keeps scope narrow: Cursor uses CLI-driven auth readiness, `stream-json` as the
canonical structured output path with raw-log fallback, operator-configured loop support through `loop.enabled` /
`loop.command`, and targeted updates to Bootstrap, docs, and tests.

## System Architecture

### Component Overview

**Runtime Settings / Harness Parsing**
- Module: `apps/backend/lib/config.ml`
- Purpose: Parse `kind: "cursor"` inside `harnesses`, merge logical-agent overrides, define defaults, and surface
  readiness gaps.
- Boundary: Owns Runtime Contract interpretation and selected-Harness validation, not runtime execution itself.

**Harness Launch And Prompt Composition**
- Module: `apps/backend/lib/orchestrator.ml`
- Purpose: Render the selected Cursor command, compose prompt input, launch the process in an `Agent Worktree`, and
  capture stdout/stderr.
- Boundary: Owns dispatch-time behavior and runtime child process handling.

**Runtime State And Operator Visibility**
- Modules: `apps/backend/lib/runtime_state.ml`, `apps/backend/lib/terminal_console_model.ml`,
  `apps/frontend/src/RuntimeStateSnapshot.res`, `apps/frontend/src/Pages/Dashboard.res`
- Purpose: Preserve Harness identity and, where supported, structured live activity for running Cursor tasks.
- Boundary: Owns operator-facing visibility, not command execution or readiness probing.

**Bootstrap And Runtime Contract Examples**
- Module: `apps/backend/lib/runtime_home.ml`
- Purpose: Seed bootstrapped `.symphony/settings.json` examples with Cursor support.
- Boundary: Owns default Runtime Contract examples and idempotent Bootstrap behavior.

**Documentation And Domain Language**
- Files: `CONTEXT.md`, `README.md`, `docs/adr/0021-agent-harness-runtime-settings.md`
- Purpose: Update glossary, supported Harness examples, and architectural documentation so Cursor is part of the
  official model.
- Boundary: Owns product-contract explanation rather than implementation behavior.

**Backend Verification**
- Module: `apps/backend/test/test_backend.ml`
- Purpose: Extend parser, readiness, command rendering, loop, dispatch, and activity coverage for Cursor.
- Boundary: Owns regression confidence across shared Harness code.

### Data Flow

1. Operator defines `harnesses.cursor` in `.symphony/settings.json`.
2. `Config.from_settings_file` parses Cursor as a native Harness kind and merges role-level overrides from
   `agents.<name>`.
3. `Config.selected_agent_harness` resolves a stage to a logical agent and then to the Cursor Harness.
4. `Config.readiness_gaps` performs selected-Harness Cursor install/auth/loop readiness before dispatch.
5. `Orchestrator.compose_prompt` prepends loop handoff only when `loop.enabled` is true and Cursor loop readiness is
   satisfied.
6. `Orchestrator.shell_launch` renders the Cursor command, writes the prompt, and launches the child process with
   stdout/stderr capture.
7. Runtime refresh logic parses Cursor `stream-json` when available, otherwise falls back to raw logs.
8. Runtime State and UI surfaces show `harness_name`, `harness_kind`, and activity updates for the running task.

## Implementation Design

### Core Interfaces

```ocaml
type agent_harness = {
  name : string;
  kind : string;
  command : string;
  model : string;
  reasoning_effort : string;
  turn_timeout_ms : int;
  read_timeout_ms : int;
  stall_timeout_ms : int;
  loop_enabled : bool;
  loop_command : string;
}
```

```ocaml
type selected_harness_resolution =
  | Resolved_harness of agent_harness
  | Missing_logical_agent of string
  | Missing_referenced_harness of string
```

```ocaml
val selected_agent_harness : t -> stage_agent option -> agent_harness option
val readiness_gaps : t -> readiness_gap list
val render_harness_command : Config.agent_harness -> string
```

These interfaces already exist and should remain the primary contracts. The Cursor work extends them by:
- adding `cursor` as an allowed `kind`
- adding Cursor-specific default command and readiness behavior
- optionally extending runtime activity parsing for Cursor output

### Data Models

**Runtime Settings Harness Entry**
- Existing `agent_harness` record remains the primary data model.
- Cursor uses the same fields as other Harnesses:
  - `name`
  - `kind = "cursor"`
  - `command`
  - `model`
  - `reasoningEffort`
  - `turnTimeoutMs`
  - `readTimeoutMs`
  - `stallTimeoutMs`
  - `loop.enabled`
  - `loop.command`

**Logical Agent Mapping**
- Existing `logical_agent` model remains unchanged.
- Cursor support is driven through `agents.<name>.harness = "cursor"` or another named Cursor Harness.

**Runtime State Running Row**
- Existing `running` model already carries:
  - `harness_name`
  - `harness_kind`
  - `last_event`
  - `last_message`
  - `tokens`
- No schema expansion is required for minimal Cursor support if live activity can fit the current normalized fields.

### API Endpoints

No new external HTTP API endpoints are required.

Existing backend state endpoints and WebSocket/live-state surfaces continue to serve Runtime State snapshots. Cursor
support changes the contents of existing running-task rows rather than adding new resources.

## Integration Points

This design does not integrate with systems outside the codebase beyond the local Cursor CLI executable invoked by
Symphony.

The main external boundary is the local Cursor CLI command:
- installation availability must be verified before dispatch
- auth/status readiness must be checked through the Cursor CLI itself
- `stream-json` output must be parsed defensively
- loop support must validate the plugin-backed command path before dispatch when enabled

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
|-----------|-------------|---------------------|-----------------|
| `apps/backend/lib/config.ml` | modified | Core Harness parsing and readiness logic; high shared-module risk | Add Cursor kind/defaults, CLI-driven auth readiness, and loop readiness |
| `apps/backend/lib/orchestrator.ml` | modified | Launch path and runtime activity parsing; high behavioral risk | Add Cursor command rendering if needed, Cursor activity parsing, and loop-safe behavior |
| `apps/backend/lib/runtime_home.ml` | modified | Bootstrap default Runtime Contract; product-contract risk | Add Cursor example while preserving idempotent Bootstrap |
| `apps/backend/lib/runtime_state.ml` | modified or unchanged | Likely schema reuse, but verify normalized activity suffices | Confirm no new fields are needed |
| `apps/backend/lib/terminal_console_model.ml` | modified or unchanged | Running-row detail already includes Harness identity | Verify Cursor activity is readable without model changes |
| `apps/frontend/src/RuntimeStateSnapshot.res` | modified or unchanged | Existing runtime snapshot may already be sufficient | Verify frontend accepts Cursor Harness rows without schema change |
| `apps/frontend/src/Pages/Dashboard.res` | modified or unchanged | Dashboard may only need display validation | Confirm Harness identity renders correctly |
| `apps/backend/test/test_backend.ml` | modified | Large shared suite; regression risk | Add targeted Cursor tests near existing Harness cases |
| `CONTEXT.md` | modified | Domain source of truth; required by repo rules | Add Cursor Harness terminology and semantics |
| `README.md` | modified | Operator-facing setup surface | Add supported Cursor examples |
| `docs/adr/0021-agent-harness-runtime-settings.md` | modified | Existing architecture ADR needs amendment for new supported kind | Update supported Harness set and semantics |

## Testing Approach

### Unit Tests

Focus areas:
- `Config` parses `kind: "cursor"` and default Cursor command/loop behavior correctly.
- `Config.selected_agent_harness` resolves Cursor through logical agents.
- `Config.readiness_gaps` validates:
  - selected-only Cursor install checks
  - CLI-driven auth/status checks
  - Cursor loop readiness when `loop.enabled` is true
- `Orchestrator.render_harness_command` handles Cursor token replacement or provider-specific rendering correctly.
- Cursor structured-output parsing normalizes `stream-json` into existing Runtime State activity fields.
- Loop-disabled and loop-enabled Cursor prompts behave correctly.

Mock and boundary strategy:
- Use temporary settings files and fake shell commands as existing tests do for Claude/PI.
- Use fake Cursor scripts that emit deterministic `stream-json` or status output.
- Keep tests adjacent to current Harness coverage in `apps/backend/test/test_backend.ml`.

Critical scenarios:
- selected Cursor Harness with successful install/auth readiness
- unselected Cursor Harness does not block readiness
- loop-enabled Cursor Harness without plugin support fails readiness
- loop-enabled Cursor Harness with plugin support prepends configured `loop.command`
- Cursor `stream-json` parser ignores malformed lines and preserves raw-log fallback behavior

### Integration Tests

Integration slices:
- full config load with `harnesses.cursor`, `agents.<role>.harness`, and enabled stage routing
- dispatch path that launches a fake Cursor command and updates Runtime State
- bootstrapped settings content includes Cursor examples
- Terminal Console / Runtime State JSON exposes Cursor `harness_name` and `harness_kind`

Test data/setup:
- temp Workspace Repository roots
- fake `.symphony/agents/*.md` prompt files
- fake Cursor binaries/scripts in PATH or explicit temp command paths
- deterministic fake auth/status command responses

Environment dependencies:
- no real Cursor install required for tests
- tests should not depend on user-local Cursor state
- loop/plugin readiness must be simulated through fake command responses

## Development Sequencing

### Build Order

1. Add Cursor kind/defaults in `Config` and update supported-kind validation - no dependencies
2. Add Cursor selected-Harness install/auth readiness in `Config` - depends on step 1
3. Add Cursor loop-readiness checks tied to `loop.enabled` / `loop.command` - depends on steps 1-2
4. Add Cursor command rendering adjustments in `Orchestrator` if the standard token replacement is insufficient - depends on steps 1-2
5. Add Cursor `stream-json` parsing and running-row activity updates - depends on step 4
6. Add targeted backend tests for parsing, readiness, loop, rendering, and dispatch - depends on steps 1-5
7. Update Bootstrap defaults, glossary, README, and project ADR docs - depends on steps 1-6
8. Verify frontend/dashboard and Terminal Console behavior with Cursor runtime rows - depends on steps 5-7

### Technical Dependencies

- A documented Cursor CLI command shape that works with stdin-fed non-interactive launch.
- A documented Cursor CLI auth/status command usable for readiness probing.
- A documented or validated `stream-json` event shape sufficient for normalized activity parsing.
- A documented plugin-backed loop command path for Cursor when `loop.enabled` is true.
- User-approved Bootstrap default change, which has already been provided in the clarification round.

## Monitoring and Observability

Key metrics:
- Cursor-selected readiness failure rate by requirement (`install`, `auth`, `loop`)
- Cursor dispatch success rate
- Cursor structured-output parse success rate
- Cursor fallback-to-raw-log rate
- Cursor loop-enabled dispatch success rate

Log events and fields:
- `harness_name=cursor`
- `harness_kind=cursor`
- Cursor readiness requirement identifiers
- parsed Cursor last event and last message when structured output is available
- loop-enabled readiness diagnostic details
- raw stdout/stderr preservation path for troubleshooting

Alerting and escalation:
- repeated Cursor auth/readiness failures in dogfood environments
- unexpected parse failure spikes after Cursor CLI upgrades
- loop-enabled Cursor tasks consistently failing before first output

## Technical Considerations

### Key Decisions

- **Decision:** Implement Cursor as a native Harness kind rather than a generic command shim.
  - **Rationale:** Fits the accepted Runtime Contract and preserves provider-specific behavior in the right layer.
  - **Trade-offs:** Adds complexity to shared backend modules.
  - **Alternatives rejected:** PI-style compatibility-only path; broader generic refactor first.

- **Decision:** Use Cursor CLI itself for auth/status readiness.
  - **Rationale:** Matches the selected design choice and avoids weaker indirect heuristics as the main signal.
  - **Trade-offs:** Couples readiness to a provider-owned CLI contract.
  - **Alternatives rejected:** env/file-only auth detection; no preflight auth readiness.

- **Decision:** Treat `stream-json` as the canonical Cursor output path.
  - **Rationale:** Gives Cursor a structured observability contract comparable to Claude where supported.
  - **Trade-offs:** Requires provider-specific parser maintenance.
  - **Alternatives rejected:** `json` only; raw-log-only V1.

- **Decision:** Support Cursor loop entry through `loop.enabled` / `loop.command`.
  - **Rationale:** Preserves the current Harness loop model and fits the plugin-backed Cursor path described by the user.
  - **Trade-offs:** Requires new loop readiness checks beyond current Codex-only protection.
  - **Alternatives rejected:** no loop support; Codex-style implicit loop parity.

- **Decision:** Add Cursor to bootstrapped settings examples.
  - **Rationale:** Matches the approved product posture and reduces Runtime Contract ambiguity for new operators.
  - **Trade-offs:** Changes default examples in a repo area marked “ask first.”
  - **Alternatives rejected:** docs-only support; defer Bootstrap changes.

### Known Risks

- **stdin/non-TTY incompatibility**
  - Likelihood: medium
  - Mitigation: validate the documented non-interactive Cursor command shape early and add a provider-local renderer if
    required.

- **Cursor CLI contract drift**
  - Likelihood: medium
  - Mitigation: keep parsing defensive, preserve raw-log fallback, and isolate Cursor-specific readiness logic.

- **Loop false positives**
  - Likelihood: medium
  - Mitigation: add explicit readiness validation for loop-enabled Cursor Harnesses before dispatch instead of
    inheriting Codex assumptions.

- **Shared-module regression risk**
  - Likelihood: high
  - Mitigation: use targeted changes, add focused backend tests near existing Harness cases, and avoid refactoring
    `test_backend.ml` structure.

- **Bootstrap/example ambiguity between `--force` and non-`--force`**
  - Likelihood: medium
  - Mitigation: make the example posture explicit in docs and seeded settings rather than implying one safe default
    without explanation.

## Architecture Decision Records

- [ADR-001: Cursor Harness As A Bounded Multi-Harness Extension](adrs/adr-001.md) — Accepts `kind: "cursor"` as a
  first-class `Agent Harness` while keeping scope bounded and reusable.
- [ADR-002: Stable First-Class Cursor Harness Product Posture](adrs/adr-002.md) — Commits the PRD to stable
  first-class support for Cursor across any `Logical Agent` role.
- [ADR-003: Native Cursor Harness Technical Design](adrs/adr-003.md) — Chooses a native `cursor` Harness kind over a
  compatibility shim or broader refactor.
- [ADR-004: Cursor Output, Readiness, And Loop Contract](adrs/adr-004.md) — Sets `stream-json`, CLI-driven
  readiness, explicit loop support, and dual command-posture handling as the core Cursor contract.

