type tracker = {
  kind : string;
  owner : string;
  repo : string;
  project_number : int;
  api_key_env : string;
  api_key : string option;
  minibeads_root : string;
  minibeads_command : string;
  compozy_root : string;
  compozy_max_task_step_retries : int;
  active_states : string list;
  terminal_states : string list;
  ready_status : string;
  ready_status_explicit : bool;
  project_status_field : string;
  project_status_on_dispatch : string option;
  project_status_on_success : string option;
  project_status_on_retry : string option;
  ensure_project_statuses : bool;
}

type polling = { interval_ms : int }
type workspace = { root : string }
type git_cleanup = { remove_worktree_after_merge : bool; keep_task_branch : bool }
type git = {
  task_branch_prefix : string;
  protected_trunk_branches : string list;
  allowed_loop_start_branches : string list;
  auto_merge : bool;
  merge_attention_status : string;
  cleanup : git_cleanup;
}
type agent = { max_concurrent_agents : int; max_turns : int; max_retry_backoff_ms : int }
type agent_harness = {
  name : string;
  kind : string;
  command : string;
  model : string;
  reasoning_effort : string;
  turn_timeout_ms : int;
  read_timeout_ms : int;
  stall_timeout_ms : int;
  loop_enabled : bool;
  loop_command : string;
}
type logical_agent = {
  name : string;
  harness : string;
  model : string option;
  reasoning_effort : string option;
  turn_timeout_ms : int option;
  read_timeout_ms : int option;
  stall_timeout_ms : int option;
}
type codex = {
  command : string;
  model : string;
  reasoning_effort : string;
  turn_timeout_ms : int;
  read_timeout_ms : int;
  stall_timeout_ms : int;
}
type server = { host : string; port : int option }
type protected_path_pattern = { name : string; pattern : string; reason : string option }
type protected_path_authorization = { issue_section : string }
type protected_paths = { patterns : protected_path_pattern list; authorization : protected_path_authorization }
type sandbox_validation_error = { requirement : string; remediation : string }
type sandbox = {
  enabled : bool;
  type_ : string option;
  image : string option;
  bootstrap_commands : string list;
  persistent : bool option;
  network_enabled : bool option;
  cpu_limit : int option;
  memory_mb : int option;
  validation_errors : sandbox_validation_error list;
}
type pull_request = {
  enabled : bool;
  mode : string;
  open_on_review : bool;
  base_branch : string;
  title : string;
  body : string;
}
type stage_commit_classification = {
  default : string;
  label_map : (string * string) list;
  conflict_behavior : string;
}
type stage_commit = {
  enabled : bool;
  commit_type : string;
  message : string;
  push : bool;
  classification : stage_commit_classification option;
}
type stage_goal = { enabled : bool }
type stage_context_snapshot = {
  enabled : bool;
  max_output_bytes : int;
  validation_error : string option;
}
type stage_context_command = {
  argv : string list;
  cwd : string;
  timeout_ms : int;
  max_output_bytes : int;
  validation_error : string option;
}
type stage_agent = {
  states : string list;
  agent : string;
  harness : string option;
  max_concurrent_agents : int option;
  context_snapshot : stage_context_snapshot option;
  context_command : stage_context_command option;
  skills : string list;
  start_status : string option;
  success_status : string option;
  retry_status : string option;
  goal : stage_goal option;
  commit : stage_commit option;
}

type stage_agents = { enabled : bool; root : string; default_agent : string option; stages : stage_agent list }

type t = {
  workflow_path : string;
  repository_root : string;
  tracker : tracker;
  polling : polling;
  workspace : workspace;
  git : git;
  agent : agent;
  codex : codex;
  agent_harnesses_explicit : bool;
  agent_harnesses : agent_harness list;
  logical_agents : logical_agent list;
  legacy_agent_harness_paths : string list;
  server : server;
  pull_request : pull_request;
  protected_paths : protected_paths;
  sandbox : sandbox;
  stage_agents : stage_agents;
}

type runtime_invocation_overrides = {
  polling_interval_ms : int option;
  workspace_root : string option;
  agent_max_concurrent_agents : int option;
  agent_max_turns : int option;
  agent_max_retry_backoff_ms : int option;
}

type readiness_gap = { requirement : string; remediation : string }

exception Invalid_config of string

let default_active_states = [ "To-Do"; "Todo"; "In Progress" ]
let default_terminal_states = [ "Done"; "Closed"; "Cancelled"; "Canceled"; "Duplicate" ]
let default_ready_status = "Ready for Symphony"
let default_dispatch_status = "In progress"
let default_review_status = "In review"
let default_retry_status = "To-Do"
let default_merge_attention_status = "Human attention"
let default_commit_message = "<type>: <generated_message_max_90char>"
let default_model = "gpt-5.5"
let default_reasoning_effort = "medium"
let default_codex_command = "codex exec"
let default_codex_loop_command = "/goal"
let default_pi_model = "openai/gpt-5.5"
let default_pi_command = "pi --model <model> --thinking <reasoning> --print --no-session"
let default_claude_command = "claude -p --model <model> --output-format stream-json"
let default_cursor_command = "cursor-agent -p --model <model> --output-format stream-json"
let default_pull_request_title = "Symphony batch from <head_branch>"
let default_pull_request_body = "Opened automatically by Symphony after orchestration became idle."
let default_minibeads_root = ".beads"
let default_minibeads_command = "mb"
let default_compozy_root = ".compozy/tasks"
let default_compozy_max_task_step_retries = 2
let default_server_host = "127.0.0.1"
let default_server = { host = default_server_host; port = None }
let default_protected_path_authorization = { issue_section = "Protected Path Authorization" }
let default_protected_paths = { patterns = []; authorization = default_protected_path_authorization }
let default_sandbox =
  {
    enabled = false;
    type_ = None;
    image = None;
    bootstrap_commands = [];
    persistent = None;
    network_enabled = None;
    cpu_limit = None;
    memory_mb = None;
    validation_errors = [];
  }
let default_pull_request =
  {
    enabled = false;
    mode = "batch";
    open_on_review = false;
    base_branch = "main";
    title = default_pull_request_title;
    body = default_pull_request_body;
  }
let default_conflict_behavior = "human_attention"
let default_context_snapshot_max_output_bytes = 12000
let default_context_command_cwd = "agentWorktree"
let default_context_command_timeout_ms = 30000
let default_context_command_max_output_bytes = 12000

let default_git =
  {
    task_branch_prefix = "symphony/task-";
    protected_trunk_branches = [ "main"; "master" ];
    allowed_loop_start_branches = [];
    auto_merge = true;
    merge_attention_status = default_merge_attention_status;
    cleanup = { remove_worktree_after_merge = true; keep_task_branch = true };
  }

let normalize_codex_command command =
  if Util.trim command = "codex app-server" then default_codex_command else command

let codex_of_harness (harness : agent_harness) =
  {
    command = harness.command;
    model = harness.model;
    reasoning_effort = harness.reasoning_effort;
    turn_timeout_ms = harness.turn_timeout_ms;
    read_timeout_ms = harness.read_timeout_ms;
    stall_timeout_ms = harness.stall_timeout_ms;
  }

let harness_of_codex ?(name = "codex") (codex : codex) =
  {
    name;
    kind = "codex";
    command = codex.command;
    model = codex.model;
    reasoning_effort = codex.reasoning_effort;
    turn_timeout_ms = codex.turn_timeout_ms;
    read_timeout_ms = codex.read_timeout_ms;
    stall_timeout_ms = codex.stall_timeout_ms;
    loop_enabled = true;
    loop_command = default_codex_loop_command;
  }

let default_stage_agents =
  [
    {
      states = [ "Backlog" ];
      agent = "planner";
      harness = None;
      max_concurrent_agents = None;
      context_snapshot = None;
      context_command = None;
      skills = [];
      start_status = None;
      success_status = Some "To-Do";
      retry_status = Some "Backlog";
      goal = Some { enabled = false };
      commit = Some { enabled = false; commit_type = "feature"; message = default_commit_message; push = false; classification = None };
    };
    {
      states = [ "Todo"; "To-Do"; "In progress"; "In Progress" ];
      agent = "engineer";
      harness = None;
      max_concurrent_agents = None;
      context_snapshot = None;
      context_command = None;
      skills = [];
      start_status = Some "In progress";
      success_status = Some "In review";
      retry_status = Some "To-Do";
      goal = Some { enabled = false };
      commit = Some { enabled = true; commit_type = "feature"; message = default_commit_message; push = false; classification = None };
    };
    {
      states = [ "In review"; "In Review" ];
      agent = "reviewer";
      harness = None;
      max_concurrent_agents = None;
      context_snapshot = None;
      context_command = None;
      skills = [];
      start_status = None;
      success_status = Some "Done";
      retry_status = Some "In progress";
      goal = Some { enabled = false };
      commit = Some { enabled = false; commit_type = "refactor"; message = default_commit_message; push = false; classification = None };
    };
  ]

let add_string_ci value values =
  if List.exists (fun existing -> String.lowercase_ascii existing = String.lowercase_ascii value) values then values
  else values @ [ value ]

let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b

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

let expand_path_preserving_missing ~base_dir path =
  let path =
    match Util.drop_prefix ~prefix:"~/" path with
    | Some suffix -> Filename.concat (Sys.getenv "HOME") suffix
    | None -> (
        match Util.drop_prefix ~prefix:"$" path with Some var -> Option.value (Util.getenv_nonempty var) ~default:path | None -> path)
  in
  let path = if Filename.is_relative path then Filename.concat base_dir path else path in
  let rec existing_parent candidate missing =
    if Sys.file_exists candidate then (Unix.realpath candidate, missing)
    else
      let parent = Filename.dirname candidate in
      let name = Filename.basename candidate in
      let missing = match missing with "" -> name | suffix -> Filename.concat name suffix in
      if parent = candidate then (parent, missing) else existing_parent parent missing
  in
  if Sys.file_exists path then Unix.realpath path
  else
    let real_parent, missing = existing_parent (Filename.dirname path) (Filename.basename path) in
    Filename.concat real_parent missing

let positive name value =
  if value <= 0 then raise (Invalid_config (name ^ " must be positive"));
  value

let positive_option name = function None -> None | Some value -> Some (positive name value)

let parse_tracker_kind raw =
  match Util.trim raw |> String.lowercase_ascii with
  | "github" -> "github"
  | "minibeads" -> "minibeads"
  | "compozy_tasks" -> "compozy_tasks"
  | unsupported ->
      let shown = if unsupported = "" then "<empty>" else unsupported in
      raise
        (Invalid_config
           (Printf.sprintf "Unsupported tracker.kind %s. Set tracker.kind to github, minibeads, or compozy_tasks." shown))

