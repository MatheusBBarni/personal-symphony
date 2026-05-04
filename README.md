# Personal Symphony

Personal Symphony is an installable `symphony` CLI for the Symphony service described in
[Symphony SPEC](https://github.com/openai/symphony/blob/main/SPEC.md). The product repository keeps
the OCaml backend, the ReScript React dashboard, and the npm launcher; each workspace repository gets
its own repository-owned runtime contract under `.symphony/`.

This implementation variant targets GitHub Issues plus GitHub Projects for issue tracking.

## Repository Layout

- `apps/backend`: OCaml service, workflow loader, GitHub tracker boundary, workspace manager, HTTP
  state API, CLI, and tests.
- `apps/frontend`: ReScript React/Vite dashboard that consumes the backend state API.
- `.github/ISSUE_TEMPLATE`: issue template for work items Symphony can dispatch.
- `.github/project-tracking.md`: required GitHub Project setup and workflow notes.
- `WORKFLOW.example.md`: legacy/developer fixture for the earlier root workflow format.
- `bin/symphony.js`: npm `bin` launcher that runs a packaged platform binary or the local dune
  executable in product-repository development.

## Prerequisites

- `pnpm` 10.x
- OCaml toolchain with `opam`, `dune`, `cmdliner`, `yojson`, and `alcotest` for product-repository
  development only
- GitHub CLI: `gh`
- A GitHub personal access token available as `GITHUB_TOKEN` or `GH_TOKEN`
- `codex` CLI available on `PATH` when running real agent sessions

The local scripts run OCaml commands through `opam exec`, so make sure the active opam switch has
the required packages installed.

## Install

The npm package exposes a global `symphony` command:

```sh
npm install -g symphony-orchestrator
```

Published packages should include platform-specific binaries for Linux, macOS, and Windows:

- `vendor/symphony-linux-x64`
- `vendor/symphony-darwin-x64`
- `vendor/symphony-darwin-arm64`
- `vendor/symphony-win32-x64.exe`

When running from this product repository, the Node launcher falls back to:

```sh
opam exec -- dune exec symphony --
```

Before publishing, run:

```sh
pnpm npm:validate:release
```

The GitHub Actions `Export npm package` workflow builds those binaries on Linux, macOS, and Windows,
assembles the npm tarball, uploads the tarball and binaries as a GitHub workflow artifact, and uploads
the same files to a GitHub Release when run from a `v*` tag. Manual runs can publish to npm when
`publish_npm` is enabled and the repository has an `NPM_TOKEN` secret.

## Set Up In A Workspace Repository

Run the command from the root of a Git repository:

```sh
symphony init
symphony
```

`symphony init` and the first `symphony` run are idempotent. They create missing runtime files under
`.symphony/` without overwriting user-edited files:

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

Edit `.symphony/settings.json` to set the GitHub owner, repository, project number, project states,
and runtime commands. Secrets are referenced by environment variable name, not stored in settings:

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

Set `goal.enabled` to `true` on a specific stage to enable Stage Goal Handoff for that stage only.
When enabled, Symphony sends `/goal` with deterministic Stage Goal Context before the normal Agent
Prompt. Stage Goal Context includes issue identifier, title, description, URL, current project
status, labels, priority when present, blocker references when present, attempt, and stage agent
name. It omits issue creation and update timestamps.

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

## Batch Pull Requests

Symphony can optionally open one Batch Pull Request after Orchestration Idle, using the Loop-Start
Branch as the PR head. Automatic PR creation is disabled by default:

```json
{
  "pullRequest": {
    "enabled": false,
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

The `title` and `body` fields are deterministic templates. They support `<head_branch>` and
`<base_branch>`; Symphony does not generate PR prose with an agent.

## GitHub Token Permissions

Personal Symphony reads GitHub Issues and GitHub Projects. Use a **personal access token (classic)**
when the GitHub Project is owned by a user account, such as `@your-user's Kanban`. GitHub
fine-grained personal access tokens currently cannot access Projects owned by a user account.

Recommended classic PAT scopes:

- `repo`: required for private Workspace Repositories and repository Issues.
- `read:project`: enough for readiness checks and read-only project polling.
- `project`: required instead of `read:project` when Symphony will move project cards, update
  project fields, or otherwise write GitHub Projects data.

Classic PATs do **not** ask you to select individual repositories or projects. If GitHub shows a
repository picker, project picker, "Resource owner", or "Repository access" section, you are creating
a fine-grained token. Go back to **Personal access tokens > Tokens (classic) > Generate new token
(classic)** for user-owned Projects.

Fine-grained PATs are only suitable when the GitHub Project is owned by an organization and GitHub
allows fine-grained tokens for that owner. Configure the token with:

- Resource owner: the organization that owns the Workspace Repository and GitHub Project.
- Repository access: select the Workspace Repository, or all repositories for that owner.
- Repository permissions: `Metadata: Read`, `Issues: Read and write`, and `Contents: Read`.
- Organization permissions: `Projects: Read and write`.

Store the token in the Workspace Repository Local Environment:

```sh
printf 'GITHUB_TOKEN=github_pat_...\n' > .symphony/.env
```

`GITHUB_TOKEN` takes precedence over `GH_TOKEN`. If `gh auth status` shows a working stored token but
Symphony still reports repository or project access gaps, remove the stale `GITHUB_TOKEN` from
`.symphony/.env` or replace it with a token that has the scopes above.

## Product Repository Development

1. Install dependencies:

   ```sh
   pnpm install
   ```

2. Optionally create a legacy workflow file for product-repository fixture runs:

   ```sh
   cp WORKFLOW.example.md WORKFLOW.md
   ```

3. Edit `WORKFLOW.md`:

   ```yaml
   tracker:
     kind: github
     owner: your-org
     repo: your-repo
     project_number: 1
     api_key: $GITHUB_TOKEN
     active_states: [Todo, In Progress]
     terminal_states: [Done, Closed, Cancelled]
     project_status_field: Status
     project_status_on_dispatch: In progress
     project_status_on_success: In review
     project_status_on_retry: Todo
   codex:
     command: codex exec
     model: gpt-5.5
     reasoning_effort: medium
   ```

4. Configure the GitHub Project:

   - Add a single-select `Status` field.
   - Add active values matching `active_states`, usually `Todo` and `In Progress`.
   - Add terminal values matching `terminal_states`, usually `Done`, `Closed`, and `Cancelled`.
   - Add or let Symphony create transition values such as `In progress` and `In review`.
   - Add repository issues to the project before expecting Symphony to pick them up.

5. Authenticate GitHub access:

   ```sh
   gh auth status
   export GITHUB_TOKEN=...
   ```

   See "GitHub Token Permissions" above for the exact PAT scopes and fine-grained permissions.

## Run Locally

Validate and build everything:

```sh
pnpm test
pnpm build
```

Start the OCaml backend:

```sh
pnpm backend:dev
```

The backend serves:

- Dashboard placeholder/API root: `http://127.0.0.1:8080/`
- Runtime state JSON: `http://127.0.0.1:8080/api/v1/state`
- Tailscale/LAN access: `http://<machine-ip>:8080/` because the backend binds to `0.0.0.0`.

Start the ReScript React frontend in another terminal:

```sh
pnpm frontend:dev
```

Open:

```text
http://127.0.0.1:5173/
```

The frontend proxies `/api/*` requests to the backend at `127.0.0.1:8080`.

## Useful Commands

```sh
pnpm backend:build
pnpm backend:test
pnpm frontend:build
opam exec -- dune exec symphony -- --once
opam exec -- dune exec symphony -- init
opam exec -- dune exec symphony -- --web --port 8080
opam exec -- dune exec symphony -- --once WORKFLOW.md
```

If no GitHub token is configured, the runtime still starts, but readiness gaps report the missing
token and live issue dispatch is disabled.
