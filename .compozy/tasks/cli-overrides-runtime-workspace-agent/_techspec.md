# Runtime Settings Invocation Overrides TechSpec

## Executive Summary

The implementation adds explicit runtime-only CLI flags for issue 66, applies them after Runtime Settings load by copying the loaded `Config.t`, and passes that effective config through existing runtime paths. The main trade-off is that this keeps `Config.from_settings_file` unchanged, but places override precedence in the CLI startup layer instead of the Runtime Settings parser.

The design also factors Cmdliner command construction into a backend library module so help text, parse errors, unsupported-mode failures, and duplicate-flag behavior can be tested without shelling out to the executable. `--agent.maxTurns` will override the effective config field in this TechSpec, but it will not add new retry-stop semantics.

## System Architecture

### Component Overview

- **CLI command module**: Owns Cmdliner term construction, runtime override arguments, help text, argv pre-scan rules, and command evaluation helpers for tests.
- **Executable entrypoint**: Keeps `Sys.argv` normalization and calls the factored command module.
- **Runtime override model**: Represents the five optional invocation override values before applying them to the loaded config.
- **Runtime config loader path**: Loads `.symphony/settings.json` normally, then creates the effective runtime config by copying selected fields.
- **Runtime consumers**: Read the effective config through existing paths for readiness, Web Dashboard, Terminal Console, Manual Task Merge, and orchestration.

Data flow:

1. CLI parses default runtime arguments and runtime-only override flags.
2. Startup validates the Workspace Repository root.
3. Startup bootstraps Runtime Home and loads Runtime Settings.
4. Startup applies overrides by copying `Config.t`.
5. Existing runtime behavior receives the effective config.

## Implementation Design

### Core Interfaces

The template requires a Go contract sketch; the implementation equivalent is an OCaml record.

```go
type RuntimeInvocationOverrides struct {
    PollingIntervalMs       *int
    WorkspaceRoot           *string
    AgentMaxConcurrent      *int
    AgentMaxTurns           *int
    AgentMaxRetryBackoffMs  *int
}
```

OCaml implementation shape:

```ocaml
type runtime_invocation_overrides = {
  polling_interval_ms : int option;
  workspace_root : string option;
  agent_max_concurrent_agents : int option;
  agent_max_turns : int option;
  agent_max_retry_backoff_ms : int option;
}
```

Primary helper contract:

```ocaml
val apply_runtime_invocation_overrides :
  workspace_root:string ->
  Config.t ->
  runtime_invocation_overrides ->
  Config.t
```

### Data Models

No persistent data model changes.

New transient data:

- `runtime_invocation_overrides`: optional CLI-supplied values for the five allowed fields.
- `effective_config`: copied `Config.t` used only by the current process.

Field mapping:

| CLI Flag | Effective Config Field |
| --- | --- |
| `--polling.intervalMs` | `config.polling.interval_ms` |
| `--workspace.root` | `config.workspace.root` |
| `--agent.maxConcurrentAgents` | `config.agent.max_concurrent_agents` |
| `--agent.maxTurns` | `config.agent.max_turns` |
| `--agent.maxRetryBackoffMs` | `config.agent.max_retry_backoff_ms` |

### API Endpoints

No HTTP API endpoints change.

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/bin/main.ml` | Modified | Entry point becomes thinner and delegates command construction. Medium risk around startup behavior. | Keep argv normalization and `Cmd.eval'` wiring only. |
| Backend CLI module | New | Owns Cmdliner command definitions and parser tests. Medium risk due command extraction. | Add runtime override args, pre-scan, and command construction. |
| `apps/backend/lib/config.ml` or adjacent module | Modified | Adds override application helper without changing settings parsing. Low risk. | Copy loaded `Config.t` with selected effective fields replaced. |
| `apps/backend/lib/orchestrator.ml` | Existing behavior used | Polling, concurrency, worktree root, and retry backoff already consume config. | No retry-stop change for `max_turns` in this TechSpec. |
| `apps/backend/lib/manual_merge.ml` | Existing behavior used | Manual merge already uses `config.workspace.root`. | Ensure effective config reaches manual merge. |
| `apps/backend/test/test_backend.ml` | Modified | Adds config, CLI, unsupported-mode, and runtime behavior tests. | Keep focused additions in existing test groups. |
| Dune files | Modified | Cmdliner becomes available to backend library/tests. | Add the minimal dependency needed by command extraction. |

## Testing Approach

### Unit Tests