let parse_server_host field raw =
  let host =
    match Util.trim raw |> String.lowercase_ascii with
    | "" | "localhost" -> default_server_host
    | value -> value
  in
  if String.contains host ':' then raise (Invalid_config (field ^ " must be an IPv4 bind address"));
  try Unix.inet_addr_of_string host |> Unix.string_of_inet_addr
  with Unix.Unix_error _ | Failure _ -> raise (Invalid_config (field ^ " must be an IPv4 bind address"))

let apply_runtime_invocation_overrides ~workspace_root config overrides =
  let polling =
    match overrides.polling_interval_ms with
    | Some interval_ms -> { interval_ms = positive "polling.intervalMs" interval_ms }
    | None -> config.polling
  in
  let workspace =
    match overrides.workspace_root with
    | Some root -> { root = expand_path ~base_dir:workspace_root root }
    | None -> config.workspace
  in
  let agent =
    {
      max_concurrent_agents =
        Option.value
          (positive_option "agent.maxConcurrentAgents" overrides.agent_max_concurrent_agents)
          ~default:config.agent.max_concurrent_agents;
      max_turns =
        Option.value (positive_option "agent.maxTurns" overrides.agent_max_turns) ~default:config.agent.max_turns;
      max_retry_backoff_ms =
        Option.value
          (positive_option "agent.maxRetryBackoffMs" overrides.agent_max_retry_backoff_ms)
          ~default:config.agent.max_retry_backoff_ms;
    }
  in
  { config with polling; workspace; agent }

let from_workflow workflow =
  let root = workflow.Workflow.config in
  let tracker_raw = Simple_yaml.get_map "tracker" root in
  let polling_raw = Simple_yaml.get_map "polling" root in
  let workspace_raw = Simple_yaml.get_map "workspace" root in
  let agent_raw = Simple_yaml.get_map "agent" root in
  let codex_raw = Simple_yaml.get_map "codex" root in
  let server_raw = Simple_yaml.get_map "server" root in
  let kind = Option.value (Simple_yaml.get_string "kind" tracker_raw) ~default:"" |> Util.trim |> String.lowercase_ascii in
  if kind <> "github" then
    raise
      (Invalid_config
         "tracker.kind must be github for legacy workflow files; use .symphony/settings.json for minibeads.");
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
  let ready_status = Simple_yaml.get_string "ready_status" tracker_raw in
  let active_states =
    match Simple_yaml.get_list "active_states" tracker_raw with [] -> default_active_states | states -> states
  in
  let active_states =
    match ready_status with
    | Some status when Util.trim status <> "" -> add_string_ci (Util.trim status) active_states
    | _ -> active_states
  in
  let terminal_states =
    (match Simple_yaml.get_list "terminal_states" tracker_raw with [] -> default_terminal_states | states -> states)
    |> add_string_ci default_git.merge_attention_status
  in
  let workspace_root =
    Simple_yaml.get_string "root" workspace_raw
    |> Option.value ~default:(Filename.concat (Filename.get_temp_dir_name ()) "symphony_workspaces")
    |> expand_path ~base_dir:workflow.dir
  in
  let codex =
    {
      command =
        Option.value (Simple_yaml.get_string "command" codex_raw) ~default:default_codex_command |> normalize_codex_command;
      model = Option.value (Simple_yaml.get_string "model" codex_raw) ~default:default_model;
      reasoning_effort =
        Option.value (Simple_yaml.get_string "reasoning_effort" codex_raw) ~default:default_reasoning_effort;
      turn_timeout_ms = Option.value (Simple_yaml.get_int "turn_timeout_ms" codex_raw) ~default:3600000;
      read_timeout_ms = Option.value (Simple_yaml.get_int "read_timeout_ms" codex_raw) ~default:5000;
      stall_timeout_ms = Option.value (Simple_yaml.get_int "stall_timeout_ms" codex_raw) ~default:300000;
    }
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
        minibeads_root = Filename.concat workflow.dir default_minibeads_root;
        minibeads_command = default_minibeads_command;
        compozy_root = Filename.concat workflow.dir default_compozy_root;
        compozy_max_task_step_retries = default_compozy_max_task_step_retries;
        active_states;
        terminal_states;
        ready_status = Option.value ready_status ~default:default_ready_status;
        ready_status_explicit = Option.is_some ready_status;
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
    git = default_git;
    agent =
      {
        max_concurrent_agents =
          positive "agent.max_concurrent_agents" (Option.value (Simple_yaml.get_int "max_concurrent_agents" agent_raw) ~default:10);
        max_turns = positive "agent.max_turns" (Option.value (Simple_yaml.get_int "max_turns" agent_raw) ~default:20);
        max_retry_backoff_ms =
          positive "agent.max_retry_backoff_ms" (Option.value (Simple_yaml.get_int "max_retry_backoff_ms" agent_raw) ~default:300000);
      };
    codex;
    agent_harnesses_explicit = false;
    agent_harnesses = [ harness_of_codex codex ];
    logical_agents = [];
    legacy_agent_harness_paths = [];
    server =
      {
        host = Simple_yaml.get_string "host" server_raw |> Option.value ~default:default_server_host |> parse_server_host "server.host";
        port = Simple_yaml.get_int "port" server_raw;
      };
    pull_request = default_pull_request;
    protected_paths = default_protected_paths;
    sandbox = default_sandbox;
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

let nonempty_trimmed_string path value =
  match Util.trim value with
  | "" -> raise (Invalid_config (path ^ " must not be empty"))
  | trimmed -> trimmed

let json_string_assoc path json =
  match json with
  | `Null -> []
  | `Assoc fields ->
      fields
      |> List.map (fun (key, value) ->
             let key = nonempty_trimmed_string (path ^ "." ^ key) key |> String.lowercase_ascii in
             let value =
               match value with
               | `String s -> nonempty_trimmed_string (path ^ "." ^ key) s
               | `Int i -> string_of_int i
               | _ -> raise (Invalid_config (path ^ "." ^ key ^ " must be a string"))
             in
             (key, value))
  | _ -> raise (Invalid_config (path ^ " must be an object"))

let json_branch_name_list name json ~default =
  match member name json with
  | `Null -> default
  | `List values ->
      values
      |> List.map (function
           | `String s when Util.trim s <> "" -> Util.trim s
           | `String _ -> raise (Invalid_config ("git." ^ name ^ " must not contain empty branch names"))
           | _ -> raise (Invalid_config ("git." ^ name ^ " must contain only branch name strings")))
  | _ -> raise (Invalid_config ("git." ^ name ^ " must be a list of branch name strings"))

let json_bool name json ~default =
  match member name json with `Bool b -> b | `String "true" -> true | `String "false" -> false | _ -> default

let json_bool_strict path json =
  match json with
  | `Bool b -> Ok b
  | `String "true" -> Ok true
  | `String "false" -> Ok false
  | `Null -> Ok false
  | _ -> Error (path ^ " must be a boolean")

let json_positive_int_strict path json ~default =
  match json with
  | `Null -> Ok default
  | `Int value when value > 0 -> Ok value
  | `String value -> (
      match int_of_string_opt value with
      | Some parsed when parsed > 0 -> Ok parsed
      | _ -> Error (path ^ " must be positive"))
  | `Int _ -> Error (path ^ " must be positive")
  | _ -> Error (path ^ " must be an integer")

let json_optional_string name json =
  match member name json with `String s when Util.trim s <> "" -> Some s | _ -> None

let json_object_list name json =
  match member name json with `List values -> values | _ -> []

let sandbox_validation_error requirement remediation : sandbox_validation_error = { requirement; remediation }

let json_sandbox_enabled raw =
  match raw with
  | `Null -> false
  | `Bool value -> value
  | `String value -> (
      match Util.trim value |> String.lowercase_ascii with
      | "true" -> true
      | "false" -> false
      | _ -> raise (Invalid_config "sandbox.enabled must be a boolean"))
  | _ -> raise (Invalid_config "sandbox.enabled must be a boolean")

let json_sandbox_optional_string path raw =
  match raw with
  | `Null -> (None, [])
  | `String value -> (
      match Util.trim value with
      | "" -> (None, [ sandbox_validation_error path (path ^ " must not be empty.") ])
      | trimmed -> (Some trimmed, []))
  | _ -> (None, [ sandbox_validation_error path (path ^ " must be a string.") ])

let json_sandbox_optional_bool path raw =
  match raw with
  | `Null -> (None, [])
  | `Bool value -> (Some value, [])
  | `String value -> (
      match Util.trim value |> String.lowercase_ascii with
      | "true" -> (Some true, [])
      | "false" -> (Some false, [])
      | _ -> (None, [ sandbox_validation_error path (path ^ " must be a boolean.") ]))
  | _ -> (None, [ sandbox_validation_error path (path ^ " must be a boolean.") ])

let json_sandbox_optional_positive_int path raw =
  match raw with
  | `Null -> (None, [])
  | `Int value when value > 0 -> (Some value, [])
  | `String value -> (
      match Util.trim value |> int_of_string_opt with
      | Some parsed when parsed > 0 -> (Some parsed, [])
      | _ -> (None, [ sandbox_validation_error path (path ^ " must be positive.") ]))
  | `Int _ -> (None, [ sandbox_validation_error path (path ^ " must be positive.") ])
  | _ -> (None, [ sandbox_validation_error path (path ^ " must be an integer.") ])

let json_sandbox_bootstrap_commands raw =
  match raw with
  | `Null -> ([], [])
  | `List values ->
      let commands = ref [] in
      let errors = ref [] in
      List.iteri
        (fun index value ->
          let path = Printf.sprintf "sandbox.bootstrapCommands[%d]" index in
          match value with
          | `String command -> (
              match Util.trim command with
              | "" ->
                  errors :=
                    sandbox_validation_error path
                      "Set sandbox.bootstrapCommands to a list of non-empty shell commands."
                    :: !errors
              | trimmed -> commands := trimmed :: !commands)
          | _ ->
              errors :=
                sandbox_validation_error path
                  "Set sandbox.bootstrapCommands to a list of non-empty shell commands."
                :: !errors)
        values;
      (List.rev !commands, List.rev !errors)
  | _ ->
      ( [],
        [
          sandbox_validation_error "sandbox.bootstrapCommands"
            "Set sandbox.bootstrapCommands to a list of non-empty shell commands.";
        ] )

