# Personal Symphony Agent Contract

## Commands

- Install deps with `pnpm install`.
- Run all backend tests with `pnpm test`.
- Run frontend live-state tests with `pnpm frontend:test`.
- Build frontend assets with `pnpm frontend:build`.
- Build the OCaml backend with `pnpm backend:build`.
- Build the package payload with `pnpm prepack`.
- Run backend dev server with `pnpm backend:dev` from the Product Repository root.
- Run frontend dev server with `pnpm frontend:dev`; Vite proxies `/api` to `http://127.0.0.1:8080`.

## Stack

- Backend is OCaml/Dune with `cmdliner`, `yojson`, and `alcotest`.
- Frontend is ReScript React compiled to ignored `.res.js` files, then Vite.
- Package distribution is npm `bin/symphony.js` plus a platform binary in `vendor/`.
- Runtime files belong to a Workspace Repository under `.symphony/`; this repo is the Product Repository.

## Boundaries

### Always

- MUST use the glossary in `CONTEXT.md` for product terms such as Workspace Repository, Product Repository, Runtime Home, Runtime Contract, Loop-Start Branch, and Task Branch.
- MUST update `CONTEXT.md` when adding or changing domain language.
- MUST add or update an ADR under `docs/adr/` for architecture decisions that change runtime semantics.
- MUST edit `.res` sources only; generated `apps/frontend/src/*.res.js` files are ignored and must not be committed. Run `pnpm frontend:build` or `pnpm --filter @personal-symphony/frontend rescript:build` after ReScript changes.
- MUST keep `symphony` commands rooted in a Workspace Repository; root validation is an accepted product behavior.
- MUST preserve idempotent Bootstrap behavior: create missing Runtime Home files without overwriting user-edited runtime files.
- MUST treat `GITHUB_TOKEN` and `GH_TOKEN` as secret values; only variable names belong in docs or examples.

### Ask First

- Ask before changing Runtime Contract defaults in `apps/backend/lib/runtime_home.ml`.
- Ask before changing Task Branch cleanup or auto-merge defaults.
- Ask before replacing the GitHub Issues + Projects tracker model.
- Ask before changing npm package files, `bin/symphony.js`, or packaged-binary behavior.
- Ask before splitting the large backend test file unless the task explicitly targets test structure.

### Never

- NEVER commit secrets, token values, webhook URLs, or local `.env` contents.
- NEVER commit generated `apps/frontend/src/*.res.js` files.
- NEVER auto-merge task work into a Protected Trunk Branch.
- NEVER force-push as part of Stage Push or Batch Branch Push behavior.
- NEVER overwrite existing `.symphony/settings.json`, `.symphony/prompt.md`, `.symphony/agents/*`, or `.symphony/.env` during Bootstrap.

## Landmines

- `CONTEXT.md` is the domain source of truth and is large; read the relevant terms, then close it.
- `README.md` and `.github/project-tracking.md` still contain legacy `WORKFLOW.md` references; current runtime contract semantics live under `.symphony/`.
- `apps/backend/test/test_backend.ml` is a 2K-line integration-heavy suite; prefer targeted test additions near existing related cases.
- `apps/backend/lib/orchestrator.ml`, `config.ml`, `github_tracker.ml`, and `server.ml` are large shared modules; run focused backend tests after touching them.
- `apps/backend/lib/runtime_home.ml` embeds default JSON and agent prompt templates; keep examples secret-free and idempotent.
- `scripts/package-binary.js` copies `_build/default/apps/backend/bin/main.exe` into `vendor/symphony-<platform>-<arch>` or `vendor/symphony-win32-<arch>.exe`; packaging depends on that exact Dune output.

## Patterns

- Runtime settings use JSON in `.symphony/settings.json`; legacy `WORKFLOW.md` remains only for fixture/import compatibility.
- Git integration uses per-task Git worktrees under `.symphony/workspaces/` and Task Branches with the configured prefix.
- Stage Commit happens before a task moves to success status; Stage Push, when enabled, pushes the Task Branch non-force.
- Batch Pull Request creation is deterministic and disabled by default.
- Frontend Live Dashboard state is shaped by `Runtime_state` snapshots, not event envelopes.
