type loaded_config = {
  config: Config.t,
  prompt_template: string,
};

type prepared_runtime = {
  home: Runtime_home.t,
  bootstrap_report: list(Runtime_home.bootstrap_item),
  bootstrap_guidance: Runtime_home.bootstrap_guidance,
  loaded: loaded_config,
};

let empty_runtime_invocation_overrides: Config.runtime_invocation_overrides = {
  polling_interval_ms: None,
  workspace_root: None,
  agent_max_concurrent_agents: None,
  agent_max_turns: None,
  agent_max_retry_backoff_ms: None,
};

let load_runtime_config = (~overrides=empty_runtime_invocation_overrides, home) => {
  Runtime_home.load_env(home);
  let loaded_config =
    Config.from_settings_file(
      ~workspace_root=home.Runtime_home.workspace_root,
      home.settings_path,
    );
  let config =
    Config.apply_runtime_invocation_overrides(
      ~workspace_root=home.Runtime_home.workspace_root,
      loaded_config,
      overrides,
    );
  let prompt_template = Runtime_home.load_prompt(home);
  let example_issue =
    Issue.empty(~id="local", ~identifier="#0", ~title="Local dry run", ~state="Todo");
  let _rendered = Prompt.render(~issue=example_issue, ~attempt=None, prompt_template);
  {config, prompt_template};
};

let prepare_runtime =
    (
      ~overrides=empty_runtime_invocation_overrides,
      ~bootstrap_probe=Runtime_home.default_bootstrap_probe,
      (),
    ) =>
  switch (Runtime_home.require_workspace_root()) {
  | Error(msg) => Error(msg)
  | Ok(workspace_root) =>
    let bootstrap =
      Runtime_home.bootstrap_with_guidance(~probe=bootstrap_probe, workspace_root);
    let home = bootstrap.Runtime_home.home;
    let bootstrap_report = bootstrap.Runtime_home.report;
    let bootstrap_guidance = bootstrap.Runtime_home.guidance;
    let loaded = load_runtime_config(~overrides, home);
    Ok({home, bootstrap_report, bootstrap_guidance, loaded});
  };

let bootstrap_guidance_lines = guidance =>
  switch (guidance) {
  | Runtime_home.Bootstrap_selected_harness(selected) => [
      Printf.sprintf(
        "bootstrap guidance: selected Agent Harness %s (%s) from local Bootstrap detection; runtime readiness remains the dispatch authority before dispatch.",
        selected.Runtime_home.name,
        selected.Runtime_home.kind,
      ),
      "bootstrap next: run Symphony normally to let runtime readiness validate the selected Harness.",
    ]
  | Runtime_home.Bootstrap_no_usable_harness => [
      "bootstrap guidance: no supported usable Agent Harness was found by local Bootstrap detection; Bootstrap still created any missing Runtime Contract files.",
      "bootstrap next: install or authenticate Codex, Claude Code, Cursor CLI, or PI, then rerun Symphony so runtime readiness can validate dispatch.",
    ]
  | Runtime_home.Bootstrap_existing_settings_preserved => [
      "bootstrap guidance: existing Runtime Settings were preserved; Bootstrap did not reinterpret, regenerate, or rewrite Harness settings.",
      "bootstrap next: edit .symphony/settings.json manually if you want to change Agent Harness routing.",
    ]
  };

let terminal_console_initial_log_lines =
    (~bootstrap_report_lines, ~bootstrap_guidance, ~startup_completed_line) =>
  bootstrap_report_lines
  @ bootstrap_guidance_lines(bootstrap_guidance)
  @ [startup_completed_line];

let startup_completed_event = (~mode, ~config, ~runtime_home) =>
  Printf.sprintf(
    "event=startup outcome=completed mode=%s tracker=%s issue_source=%s project_number=%d runtime_home=%s workspace_root=%s",
    mode,
    config.Config.tracker.kind,
    (
      switch (config.tracker.kind) {
      | "github" =>
        Printf.sprintf("%s/%s", config.tracker.owner, config.tracker.repo)
      | "minibeads" => config.tracker.minibeads_root
      | "compozy_tasks" => config.tracker.compozy_root
      | kind => kind
      }
    ),
    config.tracker.project_number,
    runtime_home,
    config.workspace.root,
  );
