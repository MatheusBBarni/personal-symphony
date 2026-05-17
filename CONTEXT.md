# Personal Symphony

Personal Symphony helps a user run a Symphony orchestration workflow inside an existing software repository.

## Language

**Workspace Repository**:
The repository where a user runs Personal Symphony and where runtime configuration and state are created.
_Avoid_: project, target project

**Product Repository**:
The repository that contains the Personal Symphony source code.
_Avoid_: project, source project

**Self-Dogfooding Workspace Repository**:
A Product Repository that also acts as a Workspace Repository for running Personal Symphony against its own work.
_Avoid_: self-hosted project, dogfood repo

**Bootstrap**:
The first-time setup of Personal Symphony runtime files inside a Workspace Repository.
_Avoid_: install, setup

**Runtime Home**:
The `.symphony/` directory that contains Personal Symphony configuration and runtime-owned files for a Workspace Repository.
_Avoid_: config folder, hidden project folder

**Agent Workspace**:
A generated working copy or working area used by an agent while handling a dispatched task.
_Avoid_: workspace folder, temp folder

**Agent Worktree**:
An Agent Workspace backed by a Git worktree for one dispatched task.
_Avoid_: worktress, task folder, copied repository

**Loop-Start Branch**:
The Workspace Repository branch that is checked out when orchestration starts.
_Avoid_: base branch, original branch, main branch

**Task Branch**:
A Git branch created from the Loop-Start Branch for one dispatched task.
_Avoid_: worktree branch, feature branch, temporary branch

**Task Branch Prefix**:
The configured Git branch namespace used for Task Branch names.
_Avoid_: branch folder, branch category

**Protected Trunk Branch**:
A configured branch, such as `main` or `master`, that Symphony must not auto-merge task work into.
_Avoid_: main branch, default branch, protected branch

**Human Attention Status**:
A paused project status for task work that requires operator triage before Symphony should continue.
_Avoid_: blocked status, manual review status, failed status

**Merge Attention Status**:
The Human Attention Status used when agent work completed but its Task Branch could not be auto-merged.
_Avoid_: retry status, review status, failed status

**Manual Task Merge**:
A one-shot operator CLI action that integrates explicitly selected completed Agent Worktrees or Task Branches into the current Loop-Start Branch.
_Avoid_: manual auto-merge, branch merge mode, raw git merge

**Environment Template**:
The committed `.symphony/.env.example` file that lists required runtime variables without secret values.
_Avoid_: sample env, example secrets

**Local Environment**:
The ignored `.symphony/.env` file that stores local secret values for a Workspace Repository.
_Avoid_: env file, secrets file

**Runtime Contract**:
The repository-owned files inside the Runtime Home that define Personal Symphony behavior for a Workspace Repository.
_Avoid_: workflow file, harness config

**Runtime Settings**:
The `settings.json` portion of the Runtime Contract that defines tracker, project, orchestration, Harness, logical agent, server, and path configuration.
_Avoid_: config, preferences

**Issue Tracker**:
The configured source of Workspace Repository issue records that Personal Symphony polls and updates during orchestration.
_Avoid_: task database, work list

**Symphony-ready Status**:
The tracker-owned status value that makes one Workspace Repository work item eligible for first admission into orchestration.
_Avoid_: queue state, in-progress status, label-only marker

**GitHub Tracker**:
An Issue Tracker that uses GitHub Issues as issue records and GitHub Projects status values as dispatch state.
_Avoid_: GitHub workflow, remote tracker

**Local Issue Tracker**:
An Issue Tracker whose issue records live as repository-owned local files inside the Workspace Repository and can be consumed without GitHub API access.
_Avoid_: synced GitHub issues, local notes

**Local Issue File**:
A human-editable issue record stored by a Local Issue Tracker and used by Personal Symphony to render an Agent Prompt, select a Stage Agent, and update tracker status.
_Avoid_: task markdown, PRD file, scratch note

**Compozy PRD Run**:
A Local Issue Tracker work item represented by one `.compozy/tasks/<task_name>/` directory in a Workspace Repository.
_Avoid_: Compozy issue, task folder, PRD issue

**Compozy Task Step**:
One `task_NN.md` file inside a Compozy PRD Run that Symphony executes as an ordered step in the same Agent Worktree and Task Branch.
_Avoid_: separate Symphony issue, GitHub issue, standalone task

**Compozy PRD Run Lifecycle**:
The run-level state for one Compozy PRD Run, separate from Compozy Task Step progress, represented by `pending`, `in_planning`, `in_execution`, `in_review`, `blocked`, `completed`, `failed`, `skipped`, `not_pr_ready`, or `pr_handoff`.
_Avoid_: task status, step status, issue lane

**Compozy PR Readiness**:
The run-level Batch Pull Request eligibility summary for one Compozy PRD Run, separate from Compozy Task Step progress and represented by `disabled`, `not_ready`, `ready`, `handoff_attempting`, `handoff_completed`, or `handoff_failed`.
_Avoid_: completed steps, terminal progress, review status

**Runtime Settings Invocation Override**:
A command-line value on the default runtime command that replaces one loaded Runtime Settings field for the current Symphony process only, after Runtime Settings load and before orchestration uses the effective runtime config.
_Avoid_: temporary config, settings rewrite, runtime patch

**Stage Agent**:
A Runtime Settings mapping from project statuses to a named logical agent, its matching instruction file, and optional stage behavior.
_Avoid_: status agent, workflow step, lane

**Logical Agent**:
A Runtime Settings `agents.<name>` definition, such as planner, engineer, or reviewer, that selects one Agent Harness and may override execution defaults for that role.
_Avoid_: harness, agent command, provider

**Agent Harness**:
A named Runtime Settings `harnesses.<name>` launch configuration that tells Symphony which non-interactive agent tool to run after a logical agent selects it.
_Avoid_: agent command, codex config, provider

**Codex Harness**:
An Agent Harness whose launch semantics target Codex non-interactive execution.
_Avoid_: default agent, symphony agent

**Claude Harness**:
An Agent Harness whose launch semantics target Claude Code non-interactive execution with CLI `stream-json` output.
_Avoid_: codex clone, claude agent

**PI Harness**:
An Agent Harness whose launch semantics target PI non-interactive execution.
_Avoid_: codex-compatible command, pi agent

**Cursor Harness**:
An Agent Harness whose launch semantics target Cursor CLI non-interactive execution with CLI `stream-json` output.
_Avoid_: codex clone, cursor agent

**Harness Loop**:
The per-Harness Runtime Settings capability that controls whether Stage Goal Handoff prepends a loop command such as `/goal`.
_Avoid_: global goal mode, codex-only setting

**Git Policy**:
The Runtime Settings section that defines Task Branch and Protected Trunk Branch behavior.
_Avoid_: branch config, git settings

**Allowed Loop-Start Branch Policy**:
A Runtime Settings rule that identifies which Loop-Start Branches may dispatch automated orchestration.
_Avoid_: branch allowlist, dogfood branch guard, protected branch check

**Protected Path Policy**:
A repository-owned rule that identifies Workspace Repository paths agent work must not modify without explicit authorization.
_Avoid_: symphony ignore, agent ignore, untouchable files

