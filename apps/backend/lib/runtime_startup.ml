type loaded_config = { config : Config.t; prompt_template : string }

type prepared_runtime = {
  home : Runtime_home.t;
  bootstrap_report : Runtime_home.bootstrap_item list;
  loaded : loaded_config;
}

let empty_runtime_invocation_overrides : Config.runtime_invocation_overrides =
  {
    polling_interval_ms = None;
    workspace_root = None;
    agent_max_concurrent_agents = None;
    agent_max_turns = None;
    agent_max_retry_backoff_ms = None;
  }

let load_runtime_config ?(overrides = empty_runtime_invocation_overrides) home =
  Runtime_home.load_env home;
  let loaded_config = Config.from_settings_file ~workspace_root:home.Runtime_home.workspace_root home.settings_path in
  let config =
    Config.apply_runtime_invocation_overrides ~workspace_root:home.Runtime_home.workspace_root loaded_config overrides
  in
  let prompt_template = Runtime_home.load_prompt home in
  let example_issue = Issue.empty ~id:"local" ~identifier:"#0" ~title:"Local dry run" ~state:"Todo" in
  let _rendered = Prompt.render ~issue:example_issue ~attempt:None prompt_template in
  { config; prompt_template }

let prepare_runtime ?(overrides = empty_runtime_invocation_overrides) () =
  match Runtime_home.require_workspace_root () with
  | Error msg -> Error msg
  | Ok workspace_root ->
      let home, bootstrap_report = Runtime_home.bootstrap workspace_root in
      let loaded = load_runtime_config ~overrides home in
      Ok { home; bootstrap_report; loaded }

let startup_completed_event ~mode ~config ~runtime_home =
  Printf.sprintf
    "event=startup outcome=completed mode=%s tracker=%s issue_source=%s project_number=%d runtime_home=%s workspace_root=%s"
    mode config.Config.tracker.kind
    (match config.tracker.kind with
    | "github" -> Printf.sprintf "%s/%s" config.tracker.owner config.tracker.repo
    | "minibeads" -> config.tracker.minibeads_root
    | "compozy_tasks" -> config.tracker.compozy_root
    | kind -> kind)
    config.tracker.project_number runtime_home config.workspace.root
