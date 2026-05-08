# Task Memory: task_04.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Implement Task 04: accept Claude as a Harness kind, add selected-only Claude readiness checks, render Claude commands with model/reasoning placeholders, defensively parse Claude CLI `stream-json` into normalized live activity and usage, and preserve raw stdout/stderr logs.

## Important Decisions
- Claude readiness is selected-Harness-only, matching PI readiness behavior: unused Claude Harness definitions do not create install/auth gaps.
- Claude auth readiness checks for non-secret signals only: configured environment auth, `CLAUDE_CONFIG_DIR`/`~/.claude/.credentials.json`, or a command settings reference intended for `apiKeyHelper`.
- Claude stream parsing is read-only over the existing stdout/stderr log files; `shell_launch` still writes raw provider output unchanged.

## Learnings
- Claude Code docs describe CLI `stream-json` as newline-delimited JSON. Live partial text arrives on `stream_event.event.content_block_delta.delta.text`, tool starts on `content_block_start` with a `tool_use` content block, and message usage can appear on message-level/final result usage fields.
- This repository has no configured coverage instrumentation command found by searching for coverage/Bisect configuration; backend verification is currently `pnpm test`.

## Files / Surfaces
- Planned primary surfaces: `apps/backend/lib/config.ml`, `apps/backend/lib/orchestrator.ml`, and `apps/backend/test/test_backend.ml`.
- Touched `apps/backend/lib/config.ml` for Claude executable/auth readiness.
- Touched `apps/backend/lib/orchestrator.ml` for defensive Claude `stream-json` parsing and running-row activity updates.
- Touched `apps/backend/test/test_backend.ml` for command rendering, readiness, parser, and fake Claude stream integration tests.

## Errors / Corrections
- Repository root did not contain `AGENTS.md` or `CLAUDE.md`; this run uses the inline `AGENTS.md` instruction plus `/Users/matheusbbarni/.codex/RTK.md`.
- Corrected repository root: implementation files live in `/Users/matheusbbarni/projects/symphony-orchestrator`, not `/Users/matheusbbarni/projects/pi-agent-native`.
- First `pnpm test` failed on OCaml warning 23 (`useless-record-with`) in the new Claude parser; removed the redundant record `with` and reran successfully.

## Ready for Next Run
- Final backend verification evidence: `pnpm test` exited 0, and `opam exec -- dune exec apps/backend/test/test_backend.exe` passed 167 Alcotest cases.
- Local implementation commit: `8892c84 feat: add claude harness readiness and stream parsing`.
- Task tracking and memory files are intentionally left unstaged/out of the implementation commit.
