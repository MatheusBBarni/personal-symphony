---
description: Backend package rules
globs:
  - "apps/backend/**"
---

# Backend Rules

Apply these rules when editing `apps/backend/**`.

- MUST write new backend OCaml source modules in ReasonML (`.re`/`.rei`). Do not add new `.ml`/`.mli` backend modules unless the user explicitly asks for an OCaml-syntax file.
- MUST keep non-source backend files in their native formats, including `dune`, fixtures, JSON, Markdown, shell scripts, and generated package metadata.
- MUST run `pnpm test` after changing OCaml runtime behavior.
- SHOULD run `pnpm backend:build` after backend compile-surface changes.
- MUST keep `symphony` commands rooted in a Workspace Repository; root validation is accepted product behavior.
- MUST preserve idempotent Bootstrap behavior: create missing Runtime Home files without overwriting user-edited runtime files.
- MUST keep `GITHUB_TOKEN` and `GH_TOKEN` values out of logs, docs, fixtures, examples, and test output.
- MUST add or update focused Alcotest coverage in `apps/backend/test/test_backend.ml` for changes to config parsing, orchestration, Git behavior, runtime state, startup behavior, Terminal Console behavior, or HTTP responses.
- Ask before changing Runtime Contract defaults in `apps/backend/lib/runtime_home.ml`.
- Ask before changing Task Branch cleanup or auto-merge defaults.
- Ask before replacing the GitHub Issues + Projects tracker model.
- NEVER force-push as part of Stage Push or Batch Branch Push behavior.
- NEVER auto-merge task work into a Protected Trunk Branch.

Large shared modules need focused verification after edits:

- `apps/backend/lib/orchestrator.ml` owns polling, dispatch, Stage Commit, retries, auto-merge, and Batch Pull Request handoff.
- `apps/backend/lib/config.ml` owns legacy workflow parsing plus current `.symphony/settings.json` parsing.
- `apps/backend/lib/runtime_home.ml` owns Bootstrap defaults and Runtime Home file creation.
- `apps/backend/lib/github_tracker.ml` owns GitHub Issues and Projects API boundaries.
- `apps/backend/lib/server.ml` owns HTTP behavior for the Web Dashboard.