let json_sandbox raw =
  match raw with
  | `Null -> default_sandbox
  | `Assoc _ ->
      let enabled = json_sandbox_enabled (member "enabled" raw) in
      if not enabled then { default_sandbox with enabled = false }
      else
        let type_, type_errors = json_sandbox_optional_string "sandbox.type" (member "type" raw) in
        let type_ = Option.map (fun value -> Util.trim value |> String.lowercase_ascii) type_ in
        let image, image_errors = json_sandbox_optional_string "sandbox.image" (member "image" raw) in
        let bootstrap_commands, bootstrap_errors = json_sandbox_bootstrap_commands (member "bootstrapCommands" raw) in
        let persistent, persistent_errors =
          json_sandbox_optional_bool "sandbox.persistent" (member "persistent" raw)
        in
        let network_enabled, network_errors =
          json_sandbox_optional_bool "sandbox.networkEnabled" (member "networkEnabled" raw)
        in
        let cpu_limit, cpu_errors = json_sandbox_optional_positive_int "sandbox.cpuLimit" (member "cpuLimit" raw) in
        let memory_mb, memory_errors =
          json_sandbox_optional_positive_int "sandbox.memoryMb" (member "memoryMb" raw)
        in
        {
          enabled;
          type_;
          image;
          bootstrap_commands;
          persistent;
          network_enabled;
          cpu_limit;
          memory_mb;
          validation_errors =
            type_errors @ image_errors @ bootstrap_errors @ persistent_errors @ network_errors @ cpu_errors @ memory_errors;
        }
  | _ -> raise (Invalid_config "sandbox must be an object")

let harness_named name (harnesses : agent_harness list) =
  List.find_opt (fun (harness : agent_harness) -> harness.name = name) harnesses

let logical_agent_named name (agents : logical_agent list) =
  List.find_opt (fun (agent : logical_agent) -> agent.name = name) agents

let harness_loop_handoff_enabled (harness : agent_harness) = harness.loop_enabled && Util.trim harness.loop_command <> ""

let merge_agent_harness (harness : agent_harness) (agent : logical_agent) =
  {
    harness with
    model = Option.value agent.model ~default:harness.model;
    reasoning_effort = Option.value agent.reasoning_effort ~default:harness.reasoning_effort;
    turn_timeout_ms = Option.value agent.turn_timeout_ms ~default:harness.turn_timeout_ms;
    read_timeout_ms = Option.value agent.read_timeout_ms ~default:harness.read_timeout_ms;
    stall_timeout_ms = Option.value agent.stall_timeout_ms ~default:harness.stall_timeout_ms;
  }

type selected_harness_resolution =
  | Resolved_harness of agent_harness
  | Missing_logical_agent of string
  | Missing_referenced_harness of string

let default_harness_kind name =
  match name with "codex" -> "codex" | "pi" -> "pi" | "claude" -> "claude" | "cursor" -> "cursor" | _ -> ""

let default_harness_command = function
  | "codex" -> default_codex_command
  | "pi" -> default_pi_command
  | "claude" -> default_claude_command
  | "cursor" -> default_cursor_command
  | _ -> ""

let default_harness_model = function "pi" -> default_pi_model | _ -> default_model

let default_harness_loop kind =
  if kind = "codex" then (true, default_codex_loop_command) else (false, "")

let json_harness_loop path raw ~kind =
  let default_enabled, default_command = default_harness_loop kind in
  match member "loop" raw with
  | `Null -> (default_enabled, default_command)
  | `Assoc _ as loop_raw ->
      ( json_bool "enabled" loop_raw ~default:default_enabled,
        json_string "command" loop_raw ~default:default_command )
  | _ -> raise (Invalid_config (path ^ ".loop must be an object"))

let json_agent_harness path name raw =
  let default_kind = default_harness_kind name in
  let default_command = default_harness_command default_kind in
  let default_model = default_harness_model default_kind in
  match raw with
  | `Assoc _ ->
      let kind = json_string "kind" raw ~default:default_kind |> Util.trim |> String.lowercase_ascii in
      let command =
        json_string "command" raw ~default:default_command
        |> fun command -> if kind = "codex" then normalize_codex_command command else command
      in
      let loop_enabled, loop_command = json_harness_loop path raw ~kind in
      {
        name = Util.trim name;
        kind;
        command;
        model = json_string "model" raw ~default:default_model;
        reasoning_effort = json_string "reasoningEffort" raw ~default:default_reasoning_effort;
        turn_timeout_ms = json_int "turnTimeoutMs" raw ~default:3600000;
        read_timeout_ms = json_int "readTimeoutMs" raw ~default:5000;
        stall_timeout_ms = json_int "stallTimeoutMs" raw ~default:300000;
        loop_enabled;
        loop_command;
      }
  | _ ->
      let loop_enabled, loop_command = default_harness_loop default_kind in
      {
        name = Util.trim name;
        kind = default_kind;
        command = "";
        model = default_model;
        reasoning_effort = default_reasoning_effort;
        turn_timeout_ms = 3600000;
        read_timeout_ms = 5000;
        stall_timeout_ms = 300000;
        loop_enabled;
        loop_command;
      }

let json_harness_map path raw ~legacy_codex =
  match raw with
  | `Assoc fields ->
      let harnesses =
        fields
        |> List.map (fun (name, raw) -> json_agent_harness (path ^ "." ^ Util.trim name) name raw)
      in
      (match harness_named "codex" harnesses with
      | Some _ -> harnesses
      | None -> harness_of_codex legacy_codex :: harnesses)
  | _ -> raise (Invalid_config (path ^ " must be an object"))

let is_legacy_agent_harness raw =
  match raw with
  | `Assoc _ -> member "kind" raw <> `Null || member "command" raw <> `Null
  | _ -> true

let legacy_agent_harness_path name raw =
  let path = "agents." ^ Util.trim name in
  match raw with
  | `Assoc _ when member "kind" raw <> `Null -> Some (path ^ ".kind")
  | `Assoc _ when member "command" raw <> `Null -> Some (path ^ ".command")
  | _ when is_legacy_agent_harness raw -> Some path
  | _ -> None

let legacy_agent_harness_paths agents_raw =
  match agents_raw with
  | `Assoc fields -> List.filter_map (fun (name, raw) -> legacy_agent_harness_path name raw) fields
  | _ -> []

let json_agent_harnesses agents_raw ~legacy_codex =
  match agents_raw with
  | `Null -> (false, [ harness_of_codex legacy_codex ])
  | `Assoc fields ->
      let harness_fields = List.filter (fun (_, raw) -> is_legacy_agent_harness raw) fields in
      if harness_fields = [] then (false, [ harness_of_codex legacy_codex ])
      else
        let harnesses =
          harness_fields
          |> List.map (fun (name, raw) -> json_agent_harness ("agents." ^ Util.trim name) name raw)
        in
        let harnesses =
          match harness_named "codex" harnesses with
          | Some _ -> harnesses
          | None -> harness_of_codex legacy_codex :: harnesses
        in
        (false, harnesses)
  | _ -> raise (Invalid_config "agents must be an object")

let json_harnesses harnesses_raw agents_raw ~legacy_codex =
  match harnesses_raw with
  | `Null -> json_agent_harnesses agents_raw ~legacy_codex
  | `Assoc _ -> (true, json_harness_map "harnesses" harnesses_raw ~legacy_codex)
  | _ -> raise (Invalid_config "harnesses must be an object")

let json_optional_positive_int path name json =
  match member name json with
  | `Null -> None
  | _ -> Some (positive path (json_int name json ~default:0))

let json_logical_agents agents_raw =
  match agents_raw with
  | `Null -> []
  | `Assoc fields ->
      fields
      |> List.filter_map (fun (name, raw) ->
             match raw with
             | `Assoc _ when member "harness" raw <> `Null ->
                 let name = nonempty_trimmed_string ("agents." ^ name) name in
                 Some
                   {
                     name;
                     harness = json_string "harness" raw ~default:"" |> nonempty_trimmed_string ("agents." ^ name ^ ".harness");
                     model = json_optional_string "model" raw;
                     reasoning_effort = json_optional_string "reasoningEffort" raw;
                     turn_timeout_ms = json_optional_positive_int ("agents." ^ name ^ ".turnTimeoutMs") "turnTimeoutMs" raw;
                     read_timeout_ms = json_optional_positive_int ("agents." ^ name ^ ".readTimeoutMs") "readTimeoutMs" raw;
                     stall_timeout_ms = json_optional_positive_int ("agents." ^ name ^ ".stallTimeoutMs") "stallTimeoutMs" raw;
                   }
             | `Assoc _ -> None
             | _ -> raise (Invalid_config ("agents." ^ name ^ " must be an object")))
  | _ -> raise (Invalid_config "agents must be an object")

let selected_agent_harness_resolution config (stage : stage_agent option) =
  if not config.agent_harnesses_explicit then
    match harness_named "codex" config.agent_harnesses with
    | Some harness -> Resolved_harness harness
    | None -> Resolved_harness (harness_of_codex config.codex)
  else
    match stage with
    | Some (stage : stage_agent) ->
        (match logical_agent_named stage.agent config.logical_agents with
        | None -> Missing_logical_agent stage.agent
        | Some agent -> (
            match harness_named agent.harness config.agent_harnesses with
            | Some harness -> Resolved_harness (merge_agent_harness harness agent)
            | None -> Missing_referenced_harness agent.harness))
    | None -> (
        match harness_named "codex" config.agent_harnesses with
        | Some harness -> Resolved_harness harness
        | None -> Missing_referenced_harness "codex")

let selected_agent_harness config stage =
  match selected_agent_harness_resolution config stage with
  | Resolved_harness harness -> Some harness
  | Missing_logical_agent _ | Missing_referenced_harness _ -> None

let default_agent_harness config =
  match harness_named "codex" config.agent_harnesses with Some harness -> harness | None -> harness_of_codex config.codex

let unique_harnesses_by_name harnesses =
  let rec loop acc = function
    | [] -> List.rev acc
    | (harness : agent_harness) :: rest ->
        if List.exists (fun (existing : agent_harness) -> existing.name = harness.name) acc then loop acc rest
        else loop (harness :: acc) rest
  in
  loop [] harnesses

let selected_stage_agent_harnesses config =
  if not config.stage_agents.enabled then []
  else
    config.stage_agents.stages
    |> List.filter_map (fun stage -> selected_agent_harness config (Some stage))
    |> unique_harnesses_by_name

let active_state_has_stage config state =
  config.stage_agents.stages
  |> List.exists (fun (stage : stage_agent) ->
         List.exists (fun stage_state -> string_equal_ci stage_state state) stage.states)

let has_non_stage_dispatch_path config =
  (not config.stage_agents.enabled)
  || List.exists (fun state -> not (active_state_has_stage config state)) config.tracker.active_states

let readiness_agent_harnesses config =
  let selected_harnesses = selected_stage_agent_harnesses config in
  let harnesses =
    if has_non_stage_dispatch_path config then default_agent_harness config :: selected_harnesses
    else selected_harnesses
  in
  unique_harnesses_by_name harnesses

