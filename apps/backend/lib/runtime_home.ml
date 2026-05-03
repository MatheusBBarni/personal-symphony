type bootstrap_status = Created | Already_present | Skipped_existing

type bootstrap_item = { path : string; status : bootstrap_status }

type t = { workspace_root : string; runtime_dir : string; settings_path : string; prompt_path : string }

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
    "activeStates": ["Todo", "In Progress"],
    "terminalStates": ["Done", "Closed", "Cancelled"]
  },
  "polling": {
    "intervalMs": 30000
  },
  "workspace": {
    "root": ".symphony/workspaces"
  },
  "agent": {
    "maxConcurrentAgents": 2,
    "maxTurns": 10,
    "maxRetryBackoffMs": 300000
  },
  "codex": {
    "command": "codex app-server",
    "turnTimeoutMs": 3600000,
    "readTimeoutMs": 5000,
    "stallTimeoutMs": 300000
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

let bootstrap workspace_root =
  let home = paths workspace_root in
  let report = [] in
  let report = ensure_dir report home.runtime_dir in
  let report = ensure_file report home.settings_path settings_json in
  let report = ensure_file report home.prompt_path prompt_md in
  let report = ensure_file report (Filename.concat home.runtime_dir ".env.example") env_example in
  let report = ensure_file report (Filename.concat home.runtime_dir ".gitignore") gitignore in
  let report = ensure_file report (Filename.concat home.runtime_dir ".env") "" in
  let report = ensure_dir report (Filename.concat home.runtime_dir "state") in
  let report = ensure_dir report (Filename.concat home.runtime_dir "workspaces") in
  (home, List.rev report)

let load_prompt home =
  if not (Sys.file_exists home.prompt_path) then
    raise (Runtime_home_error ("missing runtime prompt: " ^ home.prompt_path));
  Util.read_file home.prompt_path |> Util.trim
