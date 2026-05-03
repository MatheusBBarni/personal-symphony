# Personal Symphony

Personal Symphony is a pnpm monorepo scaffold for the Symphony service described in
[Symphony SPEC](https://github.com/openai/symphony/blob/main/SPEC.md). The backend is OCaml, the
frontend is ReScript React, and the UI is styled with Tailwind.

This implementation variant targets GitHub Issues plus GitHub Projects for issue tracking.

## Repository Layout

- `apps/backend`: OCaml service, workflow loader, GitHub tracker boundary, workspace manager, HTTP
  state API, CLI, and tests.
- `apps/frontend`: ReScript React/Vite dashboard that consumes the backend state API.
- `.github/ISSUE_TEMPLATE`: issue template for work items Symphony can dispatch.
- `.github/project-tracking.md`: required GitHub Project setup and workflow notes.
- `WORKFLOW.example.md`: example repository-owned runtime contract.

## Prerequisites

- `pnpm` 10.x
- OCaml toolchain with `opam`, `dune`, `cmdliner`, `yojson`, and `alcotest`
- GitHub CLI: `gh`
- A GitHub token available as `GITHUB_TOKEN` or `GH_TOKEN`
- `codex` CLI available on `PATH` when running real agent sessions

The local scripts run OCaml commands through `opam exec`, so make sure the active opam switch has
the required packages installed.

## Set Up In A Repository

1. Install dependencies:

   ```sh
   pnpm install
   ```

2. Create a workflow file for the repository:

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
opam exec -- dune exec symphony -- --once WORKFLOW.md
opam exec -- dune exec symphony -- --port 8080 WORKFLOW.md
```

If no GitHub token is configured, the backend still starts and serves a runtime snapshot, but
`last_error` reports the missing token and live issue dispatch is disabled.
