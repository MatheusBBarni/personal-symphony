type bootstrap_status = Created | Already_present | Skipped_existing

type bootstrap_item = { path : string; status : bootstrap_status }

type bootstrap_selected_harness = { name : string; kind : string }

type bootstrap_guidance =
  | Bootstrap_selected_harness of bootstrap_selected_harness
  | Bootstrap_no_usable_harness
  | Bootstrap_existing_settings_preserved

type t = {
  workspace_root : string;
  runtime_dir : string;
  settings_path : string;
  prompt_path : string;
  env_path : string;
  agents_dir : string;
}

type bootstrap_result = { home : t; report : bootstrap_item list; guidance : bootstrap_guidance }

exception Runtime_home_error of string

let runtime_dir_name = ".symphony"

let settings_json =
  {|{
  "tracker": {
    "kind": "github",
    "owner": "your-org",
    "repo": "your-repo",
    "projectNumber": 1,
    "apiKeyEnv": "GITHUB_TOKEN"
  },
  "project": {
    "statusField": "Status",
    "readyStatus": "Ready for Symphony",
    "activeStates": ["Backlog", "Todo", "To-Do", "In progress", "In Progress", "In review"],
    "terminalStates": ["Done", "Closed", "Cancelled"],
    "startStatus": "In progress",
    "reviewStatus": "In review",
    "retryStatus": "To-Do",
    "ensureStatuses": true
  },
  "polling": {
    "intervalMs": 30000
  },
  "workspace": {
    "root": ".symphony/workspaces"
  },
  "sandbox": {
    "enabled": false,
    "type": "docker",
    "image": "ghcr.io/your-org/symphony-agent:latest",
    "bootstrapCommands": [],
    "persistent": true,
    "networkEnabled": false,
    "cpuLimit": 2,
    "memoryMb": 4096
  },
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
    "cursor": {
      "kind": "cursor",
      "command": "cursor-agent -p --model <model> --output-format stream-json",
      "loop": {
        "enabled": false,
        "command": ""
      }
    },
    "cursor-force": {
      "kind": "cursor",
      "command": "cursor-agent -p --force --model <model> --output-format stream-json",
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
  "git": {
    "taskBranchPrefix": "symphony/task-",
    "protectedTrunkBranches": ["main", "master"],
    "autoMerge": true,
    "mergeAttentionStatus": "Human attention",
    "cleanup": {
      "removeWorktreeAfterMerge": true,
      "keepTaskBranch": true
    }
  },
  "pullRequest": {
    "enabled": false,
    "mode": "batch",
    "baseBranch": "main",
    "title": "Symphony batch from <head_branch>",
    "body": "Opened automatically by Symphony after orchestration became idle."
  },
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "defaultAgent": "engineer",
    "stages": [
      {
        "states": ["Backlog"],
        "agent": "planner",
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
  },
  "agent": {
    "maxConcurrentAgents": 2,
    "maxTurns": 10,
    "maxRetryBackoffMs": 300000
  },
  "server": {
    "port": 8080
  }
}
|}

let prompt_md =
  {|You are working on GitHub issue {{ issue.identifier }}: {{ issue.title }}.

Repository issue URL: {{ issue.url }}
Current project status: {{ issue.state }}
Attempt: {{ attempt }}

Use the repository-owned workflow policy, make focused changes, validate them, and hand off through
the project status expected by the team.
|}

let planner_agent_md =
  {|You are the Planner agent for Personal Symphony.

Your job is to turn a Backlog issue into an implementation-ready task.

Focus:
- Clarify the problem, acceptance criteria, risks, and likely files/modules.
- Prefer concise technical planning over implementation.
- Leave concrete next steps for the engineer.
- Do not make broad code changes unless they are necessary to make the task actionable.
|}

let engineer_agent_md =
  {|You are the Engineer agent for Personal Symphony.

You are a senior software engineer specializing in OCaml, ReScript, Rust, React, TypeScript, and JavaScript.

Principles:
- Use type-driven design and keep illegal states unrepresentable where practical.
- Keep a functional core with an imperative shell.
- Make focused production-quality changes.
- Run targeted verification and report what changed.
- Avoid unrelated refactors.
|}

let reviewer_agent_md =
  {|You are the Code Reviewer agent for Personal Symphony.

You are a tech lead reviewing completed work before it moves to Done.

Review focus:
- Correctness, regressions, missing tests, race conditions, and edge cases.
- OCaml/ReScript type soundness and clear module boundaries.
- React/TypeScript state, rendering, accessibility, and maintainability.
- Provide actionable findings first. If no blocking issues remain, say so clearly.
|}

let env_example = "GITHUB_TOKEN=\n"
let gitignore = "/.env\n/state/\n/workspaces/\n"

let current_dir () = Unix.getcwd () |> Unix.realpath

let read_first_line ic =
  try Some (input_line ic |> Util.trim) with End_of_file -> None

let git_root () =
  let ic = Unix.open_process_in "git rev-parse --show-toplevel 2>/dev/null" in
  let line = read_first_line ic in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Option.map Unix.realpath line
  | _ -> None

let require_workspace_root () =
  match git_root () with
  | None ->
      Error
        "symphony must be run from the root of a Git Workspace Repository; this directory is not inside a Git repository"
  | Some root ->
      let cwd = current_dir () in
      if cwd = root then Ok root
      else
        Error
          (Printf.sprintf
             "symphony must be run from the root of a Git Workspace Repository; current directory is %s but repository root is %s"
             cwd root)

let paths workspace_root =
  let runtime_dir = Filename.concat workspace_root runtime_dir_name in
  {
    workspace_root;
    runtime_dir;
    settings_path = Filename.concat runtime_dir "settings.json";
    prompt_path = Filename.concat runtime_dir "prompt.md";
    env_path = Filename.concat runtime_dir ".env";
    agents_dir = Filename.concat runtime_dir "agents";
  }

let status_to_string = function
  | Created -> "created"
  | Already_present -> "already_present"
  | Skipped_existing -> "skipped_existing"

let ensure_dir report path =
  if Sys.file_exists path then
    if Sys.is_directory path then { path; status = Already_present } :: report
    else raise (Runtime_home_error (path ^ " exists and is not a directory"))
  else (
    Util.mkdir_p path;
    { path; status = Created } :: report)

let ensure_file report path content =
  if Sys.file_exists path then { path; status = Skipped_existing } :: report
  else (
    Util.write_file path content;
    { path; status = Created } :: report)

let bootstrap_probe_harness (definition : Bootstrap_harness_detection.harness_definition) =
  {
    Config.name = definition.Bootstrap_harness_detection.name;
    kind = definition.Bootstrap_harness_detection.kind;
    command = definition.Bootstrap_harness_detection.executable;
    model = Config.default_model;
    reasoning_effort = Config.default_reasoning_effort;
    turn_timeout_ms = 3600000;
    read_timeout_ms = 5000;
    stall_timeout_ms = 300000;
    loop_enabled = false;
    loop_command = "";
  }

let default_bootstrap_probe : Bootstrap_harness_detection.probe =
  {
    executable_available = Config.executable_available;
    auth_signal =
      (fun (definition : Bootstrap_harness_detection.harness_definition) ->
        match definition.Bootstrap_harness_detection.name with
        | "claude" ->
            if Config.claude_env_auth_configured () || Config.claude_credentials_configured () then
              Bootstrap_harness_detection.Authenticated
            else Bootstrap_harness_detection.Auth_missing
        | "pi" ->
            if Config.pi_any_auth_configured () || Config.pi_any_env_configured () then
              Bootstrap_harness_detection.Authenticated
            else Bootstrap_harness_detection.Auth_missing
        | _ -> Bootstrap_harness_detection.Auth_not_checked);
    status_signal =
      (fun (definition : Bootstrap_harness_detection.harness_definition) ->
        match definition.Bootstrap_harness_detection.name with
        | "cursor" | "cursor-force" ->
            if
              Config.executable_available definition.Bootstrap_harness_detection.executable
              && Config.cursor_harness_auth_configured (bootstrap_probe_harness definition)
            then
              Bootstrap_harness_detection.Status_succeeded
            else Bootstrap_harness_detection.Status_failed
        | _ -> Bootstrap_harness_detection.Status_not_checked);
  }

let bootstrap_guidance_of_detection (detection : Bootstrap_harness_detection.detection_result) =
  match detection.Bootstrap_harness_detection.selected with
  | Some status ->
      Bootstrap_selected_harness
        { name = status.Bootstrap_harness_detection.name; kind = status.Bootstrap_harness_detection.kind }
  | None -> Bootstrap_no_usable_harness

let bootstrap_with_guidance ?(probe = default_bootstrap_probe) workspace_root =
  let home = paths workspace_root in
  let settings_exists = Sys.file_exists home.settings_path in
  let settings_content, guidance =
    if settings_exists then (settings_json, Bootstrap_existing_settings_preserved)
    else
      let detection = Bootstrap_harness_detection.detect ~probe () in
      (Bootstrap_settings.to_string detection, bootstrap_guidance_of_detection detection)
  in
  let report = [] in
  let report = ensure_dir report home.runtime_dir in
  let report = ensure_file report home.settings_path settings_content in
  let report = ensure_file report home.prompt_path prompt_md in
  let report = ensure_file report (Filename.concat home.runtime_dir ".env.example") env_example in
  let report = ensure_file report (Filename.concat home.runtime_dir ".gitignore") gitignore in
  let report = ensure_file report home.env_path "" in
  let report = ensure_dir report (Filename.concat home.runtime_dir "state") in
  let report = ensure_dir report (Filename.concat home.runtime_dir "workspaces") in
  let report = ensure_dir report home.agents_dir in
  let report = ensure_file report (Filename.concat home.agents_dir "planner.md") planner_agent_md in
  let report = ensure_file report (Filename.concat home.agents_dir "engineer.md") engineer_agent_md in
  let report = ensure_file report (Filename.concat home.agents_dir "reviewer.md") reviewer_agent_md in
  { home; report = List.rev report; guidance }

let bootstrap workspace_root =
  let result = bootstrap_with_guidance workspace_root in
  (result.home, result.report)

let is_env_name name =
  let valid_char = function 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' -> true | _ -> false in
  String.length name > 0
  && (match name.[0] with 'A' .. 'Z' | 'a' .. 'z' | '_' -> true | _ -> false)
  && String.for_all valid_char name

let strip_matching_quotes value =
  let len = String.length value in
  if len >= 2 then
    match (value.[0], value.[len - 1]) with
    | '"', '"' | '\'', '\'' -> String.sub value 1 (len - 2)
    | _ -> value
  else value

let parse_env_line line =
  let line = Util.trim line in
  if line = "" || Util.starts_with ~prefix:"#" line then None
  else
    let line =
      match Util.drop_prefix ~prefix:"export " line with
      | Some rest -> Util.trim rest
      | None -> line
    in
    match String.index_opt line '=' with
    | None -> None
    | Some idx ->
        let name = String.sub line 0 idx |> Util.trim in
        let value = String.sub line (idx + 1) (String.length line - idx - 1) |> Util.trim |> strip_matching_quotes in
        if is_env_name name then Some (name, value) else None

let load_env home =
  if Sys.file_exists home.env_path then
    Util.read_file home.env_path |> Util.split_lines
    |> List.iter (fun line ->
           match parse_env_line line with
           | Some (name, value) when Util.getenv_nonempty name = None -> Unix.putenv name value
           | _ -> ())

let load_prompt home =
  if not (Sys.file_exists home.prompt_path) then
    raise (Runtime_home_error ("missing runtime prompt: " ^ home.prompt_path));
  Util.read_file home.prompt_path |> Util.trim
