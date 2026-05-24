# Codebase Improvement Scan - Discovery Task List

> MVP discovery artifact: this `_tasks.md` is non-runnable backlog output. Do not run `compozy tasks validate --name codebase-improvement-scan` against it until Phase 2 converts selected findings into executable `task_NN.md` Compozy Task Steps.

## Tasks

| ID | Title | Category | Boundary | Priority | Guardrail | Deferred |
| --- | --- | --- | --- | --- | --- | --- |
| F-001 | Make custom GitHub token env names actually work with `gh api` | Runtime Contract drift | Runtime Contract, CLI | Critical | yes | no |
| F-002 | Validate `server.port` consistently across Runtime Settings and CLI overrides | defect | Runtime Contract, Web Dashboard, CLI | Critical | yes | no |
| F-003 | Preserve Context Status for attention rows in the Web Dashboard | defect | Web Dashboard, Runtime State | High | no | no |
| F-004 | Replace misleading Web Dashboard metric labels | polish | Web Dashboard | High | no | no |
| F-005 | Stop `backend:dev` from presenting legacy `WORKFLOW.example.md` as the normal dev path | docs hygiene | maintainer workflow, CLI | High | no | no |
| F-006 | Catch staged generated ReScript artifacts in documentation validation | agent-readiness risk | frontend, maintainer workflow | High | yes | no |
| F-007 | Fix stale frontend guidance that points agents at a nonexistent JavaScript boundary file | docs hygiene | frontend, maintainer workflow | Medium | yes | no |
| F-008 | Add ADR-number uniqueness guardrails | docs hygiene | docs, maintainer workflow | High | yes | no |
| F-009 | Re-characterize the backend integration test monolith before any split | maintainability | backend, maintainer workflow | Medium | no | yes |
| F-010 | Decompose `orchestrator.ml` only after a behavior-preserving boundary map exists | maintainability | backend, Runtime State, Task Branch | Medium | no | yes |
| F-011 | Remove duplicated Bootstrap Runtime Settings defaults | Runtime Contract drift | Runtime Home, Bootstrap | High | yes | yes |
| F-012 | Improve generated Runtime Home environment template coverage | polish | Runtime Home, Bootstrap | Medium | no | no |
| F-013 | Consolidate or formally constrain the repository's YAML/frontmatter parsers | maintainability | Compozy Task Step, backend | Medium | yes | yes |
| F-014 | Scope Compozy `_tasks.md` ready-status parsing so body metadata cannot masquerade as run-level intake state | Runtime Contract drift | Compozy PRD Run | High | yes | no |
| F-015 | Share Web Dashboard host normalization between config parsing and server binding | maintainability | Web Dashboard, CLI | Medium | yes | yes |
| F-016 | Replace impossible-state `assert false` in CLI branch selection with an explicit diagnostic | defect | CLI | Medium | no | no |
| F-017 | Replace dashboard auth-token `failwith` with typed startup failure handling | security/blast-radius | Web Dashboard | Medium | no | no |
| F-018 | Add safer affordances to the Compozy completion utility before it moves PRD Run directories | product polish | Compozy PRD Run, maintainer workflow | Low | no | no |

## F-001: Make custom GitHub token env names actually work with `gh api`

- Category: Runtime Contract drift
- Boundary: Runtime Contract, CLI
- Priority: Critical
- Evidence:
  - `.github/project-tracking.md:46` says `tracker.apiKeyEnv` names the Local Environment variable that contains the GitHub token.
  - `apps/backend/lib/config.ml:1731` reads `tracker.apiKeyEnv`, and `apps/backend/lib/config.ml:1784` resolves `api_key` from that configured environment name.
  - `apps/backend/lib/github_tracker.ml:193` builds `gh api graphql`, and `apps/backend/lib/github_tracker.ml:201` invokes it without passing the resolved token or remapping a custom variable to an environment name recognized by GitHub CLI.
- Acceptance target: A Workspace Repository that sets `tracker.apiKeyEnv` to a non-default variable either works deterministically with `gh api` or receives a startup Readiness Gap explaining that only GitHub CLI-supported token variables are accepted.
- Verification expectation:
  - Add a backend test where `tracker.apiKeyEnv` is a custom variable and `GITHUB_TOKEN`/`GH_TOKEN` are empty.
  - Run `pnpm test`.
- Runtime semantics impact: Runtime Contract
- Guardrail candidate: yes
- Deferred follow-up: no

## F-002: Validate `server.port` consistently across Runtime Settings and CLI overrides

