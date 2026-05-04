type tracker = {
  kind : string;
  owner : string;
  repo : string;
  project_number : int;
  api_key_env : string;
  api_key : string option;
  active_states : string list;
  terminal_states : string list;
  project_status_field : string;
  project_status_on_dispatch : string option;
  project_status_on_success : string option;
  project_status_on_retry : string option;
  ensure_project_statuses : bool;
}

type polling = { interval_ms : int }
type workspace = { root : string }
type agent = { max_concurrent_agents : int; max_turns : int; max_retry_backoff_ms : int }
type codex = {
  command : string;
  model : string;
  reasoning_effort : string;
  turn_timeout_ms : int;
  read_timeout_ms : int;
  stall_timeout_ms : int;
}
type server = { port : int option }
type stage_commit = { enabled : bool; commit_type : string; message : string }
type stage_agent = {
  states : string list;
  agent : string;
  start_status : string option;
  success_status : string option;
  retry_status : string option;
  commit : stage_commit option;
}

type stage_agents = { enabled : bool; root : string; default_agent : string option; stages : stage_agent list }

type t = {
  workflow_path : string;
  repository_root : string;
  tracker : tracker;
  polling : polling;
  workspace : workspace;
  agent : agent;
  codex : codex;
  server : server;
  stage_agents : stage_agents;
}

type readiness_gap = { requirement : string; remediation : string }

exception Invalid_config of string

let default_active_states = [ "To-Do"; "Todo"; "In Progress" ]
let default_terminal_states = [ "Done"; "Closed"; "Cancelled"; "Canceled"; "Duplicate" ]
let default_dispatch_status = "In progress"
let default_review_status = "In review"
let default_retry_status = "To-Do"
let default_commit_message = "<type>: <generated_message_max_90char>"
let default_model = "gpt-5.5"
let default_reasoning_effort = "medium"
let default_codex_command = "codex exec"

let normalize_codex_command command =
  if Util.trim command = "codex app-server" then default_codex_command else command

let default_stage_agents =
  [
    {
      states = [ "Backlog" ];
      agent = "planner";
      start_status = None;
      success_status = Some "To-Do";
      retry_status = Some "Backlog";
      commit = Some { enabled = false; commit_type = "feature"; message = default_commit_message };
    };
    {
      states = [ "Todo"; "To-Do"; "In progress"; "In Progress" ];
      agent = "engineer";
      start_status = Some "In progress";
      success_status = Some "In review";
      retry_status = Some "To-Do";
      commit = Some { enabled = true; commit_type = "feature"; message = default_commit_message };
    };
    {
      states = [ "In review"; "In Review" ];
      agent = "reviewer";
      start_status = None;
      success_status = Some "Done";
      retry_status = Some "In progress";
      commit = Some { enabled = false; commit_type = "refactor"; message = default_commit_message };
    };
  ]

let resolve_secret = function
  | None -> None
  | Some s -> (
      match Util.drop_prefix ~prefix:"$" s with
      | Some var -> Util.getenv_nonempty var
      | None when s <> "" -> Some s
      | _ -> None)

let resolve_env_secret env_name =
  match Util.getenv_nonempty env_name with
  | Some _ as token -> token
  | None -> if env_name = "GITHUB_TOKEN" then Util.getenv_nonempty "GH_TOKEN" else None

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
    repository_root = workflow.dir;
    tracker =
      {
        kind;
        owner;
        repo;
        project_number;
        api_key_env = "GITHUB_TOKEN";
        api_key;
        active_states;
        terminal_states;
        project_status_field = Option.value (Simple_yaml.get_string "project_status_field" tracker_raw) ~default:"Status";
        project_status_on_dispatch =
          Some (Option.value (Simple_yaml.get_string "project_status_on_dispatch" tracker_raw) ~default:default_dispatch_status);
        project_status_on_success =
          Some (Option.value (Simple_yaml.get_string "project_status_on_success" tracker_raw) ~default:default_review_status);
        project_status_on_retry =
          Some (Option.value (Simple_yaml.get_string "project_status_on_retry" tracker_raw) ~default:default_retry_status);
        ensure_project_statuses = true;
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
        command =
          Option.value (Simple_yaml.get_string "command" codex_raw) ~default:default_codex_command |> normalize_codex_command;
        model = Option.value (Simple_yaml.get_string "model" codex_raw) ~default:default_model;
        reasoning_effort =
          Option.value (Simple_yaml.get_string "reasoning_effort" codex_raw) ~default:default_reasoning_effort;
        turn_timeout_ms = Option.value (Simple_yaml.get_int "turn_timeout_ms" codex_raw) ~default:3600000;
        read_timeout_ms = Option.value (Simple_yaml.get_int "read_timeout_ms" codex_raw) ~default:5000;
        stall_timeout_ms = Option.value (Simple_yaml.get_int "stall_timeout_ms" codex_raw) ~default:300000;
      };
    server = { port = Simple_yaml.get_int "port" server_raw };
    stage_agents = { enabled = false; root = Filename.concat workflow.dir ".symphony/agents"; default_agent = None; stages = [] };
  }