let json_protected_path_patterns json =
  json_object_list "patterns" json
  |> List.mapi (fun index raw ->
         match raw with
         | `Assoc _ ->
             let name = json_string "name" raw ~default:"" |> Util.trim in
             let pattern = json_string "pattern" raw ~default:"" |> Util.trim in
             if name = "" then
               raise
                 (Invalid_config
                    (Printf.sprintf "paths.protected.patterns[%d].name is required" index));
             if pattern = "" then
               raise
                 (Invalid_config
                    (Printf.sprintf "paths.protected.patterns[%d].pattern is required" index));
             if String.length pattern > 0 && pattern.[0] = '!' then
               raise
                 (Invalid_config
                    (Printf.sprintf
                       "paths.protected.patterns[%d].pattern must not use negation" index));
             if String.length pattern > 0 && pattern.[0] = '/' then
               raise
                 (Invalid_config
                    (Printf.sprintf
                       "paths.protected.patterns[%d].pattern must be repository-root-relative" index));
             if List.exists (( = ) "..") (String.split_on_char '/' pattern) then
               raise
                 (Invalid_config
                    (Printf.sprintf
                       "paths.protected.patterns[%d].pattern must not contain .. segments" index));
             if String.contains pattern '\\' then
               raise
                 (Invalid_config
                    (Printf.sprintf
                       "paths.protected.patterns[%d].pattern must use / path separators" index));
             {
               name;
               pattern;
               reason =
                 (match member "reason" raw with
                 | `String reason when Util.trim reason <> "" -> Some (Util.trim reason)
                 | _ -> None);
             }
         | _ ->
             raise
               (Invalid_config
                  (Printf.sprintf "paths.protected.patterns[%d] must be an object" index)))

let json_protected_paths paths_raw =
  let protected_raw = member "protected" paths_raw in
  match protected_raw with
  | `Assoc _ ->
      let authorization_raw = member "authorization" protected_raw in
      let issue_section =
        json_string "issueSection" authorization_raw
          ~default:default_protected_path_authorization.issue_section
        |> Util.trim
      in
      {
        patterns = json_protected_path_patterns protected_raw;
        authorization =
          {
            issue_section =
              (if issue_section = "" then default_protected_path_authorization.issue_section
               else issue_section);
          };
      }
  | _ -> default_protected_paths

let json_context_command_argv path json =
  match json with
  | `List values ->
      let rec loop acc = function
        | [] ->
            if acc = [] then Error (path ^ " must contain at least one argument") else Ok (List.rev acc)
        | `String value :: rest when Util.trim value <> "" -> loop (value :: acc) rest
        | `String _ :: _ -> Error (path ^ " must not contain empty arguments")
        | _ :: _ -> Error (path ^ " must be an array of strings")
      in
      loop [] values
  | _ -> Error (path ^ " must be an argv array")

let json_context_command_cwd path json =
  match json with
  | `Null -> Ok default_context_command_cwd
  | `String value -> (
      match Util.trim value with
      | "workspaceRepositoryRoot" as cwd -> Ok cwd
      | "agentWorktree" as cwd -> Ok cwd
      | _ -> Error (path ^ " must be workspaceRepositoryRoot or agentWorktree"))
  | _ -> Error (path ^ " must be a string")

let json_stage_context_command json =
  let context_raw = member "context" json in
  match context_raw with
  | `Assoc _ -> (
      let command_raw = member "command" context_raw in
      match command_raw with
      | `Null -> None
      | _ ->
          let argv_result = json_context_command_argv "stageAgents.stages[].context.command" command_raw in
          let cwd_result = json_context_command_cwd "stageAgents.stages[].context.cwd" (member "cwd" context_raw) in
          let timeout_result =
            json_positive_int_strict "stageAgents.stages[].context.timeoutMs" (member "timeoutMs" context_raw)
              ~default:default_context_command_timeout_ms
          in
          let max_result =
            json_positive_int_strict "stageAgents.stages[].context.maxOutputBytes"
              (member "maxOutputBytes" context_raw)
              ~default:default_context_command_max_output_bytes
          in
          let validation_error =
            match (argv_result, cwd_result, timeout_result, max_result) with
            | Error error, _, _, _ -> Some error
            | _, Error error, _, _ -> Some error
            | _, _, Error error, _ -> Some error
            | _, _, _, Error error -> Some error
            | Ok _, Ok _, Ok _, Ok _ -> None
          in
          Some
            {
              argv = (match argv_result with Ok argv -> argv | Error _ -> []);
              cwd = (match cwd_result with Ok cwd -> cwd | Error _ -> default_context_command_cwd);
              timeout_ms =
                (match timeout_result with Ok timeout_ms -> timeout_ms | Error _ -> default_context_command_timeout_ms);
              max_output_bytes =
                (match max_result with Ok max_output_bytes -> max_output_bytes | Error _ -> default_context_command_max_output_bytes);
              validation_error;
            })
  | _ -> None

let json_stage_context_snapshot json =
  let context_raw = member "context" json in
  match context_raw with
  | `Null -> None
  | `Assoc _ -> (
      let snapshot_raw = member "snapshot" context_raw in
      match snapshot_raw with
      | `Null -> None
      | `Assoc _ ->
          let enabled_result = json_bool_strict "stageAgents.stages[].context.snapshot.enabled" (member "enabled" snapshot_raw) in
          let max_result =
            json_positive_int_strict "stageAgents.stages[].context.snapshot.maxOutputBytes"
              (member "maxOutputBytes" snapshot_raw)
              ~default:default_context_snapshot_max_output_bytes
          in
          let enabled = match enabled_result with Ok enabled -> enabled | Error _ -> false in
          let max_output_bytes =
            match max_result with Ok max_output_bytes -> max_output_bytes | Error _ -> default_context_snapshot_max_output_bytes
          in
          let validation_error =
            match (enabled_result, max_result) with
            | Error error, _ -> Some error
            | _, Error error -> Some error
            | Ok _, Ok _ -> None
          in
          Some { enabled; max_output_bytes; validation_error }
      | _ ->
          Some
            {
              enabled = false;
              max_output_bytes = default_context_snapshot_max_output_bytes;
              validation_error = Some "stageAgents.stages[].context.snapshot must be an object";
            })
  | _ ->
      Some
        {
          enabled = false;
          max_output_bytes = default_context_snapshot_max_output_bytes;
          validation_error = Some "stageAgents.stages[].context must be an object";
        }

