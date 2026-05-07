/goal {"kind":"Stage Goal Context","issue_identifier":"#39","title":"Carry Retry Output Into The Agent Context Snapshot","description":"## What to build\n\nExtend the built-in Agent Context Snapshot so retry launches include bounded context from the previous failed attempt. The retry context should help the next agent continue without storing or replaying the full transcript.\n\n## Acceptance criteria\n\n- [ ] Include previous attempt number and a bounded stdout/stderr tail when launching a retry.\n- [ ] Keep retry output out of the snapshot on first launch.\n- [ ] Truncate retry output deterministically with a clear truncation marker.\n- [ ] Avoid persisting full prompt text or full Codex transcript content as part of this slice.\n- [ ] Add backend tests for first launch, retry launch, stdout/stderr truncation, and prompt ordering with Stage Goal Handoff enabled.\n\n## Blocked by\n\n- #38\n\n# SPEC\n\n---\ntitle: Agent Context Retry Output\nversion: 1.0\ndate_created: 2026-05-06\nlast_updated: 2026-05-06\nowner: Product Repository maintainers\ntags: [process, agent-context, retry, issue-39]\n---\n\n# Introduction\n\nThis specification defines how bounded previous-attempt output is included in Agent Context Snapshot content for retry launches.\n\nSource issue: [#39 Carry Retry Output Into The Agent Context Snapshot](https://github.com/MatheusBBarni/symphony-orchestrator/issues/39).\n\n## 1. Purpose & Scope\n\nThe purpose is to give retrying agents useful failure context without storing or replaying a full Codex transcript.\n\nThis specification covers retry-only stdout/stderr tail selection, truncation, prompt ordering, and tests.\n\nOut of scope:\n\n- First-launch snapshot fields. Covered by issue #38.\n- Persisted diagnostics. Covered by issue #42.\n\n## 2. Definitions\n\n- **Retry Launch**: A new agent dispatch attempt after a previous attempt failed or stopped unsuccessfully.\n- **Previous Attempt Output**: The stdout and stderr files captured from the immediately previous agent process.\n- **Agent Context Snapshot**: The bounded markdown section added to the Agent Prompt.\n- **Stage Goal Handoff**: Optional Codex goal handoff sent before the normal Agent Prompt.\n- **Runtime State**: Snapshot data that records running, retrying, and error activity.\n\n## 3. Requirements, Constraints & Guidelines\n\n- **REQ-001**: Retry output MUST be omitted on first launch.\n- **REQ-002**: Retry output MUST include the previous attempt number.\n- **REQ-003**: Retry output SHOULD include bounded tails for stdout and stderr when available.\n- **REQ-004**: Truncation MUST be deterministic and marked clearly.\n- **REQ-005**: Missing stdout or stderr files MUST render as unavailable, not as an error.\n- **REQ-006**: Retry context MUST preserve Stage Goal Handoff ordering.\n- **CON-001**: Retry context MUST NOT persist full Codex transcripts.\n- **CON-002**: Retry context MUST NOT include full rendered Agent Prompt content.\n- **GUD-001**: Prefer byte caps over line caps when enforcing maximum prompt contribution size.\n\n## 4. Interfaces & Data Contracts\n\n### Retry Snapshot Section\n\n````md\n### Previous Attempt\n\n- Previous attempt: 1\n- stdout tail bytes: 4096\n- stderr tail bytes: 4096\n\n#### stdout tail\n\n```text\n...\n```\n\n#### stderr tail\n\n```text\n...\n```\n````\n\n### Truncation Marker\n\n```text\n[truncated to 4096 bytes]\n```\n\n## 5. Acceptance Criteria\n\n- **AC-001**: Given attempt `1`, When the Agent Context Snapshot renders, Then previous attempt output is absent.\n- **AC-002**: Given attempt `2` and captured stdout/stderr, When the snapshot renders, Then bounded tails are present.\n- **AC-003**: Given output larger than the byte cap, When the snapshot renders, Then content is truncated with a stable marker.\n- **AC-004**: Given Stage Goal Handoff is enabled, When a retry prompt is composed, Then retry context remains after the normal prompt content.\n- **AC-005**: Given one output file is missing, When rendering occurs, Then the missing stream is reported as unavailable.\n\n## 6. Test Automation Strategy\n\n- **Test Levels**: Backend unit tests and orchestration tests.\n- **Frameworks**: OCaml Alcotest.\n- **Test Data Management**: Use temporary stdout/stderr files with known content.\n- **CI/CD Integration**: Run `pnpm test`.\n- **Coverage Requirements**: First launch, retry launch, missing files, stdout truncation, stderr truncation, and ordering.\n- **Performance Testing**: Verify bounded file reading for large files.\n\n## 7. Rationale & Context\n\nRetries need concrete failure context, but full transcripts create size, privacy, and determinism problems. Captured process output already exists in Symphony's launch model and can be bounded before prompt injection.\n\n## 8. Dependencies & External Integrations\n\n### Infrastructure Dependencies\n\n- **INF-001**: Agent Worktree launch artifacts - Provide stdout and stderr paths.\n- **INF-002**: Runtime Home - Contains ignored runtime artifacts.\n\n### Technology Platform Dependencies\n\n- **PLT-001**: OCaml backend - Implements retry and prompt composition.\n\n## 9. Examples & Edge Cases\n\n```text\nAttempt 1: no previous output section.\nAttempt 2: previous attempt 1 stdout and stderr tails included.\nAttempt 3: previous attempt 2 output included, not attempt 1 output.\n```\n\nEdge cases:\n\n- Empty stdout.\n- Empty stderr.\n- Binary or invalid UTF-8 output.\n- Output files deleted during cleanup.\n\n## 10. Validation Criteria\n\n- `pnpm test` passes.\n- Retry prompt content is bounded and deterministic.\n- Full transcript content is not stored or rendered.\n\n## 11. Related Specifications / Further Reading\n\n- [Issue #39](https://github.com/MatheusBBarni/symphony-orchestrator/issues/39)\n- [Issue #38](https://github.com/MatheusBBarni/symphony-orchestrator/issues/38)\n- [CONTEXT.md](../CONTEXT.md)\n","comments":[],"url":"https://github.com/MatheusBBarni/symphony-orchestrator/issues/39","current_project_status":"In Progress","labels":["enhancement"],"priority":null,"blocker_references":[],"attempt":0,"stage_agent_name":"engineer"}

---

You are the Engineer agent for the Personal Symphony Self-Dogfooding Workspace Repository.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Responsibilities:
- Implement only the scoped issue.
- Use CONTEXT.md terms and follow AGENTS.md.
- Prefer existing module boundaries and tests over new abstractions.
- Preserve Runtime Contract semantics unless the issue explicitly asks to change them.
- Do not touch protected release/package paths unless the issue explicitly authorizes that scope.
- Edit ReScript .res sources only; never commit generated .res.js files.
- Keep examples secret-free and refer only to GITHUB_TOKEN or GH_TOKEN variable names.
- Run focused verification, then broader checks when shared orchestration/config/runtime behavior changes.

Stage Commit is enabled for this stage. Leave the worktree ready for a local commit boundary before review.

---

Stage agent: engineer

You are working on GitHub issue #39: Carry Retry Output Into The Agent Context Snapshot.

Repository issue URL: https://github.com/MatheusBBarni/symphony-orchestrator/issues/39
Current project status: In Progress
Attempt: 

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
