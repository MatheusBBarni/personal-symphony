# Testing Guide

Backend:
- Use `pnpm test` for OCaml behavior.
- The backend suite is in `apps/backend/test/test_backend.ml` and includes config, Bootstrap, Git worktree, orchestration, stage commit, auto-merge, and server cases.
- Prefer adding cases near related existing tests.

Frontend:
- Use `pnpm frontend:test` for live-state stream parsing and Audio Notification transition rules.
- Use `pnpm frontend:build` for ReScript and Vite compilation.
- ReScript emits ignored `.res.js` files beside source files during build; generated files must not be committed.

Packaging:
- Use `pnpm prepack` before validating npm package contents or `vendor/` binary behavior.
