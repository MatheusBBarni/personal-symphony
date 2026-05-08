# Task Memory: task_10.md

Keep only task-local execution context here. Do not duplicate facts that are obvious from the repository, task file, PRD documents, or git history.

## Objective Snapshot
- Update user-facing tracker docs so GitHub is documented as the default Issue Tracker and minibeads is documented as an explicit first-class Local Issue Tracker option.
- Add validation coverage for docs examples, secret safety, and glossary terminology before marking task tracking complete.

## Important Decisions
- Keep Runtime Contract defaults unchanged; this task is documentation and docs-validation only.
- Existing `CONTEXT.md` terms for Issue Tracker, GitHub Tracker, Local Issue Tracker, Local Issue File, Runtime Settings, and Readiness Gap are sufficient unless implementation reveals a terminology gap.

## Learnings
- Current README setup/prerequisite sections are GitHub-only before this task and do not yet document minibeads setup or readiness guidance.
- `.github/project-tracking.md` is intentionally GitHub-specific but should explicitly say it applies to `tracker.kind = "github"` only.
- `pnpm build` currently emits Vite warnings about ignored third-party `"use client"` directives, but exits successfully.

## Files / Surfaces
- Updated: `README.md`, `.github/project-tracking.md`, `package.json`, `scripts/validate-docs-examples.js`, task tracking files.
- Did not update `CONTEXT.md`; existing glossary terms already cover the task language.

## Errors / Corrections
- Initial skill path lookup under `~/.codex/skills` failed; installed repo-local skill files under `.agents/skills` were used instead.
- `rtk git diff -- ...` treated the path as a revision; reran the diff through `rtk proxy git diff -- ...`.

## Ready for Next Run
- Verification evidence before tracking updates: `pnpm docs:test` passed with 9 JSON examples checked across 2 docs; `pnpm test` exited 0; `pnpm build` exited 0 with third-party Vite warnings only.
