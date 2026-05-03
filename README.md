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
- A GitHub token available as `GITHUB_TOKEN` or `GH_TOKEN`
- `codex` CLI available on `PATH` when running real agent sessions

The local scripts run OCaml commands through `opam exec`, so make sure the active opam switch has
the required packages installed.

## Install

The npm package exposes a global `symphony` command:

```sh
npm install -g personal-symphony
```

Published packages should include a platform-specific binary at `vendor/symphony-<platform>-<arch>`.
When running from this product repository, the Node launcher falls back to:

```sh
opam exec -- dune exec symphony --
```

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

If setup is incomplete, the Terminal Console still starts and prints Readiness Gaps with remediation
steps. Dispatch remains disabled until those gaps are resolved.

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
   ```

4. Configure the GitHub Project:

   - Add a single-select `Status` field.
   - Add active values matching `active_states`, usually `Todo` and `In Progress`.
   - Add terminal values matching `terminal_states`, usually `Done`, `Closed`, and `Cancelled`.
   - Add repository issues to the project before expecting Symphony to pick them up.

5. Authenticate GitHub access:

   ```sh
   gh auth status
   export GITHUB_TOKEN=...
   ```

   The token needs read access to repository issues and project item metadata. If the agent will
   update issues or project fields, its runtime credentials need matching write access.

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