- Category: defect
- Boundary: Runtime Contract, Web Dashboard, CLI
- Priority: Critical
- Evidence:
  - `apps/backend/lib/config.ml:1844` loads `server.port` with `json_int` and does not enforce the 1-65535 port range.
  - `apps/backend/lib/cli_command.re:117` defines `--port` as a raw integer option.
  - `apps/backend/lib/terminal_console_settings.re:117` through `apps/backend/lib/terminal_console_settings.re:125` already enforce non-empty, numeric, 1-65535 input for Terminal Console settings.
- Acceptance target: Runtime Settings, Terminal Console settings, and `--port` use one consistent port validation rule and reject invalid values before server startup.
- Verification expectation:
  - Add backend tests for `server.port: 0`, `server.port: 65536`, `--port 0`, and one valid edge value.
  - Run `pnpm test`.
- Runtime semantics impact: Runtime Contract
- Guardrail candidate: yes
- Deferred follow-up: no

## F-003: Preserve Context Status for attention rows in the Web Dashboard

- Category: defect
- Boundary: Web Dashboard, Runtime State
- Priority: High
- Evidence:
  - `apps/backend/lib/runtime_state.re:162` stores `context_statuses` independently by issue id.
  - `apps/backend/lib/terminal_console_model.re:454` through `apps/backend/lib/terminal_console_model.re:462` attaches Context Status to Terminal Console attention rows.
  - `apps/backend/lib/runtime_state.re:540` through `apps/backend/lib/runtime_state.re:552` serializes `issue_errors` without Context Status, while `apps/frontend/src/RuntimeStateSnapshot.res:133` through `apps/frontend/src/RuntimeStateSnapshot.res:138` types blocked task errors without Context Status.
  - `apps/frontend/src/RuntimeStateSnapshot.res:291` through `apps/frontend/src/RuntimeStateSnapshot.res:299` derives dashboard Context Status only from `running` and `retrying` rows.
- Acceptance target: A task with `issue_errors` and a current Context Status shows the same Context Status signal in the Web Dashboard that the Terminal Console shows.
- Verification expectation:
  - Add a frontend live-state test with an attention row and a Context Status value.
  - Run `pnpm frontend:test`.
- Runtime semantics impact: Runtime State
- Guardrail candidate: no
- Deferred follow-up: no

## F-004: Replace misleading Web Dashboard metric labels

- Category: polish
- Boundary: Web Dashboard
- Priority: High
- Evidence:
  - `apps/frontend/src/Pages/Dashboard.res:564` through `apps/frontend/src/Pages/Dashboard.res:575` labels the retrying count as "Network Queue" and total tokens as "Consumed (24h)".
  - `apps/backend/lib/terminal_console_model.re:627` through `apps/backend/lib/terminal_console_model.re:629` exposes the same Runtime State values as direct running, retrying, and total-token counts.
  - `CONTEXT.md:608` through `CONTEXT.md:611` keeps Goal Usage and token data in Runtime State and says token usage is not the primary Web Dashboard metric.
- Acceptance target: Dashboard metric labels describe the actual Runtime State values without implying network-only retries or a 24-hour token window.
- Verification expectation:
  - Update frontend live-state render assertions for the revised copy.
  - Run `pnpm frontend:test` and `pnpm frontend:build`.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: no

## F-005: Stop `backend:dev` from presenting legacy `WORKFLOW.example.md` as the normal dev path

- Category: docs hygiene
- Boundary: maintainer workflow, CLI
- Priority: High
- Evidence:
  - `package.json:34` runs `opam exec -- dune exec symphony -- --port 8080 --web WORKFLOW.example.md`.
  - `README.md:810` through `README.md:811` says `WORKFLOW.example.md` is only a legacy fixture/import compatibility file and must not be used as the active Runtime Contract.
  - `README.md:815` through `README.md:819` tells maintainers to start the backend dev server with `pnpm backend:dev`.
  - `.github/project-tracking.md:61` through `.github/project-tracking.md:62` says legacy `WORKFLOW.md` files are not the active Runtime Contract for new Workspace Repository setup.
- Acceptance target: Local dev instructions and scripts make clear whether the developer is running fixture compatibility mode or a real Workspace Repository Runtime Contract.
- Verification expectation:
  - Update the script or docs with explicit fixture naming and run the affected startup test path.
  - Run `pnpm docs:test`.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: no

## F-006: Catch staged generated ReScript artifacts in documentation validation

- Category: agent-readiness risk
- Boundary: frontend, maintainer workflow
- Priority: High
- Evidence:
  - `.gitignore:12` ignores generated `apps/frontend/src/**/*.res.js` output.
  - `apps/frontend/CLAUDE.md:5` says generated `.res.js` files must not be committed.
  - `scripts/validate-docs-examples.js:538` through `scripts/validate-docs-examples.js:549` checks only `git diff --name-only -- apps/frontend/src`, which misses staged-only generated files.
