# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State
- Task 01 added the raw Runtime Settings schema foundation in `Config`: top-level `harnesses` parse into existing Harness records, and top-level logical `agents` parse into `Config.logical_agents`.
- Task 02 updated `Config.selected_agent_harness` for new Runtime Settings so enabled Stage Agents resolve through `stageAgents.stages[].agent -> agents.<name>.harness -> harnesses.<name>` with logical agent execution overrides merged over Harness defaults.
- Task 04 added selected-only Claude readiness and parses Claude `stream-json` into existing running-row `last_event`, `last_message`, and token fields while preserving raw stdout/stderr logs.
- Task 05 renamed backend Runtime State aggregate totals to `usage_totals`, removed `codex_totals` from backend JSON, and added running-row `harness_name`/`harness_kind`.
- Task 07 updated Bootstrap-created Runtime Settings defaults to the new `harnesses` plus logical `agents` shape, with planner on Codex, engineer on Claude, and reviewer on PI.

## Shared Decisions
- Legacy compatibility is preserved at the config parsing layer: top-level `codex` still loads, and legacy harness-shaped `agents.*` entries still populate `agent_harnesses` when top-level `harnesses` is absent.
- Legacy stage-level `stageAgents.stages[].harness` and harness-shaped `agents.*` entries are blocking readiness migration gaps, not steady-state selection inputs.

## Shared Learnings
- Harness records now carry `loop_enabled` and `loop_command`; `harness_of_codex` defaults these to enabled with `/goal` to preserve existing Codex Stage Goal Handoff assumptions until later loop-semantics work.

## Open Risks
- Repository docs/context still contain pre-Task-02 language for stage-level Harness selection; task 08 owns the docs/glossary migration.

## Handoffs
- Later readiness/migration tasks should account for both new `harnesses` and compatibility parsing of legacy harness-shaped `agents.*`.
- Task 06 should update frontend live-state types/tests to consume backend `usage_totals` and running-row Harness identity fields.