let member name = function
  | `Assoc fields -> List.assoc_opt name fields |> Option.value ~default:`Null
  | _ -> `Null

let json_string name json ~default =
  match member name json with `String s -> s | `Int i -> string_of_int i | _ -> default

let json_int name json ~default =
  match member name json with `Int i -> i | `String s -> Option.value (int_of_string_opt s) ~default | _ -> default

let json_string_list name json ~default =
  match member name json with
  | `List values ->
      values
      |> List.filter_map (function `String s -> Some s | `Int i -> Some (string_of_int i) | _ -> None)
  | _ -> default

let json_bool name json ~default =
  match member name json with `Bool b -> b | `String "true" -> true | `String "false" -> false | _ -> default

let json_optional_string name json =
  match member name json with `String s when Util.trim s <> "" -> Some s | _ -> None

let json_object_list name json =
  match member name json with `List values -> values | _ -> []

let json_stage_agent json =
  let commit_raw = member "commit" json in
  let commit =
    match commit_raw with
    | `Assoc _ ->
        Some
          {
            enabled = json_bool "enabled" commit_raw ~default:false;
            commit_type = json_string "type" commit_raw ~default:"feature";
            message = json_string "message" commit_raw ~default:default_commit_message;
          }
    | _ -> None
  in
  {
    states = json_string_list "states" json ~default:[];
    agent = json_string "agent" json ~default:"";
    start_status = json_optional_string "startStatus" json;
    success_status = json_optional_string "successStatus" json;
    retry_status = json_optional_string "retryStatus" json;
    commit;
  }

