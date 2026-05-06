# Symphony Orchestrator

Symphony Orchestrator is an installable `symphony` CLI for the Symphony service described in
[Symphony SPEC](https://github.com/openai/symphony/blob/main/SPEC.md). The Product Repository keeps
the OCaml backend, the ReScript React dashboard, and the npm launcher; each Workspace Repository gets
its own repository-owned Runtime Contract under `.symphony/`.

## Prerequisites

- GitHub CLI: `gh`
- A GitHub personal access token available as `GITHUB_TOKEN` or `GH_TOKEN`
- `codex` CLI available on `PATH` when running real agent sessions

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

Edit `.symphony/settings.json` to set the GitHub owner, Workspace Repository name, GitHub Project
number, GitHub Project states, and runtime commands. Runtime Settings reference secrets by environment
variable name; secret values belong only in the Local Environment:

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

Choose the Codex model and reasoning effort in the same file. If omitted, Symphony uses `gpt-5.5`
with `medium` reasoning:

```json
{
  "codex": {
    "command": "codex exec",
    "model": "gpt-5.5",
    "reasoningEffort": "medium"
  }
}
```

If setup is incomplete, the Terminal Console still starts and prints Readiness Gaps with remediation
steps. Dispatch remains disabled until those gaps are resolved.

## Project Status Workflow

Symphony moves the configured GitHub Projects `Status` field as work progresses:

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

Rendered Agent Prompts include GitHub issue comments as issue context in addition to the issue body.

Set `goal.enabled` to `true` on a specific stage to enable Stage Goal Handoff for that stage only.
When enabled, Symphony sends `/goal` with deterministic Stage Goal Context before the normal Agent
Prompt. Stage Goal Context includes issue identifier, title, description, comments, URL, current
GitHub Project status, labels, priority when present, blocker references when present, attempt, and
stage agent name. It omits issue creation and update timestamps.

Stage Goal Handoff requires Codex goals in `~/.codex/config.toml`:

```toml
[features]
goals = true
```

If a stage enables goal handoff but Codex goals are not enabled, Symphony reports a Readiness Gap.
Goal Usage reported by Codex is stored in Runtime State for running, retrying, and attention-needed
task details when available; missing or unparseable Goal Usage does not fail a task.

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

Symphony Orchestrator reads GitHub Issues and GitHub Projects. Use a **personal access token (classic)**
when the GitHub Project is owned by a user account, such as `@your-user's Kanban`. GitHub
fine-grained personal access tokens currently cannot access Projects owned by a user account.

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
- `.github/ISSUE_TEMPLATE`: issue template for work items Symphony can dispatch.
- `.github/project-tracking.md`: required GitHub Project setup and workflow notes.
- `WORKFLOW.example.md`: legacy/developer fixture for the earlier root workflow format.
- `bin/symphony.js`: npm `bin` launcher that runs a packaged platform binary or the local dune
  executable in Product Repository development.

## Product Repository Development

Product Repository development is separate from Workspace Repository operation. Runtime files for
actual orchestration belong in the Workspace Repository where `symphony init` is run; this source
repository keeps code, tests, packaging scripts, fixtures, and documentation.

Product Repository development requires `pnpm` 10.x and an OCaml toolchain with `opam`, `dune`,
`cmdliner`, `yojson`, and `alcotest`. The local scripts run OCaml commands through `opam exec`, so
make sure the active opam switch has the required packages installed.

Install dependencies:

```sh
pnpm install
```

Run the backend test suite:

```sh
pnpm test
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

- Terminal Console/API root: `http://127.0.0.1:8080/`
- Runtime state JSON: `http://127.0.0.1:8080/api/v1/state`
- Tailscale/LAN access: `http://<machine-ip>:8080/` because the backend binds to `0.0.0.0`.

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

If no GitHub token is configured, the runtime still starts, but readiness gaps report the missing
token and live issue dispatch is disabled.

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
