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
type git_cleanup = { remove_worktree_after_merge : bool; keep_task_branch : bool }
type git = {
  task_branch_prefix : string;
  protected_trunk_branches : string list;
  auto_merge : bool;
  merge_attention_status : string;
  cleanup : git_cleanup;
}
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
type pull_request = { enabled : bool; base_branch : string; title : string; body : string }
type stage_commit = { enabled : bool; commit_type : string; message : string; push : bool }
type stage_goal = { enabled : bool }
type stage_agent = {
  states : string list;
  agent : string;
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
  server : server;
  pull_request : pull_request;
  stage_agents : stage_agents;
}

type readiness_gap = { requirement : string; remediation : string }

exception Invalid_config of string

let default_active_states = [ "To-Do"; "Todo"; "In Progress" ]
let default_terminal_states = [ "Done"; "Closed"; "Cancelled"; "Canceled"; "Duplicate" ]
let default_dispatch_status = "In progress"
let default_review_status = "In review"
let default_retry_status = "To-Do"
let default_merge_attention_status = "Human attention"
let default_commit_message = "<type>: <generated_message_max_90char>"
let default_model = "gpt-5.5"
let default_reasoning_effort = "medium"
let default_codex_command = "codex exec"
let default_pull_request_title = "Symphony batch from <head_branch>"
let default_pull_request_body = "Opened automatically by Symphony after orchestration became idle."
let default_pull_request = { enabled = false; base_branch = "main"; title = default_pull_request_title; body = default_pull_request_body }

let default_git =
  {
    task_branch_prefix = "symphony/task-";
    protected_trunk_branches = [ "main"; "master" ];
    auto_merge = true;
    merge_attention_status = default_merge_attention_status;
    cleanup = { remove_worktree_after_merge = true; keep_task_branch = true };
  }

let normalize_codex_command command =
  if Util.trim command = "codex app-server" then default_codex_command else command

let default_stage_agents =
  [
    {
      states = [ "Backlog" ];
      agent = "planner";
      skills = [];
      start_status = None;
      success_status = Some "To-Do";
      retry_status = Some "Backlog";
      goal = Some { enabled = false };
      commit = Some { enabled = false; commit_type = "feature"; message = default_commit_message; push = false };
    };
    {
      states = [ "Todo"; "To-Do"; "In progress"; "In Progress" ];
      agent = "engineer";
      skills = [];
      start_status = Some "In progress";
      success_status = Some "In review";
      retry_status = Some "To-Do";
      goal = Some { enabled = false };
      commit = Some { enabled = true; commit_type = "feature"; message = default_commit_message; push = false };
    };
    {
      states = [ "In review"; "In Review" ];
      agent = "reviewer";
      skills = [];
      start_status = None;
      success_status = Some "Done";
      retry_status = Some "In progress";
      goal = Some { enabled = false };
      commit = Some { enabled = false; commit_type = "refactor"; message = default_commit_message; push = false };
    };
  ]

let add_string_ci value values =
  if List.exists (fun existing -> String.lowercase_ascii existing = String.lowercase_ascii value) values then values
  else values @ [ value ]

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
    (match Simple_yaml.get_list "terminal_states" tracker_raw with [] -> default_terminal_states | states -> states)
    |> add_string_ci default_git.merge_attention_status
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
    git = default_git;
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
    pull_request = default_pull_request;
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
  let goal_raw = member "goal" json in
  let goal = match goal_raw with `Assoc _ -> Some { enabled = json_bool "enabled" goal_raw ~default:false } | _ -> None in
  let commit_raw = member "commit" json in
  let commit =
    match commit_raw with
    | `Assoc _ ->
        Some
          {
            enabled = json_bool "enabled" commit_raw ~default:false;
            commit_type = json_string "type" commit_raw ~default:"feature";
            message = json_string "message" commit_raw ~default:default_commit_message;
            push = json_bool "push" commit_raw ~default:false;
          }
    | _ -> None
  in
  {
    states = json_string_list "states" json ~default:[];
    agent = json_string "agent" json ~default:"";
    skills = json_string_list "skills" json ~default:[];
    start_status = json_optional_string "startStatus" json;
    success_status = json_optional_string "successStatus" json;
    retry_status = json_optional_string "retryStatus" json;
    goal;
    commit;
  }

