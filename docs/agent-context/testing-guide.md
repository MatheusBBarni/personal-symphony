# Testing Guide

Backend:
- Use `pnpm test` for OCaml behavior.
- The backend suite is in `apps/backend/test/test_backend.ml` and includes config, Bootstrap, Git worktree, orchestration, stage commit, auto-merge, and server cases.
- Prefer adding cases near related existing tests.

Frontend:
- Use `pnpm frontend:test` for `liveState.js` stream parsing.
- Use `pnpm frontend:build` for ReScript and Vite compilation.
- ReScript emits `.res.js` beside source files; generated files should follow `.res` edits.

Packaging:
- Use `pnpm prepack` before validating npm package contents or `vendor/` binary behavior.