**Task Cleanup Policy**:
The Git Policy setting that controls whether completed task worktrees or branches are removed.
_Avoid_: cleanup flag, delete option

**Agent Prompt**:
The `prompt.md` portion of the Runtime Contract that defines the task instructions rendered for each dispatched issue.
_Avoid_: prompt template, workflow body

**Agent Prompt Archive**:
Ignored Runtime Diagnostics under Runtime Home state that persist the exact Agent Prompt sent to a Harness for each dispatched task, plus structured launch metadata.
_Avoid_: prompt template, Runtime Contract prompt, transcript

**Agent Context Snapshot**:
A bounded, deterministic launch context section generated by the Symphony launch harness for a dispatched task.
_Avoid_: full context, context compression, transcript replay

**Previous Attempt Output**:
The bounded stdout and stderr tails from the immediately previous failed agent launch, included only in a retry Agent Context Snapshot.
_Avoid_: full transcript, prompt replay, all logs

**Context Command**:
An optional stage-specific local command whose bounded stdout may supplement an Agent Context Snapshot.
_Avoid_: lifecycle hook, global hook, context script

**Context Status**:
The per-task Runtime State summary of Agent Context Snapshot and Context Command generation for running or retrying work.
_Avoid_: task result, orchestration status, primary metric

**Runtime State**:
The ignored files inside the Runtime Home that record current orchestration activity and recovery data.
_Avoid_: state files, generated data

**Runtime Diagnostics**:
Ignored Runtime Home metadata that helps explain orchestration behavior without changing the Runtime Contract.
_Avoid_: contract diagnostics, debug config

**Context Diagnostics**:
Bounded Runtime Diagnostics for Agent Context Snapshot and Context Command generation, stored under ignored Runtime Home state and summarized in Runtime State.
_Avoid_: prompt archive, context transcript, command log

**Stage Commit**:
A commit created by Personal Symphony after an agent successfully completes a configured stage.
_Avoid_: auto commit, every step commit

**Stage Commit Classification**:
Repository-owned metadata used to choose the commit type or tag for a Stage Commit.
_Avoid_: commit label, stage tag, arbitrary prefix

**Stage Commit Tag Guidance**:
The repository-owned `tags.json` vocabulary that explains the four-character commit tags available to Stage Commit Classification.
_Avoid_: global commit rules, agent-only tag list, free-form tag prompt

**Stage Skill Load**:
The ordered skill identifiers that Runtime Settings render into the Agent Prompt for a matching Stage Agent.
_Avoid_: skill prompt injection, automatic skill expansion, agent plugin list

**Stage Push**:
An optional push of a Stage Commit to the currently checked-out Task Branch after the Stage Commit is created.
_Avoid_: auto push, push every step

**Stage Concurrency Policy**:
A Runtime Settings rule that limits how many agents may run for a specific Stage Agent.
_Avoid_: agents per status, per-stage maxConcurrentAgents, worker pool

**Stage Goal Handoff**:
A stage-specific Harness Loop handoff that sends Stage Goal Context when Symphony launches an agent for that stage.
_Avoid_: global goal mode, `/goal` setting, issue goal

**Stage Goal Context**:
The deterministic issue and stage data used as the Harness Loop payload for a Stage Goal Handoff.
_Avoid_: whole prompt, all context, goal message

**Goal Usage**:
The Codex-reported time and usage data for a Stage Goal Handoff.
_Avoid_: goal time, timer, duration

**Orchestration Idle**:
The orchestration condition where no active issue is running, retrying, or dispatchable.
_Avoid_: queue empty, all tasks finished, done processing

**Ordered Queue**:
A CLI-provided sequence of issue identifiers that Personal Symphony uses as the dispatch order for eligible work.
_Avoid_: project order, priority list, sorted candidates

**Ordered Queue Entry**:
One operator-provided queue identifier and its current queue progress within an Ordered Queue. For a Compozy-backed `--queue` shortcut, this identifier may be a bare Compozy PRD Run slug preserved as typed while dispatch uses the resolved canonical tracker identifier.
_Avoid_: queue item, queued issue, queue row

**Batch Pull Request**:
A single pull request opened from the Loop-Start Branch either after Symphony reaches Orchestration Idle or, when configured, after task work moves to the review status.
_Avoid_: per-task PR, task pull request, queue PR

**Task Pull Request**:
A pull request opened from one Task Branch to the configured Pull Request Base Branch when that task moves to the review status.
_Avoid_: batch PR, agent PR, worktree PR

**Batch Branch Push**:
An optional non-force push of the Loop-Start Branch before opening a Batch Pull Request.
_Avoid_: final push, queue push, release push

**Pull Request Base Branch**:
The configured target branch for a Batch Pull Request or Task Pull Request.
_Avoid_: inferred base, default branch, protected branch

**Pull Request Mode**:
The Runtime Settings choice that selects Batch Pull Request behavior or Task Pull Request behavior.
_Avoid_: PR kind, PR strategy

**Pull Request Policy**:
The Runtime Settings section that controls automatic pull request creation.
_Avoid_: PR config, GitHub settings, git policy

**Review Pull Request Handoff**:
An opt-in Pull Request Policy trigger that opens the Batch Pull Request immediately after task work is integrated and its issue moves to the review status.
_Avoid_: per-task PR, review PR, agent PR

**Pull Request Template**:
The configured title or body pattern used when opening a Batch Pull Request or Task Pull Request.
_Avoid_: generated PR text, AI summary, PR prose

**Readiness Gap**:
A missing or invalid runtime requirement that prevents Personal Symphony from dispatching work.
_Avoid_: setup error, config problem

**Clean Loop-Start Worktree**:
A Loop-Start Branch checkout with no uncommitted Workspace Repository changes.
_Avoid_: clean repo, safe branch

**Startup Reconciliation**:
The startup-time recovery pass that checks completed-stage Agent Worktrees for Task Branch commits not present on the Loop-Start Branch.
_Avoid_: startup merge, branch sweep, cleanup scan

**Task Branch Integration**:
The serialized act of bringing completed Task Branch commits into the Loop-Start Branch, directly by fast-forward when possible or by first updating the Task Branch from the current Loop-Start Branch.
_Avoid_: merge worktrees, copy workspace, finish branch

**Terminal Console**:
The default terminal interface for operating Personal Symphony in a Workspace Repository.
Normal `symphony` runs open the read-first Terminal Console unless the operator selects Web Dashboard mode, one-shot output, or another explicit CLI action.
The Terminal Console renders Runtime State snapshots for active work, retrying work, task attention, Readiness Gaps, Ordered Queue progress, Compozy PRD Run progress, Agent Worktree details, and Task Branch context.
Its MVP aids are limited to local reading, refresh, navigation, filtering, Web Dashboard handoff guidance, and validated local path inspection; they must not mutate task lifecycle state.
_Avoid_: TUI, terminal UI

**Web Dashboard**:
The optional browser interface for operating Personal Symphony in a Workspace Repository.
_Avoid_: web server, front-end

**Web Dashboard Refactor**:
A redesign of the Web Dashboard that changes its presentation and operator workflow without changing orchestration semantics.
_Avoid_: frontend refactor, UI refresh

**Web Dashboard Mock**:
A directional visual reference for a Web Dashboard Refactor, not a strict source of product language or runtime behavior.
_Avoid_: exact design spec, final dashboard contract

