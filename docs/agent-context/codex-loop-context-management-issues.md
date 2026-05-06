# Codex Loop Context Management Issue Drafts

Date: 2026-05-05

Source: `docs/agent-context/codex-loop-context-management.md`

Status: Draft only. These are local issue drafts and have not been created in GitHub.

## Breakdown Review

1. Does this granularity feel right, or should any slice be split further?
2. Are the dependency relationships correct?
3. Are the correct slices marked as HITL or AFK?
4. Should the completion-review design stay separate from deterministic context snapshots?

## User Stories

- **U1**: As an operator, I can understand and approve the Symphony-specific context model before Runtime Contract behavior changes.
- **U2**: As an operator, I can enable bounded agent context per Stage Agent without changing global Codex hooks.
- **U3**: As an agent, I receive deterministic issue, stage, Git, and retry context inside the Agent Prompt.
- **U4**: As an operator, I can add a trusted local Context Command whose stdout supplements the Agent Prompt.
- **U5**: As an operator, I can see context readiness and runtime context status in the existing Runtime State and Web Dashboard.
- **U6**: As an operator, I can debug context generation without persisting full prompts, token values, or local environment secrets.
- **U7**: As a maintainer, I can evaluate independent stage completion review separately from context snapshot behavior.

## Proposed Slices

1. **Title**: Accept Agent Context Snapshot Runtime Semantics
   **Type**: HITL
   **Blocked by**: None
   **User stories covered**: U1

2. **Title**: Inject A Built-In Agent Context Snapshot
   **Type**: AFK
   **Blocked by**: Slice 1
   **User stories covered**: U2, U3

3. **Title**: Carry Retry Output Into The Agent Context Snapshot
   **Type**: AFK
   **Blocked by**: Slice 2
   **User stories covered**: U3

4. **Title**: Run A Stage Context Command Before Agent Launch
   **Type**: AFK
   **Blocked by**: Slice 2
   **User stories covered**: U2, U4

5. **Title**: Surface Context Readiness And Runtime Status
   **Type**: AFK
   **Blocked by**: Slices 2 and 4
   **User stories covered**: U5

6. **Title**: Persist Bounded Context Diagnostics
   **Type**: AFK
   **Blocked by**: Slices 4 and 5
   **User stories covered**: U6

7. **Title**: Document Agent Context Operations
   **Type**: AFK
   **Blocked by**: Slices 2, 4, 5, and 6
   **User stories covered**: U2, U4, U5, U6

8. **Title**: Decide Independent Stage Completion Review Semantics
   **Type**: HITL
   **Blocked by**: Slice 1
   **User stories covered**: U7

## Issue Drafts

### 1. Accept Agent Context Snapshot Runtime Semantics

## What to build

Create the architectural decision and glossary updates for Symphony's bounded agent context model. The accepted model should define Agent Context Snapshot and Context Command as Workspace Repository scoped, harness-level behavior that supplements the Agent Prompt and Stage Goal Handoff without installing or mutating global Codex lifecycle hooks.

## Acceptance criteria

- [ ] Add an ADR under `docs/adr/` that states context generation happens in the Symphony launch harness, not through Codex lifecycle hooks.
- [ ] Define which parts belong in Runtime Settings, Runtime State, Agent Prompt composition, and ignored Runtime Home diagnostics.
- [ ] State that Agent Context Snapshot supplements the Agent Prompt and Stage Goal Handoff.
- [ ] State that Context Command stdout may supplement the Agent Prompt, while stderr and failures remain diagnostic by default.
- [ ] Update `CONTEXT.md` with accepted terms and avoid-list wording for ambiguous phrases such as "full context" or "context compression."
- [ ] Preserve existing Runtime Contract defaults unless the operator explicitly approves a default change.

## Blocked by

None - can start immediately.

### 2. Inject A Built-In Agent Context Snapshot

## What to build

Add a narrow, opt-in Agent Context Snapshot path for agent launches. When enabled for a matching Stage Agent, Symphony should append a deterministic bounded markdown snapshot to the composed Agent Prompt before launching the agent in its Agent Worktree.

## Acceptance criteria

- [ ] Parse a stage-specific Runtime Settings shape for built-in context snapshots with missing config treated as disabled.
- [ ] Validate invalid stage context config as a Readiness Gap before dispatch.
- [ ] Render issue identifier, title, current project status, labels, blockers, attempt, Stage Agent name, Task Branch, Agent Worktree path, and Loop-Start Branch when available.
- [ ] Append the snapshot under a stable heading after stage agent instructions and Stage Goal Handoff content.
- [ ] Keep output ordering deterministic and enforce a max-size cap.
- [ ] Add backend tests near existing config and prompt-composition coverage for disabled config, enabled config, invalid config, Stage Goal Handoff coexistence, and truncation.

## Blocked by

- Slice 1: Accept Agent Context Snapshot Runtime Semantics.

### 3. Carry Retry Output Into The Agent Context Snapshot

## What to build

Extend the built-in Agent Context Snapshot so retry launches include bounded context from the previous failed attempt. The retry context should help the next agent continue without storing or replaying the full transcript.

## Acceptance criteria

- [ ] Include previous attempt number and a bounded stdout/stderr tail when launching a retry.
- [ ] Keep retry output out of the snapshot on first launch.
- [ ] Truncate retry output deterministically with a clear truncation marker.
- [ ] Avoid persisting full prompt text or full Codex transcript content as part of this slice.
- [ ] Add backend tests for first launch, retry launch, stdout/stderr truncation, and prompt ordering with Stage Goal Handoff enabled.