let json_stage_agent json =
  let goal_raw = member "goal" json in
  let goal = match goal_raw with `Assoc _ -> Some { enabled = json_bool "enabled" goal_raw ~default:false } | _ -> None in
  let commit_raw = member "commit" json in
  let commit =
    match commit_raw with
    | `Assoc _ ->
        let commit_type = json_string "type" commit_raw ~default:"feature" in
        let classification_raw = member "classification" commit_raw in
        let classification =
          match classification_raw with
          | `Assoc _ ->
              let conflict_behavior =
                json_string "conflictBehavior" classification_raw ~default:default_conflict_behavior
                |> nonempty_trimmed_string "stageAgents.stages[].commit.classification.conflictBehavior"
              in
              if String.lowercase_ascii conflict_behavior <> default_conflict_behavior then
                raise
                  (Invalid_config
                     "stageAgents.stages[].commit.classification.conflictBehavior must be human_attention");
              Some
                {
                  default =
                    json_string "default" classification_raw ~default:commit_type
                    |> nonempty_trimmed_string "stageAgents.stages[].commit.classification.default";
                  label_map =
                    json_string_assoc "stageAgents.stages[].commit.classification.labelMap"
                      (member "labelMap" classification_raw);
                  conflict_behavior;
                }
          | `Null -> None
          | _ -> raise (Invalid_config "stageAgents.stages[].commit.classification must be an object")
        in
        Some
          {
            enabled = json_bool "enabled" commit_raw ~default:false;
            commit_type;
            message = json_string "message" commit_raw ~default:default_commit_message;
            push = json_bool "push" commit_raw ~default:false;
            classification;
          }
    | _ -> None
  in
  {
    states = json_string_list "states" json ~default:[];
    agent = json_string "agent" json ~default:"";
    harness = json_optional_string "harness" json;
    max_concurrent_agents =
      (match member "maxConcurrentAgents" json with
      | `Null -> None
      | _ -> Some (json_int "maxConcurrentAgents" json ~default:0))
      |> positive_option "stageAgents.stages.maxConcurrentAgents";
    context_snapshot = json_stage_context_snapshot json;
    context_command = json_stage_context_command json;
    skills = json_string_list "skills" json ~default:[];
    start_status = json_optional_string "startStatus" json;
    success_status = json_optional_string "successStatus" json;
    retry_status = json_optional_string "retryStatus" json;
    goal;
    commit;
  }

let stage_goal_enabled (stage : stage_agent) = match stage.goal with Some goal -> goal.enabled | None -> false

let stage_context_snapshot_enabled (stage : stage_agent) =
  match stage.context_snapshot with Some snapshot -> snapshot.enabled && snapshot.validation_error = None | None -> false

let stage_context_command_enabled (stage : stage_agent) =
  match stage.context_command with Some command -> command.validation_error = None | None -> false

let stage_goal_handoff_enabled config =
  config.stage_agents.enabled && List.exists stage_goal_enabled config.stage_agents.stages

let codex_config_path () =
  match Sys.getenv_opt "HOME" with
  | Some home when Util.trim home <> "" -> Filename.concat (Filename.concat home ".codex") "config.toml"
  | _ -> Filename.concat (Filename.concat (Unix.getcwd ()) ".codex") "config.toml"

let line_without_comment line =
  match String.index_opt line '#' with
  | Some index -> String.sub line 0 index
  | None -> line
  |> Util.trim

let codex_goals_feature_enabled path =
  if not (Sys.file_exists path) then false
  else
    let lines = Util.read_file path |> String.split_on_char '\n' in
    let in_features = ref false in
    List.exists
      (fun line ->
        let line = line_without_comment line in
        if String.length line >= 2 && line.[0] = '[' && line.[String.length line - 1] = ']' then (
          let section = String.sub line 1 (String.length line - 2) |> Util.trim in
          in_features := section = "features";
          false)
        else
          !in_features
          &&
          match String.split_on_char '=' line with
          | [ key; value ] -> Util.trim key = "goals" && Util.trim value = "true"
          | _ -> false)
      lines

let codex_goal_stdin_probe_enabled () =
  match Sys.getenv_opt "SYMPHONY_CODEX_GOAL_STDIN_PROBE" with Some "1" | Some "true" -> true | _ -> false

let replace_angle_token ~token ~value text =
  String.split_on_char '<' text
  |> List.mapi (fun index part ->
         if index = 0 then part
         else
           match String.split_on_char '>' part with
           | key :: rest when key = token -> value ^ String.concat ">" rest
           | _ -> "<" ^ part)
  |> String.concat ""

let harness_probe_command (harness : agent_harness) =
  harness.command
  |> replace_angle_token ~token:"model" ~value:(Util.shell_quote harness.model)
  |> replace_angle_token ~token:"reasoning" ~value:(Util.shell_quote harness.reasoning_effort)

let codex_probe_command config =
  harness_of_codex config.codex |> harness_probe_command

let is_env_assignment word =
  match String.index_opt word '=' with
  | None -> false
  | Some index -> index > 0

let rec drop_env_assignments = function
  | word :: rest when is_env_assignment word -> drop_env_assignments rest
  | words -> words

let static_codex_exec_command command =
  let words = String.split_on_char ' ' command |> List.filter (fun word -> Util.trim word <> "") in
  let words =
    match words with
    | "env" :: rest -> rest
    | _ -> words
    |> drop_env_assignments
  in
  match words with
  | executable :: rest when Filename.basename executable = "codex" -> List.exists (( = ) "exec") rest
  | _ -> false

let codex_goal_stdin_supported_harness (harness : agent_harness) =
  let command = Util.trim harness.command in
  let loop_command = Util.trim harness.loop_command in
  if command = "" then false
  else if loop_command = "" then false
  else if not (codex_goal_stdin_probe_enabled ()) then
    static_codex_exec_command command
  else
    let probe = Printf.sprintf "%s Verify Codex goal stdin support.\n\nReturn ok.\n" loop_command in
    let command = harness_probe_command harness in
    let shell_command =
      Printf.sprintf
        "if command -v timeout >/dev/null 2>&1; then printf %%s %s | timeout 20s %s; else printf %%s %s | %s; fi \
         >/dev/null 2>&1"
        (Util.shell_quote probe) command (Util.shell_quote probe) command
    in
    match Unix.system shell_command with Unix.WEXITED 0 -> true | _ -> false

let codex_goal_stdin_supported config =
  codex_goal_stdin_supported_harness (harness_of_codex config.codex)

let write_all fd text =
  let rec loop offset =
    if offset < String.length text then
      let written = Unix.write_substring fd text offset (String.length text - offset) in
      if written > 0 then loop (offset + written)
  in
  loop 0

let run_stdin_probe ~timeout_seconds command input =
  let input_read, input_write = Unix.pipe () in
  Unix.set_close_on_exec input_write;
  let pid =
    Unix.create_process "/bin/sh"
      [| "/bin/sh"; "-lc"; Printf.sprintf "exec %s >/dev/null 2>&1" command |]
      input_read Unix.stdout Unix.stderr
  in
  Unix.close input_read;
  (try write_all input_write input with Unix.Unix_error (Unix.EPIPE, _, _) -> ());
  Unix.close input_write;
  let deadline = Unix.gettimeofday () +. timeout_seconds in
  let rec wait () =
    match Unix.waitpid [ Unix.WNOHANG ] pid with
    | 0, _ ->
        if Unix.gettimeofday () >= deadline then (
          (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ());
          ignore (Unix.waitpid [] pid);
          false)
        else (
          Unix.sleepf 0.05;
          wait ())
    | _, Unix.WEXITED 0 -> true
    | _, (Unix.WEXITED _ | Unix.WSIGNALED _ | Unix.WSTOPPED _) -> false
  in
  wait ()

let cursor_loop_stdin_supported_harness (harness : agent_harness) =
  let command = Util.trim harness.command in
  let loop_command = Util.trim harness.loop_command in
  if command = "" || loop_command = "" then false
  else
    let probe = Printf.sprintf "%s Verify Cursor loop plugin support.\n\nReturn ok.\n" loop_command in
    run_stdin_probe ~timeout_seconds:20. (harness_probe_command harness) probe

let command_words command =
  String.split_on_char ' ' command |> List.filter (fun word -> Util.trim word <> "")

let harness_executable (harness : agent_harness) =
  let words =
    match harness_probe_command harness |> command_words with
    | "env" :: rest -> drop_env_assignments rest
    | words -> drop_env_assignments words
  in
  match words with
  | executable :: _ -> Some executable
  | [] -> None

let executable_available executable =
  if String.contains executable '/' then
    try
      Unix.access executable [ Unix.X_OK ];
      true
    with Unix.Unix_error _ -> false
  else
    match Unix.system (Printf.sprintf "command -v %s >/dev/null 2>&1" (Util.shell_quote executable)) with
    | Unix.WEXITED 0 -> true
    | _ -> false

let cursor_status_command (harness : agent_harness) =
  harness_executable harness
  |> Option.map (fun executable -> Printf.sprintf "%s status" (Util.shell_quote executable))

let cursor_harness_auth_configured (harness : agent_harness) =
  match cursor_status_command harness with
  | Some command -> run_stdin_probe ~timeout_seconds:20. command ""
  | None -> false

let pi_agent_dir () =
  match Util.getenv_nonempty "PI_CODING_AGENT_DIR" with
  | Some dir -> dir
  | None ->
      let home = Option.value (Util.getenv_nonempty "HOME") ~default:(Unix.getcwd ()) in
      Filename.concat (Filename.concat home ".pi") "agent"

let pi_auth_path () = Filename.concat (pi_agent_dir ()) "auth.json"

let rec json_has_nonempty_entry = function
  | `Null -> false
  | `String value -> Util.trim value <> ""
  | `Assoc fields -> List.exists (fun (_, value) -> json_has_nonempty_entry value) fields
  | `List values -> List.exists json_has_nonempty_entry values
  | _ -> true

let rec json_has_nonempty_field field = function
  | `Assoc fields ->
      (match List.assoc_opt field fields with Some value -> json_has_nonempty_entry value | None -> false)
      || List.exists (fun (_, value) -> json_has_nonempty_field field value) fields
  | `List values -> List.exists (json_has_nonempty_field field) values
  | _ -> false

let pi_auth_provider_configured provider =
  let path = pi_auth_path () in
  if not (Sys.file_exists path) then false
  else
    try
      match Yojson.Safe.from_file path with
      | `Assoc fields -> (
          match List.assoc_opt provider fields with Some value -> json_has_nonempty_entry value | None -> false)
      | _ -> false
    with Yojson.Json_error _ | Sys_error _ -> false

let pi_any_auth_configured () =
  let path = pi_auth_path () in
  if not (Sys.file_exists path) then false
  else
    try
      match Yojson.Safe.from_file path with
      | `Assoc fields -> List.exists (fun (_, value) -> json_has_nonempty_entry value) fields
      | _ -> false
    with Yojson.Json_error _ | Sys_error _ -> false

let pi_provider_envs =
  [
    ("anthropic", [ "ANTHROPIC_API_KEY"; "ANTHROPIC_OAUTH_TOKEN" ]);
    ("azure-openai-responses", [ "AZURE_OPENAI_API_KEY" ]);
    ("openai", [ "OPENAI_API_KEY" ]);
    ("deepseek", [ "DEEPSEEK_API_KEY" ]);
    ("google", [ "GEMINI_API_KEY" ]);
    ("mistral", [ "MISTRAL_API_KEY" ]);
    ("groq", [ "GROQ_API_KEY" ]);
    ("cerebras", [ "CEREBRAS_API_KEY" ]);
    ("cloudflare-ai-gateway", [ "CLOUDFLARE_API_KEY" ]);
    ("cloudflare-workers-ai", [ "CLOUDFLARE_API_KEY" ]);
    ("xai", [ "XAI_API_KEY" ]);
    ("openrouter", [ "OPENROUTER_API_KEY" ]);
    ("vercel-ai-gateway", [ "AI_GATEWAY_API_KEY" ]);
    ("zai", [ "ZAI_API_KEY" ]);
    ("opencode", [ "OPENCODE_API_KEY" ]);
    ("opencode-go", [ "OPENCODE_API_KEY" ]);
    ("huggingface", [ "HF_TOKEN" ]);
    ("fireworks", [ "FIREWORKS_API_KEY" ]);
    ("kimi-coding", [ "KIMI_API_KEY" ]);
    ("minimax", [ "MINIMAX_API_KEY" ]);
    ("minimax-cn", [ "MINIMAX_CN_API_KEY" ]);
    ("xiaomi", [ "XIAOMI_API_KEY" ]);
    ("xiaomi-token-plan-cn", [ "XIAOMI_TOKEN_PLAN_CN_API_KEY" ]);
    ("xiaomi-token-plan-ams", [ "XIAOMI_TOKEN_PLAN_AMS_API_KEY" ]);
    ("xiaomi-token-plan-sgp", [ "XIAOMI_TOKEN_PLAN_SGP_API_KEY" ]);
  ]

let pi_provider_env_configured provider =
  match List.assoc_opt provider pi_provider_envs with
  | None -> false
  | Some envs -> List.exists (fun env -> Util.getenv_nonempty env <> None) envs

let pi_any_env_configured () =
  pi_provider_envs |> List.exists (fun (_, envs) -> List.exists (fun env -> Util.getenv_nonempty env <> None) envs)

let command_supplies_api_key command =
  command_words command
  |> List.exists (fun word -> word = "--api-key" || Util.starts_with ~prefix:"--api-key=" word)

let pi_model_provider model =
  match String.split_on_char '/' (Util.trim model) with
  | provider :: _ :: _ when Util.trim provider <> "" -> Some (Util.trim provider)
  | _ -> None

let pi_harness_auth_configured (harness : agent_harness) =
  if command_supplies_api_key harness.command then true
  else
    match pi_model_provider harness.model with
    | Some provider -> pi_auth_provider_configured provider || pi_provider_env_configured provider
    | None -> pi_any_auth_configured () || pi_any_env_configured ()

let claude_config_dir () =
  match Util.getenv_nonempty "CLAUDE_CONFIG_DIR" with
  | Some dir -> dir
  | None ->
      let home = Option.value (Util.getenv_nonempty "HOME") ~default:(Unix.getcwd ()) in
      Filename.concat home ".claude"

let claude_credentials_path () = Filename.concat (claude_config_dir ()) ".credentials.json"

let claude_credentials_configured () =
  let path = claude_credentials_path () in
  if not (Sys.file_exists path) then false
  else
    try Yojson.Safe.from_file path |> json_has_nonempty_entry
    with Yojson.Json_error _ | Sys_error _ -> false

let claude_env_auth_configured () =
  [
    "ANTHROPIC_AUTH_TOKEN";
    "ANTHROPIC_API_KEY";
    "CLAUDE_CODE_OAUTH_TOKEN";
    "CLAUDE_CODE_USE_BEDROCK";
    "CLAUDE_CODE_USE_VERTEX";
    "CLAUDE_CODE_USE_FOUNDRY";
  ]
  |> List.exists (fun env -> Util.getenv_nonempty env <> None)

let claude_settings_paths command =
  let rec collect acc = function
    | [] -> List.rev acc
    | "--settings" :: path :: rest -> collect (path :: acc) rest
    | word :: rest when Util.starts_with ~prefix:"--settings=" word ->
        let prefix_len = String.length "--settings=" in
        let path = String.sub word prefix_len (String.length word - prefix_len) in
        collect (path :: acc) rest
    | _ :: rest -> collect acc rest
  in
  command_words command |> collect []

let command_path ~workspace_root path =
  if Filename.is_relative path then Filename.concat workspace_root path else path

let claude_settings_api_key_helper_configured ~workspace_root command =
  claude_settings_paths command
  |> List.exists (fun path ->
         let path = command_path ~workspace_root path in
         Sys.file_exists path
         &&
         try Yojson.Safe.from_file path |> json_has_nonempty_field "apiKeyHelper"
         with Yojson.Json_error _ | Sys_error _ -> false)

let claude_harness_auth_configured config (harness : agent_harness) =
  claude_env_auth_configured () || claude_credentials_configured ()
  || claude_settings_api_key_helper_configured ~workspace_root:config.repository_root harness.command

let from_settings_file ~workspace_root path =
  let root =
    try Yojson.Safe.from_file path
    with Yojson.Json_error msg -> raise (Invalid_config ("settings.json parse error: " ^ msg))
  in
  let tracker_raw = member "tracker" root in
  let compozy_raw = member "compozy" tracker_raw in
  let project_raw = member "project" root in
  let polling_raw = member "polling" root in
  let workspace_raw = member "workspace" root in
  let git_raw = member "git" root in
  let agent_raw = member "agent" root in
  let codex_raw = member "codex" root in
  let harnesses_raw = member "harnesses" root in
  let agents_raw = member "agents" root in
  let server_raw = member "server" root in
  let pull_request_raw = member "pullRequest" root in
  let paths_raw = member "paths" root in
  let sandbox_raw = member "sandbox" root in
  let stage_agents_raw = member "stageAgents" root in
  let kind = json_string "kind" tracker_raw ~default:"github" |> parse_tracker_kind in
  let api_key_env = json_string "apiKeyEnv" tracker_raw ~default:"GITHUB_TOKEN" in
  let merge_attention_status =
    json_string "mergeAttentionStatus" git_raw ~default:default_git.merge_attention_status
  in
  let terminal_states =
    json_string_list "terminalStates" project_raw ~default:default_terminal_states
    |> add_string_ci merge_attention_status
  in
  let ready_status_member = member "readyStatus" project_raw in
  let ready_status_explicit =
    match ready_status_member with `String _ | `Int _ -> true | _ -> false
  in
  let ready_status =
    match ready_status_member with
    | `String status -> status
    | `Int status -> string_of_int status
    | _ -> default_ready_status
  in
  let active_states =
    let states = json_string_list "activeStates" project_raw ~default:default_active_states in
    if kind = "github" && ready_status_explicit && Util.trim ready_status <> "" then
      add_string_ci (Util.trim ready_status) states
    else states
  in
  let workspace_root_value =
    json_string "root" workspace_raw ~default:".symphony/workspaces" |> expand_path ~base_dir:workspace_root
  in
  let legacy_codex =
    {
      command = json_string "command" codex_raw ~default:default_codex_command |> normalize_codex_command;
      model = json_string "model" codex_raw ~default:default_model;
      reasoning_effort = json_string "reasoningEffort" codex_raw ~default:default_reasoning_effort;
      turn_timeout_ms = json_int "turnTimeoutMs" codex_raw ~default:3600000;
      read_timeout_ms = json_int "readTimeoutMs" codex_raw ~default:5000;
      stall_timeout_ms = json_int "stallTimeoutMs" codex_raw ~default:300000;
    }
  in
  let legacy_agent_harness_paths = legacy_agent_harness_paths agents_raw in
  let agent_harnesses_explicit, agent_harnesses = json_harnesses harnesses_raw agents_raw ~legacy_codex in
  let logical_agents = json_logical_agents agents_raw in
  let agent_harnesses_explicit = agent_harnesses_explicit || logical_agents <> [] in
  let codex =
    match harness_named "codex" agent_harnesses with Some harness -> codex_of_harness harness | None -> legacy_codex
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
        minibeads_root =
          json_string "root" tracker_raw ~default:default_minibeads_root |> expand_path ~base_dir:workspace_root;
        minibeads_command = json_string "command" tracker_raw ~default:default_minibeads_command;
        compozy_root =
          json_string "root" compozy_raw ~default:default_compozy_root
          |> expand_path_preserving_missing ~base_dir:workspace_root;
        compozy_max_task_step_retries =
          positive "tracker.compozy.maxTaskStepRetries"
            (json_int "maxTaskStepRetries" compozy_raw ~default:default_compozy_max_task_step_retries);
        active_states;
        terminal_states;
        ready_status = Util.trim ready_status;
        ready_status_explicit;
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
    git =
      {
        task_branch_prefix = json_string "taskBranchPrefix" git_raw ~default:default_git.task_branch_prefix;
        protected_trunk_branches =
          json_string_list "protectedTrunkBranches" git_raw ~default:default_git.protected_trunk_branches;
        allowed_loop_start_branches =
          json_branch_name_list "allowedLoopStartBranches" git_raw ~default:default_git.allowed_loop_start_branches;
        auto_merge = json_bool "autoMerge" git_raw ~default:default_git.auto_merge;
        merge_attention_status;
        cleanup =
          {
            remove_worktree_after_merge =
              json_bool "removeWorktreeAfterMerge" (member "cleanup" git_raw)
                ~default:default_git.cleanup.remove_worktree_after_merge;
            keep_task_branch =
              json_bool "keepTaskBranch" (member "cleanup" git_raw) ~default:default_git.cleanup.keep_task_branch;
          };
      };
    agent =
      {
        max_concurrent_agents =
          positive "agent.maxConcurrentAgents" (json_int "maxConcurrentAgents" agent_raw ~default:2);
        max_turns = positive "agent.maxTurns" (json_int "maxTurns" agent_raw ~default:10);
        max_retry_backoff_ms =
          positive "agent.maxRetryBackoffMs" (json_int "maxRetryBackoffMs" agent_raw ~default:300000);
      };
    codex;
    agent_harnesses_explicit;
    agent_harnesses;
    logical_agents;
    legacy_agent_harness_paths;
    server =
      {
        host = json_string "host" server_raw ~default:default_server_host |> parse_server_host "server.host";
        port = (match member "port" server_raw with `Null -> None | _ -> Some (json_int "port" server_raw ~default:8080));
      };
    pull_request =
      {
        enabled = json_bool "enabled" pull_request_raw ~default:default_pull_request.enabled;
        mode =
          json_string "mode" pull_request_raw ~default:default_pull_request.mode
          |> Util.trim |> String.lowercase_ascii;
        open_on_review = json_bool "openOnReview" pull_request_raw ~default:default_pull_request.open_on_review;
        base_branch = json_string "baseBranch" pull_request_raw ~default:default_pull_request.base_branch;
        title = json_string "title" pull_request_raw ~default:default_pull_request.title;
        body = json_string "body" pull_request_raw ~default:default_pull_request.body;
      };
    protected_paths = json_protected_paths paths_raw;
    sandbox = json_sandbox sandbox_raw;
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