**Web Dashboard Navigation**:
The browser navigation structure that lets an operator move between Web Dashboard sections without changing Runtime State.
_Avoid_: react navigation, mobile navigation, native navigation

**Audio Notification Configuration**:
The Web Dashboard section where a user controls browser-local Audio Notification preferences.
_Avoid_: sound settings, Runtime Settings, repository audio config

**Live Dashboard Connection**:
The browser-to-local-server connection that streams Runtime State snapshots to the Web Dashboard.
The local server binds to loopback by default; operators must explicitly set `server.host` in Runtime Settings for non-loopback access.
Non-loopback Live Dashboard Connection and Runtime State HTTP access require the server-generated local dashboard auth token.
_Avoid_: polling, replace HTTP

**Audio Notification**:
A short browser-played sound cue emitted by the Web Dashboard when a Runtime State transition needs user attention.
_Avoid_: sound, frontend sound, backend event sound

**Work Became Idle**:
The Runtime State transition where previously running or retrying work reaches zero running tasks and zero retrying tasks.
_Avoid_: queue finished, workflow finished

**Task Needs Attention**:
A task condition shown in Runtime State issue errors that requires user intervention before Symphony can continue that task.
_Avoid_: retrying error, global error, any error

**CLI Package**:
The npm-distributed Personal Symphony package that provides the `symphony` command and carries platform binaries for supported operating systems.
_Avoid_: npm wrapper, global install

**TUI Toolkit Package**:
The opam/Dune package at `apps/tui` that contains reusable OCaml terminal UI toolkit source.
Its private pnpm workspace label is `@symphony-orchestrator/tui`, but opam publishing uses the `tui` package metadata.
It is separate from **Terminal Console** runtime semantics.
_Avoid_: Terminal Console, CLI Package, npm package

**Update Source**:
The npm registry package metadata that `symphony update` uses to discover the latest released CLI Package version.
_Avoid_: latest build, GitHub release lookup

**Install Prefix**:
The npm global prefix that owns the currently running `symphony` command.
_Avoid_: global npm, current npm prefix

**Idempotent Bootstrap**:
A Bootstrap that creates missing Runtime Home files without overwriting user-edited files.
_Avoid_: reinitialize, reset

## Relationships

