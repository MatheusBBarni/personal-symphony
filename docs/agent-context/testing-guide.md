# Testing Guide

Backend:
- Use `pnpm test` for OCaml behavior from the Product Repository root.
- The backend suite is in `apps/backend/test/test_backend.ml` and includes config, Bootstrap, Git worktree, orchestration, stage commit, auto-merge, server, and Agent Context cases.
- Prefer adding cases near related existing tests.

Frontend:
- Use `pnpm frontend:test` for live-state stream parsing, Runtime State compatibility, and Audio Notification transition rules.
- Use `pnpm frontend:build` for ReScript and Vite compilation after ReScript source changes.
- ReScript emits ignored `.res.js` files beside source files during build; generated files must not be committed.

Packaging:
- Use `pnpm prepack` before validating npm package contents or `vendor/` binary behavior.
- Use `pnpm npm:validate` to pack the CLI Package, install the tarball into a
  temporary global npm prefix, and verify that the installed `symphony` command runs.
- Use `pnpm npm:validate:release` before publishing; it also requires the Linux, macOS, and Windows
  vendor binaries to be present in the packed tarball.

## Agent Context coverage

Agent Context changes should keep coverage for:
- Runtime Settings parsing and Readiness Gaps for `context.snapshot` and `context.command`.
- Agent Prompt composition with Agent Context Snapshot, Stage Goal Handoff, Stage Skill Load, issue comments, and retry Previous Attempt Output.
- Context Command execution from `agentWorktree` and `workspaceRepositoryRoot` cwd values.
- Context Command failure behavior: missing executable, non-zero exit, signal, timeout, stdout truncation, and secret redaction.
- Runtime State exposure for `context_status` and `context_diagnostics` through HTTP and the Live Dashboard Connection.
- Context Diagnostics persistence, pruning, bounded metadata, Runtime Contract separation, and absence of full stdout/stderr or token values.
- Frontend live-state parsing for context status fields without treating them as primary task status.

Useful focused backend checks:

```sh
opam exec -- dune build --root . @apps/backend/test/runtest --no-buffer
```

Broader checks before final handoff when implementation slices have landed:

```sh
pnpm test
pnpm frontend:test
```

When running from an Agent Worktree nested under `.symphony/workspaces/`, Dune may need an explicit source root. In that case, the backend equivalent is:

```sh
pnpm test -- --root . --no-buffer
```