- Acceptance target: The documentation validation or another lightweight guard fails when generated frontend `.res.js` files are staged, unstaged, or otherwise included in review.
- Verification expectation:
  - Add a validator unit path or scripted fixture that stages a fake generated `.res.js` file and confirms failure.
  - Run `pnpm docs:test`.
- Runtime semantics impact: none
- Guardrail candidate: yes
- Deferred follow-up: no

## F-007: Fix stale frontend guidance that points agents at a nonexistent JavaScript boundary file

- Category: docs hygiene
- Boundary: frontend, maintainer workflow
- Priority: Medium
- Evidence:
  - `apps/frontend/CLAUDE.md:10` tells agents to use `apps/frontend/src/liveState.js`.
  - `apps/frontend/src/LiveState.res` is the actual Live Dashboard Connection implementation file in the Product Repository.
  - `.agents/rules/frontend.md:11` through `.agents/rules/frontend.md:19` correctly directs frontend changes through ReScript sources and existing bindings.
- Acceptance target: Frontend agent guidance names the real Live Dashboard state file and no longer points future agents toward a missing JavaScript file.
- Verification expectation:
  - Run `pnpm docs:test` after the docs update.
- Runtime semantics impact: none
- Guardrail candidate: yes
- Deferred follow-up: no

## F-008: Add ADR-number uniqueness guardrails

- Category: docs hygiene
- Boundary: docs, maintainer workflow
- Priority: High
- Evidence:
  - `docs/adr/0016-issue-comments-in-agent-context.md:1`, `docs/adr/0016-protected-path-policy.md:1`, `docs/adr/0016-stage-commit-classification-and-commit-skill-load.md:1`, and `docs/adr/0016-stage-concurrency-policy.md:1` share ADR number `0016`.
  - `docs/adr/0019-agent-context-snapshot-runtime-semantics.md:1` and `docs/adr/0019-batch-pull-request-self-target-readiness.md:1` share ADR number `0019`.
  - `docs/adr/0024-compozy-prd-run-lifecycle-semantics.md:1` and `docs/adr/0024-default-rich-terminal-console.md:1` share ADR number `0024`.
  - `scripts/validate-docs-examples.js:553` through `scripts/validate-docs-examples.js:570` runs documentation assertions but does not include an ADR filename uniqueness check.
- Acceptance target: Duplicate ADR numbers are either resolved or intentionally modeled with explicit supersession metadata, and the docs validator prevents accidental future duplicate numbers.
- Verification expectation:
  - Add an ADR-number uniqueness check to `pnpm docs:test`.
  - Run `pnpm docs:test`.
- Runtime semantics impact: none
- Guardrail candidate: yes
- Deferred follow-up: no

## F-009: Re-characterize the backend integration test monolith before any split

- Category: maintainability
- Boundary: backend, maintainer workflow
- Priority: Medium
- Evidence:
  - `AGENTS.md:60` describes `apps/backend/test/test_backend.ml` as a 2K-line integration-heavy suite.
  - `apps/backend/test/test_backend.ml` is 20,493 lines by `wc -l` in the current Product Repository checkout.
  - `apps/backend/test/test_backend.ml:19651` through `apps/backend/test/test_backend.ml:20433` registers a large, shared Alcotest suite across config, docs, Runtime State, Compozy, orchestration, pull-request handoff, and manual-merge behavior.
- Acceptance target: Produce a characterization map of test clusters, shared fixtures, slow paths, and safe split candidates before any file split is attempted.
- Verification expectation:
  - No product-code verification is required for characterization-only work.
  - Any later split must run `pnpm test`.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: yes

## F-010: Decompose `orchestrator.ml` only after a behavior-preserving boundary map exists

- Category: maintainability
- Boundary: backend, Runtime State, Task Branch
- Priority: Medium
- Evidence:
  - `apps/backend/CLAUDE.md:13` through `apps/backend/CLAUDE.md:17` calls out `orchestrator.ml`, `config.ml`, `runtime_home.ml`, and `github_tracker.ml` as large shared modules.
  - `apps/backend/lib/orchestrator.ml` is 4,516 lines by `wc -l` in the current Product Repository checkout.
  - `apps/backend/lib/orchestrator.ml:3626` through `apps/backend/lib/orchestrator.ml:3716` mixes stage selection, Compozy lifecycle marking, harness launch metadata, Runtime State running-row construction, and child-process tracking in one dispatch path.
