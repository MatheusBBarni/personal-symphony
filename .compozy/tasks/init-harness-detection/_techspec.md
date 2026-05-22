# Init Harness Detection TechSpec

## Executive Summary

Implement Init Harness Detection by adding two small Reason helper modules: `Bootstrap_harness_detection.re` for injectable, secret-free local Harness probing, and `Bootstrap_settings.re` for structured Runtime Settings generation. `Runtime_home.bootstrap` remains the idempotent file-creation owner and calls these helpers only when `.symphony/settings.json` is absent.

Primary trade-off: this adds a narrow Bootstrap-specific detection boundary instead of folding probing into `Config.ml`. That keeps runtime readiness authoritative and testable, at the cost of a small amount of new plumbing through `Runtime_home`, `Runtime_startup`, and `main.ml`.

## System Architecture

### Component Overview

| Component | Responsibility | Boundary |
| --- | --- | --- |
| `Bootstrap_harness_detection.re` | Detect supported Harness capabilities through an injectable probe and produce selected-Harness guidance. | No file writes, no Runtime Contract mutation, no secret values. |
| `Bootstrap_settings.re` | Generate `Yojson.Safe` Runtime Settings using existing Harness and Logical Agent semantics. | Settings generation only; no probing. |
| `Runtime_home.ml` | Preserve Runtime Home pathing and idempotent file creation. | Calls settings builder only when settings are missing. |
| `Runtime_startup.re` | Carry Bootstrap report and guidance into implicit startup. | No detection policy. |
| `main.ml` | Render Bootstrap report and Harness guidance for `symphony init` and normal startup. | Presentation only. |
| `Config.ml` | Continue parsing Runtime Settings and enforcing runtime readiness. | Runtime authority remains here. |

## Implementation Design

### Core Interfaces

The implementation will use Reason records, but the dependency shape is:

```go
type BootstrapHarnessDetection struct {
  Supported []HarnessStatus
  Selected  *HarnessStatus
  Guidance  []string
  SettingsMode string
}

type HarnessStatus struct {
  Name string
  Kind string
  ExecutableAvailable bool
  AuthSignal string
  Remediation string
}
```

Reason-facing concepts:

- `probe`: injectable record of command/auth checks.
- `harness_status`: supported Harness name, kind, executable state, coarse auth state, remediation.
- `detection_result`: all statuses, selected Harness option, guidance lines.
- `settings_result`: serialized JSON string plus selected Harness metadata.

### Data Models

- Keep all supported Harness definitions in generated settings: `codex`, `claude`, `cursor`, `cursor-force`, and `pi`.
- Route `agents.planner`, `agents.engineer`, and `agents.reviewer` to the selected Harness.
- Never auto-select `cursor-force`; it remains an editable explicit Harness definition.
- Codex Bootstrap detection checks executable availability only and must not claim full auth or dispatch readiness.
- Claude, Cursor, and PI detection reuse or wrap existing install/auth probes where practical.
- Existing `.symphony/settings.json` means detection does not regenerate settings and guidance reports preservation.

### API Endpoints

None. This feature changes CLI Bootstrap behavior and Runtime Settings generation only.

## Integration Points

| Integration Point | Change |
| --- | --- |
| Local CLI environment | Probe allowlisted Harness commands without capturing secrets. |
| Runtime Settings | Generate structured JSON instead of relying on a static raw string. |
| Runtime readiness | No authority change; dispatch remains gated by existing readiness checks. |
| CLI output | Add concise Harness guidance alongside existing Bootstrap report. |

## Impact Analysis

| Component | Impact Type | Description and Risk | Required Action |
| --- | --- | --- | --- |
| `apps/backend/lib/runtime_home.ml` | Modified | Static settings write becomes generated settings write when missing. Risk: idempotency regression. | Preserve `ensure_file` semantics and add regression tests. |
| `apps/backend/lib/Bootstrap_harness_detection.re` | New | Owns detection/probe contract. Risk: secret leakage or nondeterminism. | Use injectable probes and secret-free result types. |
| `apps/backend/lib/Bootstrap_settings.re` | New | Owns structured JSON generation. Risk: generated shape drift. | Parse generated settings through `Config.from_settings_file`. |
| `apps/backend/lib/runtime_startup.re` | Modified | Carries Bootstrap guidance into normal startup. Risk: startup output inconsistency. | Reuse same guidance type as `symphony init`. |
| `apps/backend/bin/main.ml` | Modified | Renders guidance. Risk: overconfident wording. | Use fixed wording that points to runtime readiness. |
| `apps/backend/test/test_backend.ml` | Modified | Adds focused Bootstrap and detection tests. Risk: large file churn. | Add targeted cases near existing Bootstrap and Harness readiness tests. |
| `README.md` / `docs/adr/0021...` | Modified | Documents adaptive Bootstrap semantics. | Keep terminology aligned with `CONTEXT.md`. |

