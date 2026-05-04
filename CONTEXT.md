# Personal Symphony

Personal Symphony helps a user run a Symphony orchestration workflow inside an existing software repository.

## Language

**Workspace Repository**:
The repository where a user runs Personal Symphony and where runtime configuration and state are created.
_Avoid_: project, target project

**Product Repository**:
The repository that contains the Personal Symphony source code.
_Avoid_: project, source project

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

**Merge Attention Status**:
The project status for a task whose agent work completed but whose Task Branch could not be auto-merged.
_Avoid_: retry status, review status, failed status

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
The `settings.json` portion of the Runtime Contract that defines tracker, project, orchestration, agent, server, and path configuration.
_Avoid_: config, preferences

**Git Policy**:
The Runtime Settings section that defines Task Branch and Protected Trunk Branch behavior.
_Avoid_: branch config, git settings

**Task Cleanup Policy**:
The Git Policy setting that controls whether completed task worktrees or branches are removed.
_Avoid_: cleanup flag, delete option

**Agent Prompt**:
The `prompt.md` portion of the Runtime Contract that defines the task instructions rendered for each dispatched issue.
_Avoid_: prompt template, workflow body

**Runtime State**:
The ignored files inside the Runtime Home that record current orchestration activity and recovery data.
_Avoid_: state files, generated data

**Stage Commit**:
A commit created by Personal Symphony after an agent successfully completes a configured stage.
_Avoid_: auto commit, every step commit

**Stage Push**:
An optional push of a Stage Commit to the currently checked-out Task Branch after the Stage Commit is created.
_Avoid_: auto push, push every step

**Orchestration Idle**:
The orchestration condition where no active issue is running, retrying, or dispatchable.
_Avoid_: queue empty, all tasks finished, done processing

**Batch Pull Request**:
A single pull request opened from the Loop-Start Branch after Symphony reaches Orchestration Idle.
_Avoid_: per-task PR, task pull request, queue PR

**Batch Branch Push**:
An optional non-force push of the Loop-Start Branch before opening a Batch Pull Request.
_Avoid_: final push, queue push, release push

**Pull Request Base Branch**:
The configured target branch for a Batch Pull Request.
_Avoid_: inferred base, default branch, protected branch

**Pull Request Policy**:
The Runtime Settings section that controls automatic Batch Pull Request creation.
_Avoid_: PR config, GitHub settings, git policy

**Pull Request Template**:
The configured title or body pattern used when opening a Batch Pull Request.
_Avoid_: generated PR text, AI summary, PR prose

**Readiness Gap**:
A missing or invalid runtime requirement that prevents Personal Symphony from dispatching work.
_Avoid_: setup error, config problem

**Clean Loop-Start Worktree**:
A Loop-Start Branch checkout with no uncommitted Workspace Repository changes.
_Avoid_: clean repo, safe branch

**Terminal Console**:
The default terminal interface for operating Personal Symphony in a Workspace Repository.
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
The npm-distributed Personal Symphony package that provides the `symphony` command.
_Avoid_: npm wrapper, global install

**Idempotent Bootstrap**:
A Bootstrap that creates missing Runtime Home files without overwriting user-edited files.
_Avoid_: reinitialize, reset

## Relationships

