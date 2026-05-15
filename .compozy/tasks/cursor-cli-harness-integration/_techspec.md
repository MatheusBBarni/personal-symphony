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
