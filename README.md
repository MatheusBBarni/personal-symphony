# Symphony Orchestrator

Symphony Orchestrator is an installable `symphony` CLI for the Symphony service described in
[Symphony SPEC](https://github.com/openai/symphony/blob/main/SPEC.md). The Product Repository keeps
the OCaml backend, the ReScript React dashboard, and the npm launcher; each Workspace Repository gets
its own repository-owned Runtime Contract under `.symphony/`.

## Prerequisites

- `codex` CLI available on `PATH` when running real agent sessions
- For the default GitHub Tracker: GitHub CLI `gh` and a GitHub personal access token available as
  `GITHUB_TOKEN` or `GH_TOKEN`
- For the minibeads Local Issue Tracker: the `mb` CLI and a local issue store in the Workspace
  Repository
- For the Compozy-backed Local Issue Tracker: a Compozy PRD Run directory under
  `.compozy/tasks/<task_name>/` in the Workspace Repository

## Install

The npm package exposes a global `symphony` command:

```sh
npm i -g symphony-orchestrator
```

## Set Up In A Workspace Repository

Run the command from the root of a Git repository:

```sh
symphony init
symphony
```

`symphony init` and the first `symphony` run perform an Idempotent Bootstrap. They create missing
Runtime Home files under `.symphony/` without overwriting user-edited Runtime Contract or Local
Environment files:

- `.symphony/settings.json`
- `.symphony/prompt.md`
- `.symphony/.env.example`
- `.symphony/.gitignore`
- `.symphony/.env`
- `.symphony/state/`
- `.symphony/workspaces/`

`.symphony/.gitignore` ignores local secrets and runtime state:

```gitignore
/.env
/state/
/workspaces/
```

Edit `.symphony/settings.json` to choose an Issue Tracker, set tracker-specific fields, configure
status states, and set runtime commands. Runtime Settings reference secrets by environment variable
name; secret values belong only in the Local Environment.

### Default Terminal Console

Run `symphony` from the Workspace Repository root to start the default read-first Terminal Console.
It is the foreground surface for normal local orchestration and renders Runtime State snapshots for
active work, retrying work, task attention, Readiness Gaps, Ordered Queue progress, Logs progress, Agent Worktree details,
and Task Branch context.
Compozy PRD Run progress appears when Compozy tracking is selected.

The Terminal Console is safe to keep open while Symphony runs. Its MVP safe local aids are limited to
refreshing the latest in-memory Runtime State snapshot, navigating and filtering tabs, showing the
Web Dashboard handoff command, and inspecting validated local paths such as the Workspace Repository
or Runtime Home. These aids do not retry tasks, pause or resume dispatch, update tracker status, merge
or push Task Branches, open pull requests, change Runtime Contract files, or otherwise mutate task
lifecycle state.

Use Web Dashboard mode when browser-level inspection is more useful:

```sh
symphony --web --port 8080
```

The Web Dashboard keeps using the Live Dashboard Connection as a Runtime State stream. It is not a
Terminal Console command channel.

For a non-interactive check, use `symphony --once`; it prints terminal output and exits without
starting the foreground Terminal Console loop.

### Issue Tracker Selection

GitHub is the default Issue Tracker. It uses GitHub Issues as issue records and GitHub Projects
status values as dispatch state. Omitted `tracker.kind` values are treated as `"github"`, but new
Workspace Repositories should set it explicitly:

```json
{
  "tracker": {
    "kind": "github",
    "owner": "your-org",
    "repo": "your-repo",
    "projectNumber": 1,
    "apiKeyEnv": "GITHUB_TOKEN"
  }
}
```

Choose minibeads when you want issue records to live in repository-owned Local Issue Files and you do
not want Symphony issue dispatch or tracker status updates to require GitHub API access. minibeads is
first-class when explicitly selected, but it is not a migration requirement for existing GitHub
Tracker users:

```json
{
  "tracker": {
    "kind": "minibeads",
    "root": ".beads",
    "command": "mb"
  }
}
```

`tracker.root` is resolved from the Workspace Repository root and defaults to `.beads`.
`tracker.command` defaults to `mb`; set it only when the executable name or path differs in your
environment. Symphony runs minibeads commands from the Workspace Repository root and treats Local
Issue Files as repository-owned user data.

Choose the Compozy-backed Local Issue Tracker when you want Symphony to run a Compozy PRD Run from
`.compozy/tasks/<task_name>/` as one user-facing work item. This tracker is opt-in with
`tracker.kind = "compozy_tasks"`; GitHub remains the default Issue Tracker when the field is omitted
or set to `"github"`:

```json
{
  "tracker": {
    "kind": "compozy_tasks",
    "compozy": {
      "root": ".compozy/tasks",
      "maxTaskStepRetries": 2
    }
  }
}
```

`tracker.compozy.root` is resolved from the Workspace Repository root and defaults to
`.compozy/tasks`. Each direct child directory, such as `.compozy/tasks/compozy-tasks-run-integration/`,
is treated as one Compozy PRD Run. The `task_NN.md` files inside that directory are Compozy Task Steps
in the same Agent Worktree and Task Branch; they are not separate Symphony issues. When
present, `_prd.md` and `_techspec.md` are included in each task-step Agent Prompt.

Symphony persists Compozy Task Step progress in task file frontmatter. During a run, task steps move
through statuses such as `pending`, `in_progress`, `completed`, `failed`, and `skipped`, with retry
metadata recorded alongside the status. `tracker.compozy.maxTaskStepRetries` controls how many times
Symphony retries a failed task step before recording the failed or skipped state and advancing to the
next runnable task step. Runtime State, the Terminal Console, and the Web Dashboard show the selected
tracker kind, Compozy PRD Run identifier, current task step, completed count, failed count, skipped
count, and total count when Compozy tracking is selected.

Compozy tracking has four related status layers:

| Layer | Runtime State field or source | What it answers |
| --- | --- | --- |
| Compozy Task Step progress | `current_step`, `completed`, `failed`, `skipped`, `total` from `task_NN.md` frontmatter | Which ordered step is selected and how many steps are terminal. |
| Compozy PRD Run lifecycle | `lifecycle_state` | What phase the whole run is in from the operator perspective. |
| Dispatch state | `dispatch_state` and `stage_agent` | Which configured tracker status and Stage Agent routing state Symphony is using. |
| Compozy PR Readiness | `pr_readiness`, `handoff_status`, and `reason` | Whether the completed run is eligible for one aggregate Batch Pull Request or why it is not. |

Runtime State, the Terminal Console, and the Web Dashboard render these layers from the same
`compozy_progress` payload. The Terminal Console and Web Dashboard use compact labels such as
`Lifecycle`, `Dispatch state`, `Stage agent`, `PR readiness`, `Handoff`, and `Reason`, but those
labels do not merge the layers. Compozy Task Step progress remains the source for current-step and
count truth; lifecycle and readiness explain the run around that progress.

Compozy PRD Run lifecycle meanings:

| Lifecycle state | Meaning |
| --- | --- |
| `pending` | The run exists but has not entered active Stage Agent work. |
| `in_planning` | Planner-stage work is active. |
| `in_execution` | Engineer-stage work or active task-step execution is in progress. |
| `in_review` | Reviewer-stage work is active. |
| `blocked` | Symphony needs operator attention and the run is not progressing normally. |
| `completed` | The run completed successfully from the lifecycle perspective. |
| `failed` | The run ended with failed work and is not ready for a Batch Pull Request. |
| `skipped` | The run ended with skipped work and is not ready for a Batch Pull Request. |
| `not_pr_ready` | The run is stopped or terminal but cannot open a Batch Pull Request; this is the not-PR-ready lifecycle and `Reason` explains why. |
| `pr_handoff` | Batch Pull Request handoff for the aggregate Batch Pull Request is attempting, completed, or failed. |

PR readiness is separate from both lifecycle and task-step counts:

| PR readiness | Meaning |
| --- | --- |
| `disabled` | The Pull Request Policy does not enable automatic Batch Pull Requests. |
| `not_ready` | The run is in the not-ready outcome for a Batch Pull Request; `Reason` describes the broad blocker. |
| `ready` | The run completed successfully and is eligible for one aggregate Batch Pull Request. |
| `handoff_attempting` | Symphony is attempting the Batch Pull Request handoff. |
| `handoff_completed` | Symphony opened, completed, or reused the aggregate Batch Pull Request. |
| `handoff_failed` | Batch Pull Request handoff failed and may be retried after the cause is fixed. |

Representative Compozy PRD Run examples:

| Scenario | Task-step progress | `lifecycle_state` | `dispatch_state` / `stage_agent` | `pr_readiness` / `handoff_status` | Operator meaning |
| --- | --- | --- | --- | --- | --- |
| Review active | Current Compozy Task Step and counts still come from task files. | `in_review` | `In review` / `reviewer` | `not_ready` / none | Reviewer work is active; the run is not ready for Batch Pull Request handoff. |
| Retrying execution | The current step remains selected while retry context is visible in Runtime State. | `in_execution` | Current configured run state / `engineer` | `not_ready` / none | Retry does not create a new lifecycle value; `Reason` explains the retry. |
| Blocked attention | Counts may show failed, skipped, or unavailable task-step progress. | `blocked` | `Human attention` / current Stage Agent when known | `not_ready` / none | Operator action is required before normal progress or handoff can continue. |
| Failed or skipped terminal | Task-step truth shows failed or skipped terminal work. | `failed` or `skipped` | Terminal configured run state | `not_ready` / none | Terminal progress is visible, but it is not Batch Pull Request-ready. |
| Completed and batch-ready | All task steps completed and final integration is safe. | `completed` | `Done` / current Stage Agent when known | `ready` / none | The Compozy PRD Run is eligible for one aggregate Batch Pull Request when the Pull Request Policy enables batch handoff. |
| Completed with pull requests disabled | All task steps completed and final integration is safe. | `completed` | `Done` / current Stage Agent when known | `disabled` / none | The run completed, but automatic Batch Pull Requests are disabled by Pull Request Policy. |
| Handoff failure | The completed run entered aggregate Batch Pull Request handoff. | `pr_handoff` | `Done` / current Stage Agent when known | `handoff_failed` / `handoff_failed` | The run is in handoff phase, and the failed handoff is a readiness outcome with a `Reason`, not successful review readiness. |

Terminal task-step progress does not imply Batch Pull Request readiness. A run with failed, skipped,
blocked, or otherwise terminal Compozy Task Steps remains `not_ready` unless the Compozy PRD Run
completed successfully, final integration is safe, and the Pull Request Policy allows handoff.
In `batch` Pull Request Mode, Compozy tracking preserves aggregate Batch Pull Request behavior:
Symphony never opens one pull request per Compozy Task Step. At most one Batch Pull Request is
eligible for the completed Compozy PRD Run, using the Loop-Start Branch as the pull-request head.
If the completed Compozy Task Steps move the run into another configured Stage Agent state, Symphony
dispatches that next Stage Agent with completed-run context first. Pull request handoff happens only
after there is no configured next Stage Agent.

When the selected Issue Tracker is `tracker.kind = "compozy_tasks"`, `--queue` accepts bare Compozy
PRD Run slugs from `.compozy/tasks/<task_name>/`:

```sh
symphony --queue compozy-tasks-run-integration,queue-docs-refresh
```

Symphony keeps those queue identifiers as typed in Runtime State and uses the same raw sequence when
deciding whether a restart resumes an Ordered Queue. Restarting with canonical selectors such as
`compozy:compozy-tasks-run-integration,compozy:queue-docs-refresh` starts a different queue run than
the bare-slug command above, even though dispatch resolves both forms to the same Compozy PRD Runs.

The bare-slug shortcut is only for `--queue` with the Compozy-backed Issue Tracker. If GitHub or
minibeads tracking is selected, a bare Compozy slug in `--queue` is reported as a startup Readiness
Gap; use GitHub identifiers such as `20` or `#20`, minibeads identifiers such as `mb-20`, or switch
Runtime Settings to `tracker.kind = "compozy_tasks"`. Canonical Compozy queue selectors such as
`--queue compozy:compozy-tasks-run-integration` remain accepted for compatibility, but a single
Compozy queue must use either bare slugs or canonical selectors, not both.

Where selector-based flows outside the `--queue` shortcut support Compozy tracking, use the stable
identifier form `compozy:<task_name>`. For example, `.compozy/tasks/compozy-tasks-run-integration/`
is selected as `compozy:compozy-tasks-run-integration` in Manual Task Merge flows.

Define execution backends under `harnesses` and logical agent roles under `agents`. Harnesses own
provider commands and loop capability. Logical agents select a Harness and may override model,
reasoning, and timeout fields for planner, engineer, or reviewer work:

```json
{
  "harnesses": {
    "codex": {
      "kind": "codex",
      "command": "codex exec",
      "loop": {
        "enabled": true,
        "command": "/goal"
      }
    },
    "claude": {
      "kind": "claude",
      "command": "claude -p --model <model> --output-format stream-json",
      "loop": {
        "enabled": false,
        "command": ""
      }
    },
    "pi": {
      "kind": "pi",
      "command": "pi --model <model> --thinking <reasoning> --print --no-session",
      "loop": {
        "enabled": false,
        "command": ""
      }
    }
  },
  "agents": {
    "planner": {
      "harness": "codex",
      "model": "gpt-5.5",
      "reasoningEffort": "medium",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    },
    "engineer": {
      "harness": "claude",
      "model": "opus-4.7",
      "reasoningEffort": "xhigh",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    },
    "reviewer": {
      "harness": "pi",
      "model": "openai-codex/gpt-5.5",
      "reasoningEffort": "high",
      "turnTimeoutMs": 3600000,
      "readTimeoutMs": 5000,
      "stallTimeoutMs": 300000
    }
  },
  "stageAgents": {
    "enabled": true,
    "stages": [
      {
        "states": ["Todo", "To-Do", "In progress", "In Progress"],
        "agent": "engineer"
      }
    ]
  }
}
```

PI and Claude are not prerequisites for Codex-only dispatch. Symphony validates install and
authentication readiness only for Harnesses selected by enabled Stage Agent routes. A selected PI
Harness requires the `pi` executable on `PATH` and provider authentication for the configured model. A
selected Claude Harness requires the `claude` executable and Claude Code authentication, such as
`ANTHROPIC_API_KEY` or Claude's configured login state. Runtime Settings must reference only
environment variable names, never secret values.

Legacy settings that place Harness definitions under `agents.*`, such as `agents.pi.kind`, are
migration input. When the new Runtime Settings shape is in use, Symphony reports a blocking Readiness
Gap that tells you to move execution fields into `harnesses.*` and keep `agents.*` for logical agent
definitions. Stage-level `stageAgents.stages[].harness` is also legacy input; move Harness selection to
`agents.<logical-agent>.harness`.

If setup is incomplete, the Terminal Console still starts and prints Readiness Gaps with remediation
steps. Dispatch remains disabled until those gaps are resolved.

### Optional Docker Sandbox

Sandboxing is a repository-level Runtime Settings boundary for Workspace Repositories that should run
agent work through Docker instead of direct host Agent Harness execution. It is optional and disabled
by default. Docker is the only supported sandbox type in V1:

```json
{
  "sandbox": {
    "enabled": false,
    "type": "docker",
    "image": "ghcr.io/your-org/symphony-agent:latest",
    "bootstrapCommands": [],
    "persistent": true,
    "networkEnabled": false,
    "cpuLimit": 2,
    "memoryMb": 4096
  }
}
```

Set `sandbox.enabled` to `true` only after replacing `sandbox.image` with the Docker image for the
Workspace Repository. When sandboxing is enabled, Symphony treats the Sandbox as required for agent
execution in that repository. Missing required settings, unsupported `sandbox.type` values, Docker
availability problems, or unhealthy sandbox state are Readiness Gaps and block dispatch; Symphony does
not silently fall back to host execution.

`sandbox.bootstrapCommands` is a list of non-empty shell commands that run only when Symphony creates
or recreates the repository-scoped Docker container. V1 requires `sandbox.persistent: true` so repeat
runs can reuse the named container. `sandbox.networkEnabled` makes network access explicit, and
`sandbox.cpuLimit` / `sandbox.memoryMb` must be positive integers.

Runtime State snapshots include the running-work fields `sandbox_enabled`, `sandbox_provider`, and
`sandbox_reuse_outcome`. The reuse outcome is one of `created`, `reused`, or `recreated`; these
fields are the V1 visibility surface for confirming whether a sandboxed run used a fresh, warm, or
refreshed container.

For the GitHub Tracker, readiness includes the configured owner, Workspace Repository name, GitHub
Project number, status field, and token environment variable. For Local Issue Tracker runs,
GitHub owner, repo, Project, and token settings are not required. The local tracker readiness checks
include tracker-specific local files and commands:

- `tracker.minibeads.command`: install minibeads or update `tracker.command` so Symphony can run the
  configured command.
- `tracker.minibeads.store`: create the local issue store at `tracker.root` or update `tracker.root`
  to the existing minibeads store.
- `tracker.compozy.root`: create the Compozy tasks root at `tracker.compozy.root` or update the
  setting to the existing `.compozy/tasks` directory.
- `tracker.compozy.tasks`: add at least one valid `.compozy/tasks/<task_name>/task_NN.md` file with
  task-step frontmatter.

## Project Status Workflow

Symphony moves the selected Issue Tracker status as work progresses. With the GitHub Tracker, this is
the configured GitHub Projects `Status` field. With the minibeads Local Issue Tracker, Symphony maps
the same Runtime Settings state names to minibeads statuses and writes them through `mb`. With the
Compozy-backed Local Issue Tracker, the Compozy PRD Run is the work item and Symphony records
task-step status in each `task_NN.md` file's frontmatter:

- `startStatus`: applied before launching an agent, default `In progress`.
- `reviewStatus`: applied after the agent exits successfully, default `In review`.
- `retryStatus`: applied when the agent fails or times out and Symphony schedules a retry, default
  `To-Do`.
- `ensureStatuses`: when `true`, Symphony creates missing single-select status options in the
  Project field before applying them.

Configure these in `.symphony/settings.json`:

```json
{
  "project": {
    "statusField": "Status",
    "activeStates": ["To-Do", "Todo", "In Progress"],
    "terminalStates": ["Done", "Closed", "Cancelled"],
    "startStatus": "In progress",
    "reviewStatus": "In review",
    "retryStatus": "To-Do",
    "ensureStatuses": true
  }
}
```

The token needs GitHub Projects write access for status moves and status option creation. If
`reviewStatus` is not listed in `activeStates`, completed issues stop being picked up on later polls.
The token requirement applies to GitHub Tracker runs only.

## Stage Agents

Symphony can route different Project statuses to different local agent prompts. The default runtime
home creates:

- `.symphony/agents/planner.md` for `Backlog`.
- `.symphony/agents/engineer.md` for `Todo`, `To-Do`, and `In progress`.
- `.symphony/agents/reviewer.md` for `In review`, then moves successful reviews to `Done`.

Configure or disable this in `.symphony/settings.json`:

```json
{
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "defaultAgent": "engineer",
    "stages": [
      {
        "states": ["Backlog"],
        "agent": "planner",
        "maxConcurrentAgents": 1,
        "skills": [],
        "successStatus": "To-Do",
        "retryStatus": "Backlog",
        "goal": {
          "enabled": false
        },
        "commit": {
          "enabled": false,
          "type": "feature",
          "message": "<type>: <generated_message_max_90char>",
          "push": false
        }
      },
      {
        "states": ["Todo", "To-Do", "In progress", "In Progress"],
        "agent": "engineer",
        "maxConcurrentAgents": 2,
        "skills": [],
        "startStatus": "In progress",
        "successStatus": "In review",
        "retryStatus": "To-Do",
        "goal": {
          "enabled": false
        },
        "commit": {
          "enabled": true,
          "type": "feature",
          "message": "<type>: <generated_message_max_90char>",
          "push": false
        }
      },
      {
        "states": ["In review", "In Review"],
        "agent": "reviewer",
        "maxConcurrentAgents": 2,
        "skills": [],
        "successStatus": "Done",
        "retryStatus": "In progress",
        "goal": {
          "enabled": false
        },
        "commit": {
          "enabled": false,
          "type": "refactor",
          "message": "<type>: <generated_message_max_90char>",
          "push": false
        }
      }
    ]
  }
}
```

Set `"enabled": false` to use the single base `.symphony/prompt.md` for every issue.

Set `maxConcurrentAgents` on a stage to configure a Stage Concurrency Policy for that Stage Agent.
The value is an optional positive integer. When omitted, that stage keeps global-only dispatch
admission. Stage caps share the global `agent.maxConcurrentAgents` ceiling, so the scheduler never
runs more total agents than the global cap permits. Stage caps are capacity limits only: Symphony
does not keep idle agents alive, and a stage with one dispatchable issue launches one agent even if
its stage cap is higher.

Set `skills` to an ordered list of skill identifiers when a stage requires reusable Codex workflows.
Runtime Settings store identifiers without `$`, for example `"to-prd"` or `"github:gh-fix-ci"`.
When a matching Stage Agent runs, Symphony renders those as `$to-prd` style references in the normal
Agent Prompt after the Stage Agent instructions and before the base Agent Prompt. It does not expand
skill files and does not include Stage Skill Load in Stage Goal Context. Missing, malformed, or
duplicate skill identifiers are Readiness Gaps; Symphony checks all configured stages before
dispatch, resolving Workspace Repository skills before Codex Home skills.

Rendered Agent Prompts include issue comments as issue context when the selected Issue Tracker
provides comments. minibeads Local Issue Tracker comments are not included in V1. Compozy-backed
Local Issue Tracker prompts include the current Compozy Task Step plus `_prd.md` and `_techspec.md`
from the same Compozy PRD Run when those files exist.

Set `goal.enabled` to `true` on a specific stage to allow Stage Goal Handoff for that stage only.
The selected Harness decides whether a loop command is actually sent. The Bootstrap default Codex
Harness has `loop.enabled: true` and `loop.command: "/goal"`, so Codex receives `/goal` with
deterministic Stage Goal Context before the normal Agent Prompt. The Bootstrap default Claude and PI
Harnesses have loop disabled, so those Harnesses run the normal prompt even when a stage has
`goal.enabled: true`. Stage Goal Context includes issue identifier, title, description, comments, URL,
current tracker status, labels, priority when present, blocker references when present,
attempt, and stage agent name. It omits issue creation and update timestamps.

Codex loop handoff requires a Codex command that accepts the configured Harness loop command from
standard input. For Codex goals, enable goals in `~/.codex/config.toml`:

```toml
[features]
goals = true
```

If a selected loop-enabled Codex Harness cannot accept the configured loop command, Symphony reports a
Readiness Gap. Goal Usage reported by Codex is stored in Runtime State for running, retrying, and
attention-needed task details when available; missing or unparseable Goal Usage does not fail a task.

Stage commits run after an agent exits successfully and before Symphony moves the issue to the
stage's `successStatus`. Set `commit.enabled` per stage to control which transitions create commits;
for example, keep `Backlog -> To-Do` uncommitted and commit `In progress -> In review`. The message
template supports `<type>`, `<generated_message_max_90char>`, `<issue_identifier>`, `<issue_title>`,
`<from_status>`, `<to_status>`, and `<agent>`. Set `commit.push` to `true` to push the current task
branch after a successful stage commit and before the status transition; omitted values default to
`false`.

## Git Policy

The Git Policy controls Task Branch naming, Protected Trunk Branches, auto-merge behavior, the Human
Attention Status used for merge problems, and cleanup of merged Agent Worktrees:

```json
{
  "git": {
    "taskBranchPrefix": "symphony/task-",
    "protectedTrunkBranches": ["main", "master"],
    "autoMerge": true,
    "mergeAttentionStatus": "Human attention",
    "cleanup": {
      "removeWorktreeAfterMerge": true,
      "keepTaskBranch": true
    }
  }
}
```

Each dispatched issue runs in an Agent Worktree under `.symphony/workspaces/` on a Task Branch
created from the Loop-Start Branch. Symphony may fast-forward a completed Task Branch into the
Loop-Start Branch only when the Loop-Start Branch is not a Protected Trunk Branch. It never
force-pushes, and Stage Push is disabled unless a stage sets `commit.push` to `true`.

## Batch Pull Requests

Symphony can optionally open one Batch Pull Request after Orchestration Idle, using the Loop-Start
Branch as the PR head. Automatic PR creation is disabled by default:

```json
{
  "pullRequest": {
    "enabled": false,
    "openOnReview": false,
    "baseBranch": "main",
    "title": "Symphony batch from <head_branch>",
    "body": "Opened automatically by Symphony after orchestration became idle."
  }
}
```

When `pullRequest.enabled` is `true`, `pullRequest.baseBranch` must be set explicitly. On an idle
poll, Symphony first performs a non-force Batch Branch Push of the Loop-Start Branch to `origin`,
then checks for an existing open PR with the same head/base pair before creating one with `gh`.
Failed pushes or PR creation attempts are recorded in Runtime State as retryable handoff failures and
are retried on later idle polls. Symphony does not attempt a Batch Pull Request while any issue is in
the configured Merge Attention Status or has unresolved orchestration attention.

Set `pullRequest.openOnReview` to `true` to open the same Batch Pull Request immediately after a
successful agent run has been committed, integrated into the Loop-Start Branch, and moved to the
configured review status. Later task integrations continue updating the same Loop-Start Branch and
the existing PR is reused.

The `title` and `body` fields are deterministic templates. They support `<head_branch>` and
`<base_branch>`; Symphony does not generate PR prose with an agent.

## GitHub Token Permissions

This section applies to the GitHub Tracker. Symphony Orchestrator reads GitHub Issues and GitHub
Projects when `tracker.kind` is `"github"`. Use a **personal access token (classic)** when the
GitHub Project is owned by a user account, such as `@your-user's Kanban`. GitHub fine-grained
personal access tokens currently cannot access Projects owned by a user account.

Recommended classic PAT scopes:

- `repo`: required for private Workspace Repositories and repository Issues.
- `read:project`: enough for readiness checks and read-only GitHub Project polling.
- `project`: required instead of `read:project` when Symphony will move GitHub Project items,
  update GitHub Project fields, or otherwise write GitHub Projects data.

Classic PATs do **not** ask you to select individual repositories or GitHub Projects. If GitHub
shows a repository picker, GitHub Project picker, "Resource owner", or "Repository access" section,
you are creating a fine-grained token. Go back to **Personal access tokens > Tokens (classic) >
Generate new token (classic)** for user-owned Projects.

Fine-grained PATs are only suitable when the GitHub Project is owned by an organization and GitHub
allows fine-grained tokens for that owner. Configure the token with:

- Resource owner: the organization that owns the Workspace Repository and GitHub Project.
- Repository access: select the Workspace Repository, or all repositories for that owner.
- Repository permissions: `Metadata: Read`, `Issues: Read and write`, and `Contents: Read`.
- Organization permissions: `Projects: Read and write`.

Store the token in the Workspace Repository Local Environment:

```sh
$EDITOR .symphony/.env
```

`GITHUB_TOKEN` takes precedence over `GH_TOKEN`. If `gh auth status` shows a working stored token but
Symphony still reports Workspace Repository or GitHub Project access gaps, remove the stale
`GITHUB_TOKEN` from `.symphony/.env` or replace it with a token that has the scopes above.

## Repository Layout

- `apps/backend`: OCaml service, workflow loader, GitHub tracker boundary, workspace manager, HTTP
  state API, CLI, and tests.
- `apps/frontend`: ReScript React/Vite dashboard that consumes the backend state API.
- `apps/tui`: reusable OCaml terminal UI toolkit packaged with Dune/opam as
  `symphony-orchestrator-tui`. Its
  `@symphony-orchestrator/tui` package.json is a private pnpm workspace label, not the publishing
  target.
- `.github/ISSUE_TEMPLATE`: issue template for work items Symphony can dispatch.
- `.github/project-tracking.md`: GitHub Tracker setup and workflow notes.
- `WORKFLOW.example.md`: legacy/developer fixture for the earlier root workflow format.
- `bin/symphony.js`: npm `bin` launcher that runs a packaged platform binary or the local dune
  executable in Product Repository development.

## Product Repository Development

Product Repository development is separate from Workspace Repository operation. Runtime files for
actual orchestration belong in the Workspace Repository where `symphony init` is run; this source
repository keeps code, tests, packaging scripts, fixtures, and documentation.

Product Repository development requires `pnpm` 10.x and an OCaml toolchain with `opam`, OCaml
`>= 5.1`, Dune `>= 3.19`, `cmdliner`, `yojson`, `alcotest`, the local `apps/tui` package, `uutf`,
and `toffee`. The local scripts run OCaml commands through `opam exec`, so make sure the active opam
switch has the required packages installed.

Install dependencies:

```sh
pnpm install
opam install . ./apps/tui --deps-only --with-test --yes
```

Run the backend test suite:

```sh
pnpm test
```

Run documentation validation:

```sh
pnpm docs:test
```

Run frontend live-state tests:

```sh
pnpm frontend:test
```

Build frontend assets:

```sh
pnpm frontend:build
```

Build the OCaml backend:

```sh
pnpm backend:build
```

Build the package payload:

```sh
pnpm prepack
```

`WORKFLOW.example.md` remains only as a legacy fixture/import compatibility file for earlier root
workflow behavior. Do not use it as the active Workspace Repository Runtime Contract.

## Run Locally

Start the backend dev server from the Product Repository root:

```sh
pnpm backend:dev
```

The backend serves:

- Backend/API root: `http://127.0.0.1:8080/`
- Runtime state JSON: `http://127.0.0.1:8080/api/v1/state`

The backend binds to `127.0.0.1` by default. To expose the Web Dashboard on Tailscale or a LAN,
set `"server": {"host": "0.0.0.0", "port": 8080}` in `.symphony/settings.json`; non-loopback
binds print a one-time `symphony_auth` URL token and require that token for Runtime State HTTP and
Live Dashboard Connection access.

Start the Web Dashboard dev server in another terminal:

```sh
pnpm frontend:dev
```

Open:

```text
http://127.0.0.1:5173/
```

The frontend proxies `/api/*` requests to the backend at `127.0.0.1:8080`.

A packaged or dune-run CLI can also start the backend and Web Dashboard from a Workspace Repository:

```sh
symphony --web --port 8080
```

## Useful Commands

```sh
pnpm install
pnpm test
pnpm docs:test
pnpm frontend:test
pnpm frontend:build
pnpm backend:build
pnpm prepack
pnpm backend:dev
pnpm frontend:dev
```

For direct Product Repository CLI checks:

```sh
opam exec -- dune exec symphony -- --once
opam exec -- dune exec symphony -- init
opam exec -- dune exec symphony -- --web --port 8080
```

If no GitHub token is configured for the GitHub Tracker, the runtime still starts, but readiness
gaps report the missing token and live issue dispatch is disabled. For Local Issue Tracker runs,
dispatch does not require a GitHub token; unresolved minibeads command or local issue store gaps, or
missing Compozy PRD Run task files, disable dispatch instead.

## Package Distribution

Published packages should include platform-specific binaries for Linux, macOS, and Windows:

- `vendor/symphony-linux-x64`
- `vendor/symphony-darwin-x64`
- `vendor/symphony-darwin-arm64`
- `vendor/symphony-win32-x64.exe`

When running from this Product Repository, the Node launcher falls back to:

```sh
opam exec -- dune exec symphony --
```

Before publishing, run:

```sh
pnpm npm:validate:release
```

The GitHub Actions `Export npm package` workflow builds those binaries on Linux, macOS, and Windows,
assembles the npm tarball, uploads the tarball and binaries as a GitHub workflow artifact, and
publishes the same files to a GitHub Release with the npm package URL. A `v*` tag uses that tag for
the release; manual runs publish a `v<package.json version>` release when `publish_npm` is enabled
and the repository has an `NPM_TOKEN` secret. The npm package is available at
https://www.npmjs.com/package/symphony-orchestrator.
