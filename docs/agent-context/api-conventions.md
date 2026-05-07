# API Conventions

- Backend HTTP state should expose Runtime State snapshots for the Web Dashboard.
- The frontend consumes snapshots through the Live Dashboard Connection.
- API changes that alter snapshot shape should update `apps/backend/lib/runtime_state.ml`, frontend snapshot types and mapping in `apps/frontend/src/Main.res`, live connection compatibility in `apps/frontend/src/LiveState.res`, and tests on both sides.
- GitHub tracker changes should preserve the Issues + Projects boundary and keep token values redacted from user-facing errors.

## Agent Context fields

Runtime State exposes Agent Context Snapshot and Context Command status as supplemental task data:

- `running[].context_status`
- `retrying[].context_status`
- top-level `context_diagnostics`

`context_status` shape:

```json
{
  "state": "succeeded",
  "summary": "Agent Context Snapshot generated; Context Command succeeded.",
  "diagnostics_path": "/path/to/workspace/.symphony/state/context-diagnostics/_43-attempt-1-1760000000000000.json"
}
```

`state` is one of `skipped`, `succeeded`, `warning`, `timed_out`, or `failed`. Consumers must not treat this field as the task's project status, retry status, Goal Usage, or readiness result. It is a per-task Runtime State summary for context generation only.

Older Runtime State snapshots may omit `context_status`. Frontend code should treat absence as compatible and avoid failing live-state parsing.

`context_diagnostics` is a bounded summary list for recent Context Diagnostics files. It may expose local diagnostic paths and bounded metadata such as command name, cwd kind, timeout flag, exit code, stdout/stderr byte counts, and truncation flag. It must not expose full Agent Prompt text, full Context Command stdout/stderr, token values, or Local Environment contents.

The API exposes diagnostic paths for operators and maintainers running on the same Workspace Repository. It does not create a browser download endpoint for diagnostic file contents.