## Testing Approach

### Unit Tests

- Detection selection with injected probes:
  - Codex-only
  - Claude-only
  - Cursor-only
  - PI-only
  - multiple usable Harnesses with deterministic priority
  - no usable Harness
- Codex detection verifies executable availability only.
- Generated JSON parses through `Config.from_settings_file`.
- Secret marker checks reject token-like values and `.env` contents in settings/guidance.

### Integration Tests

- `Runtime_home.bootstrap` creates adaptive settings only when missing.
- Existing `.symphony/settings.json` is byte-preserved.
- `symphony init` output includes selected-Harness, no-Harness, and existing-settings guidance.
- Normal `symphony --once` startup includes the same Bootstrap guidance when implicit Bootstrap creates settings.
- Existing selected readiness tests for Claude, Cursor, and PI remain authoritative.

## Development Sequencing

### Build Order

1. Add `Bootstrap_harness_detection.re` with injectable probe types and pure selection rules - no dependencies.
2. Add detection unit tests - depends on step 1.
3. Add `Bootstrap_settings.re` structured JSON builder - depends on step 1.
4. Add settings shape tests that parse generated JSON through `Config` - depends on step 3.
5. Modify `Runtime_home.bootstrap` to call the settings builder only when settings are missing - depends on steps 1 and 3.
6. Thread guidance through `Runtime_startup.re` and render it in `main.ml` - depends on step 5.
7. Add CLI/output and idempotency regression tests - depends on steps 5 and 6.
8. Update README and product ADR documentation - depends on final behavior from steps 5-7.

### Technical Dependencies

- Existing `Config` Harness defaults, parsing, and readiness helpers.
- Existing Runtime Home pathing and file preservation behavior.
- Backend verification through `pnpm test`.

## Monitoring and Observability

- Bootstrap stderr output should include:
  - selected Harness name and kind when generated settings select one,
  - no supported usable Harness guidance when none is selected,
  - existing settings preserved when settings are skipped.
- Terminal Console startup logs should include the same concise guidance when implicit Bootstrap creates settings.
- No metrics or long-lived runtime state are required for MVP.

## Technical Considerations

### Key Decisions

- **Decision:** Use new Reason helper modules for detection and settings generation.
  **Rationale:** Keeps probing and JSON generation testable without bloating `Runtime_home.ml` or turning `Config.ml` into a Bootstrap generator.
  **Trade-off:** Adds new module boundaries and plumbing.

- **Decision:** Keep all supported Harness definitions in generated settings.
  **Rationale:** Preserves editability while selected Logical Agent routes determine readiness impact.
  **Trade-off:** Generated settings remain larger than a selected-Harness-only file.

- **Decision:** Codex Bootstrap detection checks executable availability only.
  **Rationale:** Current runtime readiness does not model general Codex auth readiness.
  **Trade-off:** Codex may be selected with weaker confidence than Claude, Cursor, or PI.

- **Decision:** Prioritize injected probe unit tests plus focused Bootstrap output tests.
  **Rationale:** Avoids coupling tests to the developer machine.
  **Trade-off:** Full binary E2E coverage remains limited.

### Known Risks

- Probe helpers can leak or over-read local auth state if result types are not constrained.
- `Config` helper reuse can create module cycles if dependencies flow backward.
- Mixed OCaml/Reason edits can introduce friction; keep new modules in Reason and owner edits surgical.
- Bootstrap wording can imply readiness if guidance is not explicit.

## Architecture Decision Records

- [ADR-001: Seed Missing Runtime Settings From Local Harness Detection](adrs/adr-001.md) - Bootstrap may use local detection to seed missing Runtime Settings while preserving runtime readiness authority.
- [ADR-002: Optimize MVP Around Transparent Bootstrap Guidance](adrs/adr-002.md) - The MVP prioritizes clear selected-Harness and next-step guidance over aggressive auto-selection.
- [ADR-003: Isolate Bootstrap Detection and Settings Generation in Reason Helpers](adrs/adr-003.md) - Detection and settings generation live in small injectable Reason helpers, while Runtime Home preserves idempotent file creation.