- A **Workspace Repository** may receive a **Bootstrap** from Personal Symphony.
- A **Self-Dogfooding Workspace Repository** is both a **Product Repository** and a **Workspace Repository**.
- A **Self-Dogfooding Workspace Repository** may commit a real **Runtime Contract** for its own Personal Symphony runs.
- A **Self-Dogfooding Workspace Repository** should use a dedicated GitHub Project as its dispatch board.
- A **Self-Dogfooding Workspace Repository** may enable **Stage Goal Handoff** on every configured **Stage Agent**.
- A **Self-Dogfooding Workspace Repository** may use its planner stage as a PRD review gate for already-refined issues.
- A **Self-Dogfooding Workspace Repository** should use **Stage Commit** to create local engineer-stage commits before review.
- A **Self-Dogfooding Workspace Repository** should keep **Stage Push** disabled unless remote branch publication is deliberately enabled.
- A **Self-Dogfooding Workspace Repository** should use reviewer-stage comments and a **Human Attention Status** for review findings that require operator triage.
- A **Self-Dogfooding Workspace Repository** should have the reviewer stage run focused verification when practical before moving work to `Done`.
- A **Self-Dogfooding Workspace Repository** may increase concurrency when its **Loop-Start Branch** is not a **Protected Trunk Branch** because **Task Branch Integration** can integrate unrelated concurrently completed **Task Branches**.
- A **Self-Dogfooding Workspace Repository** should use a dedicated non-trunk **Loop-Start Branch** so completed **Task Branches** do not auto-merge into the Product Repository trunk.
- A **Self-Dogfooding Workspace Repository** may open a **Batch Pull Request** from its dedicated **Loop-Start Branch** to its **Protected Trunk Branch** after **Orchestration Idle**.
- A **Self-Dogfooding Workspace Repository** should remove merged **Agent Worktrees** and delete merged **Task Branches** to avoid local branch buildup.
- A **Self-Dogfooding Workspace Repository** should prevent accidental dogfood dispatch from the Product Repository trunk.
- A **Self-Dogfooding Workspace Repository** should define a **Protected Path Policy** for release and package files once that policy exists.
- An **Idempotent Bootstrap** must preserve existing Runtime Contract and Local Environment files.
- A **Workspace Repository** contains at most one **Runtime Home**.
- Personal Symphony commands must be run from the root of a **Workspace Repository**.
- Personal Symphony exits before Bootstrap when the current directory is not the root of a **Workspace Repository**.
- A **Runtime Home** contains the **Runtime Contract**, user-editable settings, and internal state.
- The **Runtime Contract** contains **Runtime Settings**.
- Runtime Settings select one **Issue Tracker** for orchestration.
- The **GitHub Tracker** remains the default Issue Tracker.
- A **Symphony-ready Status** controls first admission into orchestration; it does not replace queue ordering or post-admission lifecycle behavior.
- A **Local Issue Tracker** stores issue records in **Local Issue Files** owned by the Workspace Repository.
- A Compozy-backed **Local Issue Tracker** treats one **Compozy PRD Run** as the issue-level work item and the contained **Compozy Task Steps** as ordered progress within that work item.
- A **Compozy PRD Run Lifecycle** belongs to the **Compozy PRD Run**, not to an individual **Compozy Task Step**.
- **Compozy Task Step** progress remains the source for current step and completed, failed, skipped, and total counts.
- **Compozy PR Readiness** is separate from **Compozy Task Step** progress; failed, skipped, blocked, or terminal task-step progress does not by itself make a **Batch Pull Request** ready.
- When all **Compozy Task Steps** are completed and the **Compozy PRD Run Lifecycle** dispatch state selects another configured **Stage Agent**, the **Compozy PRD Run** remains dispatchable for that next stage before pull-request handoff.
- A Compozy-backed **Local Issue Tracker** in `batch` **Pull Request Mode** may become eligible for one aggregate **Batch Pull Request** for the completed **Compozy PRD Run** and must not open per-step pull requests for **Compozy Task Steps**.
- A **Local Issue Tracker** must preserve Stage Agent dispatch, tracker status transitions, Agent Prompt rendering, Task Branch naming, retry, Stage Commit, Stage Push, and Task Branch Integration behavior.
- A **Local Issue Tracker** must not require GitHub API access for issue fetches or tracker status updates.
- Bootstrap must not overwrite existing **Local Issue Files**.
- A **Runtime Settings Invocation Override** is applied after **Runtime Settings** load and before orchestration uses the effective runtime config, but it is not written into the **Runtime Contract**.
- A **Runtime Settings Invocation Override** may change effective Agent Worktree placement for one run, but it does not select a different **Workspace Repository**.
- The **Runtime Contract** contains an **Agent Prompt**.
- A **Runtime Home** contains one **Environment Template** and may contain one **Local Environment**.
- A **Runtime Home** may contain **Runtime State**.
- **Runtime State** may include an **Agent Prompt Archive** for launch debugging; it is ignored Runtime Diagnostics and not part of the **Runtime Contract**.
- A normal `symphony` run opens the read-first **Terminal Console** as the default Runtime State surface.
- `symphony --web` opens the **Web Dashboard** instead of the foreground **Terminal Console**.
- `symphony --once` prints non-interactive terminal output and exits without starting the foreground **Terminal Console** loop.
- The **Terminal Console** uses in-process **Runtime State** snapshots for display.
- The **Live Dashboard Connection** remains the **Web Dashboard** Runtime State stream, not a command channel.
- A readiness-blocked **Terminal Console** renders **Readiness Gaps** and remediation text without starting orchestration.
- **Terminal Console** local aids may refresh the latest in-memory **Runtime State** snapshot, navigate, filter, show **Web Dashboard** handoff guidance, or inspect validated local paths.
- **Terminal Console** local aids must not retry tasks, pause or resume dispatch, update tracker status, merge or push **Task Branches**, open pull requests, change the **Runtime Contract**, or otherwise mutate task lifecycle state.
- A **Runtime Home** may contain many **Agent Workspaces**.
- An **Agent Worktree** is an **Agent Workspace**.
- The **Runtime Settings** may define many named **Agent Harnesses** under `harnesses`.
- The **Runtime Settings** may define many named **Logical Agents** under `agents`.
- A **Stage Agent** mapping selects a **Logical Agent** with `agent`.
- A **Logical Agent** selects an **Agent Harness** with `harness`.
- A **Stage Agent** mapping must not select an **Agent Harness** directly with stage-level `harness`; legacy `stageAgents.stages[].harness` is a migration **Readiness Gap**.
- Legacy harness-shaped Runtime Settings under `agents.*`, such as `agents.pi.kind`, are migration input and create blocking **Readiness Gaps** when the new Runtime Settings shape is in use.
- Agent Harness readiness follows enabled **Stage Agent** mappings resolved through **Logical Agents** instead of every unused Agent Harness definition.
- A legacy Runtime Settings `codex` block is a backwards-compatible **Codex Harness** definition.
- A **Codex Harness** has **Harness Loop** enabled with `/goal` by default.
- A **Claude Harness** uses CLI `stream-json` for the first Claude integration.
- A **Claude Harness** has **Harness Loop** disabled by default.
- A **PI Harness** uses PI non-interactive print mode for the first PI integration.
- A **Cursor Harness** uses Cursor CLI non-interactive execution with CLI `stream-json` output.
- A **Cursor Harness** has **Harness Loop** disabled by default.
- A selected **PI Harness** must have an installed command executable and PI authentication before dispatch.
- An unused **PI Harness** definition must not create PI install or authentication **Readiness Gaps**.
- A **PI Harness** must preserve Agent Worktree, Task Branch, Agent Prompt, Stage Commit, Stage Push, retry, and status transition behavior.
- A selected **Cursor Harness** must have an installed command executable and a successful Cursor CLI status check before dispatch.
- An unused **Cursor Harness** definition must not create Cursor install or authentication **Readiness Gaps**.
- A selected loop-enabled **Cursor Harness** must prove that its configured **Harness Loop** command is accepted from standard input before dispatch.
- A loop-disabled **Cursor Harness**, or a **Cursor Harness** with a blank `loop.command`, must use the normal **Agent Prompt** path without **Stage Goal Handoff**.
- The **Runtime Settings** contain a **Git Policy**.
- A **Git Policy** may contain an **Allowed Loop-Start Branch Policy**.
- A **Workspace Repository** may define a **Protected Path Policy**.
- The first **Protected Path Policy** lives in **Runtime Settings**, not in a standalone `.symphonyignore` file.
- **Protected Path Policy** patterns are repository-root-relative and may match files, directories, globs, generated-file paths that would otherwise be committed or integrated, and nested paths.
- The first **Protected Path Policy** does not support negation patterns.
- **Protected Path Policy** checks added, modified, deleted, and renamed paths.
- A protected path change requires human-authored issue scope that authorizes the exact protected path or exact policy pattern name before dispatch.
- Agent output cannot authorize a protected path change.
- The **Git Policy** contains a **Task Cleanup Policy**.
- The **Local Environment**, **Runtime State**, and **Agent Workspaces** are ignored by version control.
- Each **Agent Worktree** belongs to one dispatched task.
- Agent Worktrees live under the Runtime Home workspaces directory.
- Each **Agent Worktree** checks out one **Task Branch**.
- Each **Task Branch** starts from the **Loop-Start Branch**.
- Each **Task Branch** name starts with the **Task Branch Prefix** and includes the task's stable issue number.
- If a task enters work without an existing **Task Branch**, the **Task Branch** starts from the current **Loop-Start Branch**.
- If a task already has a **Task Branch**, Symphony reuses it.
- A dispatched task has an **Agent Worktree** when it enters the in-progress project state.
- If Symphony starts while a task is already in the in-progress project state, Symphony creates or reuses that task's **Agent Worktree** before starting agent work.
- Symphony requires a **Clean Loop-Start Worktree** before creating an **Agent Worktree**.
- Symphony may auto-merge a completed **Task Branch** into the **Loop-Start Branch** only when the **Loop-Start Branch** is not a **Protected Trunk Branch**.
- Auto-merge of a **Task Branch** into the **Loop-Start Branch** keeps the final **Loop-Start Branch** update fast-forward only.
- If the **Loop-Start Branch** cannot fast-forward directly to a completed **Task Branch**, Symphony may update the **Task Branch** by merging the current **Loop-Start Branch** into it from the **Agent Worktree**, then fast-forward the **Loop-Start Branch** to the updated **Task Branch**.
- When auto-merge fails, Symphony may move the task to a **Merge Attention Status**.
- Auto-merge, **Startup Reconciliation**, and **Manual Task Merge** are **Task Branch Integration** paths.
- An **Allowed Loop-Start Branch Policy** prevents dispatch from any Loop-Start Branch outside the configured literal branch set.
- An omitted or empty **Allowed Loop-Start Branch Policy** allows any Loop-Start Branch.
- A disallowed **Loop-Start Branch** is a **Readiness Gap** that keeps the **Terminal Console** and **Web Dashboard** available for inspection while blocking dispatch, **Startup Reconciliation**, and **Batch Pull Request** creation.
- **Manual Task Merge** integrates selected completed task work with `--merge` without running normal orchestration.
- **Manual Task Merge** accepts issue identifiers such as `20` and `#20`; it does not accept raw **Task Branch** names.
- **Manual Task Merge** preflights every selected task before merging anything, requires clean Loop-Start and Agent Worktrees, and uses fast-forward-only semantics.
- **Manual Task Merge** may target a **Protected Trunk Branch** because explicit selected issue identifiers are the operator action.
- **Manual Task Merge** does not push branches, run Startup Reconciliation, dispatch agents, or open a Batch Pull Request.
- **Startup Reconciliation** runs once per process startup before normal dispatch or agent launch.
- **Startup Reconciliation** evaluates completed-stage **Agent Worktrees** in deterministic issue order.
- **Startup Reconciliation** uses the same safe **Task Branch Integration** path as normal completion.
- **Startup Reconciliation** does not create a **Stage Commit**, reconcile retained **Task Branches** without **Agent Worktrees**, or change tracker status after successful or already-contained reconciliation.
- **Startup Reconciliation** moves unsafe, contradictory, conflicted, or Protected Trunk Branch candidates to the **Merge Attention Status** and records Runtime State diagnostics.
- **Runtime State** records **Task Branch Integration** diagnostics for direct fast-forwards, update-then-fast-forward integrations, already-contained branches, and integration attention.
- A **Merge Attention Status** is a **Human Attention Status**.
- The default **Merge Attention Status** is `Human attention`.
- A **Human Attention Status** is paused and not dispatchable.
- The default **Task Cleanup Policy** removes an **Agent Worktree** after its **Task Branch** is merged.
- The default **Task Cleanup Policy** keeps a merged **Task Branch**.
- A **Stage Commit** may be created when a configured stage completes with code changes.
- A **Stage Commit** may use a **Stage Commit Classification** when rendering its commit message.
- **Stage Commit Classification** uses matching issue labels before the stage default.
- When matching issue labels resolve to conflicting classifications for a commit-enabled stage, Symphony pauses the task in a **Human Attention Status** before creating a **Stage Commit**.
- A **Workspace Repository** may define **Stage Commit Tag Guidance** in `tags.json`.
- **Stage Commit Tag Guidance** is a JSON array of objects with `tag` and `instructions` fields.
- A **Stage Commit Tag Guidance** `tag` is a four-character commit tag or type value used by **Stage Commit Classification**.
- **Stage Commit Tag Guidance** should be included in every **Stage Commit** step.
- A **Stage Push** happens only after a **Stage Commit** is successfully created.
- A **Stage Push** happens before the stage moves to its success project state.
- Runtime Settings enable a **Stage Push** with `commit.push` on a configured stage.
- A missing `commit.push` setting means the **Stage Push** is disabled.
- Bootstrapped Runtime Settings include `commit.push` as `false` in each example stage commit policy.
- A **Stage Push** sends the **Stage Commit** to the currently checked-out **Task Branch**.
- Symphony checks the **Protected Path Policy** before creating a **Stage Commit**.
- Unauthorized protected path changes move the task to the **Human Attention Status** and prevent **Stage Commit** creation.
- Because **Stage Push** follows **Stage Commit**, unauthorized protected path changes also prevent **Stage Push**.
- **Startup Reconciliation**, **Task Branch Integration**, and **Manual Task Merge** must refuse unauthorized protected path changes before integrating committed **Task Branch** work.
- **Batch Pull Request** creation remains blocked while protected-path attention is unresolved.
- A **Stage Push** pushes the current **Task Branch** tip, including earlier unpushed commits on that branch.
- A **Stage Push** is a non-force push.
- A **Stage Push** uses the current **Task Branch** upstream when one exists.
- A **Stage Push** creates an upstream on `origin` when the current **Task Branch** has no upstream.
- A **Stage Push** happens before any auto-merge attempt.
- **Task Branch Integration** must not force-push a **Task Branch** after **Stage Push**.
- Symphony does not push the **Loop-Start Branch** after auto-merge.
- A failed **Stage Push** prevents the stage from moving to its success project state.
- A failed **Stage Push** is retryable.
- A **Stage Goal Handoff** is configured per **Stage Agent**.
- A **Stage Goal Handoff** is not a global Codex launch mode.
- A **Stage Goal Handoff** is gated by stage `goal.enabled`, then controlled by the selected **Agent Harness** `loop.enabled` and `loop.command`.
- Runtime Settings configure **Stage Goal Handoff** with `goal.enabled` on a stage.
- A missing `goal` setting means **Stage Goal Handoff** is disabled for that stage.
- A rendered **Agent Prompt** includes GitHub issue comments when they are present.
- An **Agent Context Snapshot** is generated by the Symphony launch harness, not by global Codex lifecycle hooks.
- An **Agent Context Snapshot** supplements the **Agent Prompt**.
- An **Agent Context Snapshot** supplements **Stage Goal Handoff** when both are enabled.
- An **Agent Context Snapshot** must not replace the **Agent Prompt** or **Stage Goal Handoff**.
- **Previous Attempt Output** may supplement an **Agent Context Snapshot** only on retry launches.
- **Previous Attempt Output** includes the previous attempt number and bounded stdout/stderr tails when available.
- **Previous Attempt Output** must render missing stdout or stderr as unavailable.
- **Previous Attempt Output** must use deterministic truncation markers and must not replay full Codex transcripts.
- Runtime Settings own operator-configurable **Agent Context Snapshot** and **Context Command** behavior.
- **Agent Prompt** composition owns **Agent Context Snapshot** prompt injection.
- **Runtime State** exposes live **Context Status** for running or retrying work.
- **Context Status** is the per-task **Runtime State** field that reports **Agent Context Snapshot** and **Context Command** generation without replacing task state, **Goal Usage**, or readiness summaries.
- When current **Runtime State** rows carry **Context Status** and context behavior is disabled or not applicable, the **Context Status** is `skipped`; older Runtime State snapshots may omit the field.
- **Runtime Diagnostics** may store bounded, secret-free **Agent Context Snapshot** and **Context Command** metadata.
- **Context Diagnostics** files are pruned to the same retention cap as Runtime State summaries.
- **Context Diagnostics** must not persist the full rendered **Agent Prompt**, full **Context Command** stdout or stderr, `GITHUB_TOKEN` or `GH_TOKEN` values, or **Local Environment** contents.
- A **Context Command** belongs to a **Stage Agent** mapping.
- A **Context Command** stdout may supplement an **Agent Context Snapshot**.
- A **Context Command** stderr and failures are **Runtime Diagnostics** by default.
- A **Context Command** failure must not retry task work by itself.
- Missing **Agent Context Snapshot** or **Context Command** settings preserve existing Runtime Contract behavior.
- Bootstrapped Runtime Settings include `goal.enabled` as `false` in each example stage.
- A **Stage Goal Handoff** uses **Stage Goal Context** as its Harness loop payload.
- A **Stage Goal Handoff** supplements the normal **Agent Prompt**.
- A **Stage Goal Handoff** must not replace the normal **Agent Prompt**.
- A **Stage Goal Handoff** runs only when the selected **Agent Harness** has **Harness Loop** enabled with a non-empty loop command.
- Missing Codex goal support for a selected loop-enabled **Codex Harness** is a **Readiness Gap**, not a task retry condition.
- Missing Cursor loop plugin support for a selected loop-enabled **Cursor Harness** is a **Readiness Gap**, not a task retry condition.
- The **Readiness Gap** for missing Codex goal support tells the user how to use a Codex command that accepts the configured Harness loop command from standard input.
- The **Readiness Gap** for missing Cursor loop plugin support tells the user to install or enable the plugin path that accepts the configured Harness loop command from standard input, or to disable the Cursor Harness loop.
- Symphony checks `~/.codex/config.toml` for `[features] goals = true` when a selected loop-enabled **Codex Harness** uses the default `/goal` command.
- Symphony tells the user to use a Codex command that accepts the configured Harness loop command from standard input when Codex goal support is missing.
- Symphony sends the selected **Agent Harness** loop command before the normal rendered **Agent Prompt** when performing a **Stage Goal Handoff**.
- Implementation of **Stage Goal Handoff** must verify that the selected loop-enabled **Codex Harness** accepts its loop command from standard input before treating the feature as supported.
- If the selected loop-enabled **Codex Harness** does not accept its loop command from standard input, Symphony must surface the blocker instead of pretending **Stage Goal Handoff** works.
- Implementation of **Stage Goal Handoff** must verify that the selected loop-enabled **Cursor Harness** accepts its loop command from standard input before treating the feature as supported.
- If the selected loop-enabled **Cursor Harness** does not accept its loop command from standard input, Symphony must surface the blocker instead of pretending **Stage Goal Handoff** works.
- **Stage Goal Context** includes issue identifier, title, description, comments, URL, current project status, labels, priority when present, blocker references when present, attempt, and stage agent name.
- **Stage Goal Context** does not include issue creation or update timestamps by default.
- Symphony extracts **Goal Usage** from Codex output when Codex reports it in a parseable form.
- Symphony does not invent **Goal Usage** when Codex output does not report it.
- **Goal Usage** may include goal status, time used, and token usage when Codex reports those fields.
- **Goal Usage** belongs in **Runtime State**.
- **Goal Usage** remains in **Runtime State** when a task moves from running to retrying or attention-needed state.
- The **Web Dashboard** shows **Goal Usage** in task execution details when available.
- **Goal Usage** is not a primary **Web Dashboard** metric.
- **Stage Goal Handoff** does not change retry, completion, status transition, commit, push, auto-merge, or Batch Pull Request behavior.
- Missing or unparseable **Goal Usage** must not fail a task.
- A **Stage Concurrency Policy** refines the global maximum concurrent agents without allowing total running agents to exceed that global limit.
- A **Stage Concurrency Policy** is configured on a **Stage Agent** mapping.
- A missing **Stage Concurrency Policy** preserves global-only dispatch admission for that **Stage Agent** mapping.
- A **Stage Concurrency Policy** counts running work against the **Stage Agent** mapping selected when the agent launched.
- A full **Stage Concurrency Policy** does not block later **Ordered Queue** entries whose selected **Stage Agent** mapping still has capacity.
- An **Ordered Queue** is provided by the operator at launch.
- An **Ordered Queue** is named with issue identifiers from the Workspace Repository issue tracker.
- When Runtime Settings select the Compozy-backed **Issue Tracker**, `--queue` may also name **Compozy PRD Runs** with bare slugs from `.compozy/tasks/<task_name>/`.
- An **Ordered Queue** does not use issue URLs or cross-repository issue references.
- An **Ordered Queue** is not inferred from GitHub Project item order.
- `--queue` is the CLI expression of an **Ordered Queue**.
- An **Ordered Queue** controls dispatch admission order but does not override the configured maximum concurrent agents.
- An **Ordered Queue** limits dispatch to the issues named in the sequence.
- An **Ordered Queue** controls first admission into work; retrying admitted issues does not block later queue entries.
- An invalid **Ordered Queue** is a **Readiness Gap** and must identify the queue entries that prevent dispatch.
- **Ordered Queue** validation contributes to the same readiness report as other **Readiness Gaps**.
- An **Ordered Queue Entry** is invalid when it is malformed, missing from the Workspace Repository issue tracker, absent from the configured GitHub Project, terminal, or not dispatchable.
- Bare Compozy PRD Run slugs under a non-Compozy **Issue Tracker** are invalid **Ordered Queue Entries** and are reported as **Readiness Gaps** after Runtime Settings select the active tracker.
- Duplicate issue identifiers after selected-tracker normalization make an **Ordered Queue** invalid.
- If an **Ordered Queue Entry** becomes invalid after startup validation, Symphony reports the skipped entry in **Runtime State** and continues with later queue entries.
- **Runtime State** records the original order and current progress of an active **Ordered Queue** using the operator-provided queue identifiers.
- The **Runtime Home** state directory stores the active **Ordered Queue** Runtime State projection for ordinary process restart resume.
- The ordered queue identifier sequence identifies an **Ordered Queue** run.
- Restarting with the same **Ordered Queue** resumes queue progress from **Runtime State** when possible.
- Restarting with a different **Ordered Queue** starts a new queue run after validation.
- A bare-slug Compozy **Ordered Queue** and an equivalent canonical `compozy:<task_name>` **Ordered Queue** are different queue runs for resume.
- An **Ordered Queue Entry** can be pending, running, retrying, completed, or skipped.
- An **Ordered Queue Entry** is completed only after the configured task completion behavior finishes.
- A skipped **Ordered Queue Entry** must be reported to the operator.
- When all **Ordered Queue Entries** complete without skips, Symphony stops the run and summarizes the completed work.
- When remaining **Ordered Queue Entries** finish after one or more skips, Symphony stops the run and summarizes completed and skipped entries.
- Ordered Queue completion may trigger existing **Batch Pull Request** behavior for completed queued work.
- The **Terminal Console** should show compact **Ordered Queue** progress and explicit skip and completion events.
- The **Web Dashboard** should show active **Ordered Queue Entries** in their original order with current progress and skipped-entry reasons.
- Symphony reaches **Orchestration Idle** when no active issue is running, retrying, or dispatchable.
- The default **Pull Request Mode** is `batch`.
- A **Pull Request Mode** of `batch` preserves existing **Batch Pull Request** behavior.
- A **Pull Request Mode** of `task` opens **Task Pull Requests** and disables **Batch Pull Request** creation.
- A **Batch Pull Request** represents the combined task work already integrated into the **Loop-Start Branch**.
- Symphony may open a **Batch Pull Request** after reaching **Orchestration Idle**.
- Symphony must not open a **Batch Pull Request** while any issue remains in a **Merge Attention Status**.
- Symphony must not open a **Batch Pull Request** while any issue has unresolved orchestration attention.
- A **Batch Pull Request** uses the **Loop-Start Branch** as its head branch.
- A **Batch Pull Request** uses the configured **Pull Request Base Branch** as its base branch.
- Symphony reports a **Readiness Gap** when automatic **Batch Pull Request** creation is enabled and the current **Loop-Start Branch** is the same branch as the configured **Pull Request Base Branch**.
- Symphony may retry opening a **Batch Pull Request** after a failed attempt when **Orchestration Idle** is reached again.
- Symphony must not create a duplicate **Batch Pull Request** for the same head and base branches.
- A **Task Pull Request** uses a completed task's **Task Branch** as its head branch.
- A **Task Pull Request** uses the configured **Pull Request Base Branch** as its base branch.
- Symphony opens or reuses a **Task Pull Request** when automatic pull request creation is enabled, the **Pull Request Mode** is `task`, and the task moves to the review status.
- Symphony may open **Task Pull Requests** while the current **Loop-Start Branch** is the same branch as the configured **Pull Request Base Branch**.
- A **Task Pull Request** does not require **Task Branch Integration** into the **Loop-Start Branch** before handoff.
- A **Task Pull Request** handoff pushes the **Task Branch** non-force before opening or reusing the pull request.
- A **Pull Request Base Branch** must be configured explicitly in Runtime Settings.
- The **Runtime Settings** may contain a **Pull Request Policy**.
- The **Pull Request Policy** controls whether Symphony opens pull requests and which **Pull Request Mode** it uses.
- The default **Pull Request Policy** disables automatic **Batch Pull Request** creation.
- A **Pull Request Base Branch** is required when the **Pull Request Policy** enables automatic **Batch Pull Request** creation.
- A **Pull Request Base Branch** is required when the **Pull Request Policy** enables automatic **Task Pull Request** creation.
- The **Pull Request Policy** may define **Pull Request Templates** for pull request title and body.
- Default **Pull Request Templates** are deterministic and do not require an agent-generated summary.
- A **Batch Branch Push** happens before opening a **Batch Pull Request**.
- A **Batch Branch Push** pushes the **Loop-Start Branch** to its remote head branch.
- A failed **Batch Branch Push** prevents the **Batch Pull Request** from being opened.
- A failed **Batch Branch Push** is retryable.
- Runtime State records Batch Pull Request handoff attempts, completions, and retryable failures.
- The **Runtime Contract** is version-controlled with the Workspace Repository.
- A **Readiness Gap** prevents dispatch but does not prevent the **Terminal Console** from starting.
- Personal Symphony starts the **Terminal Console** by default.
- Personal Symphony starts the **Web Dashboard** when requested with `--web`.
- A **Web Dashboard Refactor** may change how Runtime State is presented in the **Web Dashboard**.
- A **Web Dashboard Refactor** must preserve the semantics of **Runtime State**.
- The current **Web Dashboard Refactor** must not require backend API changes.
- A **Web Dashboard Refactor** may follow a **Web Dashboard Mock** for visual structure.
- A **Web Dashboard Mock** must not replace the established Personal Symphony domain language.
- The **Web Dashboard** should derive its visible project board columns from Runtime State status order and issue states.
- A **Web Dashboard Mock** must not hard-code project board columns that conflict with Runtime State.
- The **Web Dashboard** should show issue metadata by default and expose task execution details only when they help the operator understand running, retrying, or attention-needed work.
- The **Web Dashboard** should use Running, Retrying, and Total Tokens as its primary operational metrics.
- The **Web Dashboard** should present Readiness Gaps and the Runtime State global last error as attention banners.
- The **Web Dashboard** should not present rate limit data until there is a clear operator action attached to it.
- The current **Web Dashboard Refactor** targets desktop Web Dashboard usage first.
- A **Web Dashboard Refactor** may introduce **Web Dashboard Navigation**.
- **Web Dashboard Navigation** belongs to the **Web Dashboard**, not to orchestration.
- **Web Dashboard Navigation** should be lightweight browser routing for Web Dashboard sections.
- **Web Dashboard Navigation** may include **Audio Notification Configuration**.
- **Audio Notification Configuration** changes browser-local preferences only.
- **Audio Notification Configuration** does not change **Runtime Settings**.
- In the current **Web Dashboard Refactor**, the Configuration section exists only for **Audio Notification Configuration**.
- The current **Web Dashboard Refactor** follows the Audio Notification work that provides **Audio Notification Configuration** behavior.
- A **Web Dashboard** may use one **Live Dashboard Connection** for Runtime State updates.
- A **Live Dashboard Connection** sends a full **Runtime State** snapshot when it opens and after each Runtime State change.
- A **Web Dashboard** may emit an **Audio Notification** after observing a Runtime State transition that needs user attention.
- An **Audio Notification** is not emitted on initial Web Dashboard load.
- An **Audio Notification** requires the user to enable audio from the Web Dashboard before any sound is played.
- The Web Dashboard persists the user's Audio Notification preference in the browser.
- **Work Became Idle** is a Runtime State transition that may emit an **Audio Notification**.
- **Task Needs Attention** is a Runtime State transition that may emit an **Audio Notification** when it newly appears.
- **Work Became Idle** and **Task Needs Attention** use distinct built-in browser-generated Audio Notification tones.
- The Web Dashboard determines Audio Notification eligibility by comparing Runtime State snapshots.
- When **Work Became Idle** and **Task Needs Attention** are observed in the same Runtime State transition, **Task Needs Attention** has Audio Notification priority.
- The Web Dashboard shows whether Audio Notifications are enabled but does not keep an Audio Notification history.
- A retrying task error is not a **Task Needs Attention** condition while Symphony can still retry the task.
- The Runtime State global last error is not a **Task Needs Attention** condition.
- A **Runtime State** change is any update to orchestration or startup state that the Web Dashboard displays.
- A **Live Dashboard Connection** is available even when Readiness Gaps prevent orchestration.
- When a **Live Dashboard Connection** drops, the Web Dashboard reconnects and keeps showing the latest received Runtime State snapshot.
- The Web Dashboard receives routine Runtime State updates through the **Live Dashboard Connection**, while HTTP state reads may remain for diagnostics.
- The **Live Dashboard Connection** endpoint is scoped to the Runtime State resource.
- The **Live Dashboard Connection** message is the Runtime State snapshot, not an event envelope.
- A **Live Dashboard Connection** on a non-loopback server host requires a local dashboard auth token.
- Each Runtime State change broadcasts the current Runtime State snapshot, even when consecutive snapshots are identical.
- The **Live Dashboard Connection** delivers Runtime State snapshots from server to browser, not browser commands to the server.
- A slow or closed **Live Dashboard Connection** must not block orchestration progress.
- The **Web Dashboard** shows a Live Dashboard Connection error only when the connection is down.
- The **Product Repository** provides the **CLI Package**.
- The **CLI Package** provides the `symphony` command.
- The **CLI Package** contains Linux x64, macOS x64, macOS arm64, and Windows x64 binaries under `vendor/`.
- The **Update Source** for normal CLI updates is the npm registry, not GitHub Releases.
- `symphony update` updates the installed **CLI Package** and does not require a **Workspace Repository**.
- `symphony update` supports npm-installed **CLI Package** instances and does not update Product Repository source checkouts.
- `symphony update` requires interactive confirmation before changing an installed **CLI Package** unless the operator passes an explicit non-interactive confirmation flag.
- `symphony update` installs the latest **CLI Package** into the **Install Prefix** that owns the running command.
- `symphony update` succeeds only after the updated `symphony` command reports the target version.
- `symphony update` reports failed update phases and manual repair guidance instead of automatically rolling back partially completed package-manager changes.
- `symphony update` requires fresh **Update Source** discovery and shows the underlying discovery error when the latest version cannot be resolved.
- `symphony update` does not retry package installation with elevated privileges when the **Install Prefix** is not writable.