- A **Workspace Repository** may receive a **Bootstrap** from Personal Symphony.
- An **Idempotent Bootstrap** must preserve existing Runtime Contract and Local Environment files.
- A **Workspace Repository** contains at most one **Runtime Home**.
- Personal Symphony commands must be run from the root of a **Workspace Repository**.
- Personal Symphony exits before Bootstrap when the current directory is not the root of a **Workspace Repository**.
- A **Runtime Home** contains the **Runtime Contract**, user-editable settings, and internal state.
- The **Runtime Contract** contains **Runtime Settings**.
- The **Runtime Contract** contains an **Agent Prompt**.
- A **Runtime Home** contains one **Environment Template** and may contain one **Local Environment**.
- A **Runtime Home** may contain **Runtime State**.
- A **Runtime Home** may contain many **Agent Workspaces**.
- An **Agent Worktree** is an **Agent Workspace**.
- The **Runtime Settings** contain a **Git Policy**.
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
- Auto-merge of a **Task Branch** into the **Loop-Start Branch** is fast-forward only.
- When auto-merge fails, Symphony may move the task to a **Merge Attention Status**.
- The default **Merge Attention Status** is `Human attention`.
- The **Merge Attention Status** is paused and not dispatchable.
- The default **Task Cleanup Policy** removes an **Agent Worktree** after its **Task Branch** is merged.
- The default **Task Cleanup Policy** keeps a merged **Task Branch**.
- A **Stage Commit** may be created when a configured stage completes with code changes.
- A **Stage Push** happens only after a **Stage Commit** is successfully created.
- A **Stage Push** happens before the stage moves to its success project state.
- Runtime Settings enable a **Stage Push** with `commit.push` on a configured stage.
- A missing `commit.push` setting means the **Stage Push** is disabled.
- Bootstrapped Runtime Settings include `commit.push` as `false` in each example stage commit policy.
- A **Stage Push** sends the **Stage Commit** to the currently checked-out **Task Branch**.
- A **Stage Push** pushes the current **Task Branch** tip, including earlier unpushed commits on that branch.
- A **Stage Push** is a non-force push.
- A **Stage Push** uses the current **Task Branch** upstream when one exists.
- A **Stage Push** creates an upstream on `origin` when the current **Task Branch** has no upstream.
- A **Stage Push** happens before any auto-merge attempt.
- Symphony does not push the **Loop-Start Branch** after auto-merge.
- A failed **Stage Push** prevents the stage from moving to its success project state.
- A failed **Stage Push** is retryable.
- Symphony reaches **Orchestration Idle** when no active issue is running, retrying, or dispatchable.
- A **Batch Pull Request** represents the combined task work already integrated into the **Loop-Start Branch**.
- Symphony may open a **Batch Pull Request** after reaching **Orchestration Idle**.
- Symphony must not open a **Batch Pull Request** while any issue remains in a **Merge Attention Status**.
- Symphony must not open a **Batch Pull Request** while any issue has unresolved orchestration attention.
- A **Batch Pull Request** uses the **Loop-Start Branch** as its head branch.
- A **Batch Pull Request** uses the configured **Pull Request Base Branch** as its base branch.
- Symphony may retry opening a **Batch Pull Request** after a failed attempt when **Orchestration Idle** is reached again.
- Symphony must not create a duplicate **Batch Pull Request** for the same head and base branches.
- A **Pull Request Base Branch** must be configured explicitly in Runtime Settings.
- The **Runtime Settings** may contain a **Pull Request Policy**.
- The **Pull Request Policy** controls whether Symphony opens a **Batch Pull Request** after **Orchestration Idle**.
- The default **Pull Request Policy** disables automatic **Batch Pull Request** creation.
- A **Pull Request Base Branch** is required when the **Pull Request Policy** enables automatic **Batch Pull Request** creation.
- The **Pull Request Policy** may define **Pull Request Templates** for the **Batch Pull Request** title and body.
- Default **Pull Request Templates** are deterministic and do not require an agent-generated summary.
- A **Batch Branch Push** happens before opening a **Batch Pull Request**.
- A **Batch Branch Push** pushes the **Loop-Start Branch** to its remote head branch.
- A failed **Batch Branch Push** prevents the **Batch Pull Request** from being opened.
- A failed **Batch Branch Push** is retryable.
- Runtime State records Batch Pull Request handoff attempts, completions, and retryable failures.
- The **Runtime Contract** is version-controlled with the Workspace Repository.
- A **Readiness Gap** prevents dispatch but does not prevent the TUI from starting.
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
- Each Runtime State change broadcasts the current Runtime State snapshot, even when consecutive snapshots are identical.
- The **Live Dashboard Connection** delivers Runtime State snapshots from server to browser, not browser commands to the server.
- A slow or closed **Live Dashboard Connection** must not block orchestration progress.
- The **Web Dashboard** shows a Live Dashboard Connection error only when the connection is down.
- The **Product Repository** provides the **CLI Package**.
- The **CLI Package** provides the `symphony` command.

## Example Dialogue

> **Dev:** "When the user runs the CLI, should we write files into the **Product Repository**?"
> **Domain expert:** "No, runtime files belong in the **Workspace Repository** where the user invoked Personal Symphony."
> **Dev:** "Should the user have to run an init command before the first TUI launch?"
> **Domain expert:** "No, the default command should perform a **Bootstrap** when required."
> **Dev:** "Where do agent working directories live?"
> **Domain expert:** "Inside the **Runtime Home** as **Agent Workspaces**, and the bootstrap should add them to the Runtime Home gitignore."
> **Dev:** "Do we commit the file that contains token values?"
> **Domain expert:** "No, commit the **Environment Template** and ignore the **Local Environment**."
> **Dev:** "Does the workflow contract stay at the repository root?"
> **Domain expert:** "No, the **Runtime Contract** lives inside the **Runtime Home**."
> **Dev:** "Should missing token values prevent the TUI from opening?"
> **Domain expert:** "No, show each **Readiness Gap** in the TUI with the action needed to resolve it."
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

## Flagged Ambiguities

- "project" was used to mean both the Personal Symphony source repository and the user's repository; resolved: use **Product Repository** for this repo and **Workspace Repository** for the repository where the CLI runs.
- "implement WebSocket instead of http" was used to mean replacing browser state polling; resolved: use a **Live Dashboard Connection** for Runtime State updates while preserving HTTP for page assets and one-off routes.
- "worktress" was used to mean per-task Git worktrees; resolved: use **Agent Worktree** for an **Agent Workspace** backed by `git worktree`.
- "push the code in every step" was used to mean pushing after each successful stage-level commit; resolved: use **Stage Push** for the optional push that follows a **Stage Commit**.
- "push to the branch that we are in" was used to mean pushing the currently checked-out **Task Branch**, especially from an **Agent Worktree**.
- "sounds in frontend" was used to mean browser-played cues from the Web Dashboard; resolved: use **Audio Notification** for sound cues emitted after relevant Runtime State transitions.
- "queue finished" was used without a queue concept in the Runtime State model; resolved: use **Work Became Idle** for the transition from running or retrying work to zero running and zero retrying work.
- "error happens" was used broadly; resolved: use **Task Needs Attention** only when a new Runtime State issue error appears.
- "tasks in queue" was used to mean there is no remaining orchestration work; resolved: use **Orchestration Idle** for the condition where no active issue is running, retrying, or dispatchable.
- "Open PR after finishing all the tasks" was used to mean opening one pull request for combined task work; resolved: use **Batch Pull Request**, opened from the **Loop-Start Branch** after **Orchestration Idle**.
- "base branch" for automatic PR creation was ambiguous because the **Loop-Start Branch** is the head of the **Batch Pull Request**; resolved: use configured **Pull Request Base Branch** for the target branch.