- Override application copies each supported field into the effective config.
- Missing override values preserve Runtime Settings values.
- `--workspace.root` uses the same path behavior as Runtime Settings for relative, absolute, and home-relative values.
- Positive integer parser rejects zero, negative, decimal, empty, and non-numeric values.
- Duplicate override flags follow Cmdliner's observed repeated-option behavior and tests document it.
- `symphony --help` includes all five flags and current-invocation wording.

### Integration Tests

- A runtime startup path using overrides leaves `.symphony/settings.json` byte-for-byte unchanged.
- Root validation still fails outside a Workspace Repository even when `--workspace.root` is supplied.
- `--web` and `--merge` receive the effective config.
- `init`, `update`, and legacy positional `WORKFLOW.md` mode produce clear runtime-only override failure via argv pre-scan.
- Existing orchestration behavior reflects effective polling, workspace root, global concurrency, and retry backoff config values.

## Development Sequencing

### Build Order

1. Add transient override record and config-copy helper - no dependencies.
2. Add explicit Cmdliner override args - depends on step 1 because parsed values need the override record.
3. Extract command construction into a backend library module - depends on step 2 because the command surface must include the new args.
4. Add argv pre-scan for unsupported modes - depends on step 3 because unsupported-mode behavior belongs beside command construction.
5. Pass overrides through runtime startup and apply them after settings load - depends on steps 1 and 3 because startup needs both the model and parsed values.
6. Add CLI/help and unsupported-mode tests - depends on steps 3 and 4.
7. Add config-copy, path, settings-preservation, and runtime behavior tests - depends on step 5.
8. Run focused backend tests, then `pnpm test` - depends on steps 6 and 7.

### Technical Dependencies

- Cmdliner must be available wherever the factored command module and tests live.
- Existing Runtime Settings path expansion must remain available to the override application helper.
- No package, frontend, npm, or Runtime Contract default changes are required.

## Monitoring and Observability

No new runtime metrics or dashboards are required for MVP.

Existing startup and failure output should continue to identify startup failures. Override parsing failures must name the invalid field without printing secrets or `.env` contents.

Phase 2 may add effective-config visibility for non-secret override values if users need debugging support.

## Technical Considerations

### Key Decisions

- **Decision:** Apply overrides after `Config.from_settings_file` by copying `Config.t`.
  **Rationale:** Keeps Runtime Settings file parsing stable.
  **Trade-off:** Override precedence lives in CLI startup, not the parser.

- **Decision:** Factor Cmdliner command construction into a backend library module.
  **Rationale:** Enables direct automated tests for help and parse behavior.
  **Trade-off:** Requires a small dependency/stanza adjustment.

- **Decision:** Do not add max-turn retry-stop behavior in this TechSpec.
  **Rationale:** User selected effective config override only for now.
  **Trade-off:** This leaves a known gap against the PRD's “observable behavior” acceptance risk.

- **Decision:** Use argv pre-scan for unsupported command modes.
  **Rationale:** Produces clear “default runtime command only” failures for `init`, `update`, and legacy mode.
  **Trade-off:** Adds a small parser-adjacent guard before normal Cmdliner dispatch.

### Known Risks

- **Max turns semantic gap:** `--agent.maxTurns` updates effective config but may not change retry behavior. Mitigation: TechSpec documents this as a known gap and follow-up candidate.
- **Command extraction regression:** Moving Cmdliner definitions could alter existing help or mode behavior. Mitigation: add tests for existing mode selection and new help output.
- **Unsupported-mode pre-scan drift:** Pre-scan flag list can drift from real runtime override args. Mitigation: define one shared list of runtime override flag names.
- **Post-load copy drift:** Future `Config.t` changes can make ad hoc copying brittle. Mitigation: isolate copying in one helper.

## Architecture Decision Records

- [ADR-001: Narrow Runtime Settings Invocation Overrides](adrs/adr-001.md) — V1 uses a fixed allowlist with process-local behavior and typed internal override application.
- [ADR-002: Full Issue-66 Runtime Override Scope](adrs/adr-002.md) — PRD scope includes all five issue-66 flags, including `--agent.maxTurns`.
- [ADR-003: Post-Load Runtime Override Application](adrs/adr-003.md) — Overrides apply after settings load by copying the effective runtime config in the CLI startup layer.
- [ADR-004: CLI Command Extraction for Override Testing](adrs/adr-004.md) — Cmdliner command construction moves into a backend library module for direct automated tests.