- Acceptance target: Create a boundary map that separates dispatch admission, stage selection, launch planning, Runtime State projection, retry handling, and branch integration before any behavior-moving refactor.
- Verification expectation:
  - No product-code verification is required for characterization-only work.
  - Any future refactor must run focused backend tests plus `pnpm test`.
- Runtime semantics impact: Runtime State, Task Branch
- Guardrail candidate: no
- Deferred follow-up: yes

## F-011: Remove duplicated Bootstrap Runtime Settings defaults

- Category: Runtime Contract drift
- Boundary: Runtime Home, Bootstrap
- Priority: High
- Evidence:
  - `apps/backend/lib/runtime_home.ml:27` through `apps/backend/lib/runtime_home.ml:211` embeds a static Runtime Settings JSON template.
  - `apps/backend/lib/bootstrap_settings.re:212` through `apps/backend/lib/bootstrap_settings.re:260` builds the generated Runtime Settings JSON from structured values.
  - `apps/backend/lib/runtime_home.ml:370` through `apps/backend/lib/runtime_home.ml:378` uses `Bootstrap_settings.to_string` when settings are missing; the static `settings_json` value is selected only when settings already exist, and `apps/backend/lib/runtime_home.ml:315` through `apps/backend/lib/runtime_home.ml:319` then skips existing files.
- Acceptance target: Bootstrap defaults have one source of truth, preserving idempotent Bootstrap behavior and avoiding stale Runtime Contract examples.
- Verification expectation:
  - Add or update Bootstrap tests that assert generated settings still parse and existing settings are preserved.
  - Run `pnpm test`.
- Runtime semantics impact: Bootstrap
- Guardrail candidate: yes
- Deferred follow-up: yes

## F-012: Improve generated Runtime Home environment template coverage

- Category: polish
- Boundary: Runtime Home, Bootstrap
- Priority: Medium
- Evidence:
  - `apps/backend/lib/runtime_home.ml:262` generates `.symphony/.env.example` with only `GITHUB_TOKEN=`.
  - `README.md:737` through `README.md:739` documents `GITHUB_TOKEN` precedence over `GH_TOKEN`.
  - `README.md:339` through `README.md:348` documents Claude and Cursor authentication environment variables as part of Harness readiness.
- Acceptance target: The generated environment template names the supported local environment variables without including token values, and the docs explain which ones are optional by selected Harness/tracker.
- Verification expectation:
  - Update Bootstrap fixture assertions and secret-scan assertions.
  - Run `pnpm test`.
- Runtime semantics impact: Runtime Home
- Guardrail candidate: no
- Deferred follow-up: no

## F-013: Consolidate or formally constrain the repository's YAML/frontmatter parsers

- Category: maintainability
- Boundary: Compozy Task Step, backend
- Priority: Medium
- Evidence:
  - `apps/backend/lib/simple_yaml.re:22` through `apps/backend/lib/simple_yaml.re:30` implements inline list parsing with a comma split and quote stripping.
  - `apps/backend/lib/compozy_tasks_tracker.ml:142` through `apps/backend/lib/compozy_tasks_tracker.ml:149` implements a separate inline list parser with the same narrow behavior.
  - `apps/backend/lib/compozy_tasks_tracker.ml:151` through `apps/backend/lib/compozy_tasks_tracker.ml:210` implements task frontmatter parsing independently from `Simple_yaml`.
- Acceptance target: Compozy task parsing and legacy/simple YAML parsing either share one documented parser subset or have explicit tests documenting why their accepted grammars differ.
- Verification expectation:
  - Add parser tests for quoted list items, commas inside quotes, dependencies blocks, and unsupported nested frontmatter.
  - Run `pnpm test`.
- Runtime semantics impact: Compozy Task Step
- Guardrail candidate: yes
- Deferred follow-up: yes

## F-014: Scope Compozy `_tasks.md` ready-status parsing so body metadata cannot masquerade as run-level intake state

- Category: Runtime Contract drift
- Boundary: Compozy PRD Run
- Priority: High
- Evidence:
  - `apps/backend/lib/compozy_tasks_tracker.ml:260` through `apps/backend/lib/compozy_tasks_tracker.ml:270` treats any markdown line with a recognized status key and colon as a ready-status declaration.
  - `apps/backend/lib/compozy_tasks_tracker.ml:272` through `apps/backend/lib/compozy_tasks_tracker.ml:294` scans all `_tasks.md` lines and accepts one unique status value.
  - `docs/adr/0027-ready-status-first-admission-compatibility.md:17` says Compozy first admission prefers a run-level `_tasks.md` ready status while preserving legacy task-list compatibility.
