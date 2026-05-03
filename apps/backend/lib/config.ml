type tracker = {
  kind : string;
  owner : string;
  repo : string;
  project_number : int;
  api_key : string option;
  active_states : string list;
  terminal_states : string list;
  project_status_field : string;
}

type polling = { interval_ms : int }
type workspace = { root : string }
type agent = { max_concurrent_agents : int; max_turns : int; max_retry_backoff_ms : int }
type codex = { command : string; turn_timeout_ms : int; read_timeout_ms : int; stall_timeout_ms : int }
type server = { port : int option }

type t = {
  workflow_path : string;
  tracker : tracker;
  polling : polling;
  workspace : workspace;
  agent : agent;
  codex : codex;
  server : server;
}

exception Invalid_config of string

let default_active_states = [ "Todo"; "In Progress" ]
let default_terminal_states = [ "Done"; "Closed"; "Cancelled"; "Canceled"; "Duplicate" ]

let resolve_secret = function
  | None -> None
  | Some s -> (
      match Util.drop_prefix ~prefix:"$" s with
      | Some var -> Util.getenv_nonempty var
      | None when s <> "" -> Some s
      | _ -> None)

let expand_path ~base_dir path =
  let path =
    match Util.drop_prefix ~prefix:"~/" path with
    | Some suffix -> Filename.concat (Sys.getenv "HOME") suffix
    | None -> (
        match Util.drop_prefix ~prefix:"$" path with Some var -> Option.value (Util.getenv_nonempty var) ~default:path | None -> path)
  in
  let path = if Filename.is_relative path then Filename.concat base_dir path else path in
  Unix.realpath (if Sys.file_exists path then path else Filename.dirname path) |> fun real_parent ->
  if Sys.file_exists path then Unix.realpath path else Filename.concat real_parent (Filename.basename path)

let positive name value =
  if value <= 0 then raise (Invalid_config (name ^ " must be positive"));
  value

let from_workflow workflow =
  let root = workflow.Workflow.config in
  let tracker_raw = Simple_yaml.get_map "tracker" root in
  let polling_raw = Simple_yaml.get_map "polling" root in
  let workspace_raw = Simple_yaml.get_map "workspace" root in
  let agent_raw = Simple_yaml.get_map "agent" root in
  let codex_raw = Simple_yaml.get_map "codex" root in
  let server_raw = Simple_yaml.get_map "server" root in
  let kind = Option.value (Simple_yaml.get_string "kind" tracker_raw) ~default:"" in
  if kind <> "github" then raise (Invalid_config "tracker.kind must be github for this implementation");
  let required_string name =
    match Simple_yaml.get_string name tracker_raw with
    | Some s when Util.trim s <> "" -> s
    | _ -> raise (Invalid_config ("tracker." ^ name ^ " is required"))
  in
  let owner = required_string "owner" in
  let repo = required_string "repo" in
  let project_number =
    match Simple_yaml.get_int "project_number" tracker_raw with
    | Some i when i > 0 -> i
    | _ -> raise (Invalid_config "tracker.project_number is required")
  in
  let api_key =
    match Simple_yaml.get_string "api_key" tracker_raw |> resolve_secret with
    | Some _ as token -> token
    | None -> (
        match Util.getenv_nonempty "GITHUB_TOKEN" with
        | Some _ as token -> token
        | None -> Util.getenv_nonempty "GH_TOKEN")
  in
  let active_states =
    match Simple_yaml.get_list "active_states" tracker_raw with [] -> default_active_states | states -> states
  in
  let terminal_states =
    match Simple_yaml.get_list "terminal_states" tracker_raw with [] -> default_terminal_states | states -> states
  in
  let workspace_root =
    Simple_yaml.get_string "root" workspace_raw
    |> Option.value ~default:(Filename.concat (Filename.get_temp_dir_name ()) "symphony_workspaces")
    |> expand_path ~base_dir:workflow.dir
  in
  {
    workflow_path = workflow.path;
    tracker =
      {
        kind;
        owner;
        repo;
        project_number;
        api_key;
        active_states;
        terminal_states;
        project_status_field = Option.value (Simple_yaml.get_string "project_status_field" tracker_raw) ~default:"Status";
      };
    polling = { interval_ms = positive "polling.interval_ms" (Option.value (Simple_yaml.get_int "interval_ms" polling_raw) ~default:30000) };
    workspace = { root = workspace_root };
    agent =
      {
        max_concurrent_agents =
          positive "agent.max_concurrent_agents" (Option.value (Simple_yaml.get_int "max_concurrent_agents" agent_raw) ~default:10);
        max_turns = positive "agent.max_turns" (Option.value (Simple_yaml.get_int "max_turns" agent_raw) ~default:20);
        max_retry_backoff_ms =
          positive "agent.max_retry_backoff_ms" (Option.value (Simple_yaml.get_int "max_retry_backoff_ms" agent_raw) ~default:300000);
      };
    codex =
      {
        command = Option.value (Simple_yaml.get_string "command" codex_raw) ~default:"codex app-server";
        turn_timeout_ms = Option.value (Simple_yaml.get_int "turn_timeout_ms" codex_raw) ~default:3600000;
        read_timeout_ms = Option.value (Simple_yaml.get_int "read_timeout_ms" codex_raw) ~default:5000;
        stall_timeout_ms = Option.value (Simple_yaml.get_int "stall_timeout_ms" codex_raw) ~default:300000;
      };
    server = { port = Simple_yaml.get_int "port" server_raw };
  }

let validate_for_dispatch config =
  if config.tracker.api_key = None then Error "missing GitHub token (set GITHUB_TOKEN or tracker.api_key)"
  else if Util.trim config.codex.command = "" then Error "codex.command must be present"
  else Ok ()
