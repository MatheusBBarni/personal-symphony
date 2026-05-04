# Backend Scope

Use this when editing `apps/backend/**`.

- MUST run backend verification with `pnpm test` after changing OCaml runtime behavior.
- MUST keep Bootstrap idempotent; `Runtime_home.bootstrap` creates missing files and preserves existing user edits.
- MUST preserve repository-root enforcement in `Runtime_home.require_workspace_root`.
- MUST keep GitHub token values out of logs, docs, and test output.
- MUST use existing `Util.shell_quote` patterns for shell commands.
- MUST update or add Alcotest cases in `apps/backend/test/test_backend.ml` for changes to config parsing, orchestration, Git behavior, runtime state, or HTTP responses.
- NEVER force-push from orchestrator paths; pushes are non-force by product contract.

Large modules:
- `orchestrator.ml` owns polling, dispatch, stage commits, retries, auto-merge, and Batch Pull Request handoff.
- `config.ml` owns legacy workflow parsing plus current `.symphony/settings.json` parsing.
- `runtime_home.ml` owns Bootstrap defaults and Runtime Home file creation.
- `github_tracker.ml` owns GitHub Issues and Projects API boundaries.