- Acceptance target: Ready-status parsing is limited to frontmatter or an explicit run-level declaration area, while legacy compatibility remains covered by tests.
- Verification expectation:
  - Add tests where `_tasks.md` body detail sections contain unrelated `Status:` fields and do not alter first-admission eligibility.
  - Run `pnpm test`.
- Runtime semantics impact: Compozy PRD Run
- Guardrail candidate: yes
- Deferred follow-up: no

## F-015: Share Web Dashboard host normalization between config parsing and server binding

- Category: maintainability
- Boundary: Web Dashboard, CLI
- Priority: Medium
- Evidence:
  - `apps/backend/lib/config.ml:392` through `apps/backend/lib/config.ml:400` normalizes and validates `server.host` during Runtime Settings parsing.
  - `apps/backend/lib/server.ml:58` through `apps/backend/lib/server.ml:64` performs a separate normalization and IPv4 validation pass before binding/auth decisions.
  - `apps/backend/lib/server.ml:66` through `apps/backend/lib/server.ml:68` computes whether a host requires dashboard auth from the server-side normalized host.
- Acceptance target: Runtime Settings parsing, dashboard handoff identity, server binding, and auth decisions share one host normalization/validation helper.
- Verification expectation:
  - Preserve tests for `localhost`, `127.0.0.1`, `0.0.0.0`, invalid host strings, and IPv6 rejection.
  - Run `pnpm test`.
- Runtime semantics impact: none
- Guardrail candidate: yes
- Deferred follow-up: yes

## F-016: Replace impossible-state `assert false` in CLI branch selection with an explicit diagnostic

- Category: defect
- Boundary: CLI
- Priority: Medium
- Evidence:
  - `apps/backend/bin/main.ml:328` through `apps/backend/bin/main.ml:332` calls `Terminal_console_runtime.select_branch` with empty merge args and crashes with `assert false` if `Manual_merge` is returned.
  - `apps/backend/lib/cli_command.re:144` onward exposes merge and runtime command parsing separately, so future argument-shape changes can make this branch less obviously impossible.
- Acceptance target: The CLI either makes the impossible branch unrepresentable in the local type flow or reports a deterministic internal-mode error instead of an assertion crash.
- Verification expectation:
  - Add a targeted backend test for the branch-selection wrapper or refactor that removes the impossible case.
  - Run `pnpm test`.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: no

## F-017: Replace dashboard auth-token `failwith` with typed startup failure handling

- Category: security/blast-radius
- Boundary: Web Dashboard
- Priority: Medium
- Evidence:
  - `apps/backend/lib/server.ml:81` through `apps/backend/lib/server.ml:96` reads `/dev/urandom` for dashboard auth tokens and uses `failwith` on a short read.
  - `apps/backend/bin/main.ml:339` generates an auth token directly during Web Dashboard startup for non-loopback binds.
- Acceptance target: Auth-token generation failures become typed startup errors with clear operator-facing diagnostics and no partial Web Dashboard startup.
- Verification expectation:
  - Add a small injectable-token-generator test seam or focused unit around failure formatting.
  - Run `pnpm test`.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: no

## F-018: Add safer affordances to the Compozy completion utility before it moves PRD Run directories

- Category: product polish
- Boundary: Compozy PRD Run, maintainer workflow
- Priority: Low
- Evidence:
  - `package.json:27` exposes `pnpm compozy:complete`.
  - `scripts/complete-compozy-tasks.js:57` through `scripts/complete-compozy-tasks.js:80` validates slugs and destinations.
  - `scripts/complete-compozy-tasks.js:83` through `scripts/complete-compozy-tasks.js:86` moves each selected PRD Run directory with `fs.renameSync` and reports only after the move.
- Acceptance target: The utility supports an explicit dry-run or preflight summary so maintainers can see exactly which Compozy PRD Runs will move before mutating the task directory.
- Verification expectation:
  - Add Node-level assertions or a small fixture test for dry-run, duplicate slug, missing source, and existing destination behavior.
  - Run the utility test path and `pnpm docs:test` if usage docs change.
- Runtime semantics impact: none
- Guardrail candidate: no
- Deferred follow-up: no

## Manual Metadata Checklist

- Findings total: 18
- Categories represented: defect, maintainability, polish, security/blast-radius, docs hygiene, Runtime Contract drift, agent-readiness risk, product polish
- Guardrail candidates: 9
- Deferred structural follow-ups: 5
- Every finding includes category, boundary, priority, evidence, acceptance target, verification expectation, runtime-semantics impact, guardrail flag, and deferred flag.
- This artifact intentionally contains no executable `task_NN.md` entries.
