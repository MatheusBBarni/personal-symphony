# Claude Context

@AGENTS.md

Read narrowly:
- `CONTEXT.md` only for domain terms affected by the task.
- `docs/adr/` only for runtime or architecture decisions touched by the task.
- `docs/agent-context/` for deeper implementation notes when root context is insufficient.

When context gets heavy after roughly 40 messages, update `HANDOFF.md`, clear the session, and restart from `HANDOFF.md` plus this file.

When a mistake exposes a missing durable rule, fix the mistake and add one concise prevention rule to `AGENTS.md`.

Before completion, run the most focused command that covers the change; for shared backend behavior prefer `pnpm test`, and for frontend state/UI behavior prefer `pnpm frontend:test` plus `pnpm frontend:build`.