let from_settings_file ~workspace_root path =
  let root =
    try Yojson.Safe.from_file path
    with Yojson.Json_error msg -> raise (Invalid_config ("settings.json parse error: " ^ msg))
  in
  let tracker_raw = member "tracker" root in
  let project_raw = member "project" root in
  let polling_raw = member "polling" root in
  let workspace_raw = member "workspace" root in
  let agent_raw = member "agent" root in
  let codex_raw = member "codex" root in
  let server_raw = member "server" root in
  let stage_agents_raw = member "stageAgents" root in
  let kind = json_string "kind" tracker_raw ~default:"github" in
  if kind <> "github" then raise (Invalid_config "tracker.kind must be github for this implementation");
  let api_key_env = json_string "apiKeyEnv" tracker_raw ~default:"GITHUB_TOKEN" in
  let workspace_root_value =
    json_string "root" workspace_raw ~default:".symphony/workspaces" |> expand_path ~base_dir:workspace_root
  in
  {
    workflow_path = path;
    repository_root = workspace_root;
    tracker =
      {
        kind;
        owner = json_string "owner" tracker_raw ~default:"";
        repo = json_string "repo" tracker_raw ~default:"";
        project_number = json_int "projectNumber" tracker_raw ~default:0;
        api_key_env;
        api_key = resolve_env_secret api_key_env;
        active_states = json_string_list "activeStates" project_raw ~default:default_active_states;
        terminal_states = json_string_list "terminalStates" project_raw ~default:default_terminal_states;
        project_status_field = json_string "statusField" project_raw ~default:"Status";
        project_status_on_dispatch =
          Some (Option.value (json_optional_string "startStatus" project_raw) ~default:default_dispatch_status);
        project_status_on_success =
          Some (Option.value (json_optional_string "reviewStatus" project_raw) ~default:default_review_status);
        project_status_on_retry =
          Some (Option.value (json_optional_string "retryStatus" project_raw) ~default:default_retry_status);
        ensure_project_statuses = json_bool "ensureStatuses" project_raw ~default:true;
      };
    polling = { interval_ms = positive "polling.intervalMs" (json_int "intervalMs" polling_raw ~default:30000) };
    workspace = { root = workspace_root_value };
    agent =
      {
        max_concurrent_agents =
          positive "agent.maxConcurrentAgents" (json_int "maxConcurrentAgents" agent_raw ~default:2);
        max_turns = positive "agent.maxTurns" (json_int "maxTurns" agent_raw ~default:10);
        max_retry_backoff_ms =
          positive "agent.maxRetryBackoffMs" (json_int "maxRetryBackoffMs" agent_raw ~default:300000);
      };
    codex =
      {
        command = json_string "command" codex_raw ~default:default_codex_command |> normalize_codex_command;
        model = json_string "model" codex_raw ~default:default_model;
        reasoning_effort = json_string "reasoningEffort" codex_raw ~default:default_reasoning_effort;
        turn_timeout_ms = json_int "turnTimeoutMs" codex_raw ~default:3600000;
        read_timeout_ms = json_int "readTimeoutMs" codex_raw ~default:5000;
        stall_timeout_ms = json_int "stallTimeoutMs" codex_raw ~default:300000;
      };
    server = { port = (match member "port" server_raw with `Null -> None | _ -> Some (json_int "port" server_raw ~default:8080)) };
    stage_agents =
      {
        enabled = json_bool "enabled" stage_agents_raw ~default:true;
        root = json_string "root" stage_agents_raw ~default:".symphony/agents" |> expand_path ~base_dir:workspace_root;
        default_agent = json_optional_string "defaultAgent" stage_agents_raw;
        stages =
          (match json_object_list "stages" stage_agents_raw |> List.map json_stage_agent |> List.filter (fun stage -> stage.states <> [] && stage.agent <> "") with
          | [] -> default_stage_agents
          | stages -> stages);
      };
  }

let is_placeholder = function "" | "your-org" | "your-repo" -> true | _ -> false
let is_repository_name value = not (String.contains value '/')

let readiness_gaps config =
  let gaps = ref [] in
  let add requirement remediation = gaps := { requirement; remediation } :: !gaps in
  if is_placeholder config.tracker.owner then
    add "tracker.owner" "Set tracker.owner in .symphony/settings.json to the GitHub organization or user that owns the repository.";
  if is_placeholder config.tracker.repo then
    add "tracker.repo" "Set tracker.repo in .symphony/settings.json to the GitHub repository name.";
  if (not (is_placeholder config.tracker.repo)) && not (is_repository_name config.tracker.repo) then
    add "tracker.repo" "Set tracker.repo in .symphony/settings.json to the repository name only, not a GitHub URL or owner/name pair.";
  if config.tracker.project_number <= 0 then
    add "tracker.projectNumber" "Set tracker.projectNumber in .symphony/settings.json to a positive GitHub Projects number.";
  if config.tracker.api_key = None then
    add ("environment." ^ config.tracker.api_key_env)
      (Printf.sprintf "Export %s with a token that can read repository issues and project metadata." config.tracker.api_key_env);
  if Util.trim config.codex.command = "" then
    add "codex.command" "Set codex.command in .symphony/settings.json to the non-interactive Codex command, such as codex exec.";
  if Util.trim config.codex.model = "" then add "codex.model" "Set codex.model to a Codex model, such as gpt-5.5.";
  if Util.trim config.codex.reasoning_effort = "" then
    add "codex.reasoningEffort" "Set codex.reasoningEffort to low, medium, high, or xhigh.";
  if config.tracker.active_states = [] then
    add "project.activeStates" "Add at least one active project state in .symphony/settings.json.";
  if config.tracker.terminal_states = [] then
    add "project.terminalStates" "Add at least one terminal project state in .symphony/settings.json.";
  if config.stage_agents.enabled then (
    if not (Sys.file_exists config.stage_agents.root && Sys.is_directory config.stage_agents.root) then
      add "stageAgents.root" "Create .symphony/agents or set stageAgents.enabled to false.";
    List.iter
      (fun (stage : stage_agent) ->
        let path = Filename.concat config.stage_agents.root (stage.agent ^ ".md") in
        if not (Sys.file_exists path) then
          add ("stageAgents." ^ stage.agent) (Printf.sprintf "Create the stage agent prompt file: %s" path))
      config.stage_agents.stages);
  List.rev !gaps

let validate_for_dispatch config =
  match readiness_gaps config with
  | [] -> Ok ()
  | gaps ->
      let message =
        gaps
        |> List.map (fun gap -> gap.requirement ^ ": " ^ gap.remediation)
        |> String.concat "; "
      in
      Error message