let codex_home () =
  match Sys.getenv_opt "CODEX_HOME" with
  | Some home when Util.trim home <> "" -> home
  | _ -> (
      match Sys.getenv_opt "HOME" with
      | Some home when Util.trim home <> "" -> Filename.concat home ".codex"
      | _ -> Filename.concat (Unix.getcwd ()) ".codex")

let contains_whitespace value =
  String.exists
    (function ' ' | '\t' | '\n' | '\r' | '\012' -> true | _ -> false)
    value

let contains_dot_segment value =
  String.contains value '.'
  &&
  let parts = String.split_on_char ':' value |> List.concat_map (String.split_on_char '.') in
  List.exists (( = ) "") parts || List.exists (( = ) "..") (String.split_on_char '/' value)

let valid_skill_identifier identifier =
  let identifier = Util.trim identifier in
  let valid_colons =
    match String.split_on_char ':' identifier with
    | [ value ] -> value <> ""
    | [ prefix; name ] -> prefix <> "" && name <> ""
    | _ -> false
  in
  identifier <> ""
  && valid_colons
  && not (String.contains identifier '$')
  && not (contains_whitespace identifier)
  && not (String.contains identifier '/')
  && not (String.contains identifier '\\')
  && not (contains_dot_segment identifier)

let skill_candidates roots identifier =
  let prefixed_candidates root =
    match String.split_on_char ':' identifier with
    | [ prefix; name ] when prefix <> "" && name <> "" ->
        [
          Filename.concat (Filename.concat root prefix) name;
          Filename.concat
            (Filename.concat
               (Filename.concat (Filename.concat (Filename.concat root "plugins") "cache") "openai-curated")
               prefix)
            name;
        ]
    | _ -> []
  in
  roots
  |> List.concat_map (fun root ->
         [
           Filename.concat (Filename.concat root identifier) "SKILL.md";
           Filename.concat (Filename.concat (Filename.concat root "skills") identifier) "SKILL.md";
           Filename.concat (Filename.concat (Filename.concat (Filename.concat root "skills") ".system") identifier) "SKILL.md";
         ]
         @ (prefixed_candidates root |> List.map (fun dir -> Filename.concat dir "SKILL.md")))

let path_exists path = Sys.file_exists path && not (Sys.is_directory path)

let path_has_dir path dir =
  String.split_on_char '/' path |> List.exists (( = ) dir)

let rec find_skill_by_scan ?plugin_prefix ~root identifier =
  if not (Sys.file_exists root && Sys.is_directory root) then None
  else
    let entries = Sys.readdir root |> Array.to_list in
    List.find_map
      (fun name ->
        let path = Filename.concat root name in
        if Sys.is_directory path then
          let skill_md = Filename.concat path "SKILL.md" in
          if
            path_exists skill_md
            &&
            match plugin_prefix with
            | Some prefix -> name = identifier && path_has_dir path prefix
            | None -> name = identifier
          then Some skill_md
          else find_skill_by_scan ?plugin_prefix ~root:path identifier
        else None)
      entries

let resolve_stage_skill_path config identifier =
  let workspace_skills = Filename.concat config.repository_root ".agents/skills" in
  let home = codex_home () in
  let home_skills = Filename.concat home "skills" in
  let home_plugins = Filename.concat (Filename.concat home "plugins") "cache" in
  let plugin_prefix, unqualified_identifier =
    match String.split_on_char ':' identifier with
    | [ prefix; name ] when prefix <> "" && name <> "" -> (Some prefix, name)
    | _ -> (None, identifier)
  in
  match List.find_opt path_exists (skill_candidates [ workspace_skills ] identifier) with
  | Some path -> Some path
  | None -> (
      match find_skill_by_scan ~root:workspace_skills identifier with
      | Some _ as path -> path
      | None -> (
          match List.find_opt path_exists (skill_candidates [ home ] identifier) with
          | Some _ as path -> path
          | None -> (
              match find_skill_by_scan ~root:home_skills identifier with
              | Some _ as path -> path
              | None -> find_skill_by_scan ?plugin_prefix ~root:home_plugins unqualified_identifier)))

let skill_exists config identifier = Option.is_some (resolve_stage_skill_path config identifier)