## Blocked by

- Slice 2: Inject A Built-In Agent Context Snapshot.

### 4. Run A Stage Context Command Before Agent Launch

## What to build

Add an optional stage-specific Context Command that runs synchronously before Symphony writes the Agent Prompt. The command should receive structured launch context, and its bounded stdout should be appended to the Agent Context Snapshot.

## Acceptance criteria

- [ ] Parse Context Command Runtime Settings with `command` as an argv array, `cwd` constrained to `workspaceRepositoryRoot` or `agentWorktree`, `timeoutMs`, and `maxOutputBytes`.
- [ ] Reject invalid command config as a Readiness Gap before dispatch.
- [ ] Execute the command from the selected Workspace Repository or Agent Worktree cwd before prompt write.
- [ ] Send structured JSON on stdin and write the same JSON to a temp file whose path is exposed through an environment variable.
- [ ] Inject stdout only; do not inject stderr into the Agent Prompt by default.
- [ ] Convert timeout, missing executable, non-zero exit, and oversized stdout into bounded warning content without moving the task to retry by themselves.
- [ ] Add backend tests using real temp scripts and isolated Runtime Home paths.

## Blocked by

- Slice 2: Inject A Built-In Agent Context Snapshot.

### 5. Surface Context Readiness And Runtime Status

## What to build

Expose context readiness and runtime context generation status through the existing Runtime State snapshot and Web Dashboard. The dashboard should make context failures visible without treating them as primary orchestration metrics.

## Acceptance criteria

- [ ] Runtime State includes context status for running and retrying tasks: skipped, succeeded, warning, timed out, or failed.
- [ ] Readiness Gaps identify the exact Stage Agent and setting path for invalid context configuration.
- [ ] Backend HTTP and websocket state endpoints expose the new context status fields.
- [ ] Frontend live-state parsing reads the new fields without breaking older snapshots that omit them.
- [ ] The Web Dashboard shows context status per running or retrying task without replacing Goal Usage, task status, or readiness summaries.
- [ ] Add backend Runtime State/API tests and frontend live-state tests.

## Blocked by

- Slice 2: Inject A Built-In Agent Context Snapshot.
- Slice 4: Run A Stage Context Command Before Agent Launch.

### 6. Persist Bounded Context Diagnostics

## What to build

Persist enough context-generation diagnostics to debug failures while keeping prompts, token values, local environment files, and full command output out of version-controlled Runtime Contract files.

## Acceptance criteria

- [ ] Write diagnostics only to ignored Runtime Home state or diagnostic files, never to Runtime Contract files.
- [ ] Persist command name, selected cwd kind, exit code, duration, timeout flag, truncation flag, and output byte count.
- [ ] Do not persist full stdout unless an explicitly accepted Runtime Settings option enables it.
- [ ] Never persist `GITHUB_TOKEN`, `GH_TOKEN`, local `.env` contents, or full rendered Agent Prompt content.
- [ ] Surface diagnostic file paths or summary identifiers in Runtime State when useful.
- [ ] Add backend tests for success, timeout, truncation, non-zero exit, disabled full-output persistence, and secret redaction.

## Blocked by

- Slice 4: Run A Stage Context Command Before Agent Launch.
- Slice 5: Surface Context Readiness And Runtime Status.

### 7. Document Agent Context Operations

## What to build

Update operator and maintainer documentation for the accepted Agent Context Snapshot and Context Command behavior after the architecture and implementation slices are complete.

## Acceptance criteria

- [ ] Update `docs/agent-context/architecture.md` with the accepted high-level context path.
- [ ] Add secret-free Runtime Settings examples for built-in snapshots and Context Commands.
- [ ] Document failure behavior: context warnings do not retry tasks by themselves.
- [ ] Document how Agent Context Snapshot coexists with Agent Prompt and Stage Goal Handoff.
- [ ] Document diagnostics locations and what is intentionally not persisted.
- [ ] Run focused backend tests and `pnpm frontend:test`; run broader `pnpm test` before final handoff if the implementation slices have landed.

## Blocked by

- Slice 2: Inject A Built-In Agent Context Snapshot.
- Slice 4: Run A Stage Context Command Before Agent Launch.
- Slice 5: Surface Context Readiness And Runtime Status.
- Slice 6: Persist Bounded Context Diagnostics.

### 8. Decide Independent Stage Completion Review Semantics

## What to build

Evaluate a separate feature inspired by `codex-loop` goal confirmation: after an agent exits successfully, Symphony may run a read-only reviewer before Stage Commit or status transition. This must stay separate from deterministic Agent Context Snapshot work because it changes runtime completion semantics.

## Acceptance criteria

- [ ] Add an ADR or design note that decides whether completion review is per-stage Runtime Settings or a separate command mode.
- [ ] Decide whether failed review retries the task, moves it to a Human Attention Status, or adds reviewer guidance to the next attempt.
- [ ] Decide whether review output is interpreted by schema or by deterministic external tooling.
- [ ] Define how review output interacts with Stage Commit, Stage Push, Task Branch Integration, and Protected Trunk Branch behavior.
- [ ] Define Runtime State and dashboard visibility for review status if the feature proceeds.
- [ ] Do not implement completion review in the same slice as Agent Context Snapshot or Context Command execution.

## Blocked by

- Slice 1: Accept Agent Context Snapshot Runtime Semantics.