## Example Dialogue

> **Dev:** "When the user runs the CLI, should we write files into the **Product Repository**?"
> **Domain expert:** "No, runtime files belong in the **Workspace Repository** where the user invoked Personal Symphony."
> **Dev:** "Should the user have to run an init command before the first **Terminal Console** launch?"
> **Domain expert:** "No, the default command should perform a **Bootstrap** when required."
> **Dev:** "Where do agent working directories live?"
> **Domain expert:** "Inside the **Runtime Home** as **Agent Workspaces**, and the bootstrap should add them to the Runtime Home gitignore."
> **Dev:** "Do we commit the file that contains token values?"
> **Domain expert:** "No, commit the **Environment Template** and ignore the **Local Environment**."
> **Dev:** "Does the workflow contract stay at the repository root?"
> **Domain expert:** "No, the **Runtime Contract** lives inside the **Runtime Home**."
> **Dev:** "Should missing token values prevent the **Terminal Console** from opening?"
> **Domain expert:** "No, show each **Readiness Gap** in the **Terminal Console** with the action needed to resolve it."
> **Dev:** "Should Symphony push after every stage even when that stage did not create a commit?"
> **Domain expert:** "No, a **Stage Push** only follows a successful **Stage Commit**."
> **Dev:** "Should a **Stage Push** target a configured branch?"
> **Domain expert:** "No, it pushes the currently checked-out **Task Branch**, because the agent may be running inside an **Agent Worktree**."
> **Dev:** "What if the current **Task Branch** has no upstream yet?"
> **Domain expert:** "The **Stage Push** should create an upstream on `origin` the first time it pushes that branch."
> **Dev:** "If the **Stage Commit** succeeds but the **Stage Push** fails, should Symphony still move the issue to the success state?"
> **Domain expert:** "No, a failed **Stage Push** means the stage handoff did not complete."
> **Dev:** "Should a failed **Stage Push** block the issue immediately?"
> **Domain expert:** "No, **Stage Push** failures are retryable because remote delivery can fail for transient reasons."
> **Dev:** "Does the web flag start the terminal interface too?"
> **Domain expert:** "No, `--web` switches from the **Terminal Console** to the **Web Dashboard**, with terminal output limited to operational status."
> **Dev:** "Does the **Live Dashboard Connection** replace every HTTP route?"
> **Domain expert:** "No, it streams **Runtime State** updates to the **Web Dashboard**; HTTP can still serve assets and one-off operations."
> **Dev:** "Should every backend event play a sound?"
> **Domain expert:** "No, the **Web Dashboard** emits **Audio Notifications** only for observed Runtime State transitions that need user attention."
> **Dev:** "Should dashboard sounds play automatically when the page opens?"
> **Domain expert:** "No, the user must enable **Audio Notifications** from the **Web Dashboard** before any sound plays."
> **Dev:** "Is enabling sound a repository setting?"
> **Domain expert:** "No, the **Web Dashboard** stores the user's **Audio Notification** preference in the browser."
> **Dev:** "Does 'queue finished' mean there are no issues visible on the board?"
> **Domain expert:** "No, **Work Became Idle** means running and retrying work drained to zero after previously being active."
> **Dev:** "Should every error field trigger an audible warning?"
> **Domain expert:** "No, only a new **Task Needs Attention** condition should emit an **Audio Notification**; retryable errors are still being handled by Symphony."
> **Dev:** "Should completion and attention use the same sound file?"
> **Domain expert:** "No, they should use distinct built-in browser-generated **Audio Notification** tones."
> **Dev:** "Should the backend send explicit sound events?"
> **Domain expert:** "No, the **Web Dashboard** should decide when to emit **Audio Notifications** by comparing Runtime State snapshots."
> **Dev:** "If work finishes and a task needs attention at the same time, should both tones play?"
> **Domain expert:** "No, play the **Task Needs Attention** tone because it has higher priority."
> **Dev:** "Should the dashboard show a list of past sounds?"
> **Domain expert:** "No, it should show whether **Audio Notifications** are enabled but not keep a notification history."
> **Dev:** "When an operator passes `--agent.maxTurns`, should Symphony edit `.symphony/settings.json`?"
> **Domain expert:** "No, that is a **Runtime Settings Invocation Override** for the current process only; the **Runtime Contract** stays unchanged."