let validate_stage_skill_load config add =
  if config.stage_agents.enabled then
    List.iter
      (fun (stage : stage_agent) ->
        let seen = Hashtbl.create 8 in
        List.iter
          (fun skill ->
            let skill = Util.trim skill in
            let requirement = "stageAgents." ^ stage.agent ^ ".skills." ^ skill in
            if not (valid_skill_identifier skill) then
              add requirement
                "Use skill identifiers without $, whitespace, path separators, dot segments, or empty values."
            else if Hashtbl.mem seen skill then
              add requirement "Remove duplicate skill identifiers from the Stage Skill Load."
            else (
              Hashtbl.add seen skill ();
              if not (skill_exists config skill) then
                add requirement
                  "Install the skill in the Workspace Repository .agents/skills directory or in the Codex Home."))
          stage.skills)
      config.stage_agents.stages

let stage_context_setting_requirement (stage : stage_agent) default_path error =
  let prefix = "stageAgents.stages[]." in
  match Util.drop_prefix ~prefix error with
  | Some rest ->
      let path = match String.index_opt rest ' ' with Some index -> String.sub rest 0 index | None -> rest in
      "stageAgents." ^ stage.agent ^ "." ^ path
  | None -> "stageAgents." ^ stage.agent ^ "." ^ default_path

let validate_stage_context_snapshots config add =
  if config.stage_agents.enabled then
    List.iter
      (fun (stage : stage_agent) ->
        match stage.context_snapshot with
        | Some { validation_error = Some error; _ } ->
            add
              (stage_context_setting_requirement stage "context.snapshot" error)
              (error ^ ". Fix the Stage Agent context snapshot Runtime Settings before dispatch.")
        | _ -> ())
      config.stage_agents.stages

let validate_stage_context_commands config add =
  if config.stage_agents.enabled then
    List.iter
      (fun (stage : stage_agent) ->
        match stage.context_command with
        | Some { validation_error = Some error; _ } ->
            add
              (stage_context_setting_requirement stage "context.command" error)
              (error ^ ". Fix the Stage Agent context command Runtime Settings before dispatch.")
        | _ -> ())
      config.stage_agents.stages

let run_shell_capture ~cwd command =
  let command = Printf.sprintf "cd %s && %s 2>&1" (Util.shell_quote cwd) command in
  let ic = Unix.open_process_in command in
  let output =
    Fun.protect ~finally:(fun () -> ()) (fun () ->
        let buffer = Buffer.create 128 in
        (try
           while true do
             Buffer.add_string buffer (input_line ic);
             Buffer.add_char buffer '\n'
           done
         with End_of_file -> ());
        Buffer.contents buffer |> Util.trim)
  in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Ok output
  | Unix.WEXITED code -> Error (Printf.sprintf "exit %d: %s" code output)
  | Unix.WSIGNALED signal -> Error (Printf.sprintf "signal %d: %s" signal output)
  | Unix.WSTOPPED signal -> Error (Printf.sprintf "stopped %d: %s" signal output)

let current_loop_start_branch root =
  match run_shell_capture ~cwd:root "git branch --show-current" with
  | Ok branch when Util.trim branch <> "" -> Some (Util.trim branch)
  | _ -> None

let allowed_loop_start_branch_policy_gap config =
  match config.git.allowed_loop_start_branches with
  | [] -> None
  | allowed_branches -> (
      let allowed = String.concat ", " allowed_branches in
      match current_loop_start_branch config.repository_root with
      | Some current_branch when List.exists (( = ) current_branch) allowed_branches -> None
      | Some current_branch ->
          Some
            {
              requirement = "git.allowedLoopStartBranches";
              remediation =
                Printf.sprintf
                  "Allowed Loop-Start Branch Policy blocked dispatch: current Loop-Start Branch %s is not allowed. \
                   Allowed branches: %s. Switch to an allowed Loop-Start Branch or update Runtime Settings."
                  current_branch allowed;
            }
      | None ->
          Some
            {
              requirement = "git.allowedLoopStartBranches";
              remediation =
                Printf.sprintf
                  "Allowed Loop-Start Branch Policy blocked dispatch: the current checkout does not have a named \
                   Loop-Start Branch. Allowed branches: %s. Switch to an allowed Loop-Start Branch or update Runtime \
                   Settings."
                  allowed;
            })

let sandbox_has_validation_error sandbox requirement =
  List.exists (fun (error : sandbox_validation_error) -> error.requirement = requirement) sandbox.validation_errors

type sandbox_shell_result = { code : int; output : string }

let sandbox_run_shell command =
  let ic = Unix.open_process_in (command ^ " 2>&1") in
  let buffer = Buffer.create 128 in
  let rec read_lines () =
    try
      Buffer.add_string buffer (input_line ic);
      Buffer.add_char buffer '\n';
      read_lines ()
    with End_of_file -> ()
  in
  read_lines ();
  let code =
    match Unix.close_process_in ic with
    | Unix.WEXITED code -> code
    | Unix.WSIGNALED signal -> 128 + signal
    | Unix.WSTOPPED signal -> 128 + signal
  in
  { code; output = Buffer.contents buffer |> Util.trim }

let sandbox_docker_executable () =
  match Sys.getenv_opt "SYMPHONY_DOCKER_BIN" with
  | Some command when Util.trim command <> "" -> Util.trim command
  | _ -> "docker"

let sandbox_docker_command args =
  String.concat " " (List.map Util.shell_quote (sandbox_docker_executable () :: args))

let sandbox_docker_success args = (sandbox_run_shell (sandbox_docker_command args)).code = 0

let sandbox_hash value =
  let digest = Digest.to_hex (Digest.string value) in
  String.sub digest 0 (min 24 (String.length digest))

let sandbox_image_is_placeholder image =
  image |> Util.trim |> String.split_on_char '/' |> List.exists is_placeholder

let sandbox_static_ready sandbox =
  sandbox.validation_errors = []
  &&
  match
    (sandbox.type_, sandbox.image, sandbox.persistent, sandbox.network_enabled, sandbox.cpu_limit, sandbox.memory_mb)
  with
  | Some "docker", Some image, Some true, Some _, Some cpu_limit, Some memory_mb ->
      Util.trim image <> "" && (not (sandbox_image_is_placeholder image)) && cpu_limit > 0 && memory_mb > 0
  | _ -> false

let sandbox_existing_container_names config =
  let root_hash = sandbox_hash config.repository_root in
  let result =
    sandbox_run_shell
      (sandbox_docker_command
         [
           "ps";
           "-a";
           "--filter";
           "label=personal-symphony.repository-root-hash=" ^ root_hash;
           "--format";
           "{{.Names}}";
         ])
  in
  if result.code <> 0 then Error result.output
  else
    Ok
      (result.output |> Util.split_lines
      |> List.map Util.trim
      |> List.filter (fun name -> name <> ""))

let sandbox_container_health name =
  let result =
    sandbox_run_shell
      (sandbox_docker_command
         [
           "inspect";
           "-f";
           "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}";
           name;
         ])
  in
  if result.code <> 0 then Error result.output else Ok (Util.trim result.output)

let sandbox_container_state_is_usable status =
  List.exists (( = ) status) [ "running"; "created"; "exited"; "healthy" ]

let sandbox_existing_state_gaps config add =
  match sandbox_existing_container_names config with
  | Error _ ->
      add "sandbox.state" "Docker sandbox state could not be inspected. Remove stale Symphony sandbox containers and retry."
  | Ok names ->
      List.iter
        (fun name ->
          match sandbox_container_health name with
          | Ok status when sandbox_container_state_is_usable status -> ()
          | Ok status when status <> "" ->
              add "sandbox.state"
                (Printf.sprintf
                   "Existing Docker sandbox container %s is %s. Remove or repair stale Symphony sandbox containers before dispatch."
                   name status)
          | Ok _ | Error _ ->
              add "sandbox.state"
                (Printf.sprintf
                   "Existing Docker sandbox container %s could not be health-checked. Remove stale Symphony sandbox containers before dispatch."
                   name))
        names

let sandbox_live_readiness_gaps config add =
  let sandbox = config.sandbox in
  if sandbox.enabled && sandbox_static_ready sandbox then
    if not (sandbox_docker_success [ "--version" ]) then
      add "sandbox.docker"
        "Install the Docker CLI or set SYMPHONY_DOCKER_BIN to an executable Docker-compatible client."
    else if not (sandbox_docker_success [ "info"; "--format"; "{{.ServerVersion}}" ]) then
      add "sandbox.dockerDaemon" "Start Docker Desktop or the Docker daemon so sandbox readiness can inspect the server."
    else
      let image = Option.get sandbox.image in
      if not (sandbox_docker_success [ "image"; "inspect"; image ]) then
        add "sandbox.image"
          "Pull or build the configured sandbox.image locally before dispatch so Docker can start the sandbox container."
      else if
        not
          (sandbox_docker_success
             [ "run"; "--rm"; "--network"; "none"; "--entrypoint"; "/bin/sh"; image; "-lc"; "true" ])
      then
        add "sandbox.image"
          "Use a sandbox.image that can start /bin/sh for non-interactive Agent Harness execution."
      else sandbox_existing_state_gaps config add

let sandbox_readiness_gaps config add =
  let sandbox = config.sandbox in
  if sandbox.enabled then (
    List.iter (fun (error : sandbox_validation_error) -> add error.requirement error.remediation) sandbox.validation_errors;
    let add_if_no_validation_error requirement remediation =
      if not (sandbox_has_validation_error sandbox requirement) then add requirement remediation
    in
    (match sandbox.type_ with
    | Some "docker" -> ()
    | Some _ ->
        add "sandbox.type" "Set sandbox.type to docker. Docker is the only supported sandbox type in V1."
    | None ->
        add_if_no_validation_error "sandbox.type"
          "Set sandbox.type to docker when sandbox.enabled is true.");
    (match sandbox.image with
    | Some image when sandbox_image_is_placeholder image ->
        add_if_no_validation_error "sandbox.image"
          "Replace the placeholder sandbox.image with the Docker image used for sandboxed agent execution."
    | Some _ -> ()
    | None ->
        add_if_no_validation_error "sandbox.image"
          "Set sandbox.image to the Docker image used for sandboxed agent execution.");
    (match sandbox.persistent with
    | Some true -> ()
    | Some false ->
        add_if_no_validation_error "sandbox.persistent"
          "Set sandbox.persistent to true. V1 requires named-container reuse for sandboxed execution."
    | None ->
        add_if_no_validation_error "sandbox.persistent"
          "Set sandbox.persistent to true when sandbox.enabled is true.");
    (match sandbox.network_enabled with
    | Some _ -> ()
    | None ->
        add_if_no_validation_error "sandbox.networkEnabled"
          "Set sandbox.networkEnabled to true or false so the sandbox network boundary is explicit.");
    (match sandbox.cpu_limit with
    | Some _ -> ()
    | None ->
        add_if_no_validation_error "sandbox.cpuLimit"
          "Set sandbox.cpuLimit to a positive integer CPU limit for sandboxed execution.");
    (match sandbox.memory_mb with
    | Some _ -> ()
    | None ->
        add_if_no_validation_error "sandbox.memoryMb"
          "Set sandbox.memoryMb to a positive integer memory limit for sandboxed execution.");
    sandbox_live_readiness_gaps config add)

