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

**Agent Prompt**:
The `prompt.md` portion of the Runtime Contract that defines the task instructions rendered for each dispatched issue.
_Avoid_: prompt template, workflow body

**Runtime State**:
The ignored files inside the Runtime Home that record current orchestration activity and recovery data.
_Avoid_: state files, generated data

**Readiness Gap**:
A missing or invalid runtime requirement that prevents Personal Symphony from dispatching work.
_Avoid_: setup error, config problem

**Terminal Console**:
The default terminal interface for operating Personal Symphony in a Workspace Repository.
_Avoid_: TUI, terminal UI

**Web Dashboard**:
The optional browser interface for operating Personal Symphony in a Workspace Repository.
_Avoid_: web server, front-end

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
- The **Local Environment**, **Runtime State**, and **Agent Workspaces** are ignored by version control.
- The **Runtime Contract** is version-controlled with the Workspace Repository.
- A **Readiness Gap** prevents dispatch but does not prevent the TUI from starting.
- Personal Symphony starts the **Terminal Console** by default.
- Personal Symphony starts the **Web Dashboard** when requested with `--web`.
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
> **Dev:** "Does the web flag start the terminal interface too?"
> **Domain expert:** "No, `--web` switches from the **Terminal Console** to the **Web Dashboard**, with terminal output limited to operational status."

## Flagged Ambiguities

- "project" was used to mean both the Personal Symphony source repository and the user's repository; resolved: use **Product Repository** for this repo and **Workspace Repository** for the repository where the CLI runs.