## Flagged Ambiguities

- "project" was used to mean both the Personal Symphony source repository and the user's repository; resolved: use **Product Repository** for this repo and **Workspace Repository** for the repository where the CLI runs.
- "implement WebSocket instead of http" was used to mean replacing browser state polling; resolved: use a **Live Dashboard Connection** for Runtime State updates while preserving HTTP for page assets and one-off routes.
- "worktress" was used to mean per-task Git worktrees; resolved: use **Agent Worktree** for an **Agent Workspace** backed by `git worktree`.
- "push the code in every step" was used to mean pushing after each successful stage-level commit; resolved: use **Stage Push** for the optional push that follows a **Stage Commit**.
- "push to the branch that we are in" was used to mean pushing the currently checked-out **Task Branch**, especially from an **Agent Worktree**.
- "/goal" was used to mean a per-stage Codex launch handoff; resolved: use **Stage Goal Handoff**.
- "all the context" for `/goal` was used broadly; resolved: use **Stage Goal Context** for deterministic issue and stage data.
- "sounds in frontend" was used to mean browser-played cues from the Web Dashboard; resolved: use **Audio Notification** for sound cues emitted after relevant Runtime State transitions.
- "queue finished" was used without a queue concept in the Runtime State model; resolved: use **Work Became Idle** for the transition from running or retrying work to zero running and zero retrying work.
- "error happens" was used broadly; resolved: use **Task Needs Attention** only when a new Runtime State issue error appears.
- "tasks in queue" was used to mean there is no remaining orchestration work; resolved: use **Orchestration Idle** for the condition where no active issue is running, retrying, or dispatchable.
- "Open PR after finishing all the tasks" was used to mean opening one pull request for combined task work; resolved: use **Batch Pull Request**, opened from the **Loop-Start Branch** after **Orchestration Idle** by default.
- "Open PR after the agent reaches In review" in `batch` **Pull Request Mode** means opening the same **Batch Pull Request** early through **Review Pull Request Handoff**.
- "Start on main, but open PRs from each Task Branch into main" means using `task` **Pull Request Mode** to open **Task Pull Requests**.
- "base branch" for automatic PR creation was ambiguous because **Batch Pull Requests** and **Task Pull Requests** have different head branches; resolved: use configured **Pull Request Base Branch** for the target branch.
- "merge the worktrees" was used to mean integrating completed **Task Branches**; resolved: Symphony fast-forward merges **Task Branches** into the **Loop-Start Branch**, not Agent Worktrees.
- ".symphonyignore" was used to mean a repository-owned rule for files agents must not modify; resolved: use **Protected Path Policy** stored in **Runtime Settings** for the first version.
- "allowed branch" was used to mean restricting where orchestration may start; resolved: use **Allowed Loop-Start Branch Policy**.
- "commit stage tags" was used to mean metadata that chooses a Stage Commit type or tag; resolved: use **Stage Commit Classification**.
- "tags.json guidance" was used to mean the repository-owned four-character commit tag vocabulary; resolved: use **Stage Commit Tag Guidance**.
- "maxConcurrentAgents for each stage" was used to mean concurrency caps per Stage Agent; resolved: use **Stage Concurrency Policy**.
- "full context" and "context compression" were used broadly for launch-time context; resolved: use **Agent Context Snapshot** for bounded deterministic launch context and **Context Command** for optional operator-generated stdout.
- "agent command" was used to mean both a local executable string and the selectable launch behavior for a Stage Agent; resolved: use **Agent Harness** for the named Runtime Settings launch configuration under `harnesses`, with **Codex Harness**, **Claude Harness**, and **PI Harness** as concrete harness kinds.
- "agent" was used to mean both a logical role and an execution backend; resolved: use **Logical Agent** for `agents.<name>` role execution selection and **Agent Harness** for `harnesses.<name>` execution backend definitions.
- "CLI override" was used to mean replacing Runtime Settings for one run without editing `.symphony/settings.json`; resolved: use **Runtime Settings Invocation Override**.
