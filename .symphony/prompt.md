You are working on GitHub issue {{ issue.identifier }}: {{ issue.title }}.

Repository issue URL: {{ issue.url }}
Current project status: {{ issue.state }}
Attempt: {{ attempt }}

This repository is a Self-Dogfooding Workspace Repository: it is both the Personal Symphony Product Repository and the Workspace Repository for this run. Use the glossary in CONTEXT.md for domain terms, and follow AGENTS.md before making changes.

Runtime boundaries:
- Keep symphony commands rooted in the Workspace Repository.
- Treat GITHUB_TOKEN and GH_TOKEN as secret values. Documentation may name the variables but must never include token values, webhook URLs, or local .env contents.
- Do not commit .symphony/.env, .symphony/state/, or .symphony/workspaces/.
- Do not commit generated apps/frontend/src/*.res.js files. Edit .res sources only and run the relevant ReScript/frontend build after ReScript changes.
- Preserve Idempotent Bootstrap behavior. Runtime Home files must be created when missing without overwriting user-edited Runtime Contract or Local Environment files.

Protected-path guidance:
- Do not modify release, package, or packaged-binary paths unless the issue explicitly scopes that work.
- Protected paths include bin/symphony.js, scripts/package-binary.js, vendor/, package.json, pnpm-lock.yaml, .github/workflows/, apps/backend/lib/runtime_home.ml Runtime Contract defaults, and package/export release documentation.
- If the requested work appears to require one of these paths but the issue does not explicitly authorize it, stop and move the task to Human attention with a clear comment.

Dogfood workflow:
- Routine development should validate source-checkout behavior.
- Installed CLI Package validation belongs only to release, update, or packaging issues that explicitly ask for it.
- Stage Push is disabled. Do not push Task Branches unless the operator explicitly asks.
- main is a Protected Trunk Branch. Do not auto-merge task work into main.
- The intended Loop-Start Branch for orchestration is symphony/dogfood until an Allowed Loop-Start Branch Policy is implemented.

Make focused changes, run targeted verification, and report the exact files changed and checks run.