let readiness_gaps config =
  let gaps = ref [] in
  let add requirement remediation = gaps := { requirement; remediation } :: !gaps in
  if config.tracker.kind = "github" then (
    if is_placeholder config.tracker.owner then
      add "tracker.owner"
        "Set tracker.owner in .symphony/settings.json to the GitHub organization or user that owns the repository.";
    if is_placeholder config.tracker.repo then
      add "tracker.repo" "Set tracker.repo in .symphony/settings.json to the GitHub repository name.";
    if (not (is_placeholder config.tracker.repo)) && not (is_repository_name config.tracker.repo) then
      add "tracker.repo" "Set tracker.repo in .symphony/settings.json to the repository name only, not a GitHub URL or owner/name pair.";
    if config.tracker.project_number <= 0 then
      add "tracker.projectNumber" "Set tracker.projectNumber in .symphony/settings.json to a positive GitHub Projects number.";
    if config.tracker.api_key = None then
      add ("environment." ^ config.tracker.api_key_env)
        (Printf.sprintf "Export %s with a token that can read repository issues and project metadata." config.tracker.api_key_env));
  sandbox_readiness_gaps config add;
  let selected_harnesses = readiness_agent_harnesses config in
  List.iter
    (fun path ->
      add path
        "Move legacy Harness settings out of agents.* and into harnesses.*. Keep agents.* for logical agent definitions \
         with a harness reference and optional execution overrides.")
    config.legacy_agent_harness_paths;
  List.iter
    (fun (harness : agent_harness) ->
      let prefix =
        if config.agent_harnesses_explicit then "harnesses." ^ harness.name else "codex"
      in
      if Util.trim harness.name = "" then
        add "harnesses" "Harness identifiers in .symphony/settings.json must not be empty.";
      if not (List.exists (( = ) harness.kind) [ "codex"; "claude"; "cursor"; "pi" ]) then
        add (prefix ^ ".kind") "Set Harness kind to codex, claude, cursor, or pi.";
      if Util.trim harness.command = "" then
        add (prefix ^ ".command") "Set the Harness command to a non-interactive launch command.";
      if Util.trim harness.model = "" then add (prefix ^ ".model") "Set the Harness model.";
      if Util.trim harness.reasoning_effort = "" then
        add (prefix ^ ".reasoningEffort") "Set the Harness reasoningEffort.")
    selected_harnesses;
  List.iter
    (fun (harness : agent_harness) ->
      if harness.kind = "pi" && Util.trim harness.command <> "" then (
        let prefix =
          if config.agent_harnesses_explicit then "harnesses." ^ harness.name else "agents.pi"
        in
        (match harness_executable harness with
        | Some executable when executable_available executable -> ()
        | Some executable ->
            add (prefix ^ ".install")
              (Printf.sprintf
                 "Install PI or update the PI Harness command so its executable is available: %s."
                 executable)
        | None -> ());
        if Util.trim harness.model <> "" && not (pi_harness_auth_configured harness) then
          let provider =
            match pi_model_provider harness.model with
            | Some provider -> " for provider " ^ provider
            | None -> ""
          in
          add (prefix ^ ".auth")
            (Printf.sprintf
               "Configure PI authentication%s. Run `pi`, use `/login` for a subscription provider, or set an API key \
                environment variable supported by PI."
               provider)))
    selected_harnesses;
  List.iter
    (fun (harness : agent_harness) ->
      if harness.kind = "claude" && Util.trim harness.command <> "" then (
        let prefix =
          if config.agent_harnesses_explicit then "harnesses." ^ harness.name else "agents.claude"
        in
        (match harness_executable harness with
        | Some executable when executable_available executable -> ()
        | Some executable ->
            add (prefix ^ ".install")
              (Printf.sprintf
                 "Install Claude Code or update the Claude Harness command so its executable is available: %s."
                 executable)
        | None -> ());
        if not (claude_harness_auth_configured config harness) then
          add (prefix ^ ".auth")
            "Configure Claude Code authentication without storing secrets in Runtime Settings. Run `claude /login`, set \
             ANTHROPIC_API_KEY or ANTHROPIC_AUTH_TOKEN, set CLAUDE_CODE_OAUTH_TOKEN for non-bare scripted runs, or \
             configure an apiKeyHelper through Claude settings."))
    selected_harnesses;
  List.iter
    (fun (harness : agent_harness) ->
      if harness.kind = "cursor" && Util.trim harness.command <> "" then
        let prefix =
          if config.agent_harnesses_explicit then "harnesses." ^ harness.name else "agents.cursor"
        in
        match harness_executable harness with
        | Some executable when executable_available executable ->
            if not (cursor_harness_auth_configured harness) then
              add (prefix ^ ".auth")
                "Configure Cursor authentication without storing secrets in Runtime Settings. Run `cursor-agent login` \
                 or set CURSOR_API_KEY, then confirm `cursor-agent status` succeeds."
        | Some executable ->
            add (prefix ^ ".install")
              (Printf.sprintf
                 "Install Cursor CLI or update the Cursor Harness command so its executable is available: %s."
                 executable)
        | None -> ())
    selected_harnesses;
  if config.tracker.active_states = [] then
    add "project.activeStates" "Add at least one active project state in .symphony/settings.json.";
  if config.tracker.terminal_states = [] then
    add "project.terminalStates" "Add at least one terminal project state in .symphony/settings.json.";
  if Util.trim config.tracker.ready_status = "" then
    add "project.readyStatus" "Set project.readyStatus to the Symphony-ready Status for first admission.";
  if config.pull_request.enabled && Util.trim config.pull_request.base_branch = "" then
    add "pullRequest.baseBranch" "Set pullRequest.baseBranch in .symphony/settings.json when pullRequest.enabled is true.";
  if
    config.pull_request.enabled
    && not (List.exists (( = ) config.pull_request.mode) [ "batch"; "task" ])
  then
    add "pullRequest.mode" "Set pullRequest.mode to batch or task.";
  if
    config.pull_request.enabled
    && config.pull_request.mode = "batch"
    && Util.trim config.pull_request.base_branch <> ""
  then (
    match current_loop_start_branch config.repository_root with
    | Some loop_start_branch when loop_start_branch = Util.trim config.pull_request.base_branch ->
        add "pullRequest.baseBranch"
          (Printf.sprintf
             "Batch Pull Request creation requires the Pull Request Base Branch to differ from the current Loop-Start \
              Branch %s. Switch to a non-trunk Loop-Start Branch or set pullRequest.baseBranch to the target branch."
             loop_start_branch)
    | _ -> ());
  (match allowed_loop_start_branch_policy_gap config with
  | Some gap -> add gap.requirement gap.remediation
  | None -> ());
  let codex_stage_goal_harnesses =
    if not config.stage_agents.enabled then []
    else
      config.stage_agents.stages
      |> List.filter_map (fun stage ->
             if not (stage_goal_enabled stage) then None
             else
               match selected_agent_harness config (Some stage) with
               | Some harness when harness.kind = "codex" && harness_loop_handoff_enabled harness -> Some harness
               | _ -> None)
  in
  if codex_stage_goal_harnesses <> [] then (
    let codex_config = codex_config_path () in
    if not (codex_goals_feature_enabled codex_config) then
      add "codex.goals"
        "Add the following to ~/.codex/config.toml to enable Stage Goal Handoff:\n\n[features]\ngoals = true";
    if List.exists (fun harness -> not (codex_goal_stdin_supported_harness harness)) codex_stage_goal_harnesses then
      add "codex.goalStdin"
        "Use a Codex command that accepts the configured Harness loop command from standard input before enabling \
         Stage Goal Handoff.");
  let cursor_stage_goal_harnesses =
    if not config.stage_agents.enabled then []
    else
      config.stage_agents.stages
      |> List.filter_map (fun stage ->
             if not (stage_goal_enabled stage) then None
             else
               match selected_agent_harness config (Some stage) with
               | Some harness when harness.kind = "cursor" && harness_loop_handoff_enabled harness -> Some harness
               | _ -> None)
  in
  List.iter
    (fun (harness : agent_harness) ->
      if not (cursor_loop_stdin_supported_harness harness) then
        let prefix =
          if config.agent_harnesses_explicit then "harnesses." ^ harness.name else "agents.cursor"
        in
        add (prefix ^ ".loop")
          "Install or enable the Cursor plugin that accepts the configured Harness loop command from standard input, \
           or disable loop.enabled / clear loop.command for this Cursor Harness.")
    cursor_stage_goal_harnesses;
  if config.stage_agents.enabled then (
    if not (Sys.file_exists config.stage_agents.root && Sys.is_directory config.stage_agents.root) then
      add "stageAgents.root" "Create .symphony/agents or set stageAgents.enabled to false.";
    List.iter
      (fun (stage : stage_agent) ->
        (match stage.harness with
        | Some _ ->
            add ("stageAgents." ^ stage.agent ^ ".harness")
              "stageAgents.stages[].harness is legacy Runtime Settings input. Move Harness selection to \
               agents.<name>.harness and keep stages routing by agent name."
        | None -> ());
        if config.agent_harnesses_explicit then (
          match selected_agent_harness_resolution config (Some stage) with
          | Missing_logical_agent name ->
              add ("agents." ^ name)
                (Printf.sprintf
                   "Define agents.%s in .symphony/settings.json with a harness reference, or route the stage to an \
                    existing logical agent."
                   name)
          | Missing_referenced_harness name ->
              add ("harnesses." ^ name)
                (Printf.sprintf
                   "Define harnesses.%s in .symphony/settings.json or update agents.%s.harness to an existing Harness."
                   name stage.agent)
          | Resolved_harness _ -> ());
        let path = Filename.concat config.stage_agents.root (stage.agent ^ ".md") in
        if not (Sys.file_exists path) then
          add ("stageAgents." ^ stage.agent) (Printf.sprintf "Create the stage agent prompt file: %s" path))
      config.stage_agents.stages);
  validate_stage_context_snapshots config add;
  validate_stage_context_commands config add;
  validate_stage_skill_load config add;
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

let project_status_order config =
  let add_unique acc status =
    let normalized = String.lowercase_ascii status in
    if List.exists (fun existing -> String.lowercase_ascii existing = normalized) acc then acc else acc @ [ status ]
  in
  let transition_statuses =
    [
      config.tracker.project_status_on_retry;
      config.tracker.project_status_on_dispatch;
      config.tracker.project_status_on_success;
      List.find_opt (fun _ -> true) config.tracker.terminal_states;
    ]
    |> List.filter_map Fun.id
  in
  transition_statuses |> List.fold_left add_unique []