let stage_goal_enabled (stage : stage_agent) = match stage.goal with Some goal -> goal.enabled | None -> false

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

let codex_probe_command config =
  config.codex.command
  |> replace_angle_token ~token:"model" ~value:(Util.shell_quote config.codex.model)
  |> replace_angle_token ~token:"reasoning" ~value:(Util.shell_quote config.codex.reasoning_effort)

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

let codex_goal_stdin_supported config =
  let command = Util.trim config.codex.command in
  if command = "" then false
  else if not (codex_goal_stdin_probe_enabled ()) then
    static_codex_exec_command command
  else
    let probe = "/goal Verify Codex goal stdin support.\n\nReturn ok.\n" in
    let command = codex_probe_command config in
    let shell_command =
      Printf.sprintf
        "if command -v timeout >/dev/null 2>&1; then printf %%s %s | timeout 20s %s; else printf %%s %s | %s; fi \
         >/dev/null 2>&1"
        (Util.shell_quote probe) command (Util.shell_quote probe) command
    in
    match Unix.system shell_command with Unix.WEXITED 0 -> true | _ -> false

let from_settings_file ~workspace_root path =
  let root =
    try Yojson.Safe.from_file path
    with Yojson.Json_error msg -> raise (Invalid_config ("settings.json parse error: " ^ msg))
  in
  let tracker_raw = member "tracker" root in
  let project_raw = member "project" root in
  let polling_raw = member "polling" root in
  let workspace_raw = member "workspace" root in
  let git_raw = member "git" root in
  let agent_raw = member "agent" root in
  let codex_raw = member "codex" root in
  let server_raw = member "server" root in
  let pull_request_raw = member "pullRequest" root in
  let stage_agents_raw = member "stageAgents" root in
  let kind = json_string "kind" tracker_raw ~default:"github" in
  if kind <> "github" then raise (Invalid_config "tracker.kind must be github for this implementation");
  let api_key_env = json_string "apiKeyEnv" tracker_raw ~default:"GITHUB_TOKEN" in
  let merge_attention_status =
    json_string "mergeAttentionStatus" git_raw ~default:default_git.merge_attention_status
  in
  let terminal_states =
    json_string_list "terminalStates" project_raw ~default:default_terminal_states
    |> add_string_ci merge_attention_status
  in
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
        terminal_states;
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
    pull_request =
      {
        enabled = json_bool "enabled" pull_request_raw ~default:default_pull_request.enabled;
        base_branch = json_string "baseBranch" pull_request_raw ~default:default_pull_request.base_branch;
        title = json_string "title" pull_request_raw ~default:default_pull_request.title;
        body = json_string "body" pull_request_raw ~default:default_pull_request.body;
      };
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
  if config.pull_request.enabled && Util.trim config.pull_request.base_branch = "" then
    add "pullRequest.baseBranch" "Set pullRequest.baseBranch in .symphony/settings.json when pullRequest.enabled is true.";
  if stage_goal_handoff_enabled config then (
    let codex_config = codex_config_path () in
    if not (codex_goals_feature_enabled codex_config) then
      add "codex.goals"
        "Add the following to ~/.codex/config.toml to enable Stage Goal Handoff:\n\n[features]\ngoals = true";
    if not (codex_goal_stdin_supported config) then
      add "codex.goalStdin"
        "Use a Codex command that accepts /goal from standard input before enabling Stage Goal Handoff.");
  if config.stage_agents.enabled then (
    if not (Sys.file_exists config.stage_agents.root && Sys.is_directory config.stage_agents.root) then
      add "stageAgents.root" "Create .symphony/agents or set stageAgents.enabled to false.";
    List.iter
      (fun (stage : stage_agent) ->
        let path = Filename.concat config.stage_agents.root (stage.agent ^ ".md") in
        if not (Sys.file_exists path) then
          add ("stageAgents." ^ stage.agent) (Printf.sprintf "Create the stage agent prompt file: %s" path))
      config.stage_agents.stages);
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
