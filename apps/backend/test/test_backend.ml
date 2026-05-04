let with_temp_file content f =
  let path = Filename.temp_file "workflow" ".md" in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      let oc = open_out path in
      output_string oc content;
      close_out oc;
      f path)

let with_temp_dir prefix f =
  let root = Filename.concat (Filename.get_temp_dir_name ()) (prefix ^ string_of_int (Random.bits ())) in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.command ("rm -rf " ^ Util.shell_quote root)))
    (fun () ->
      Unix.mkdir root 0o755;
      f root)

let run_ok ?(cwd = ".") label command =
  match Orchestrator.run_shell_capture ~cwd command with
  | Ok output -> output
  | Error error -> Alcotest.fail (label ^ ": " ^ error)

let init_repo root branch =
  ignore (run_ok ~cwd:root "git init" (Printf.sprintf "git init -q -b %s" (Util.shell_quote branch)));
  ignore (run_ok ~cwd:root "git user email" "git config user.email test@example.com");
  ignore (run_ok ~cwd:root "git user name" "git config user.name Test");
  Util.write_file (Filename.concat root "README.md") "initial\n";
  ignore (run_ok ~cwd:root "initial commit" "git add README.md && git commit -q -m initial")

let git_policy ?(auto_merge = false) ?(protected_trunk_branches = [ "main"; "master" ])
    ?(merge_attention_status = "Human attention") ?(remove_worktree_after_merge = true) () =
  {
    Config.default_git with
    auto_merge;
    protected_trunk_branches;
    merge_attention_status;
    cleanup = { Config.remove_worktree_after_merge = remove_worktree_after_merge; keep_task_branch = true };
  }

let test_config_parses_git_policy_and_stage_push () =
  with_temp_dir "symphony-settings-git-" (fun root ->
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony/agents");
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "git": {
    "taskBranchPrefix": "agent/",
    "protectedTrunkBranches": ["main", "release"],
    "autoMerge": false,
    "mergeAttentionStatus": "Needs merge",
    "cleanup": {"removeWorktreeAfterMerge": false, "keepTaskBranch": true}
  },
  "pullRequest": {
    "enabled": true,
    "baseBranch": "main",
    "title": "Symphony batch from <head_branch> into <base_branch>",
    "body": "Batch handoff for <head_branch>."
  },
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {
        "states": ["In progress"],
        "agent": "engineer",
        "commit": {"enabled": true, "type": "feat", "message": "<type>: work", "push": true}
      },
      {
        "states": ["In review"],
        "agent": "reviewer",
        "commit": {"enabled": false, "type": "refactor", "message": "<type>: review"}
      }
    ]
  }
}|};
      Util.write_file (Filename.concat root ".symphony/agents/engineer.md") "Engineer";
      Unix.putenv "GITHUB_TOKEN" "token";
      let config = Config.from_settings_file ~workspace_root:root settings in
      Alcotest.(check string) "branch prefix" "agent/" config.git.task_branch_prefix;
      Alcotest.(check (list string)) "protected trunks" [ "main"; "release" ] config.git.protected_trunk_branches;
      Alcotest.(check bool) "auto merge" false config.git.auto_merge;
      Alcotest.(check string) "attention status" "Needs merge" config.git.merge_attention_status;
      Alcotest.(check bool) "attention status visible" true
        (List.exists (( = ) "Needs merge") config.tracker.terminal_states);
      Alcotest.(check bool) "cleanup worktree" false config.git.cleanup.remove_worktree_after_merge;
      Alcotest.(check bool) "pull request enabled" true config.pull_request.enabled;
      Alcotest.(check string) "pull request base" "main" config.pull_request.base_branch;
      Alcotest.(check string) "pull request title" "Symphony batch from <head_branch> into <base_branch>" config.pull_request.title;
      match config.stage_agents.stages with
      | [ { Config.commit = Some engineer_commit; _ }; { Config.commit = Some reviewer_commit; _ } ] ->
          Alcotest.(check bool) "stage push" true engineer_commit.push;
          Alcotest.(check bool) "stage push default" false reviewer_commit.push
      | _ -> Alcotest.fail "expected stage commit policy")

let test_config_parses_stage_goal_and_readiness () =
  let original_home = Sys.getenv_opt "HOME" in
  let original_probe = Sys.getenv_opt "SYMPHONY_CODEX_GOAL_STDIN_PROBE" in
  Fun.protect
    ~finally:(fun () ->
      (match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "");
      match original_probe with
      | Some value -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" value
      | None -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "";
          Unix.putenv "GITHUB_TOKEN" "token";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          (match config.stage_agents.stages with
          | [ stage ] -> Alcotest.(check bool) "goal enabled" true (Config.stage_goal_enabled stage)
          | _ -> Alcotest.fail "expected one stage");
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "missing codex goals gap" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps);
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[ features ]\ngoals = true # enable Codex goals\n";
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex goals gap resolved" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps)))

let test_disabled_stage_goal_does_not_require_codex_goals () =
  let original_home = Sys.getenv_opt "HOME" in
  Fun.protect
    ~finally:(fun () -> match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-disabled-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": false}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "no codex goals gap" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goals") gaps);
          Alcotest.(check bool) "no stdin gap" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_stage_goal_requires_codex_exec_stdin_support () =
  let original_home = Sys.getenv_opt "HOME" in
  Fun.protect
    ~finally:(fun () -> match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-stdin-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[features]\ngoals = true\n";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let settings = Filename.concat root "settings.json" in
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "cat"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "stdin gap" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "env CODEX_HOME=/tmp/codex /usr/local/bin/codex -m <model> exec"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex exec path accepted with env" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          Util.write_file settings
            {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": "printf codex exec"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|};
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "codex as argument rejected" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_stage_goal_live_stdin_probe () =
  let original_home = Sys.getenv_opt "HOME" in
  let original_probe = Sys.getenv_opt "SYMPHONY_CODEX_GOAL_STDIN_PROBE" in
  Fun.protect
    ~finally:(fun () ->
      (match original_home with Some value -> Unix.putenv "HOME" value | None -> Unix.putenv "HOME" "");
      match original_probe with
      | Some value -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" value
      | None -> Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "")
    (fun () ->
      with_temp_dir "symphony-stage-goal-live-probe-" (fun root ->
          Unix.putenv "HOME" root;
          Unix.putenv "GITHUB_TOKEN" "token";
          Unix.putenv "SYMPHONY_CODEX_GOAL_STDIN_PROBE" "1";
          Util.mkdir_p (Filename.concat root ".codex");
          Util.write_file (Filename.concat (Filename.concat root ".codex") "config.toml") "[features]\ngoals = true\n";
          let agents_root = Filename.concat root ".symphony/agents" in
          Util.mkdir_p agents_root;
          Util.write_file (Filename.concat agents_root "engineer.md") "Engineer";
          let fake_codex = Filename.concat root "fake-codex.sh" in
          Util.write_file fake_codex
            {|#!/bin/sh
input="$(cat)"
case "$input" in
  /goal*) exit 0 ;;
  *) exit 42 ;;
esac
|};
          Unix.chmod fake_codex 0o755;
          let settings = Filename.concat root "settings.json" in
          let write_settings command =
            Util.write_file settings
              (Printf.sprintf
                 {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "codex": {"command": %S, "model": "fixture-model", "reasoningEffort": "low"},
  "stageAgents": {
    "enabled": true,
    "root": ".symphony/agents",
    "stages": [
      {"states": ["Todo"], "agent": "engineer", "goal": {"enabled": true}}
    ]
  }
}|}
                 command)
          in
          write_settings (fake_codex ^ " -m <model> exec");
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "live probe accepted" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps);
          write_settings "false";
          let config = Config.from_settings_file ~workspace_root:root settings in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "live probe rejected" true
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "codex.goalStdin") gaps)))

let test_pull_request_base_branch_readiness_gap () =
  with_temp_dir "symphony-settings-pr-gap-" (fun root ->
      let settings = Filename.concat root "settings.json" in
      Util.mkdir_p (Filename.concat root ".symphony");
      Unix.putenv "GITHUB_TOKEN" "token";
      Util.write_file settings
        {|{
  "tracker": {"owner": "acme", "repo": "widgets", "projectNumber": 7},
  "pullRequest": {"enabled": true, "baseBranch": ""},
  "stageAgents": {"enabled": false}
}|};
      let config = Config.from_settings_file ~workspace_root:root settings in
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "base branch gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "pullRequest.baseBranch") gaps))

let test_workflow_and_config () =
  let content =
    {|
---
tracker:
  kind: github
  owner: acme
  repo: widgets
  project_number: 7
  api_key: literal-token
  active_states: [Todo, Doing]
workspace:
  root: ./workspaces
codex:
  command: codex exec
---
Issue {{ issue.identifier }}: {{ issue.title }}
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      let config = Config.from_workflow workflow in
      Alcotest.(check string) "owner" "acme" config.tracker.owner;
      Alcotest.(check string) "repo" "widgets" config.tracker.repo;
      Alcotest.(check int) "project number" 7 config.tracker.project_number;
      Alcotest.(check (list string)) "active states" [ "Todo"; "Doing" ] config.tracker.active_states;
      Alcotest.(check string) "prompt" "Issue {{ issue.identifier }}: {{ issue.title }}" workflow.prompt_template)

let test_prompt_strict_rendering () =
  let issue = Issue.empty ~id:"I_kw" ~identifier:"#42" ~title:"Fix build" ~state:"Todo" in
  Alcotest.(check string)
    "rendered prompt" "Work on #42: Fix build attempt=2"
    (Prompt.render ~issue ~attempt:(Some 2) "Work on {{ issue.identifier }}: {{ issue.title }} attempt={{ attempt }}");
  Alcotest.check_raises "unknown issue field fails"
    (Prompt.Template_render_error "unknown issue field: missing")
    (fun () -> ignore (Prompt.render ~issue ~attempt:None "{{ issue.missing }}"))

let test_workspace_safety () =
  let root = Filename.concat (Filename.get_temp_dir_name ()) ("symphony-test-" ^ string_of_int (Random.bits ())) in
  Fun.protect
    ~finally:(fun () -> ignore (Sys.command ("rm -rf " ^ Util.shell_quote root)))
    (fun () ->
      let workspace = Workspace.create_for_issue ~root "ABC/42 needs work" in
      Alcotest.(check string) "sanitized" "ABC_42_needs_work" workspace.workspace_key;
      Alcotest.(check bool) "created" true workspace.created_now;
      Alcotest.(check bool) "inside root" true (Workspace.is_inside ~root ~path:workspace.path);
      let reused = Workspace.create_for_issue ~root "ABC/42 needs work" in
      Alcotest.(check bool) "reused" false reused.created_now)

let test_shell_launch_runs_agent_in_agent_worktree () =
  with_temp_dir "symphony-launch-root-" (fun root ->
      let workspace_root = Filename.concat root "workspaces" in
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = workspace_root };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex =
            {
              command = "sh -c 'pwd > launched.cwd; cat > launched.prompt'";
              model = Config.default_model;
              reasoning_effort = Config.default_reasoning_effort;
              turn_timeout_ms = 1000;
              read_timeout_ms = 100;
              stall_timeout_ms = 1000;
            };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:workspace_root issue.identifier in
      let launched = Orchestrator.shell_launch ~config ~workspace ~prompt:"Issue #1" ~issue in
      (match launched.pid with
      | Some pid -> ignore (Unix.waitpid [] pid)
      | None -> Alcotest.fail "expected shell launch pid");
      Alcotest.(check string) "agent cwd" (Unix.realpath workspace.path)
        (Util.read_file (Filename.concat workspace.path "launched.cwd") |> Util.trim);
      Alcotest.(check string) "prompt piped" "Issue #1" (Util.read_file (Filename.concat workspace.path "launched.prompt") |> Util.trim);
      Alcotest.(check bool) "loop-start unchanged" false (Sys.file_exists (Filename.concat root "launched.cwd")))

let test_invalid_tracker_kind () =
  let content =
    {|
---
tracker:
  kind: linear
---
body
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      Alcotest.check_raises "linear rejected"
        (Config.Invalid_config "tracker.kind must be github for this implementation")
        (fun () -> ignore (Config.from_workflow workflow)))

let test_legacy_codex_app_server_command_normalizes_to_exec () =
  let content =
    {|
---
tracker:
  kind: github
  owner: acme
  repo: widgets
  project_number: 7
codex:
  command: codex app-server
---
body
|}
  in
  with_temp_file content (fun path ->
      let workflow = Workflow.load path in
      let config = Config.from_workflow workflow in
      Alcotest.(check string) "legacy command" Config.default_codex_command config.codex.command)

let test_project_status_order_uses_transition_flow () =
  let tracker =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Backlog"; "Todo"; "To-Do"; "In progress"; "In Progress"; "In review" ];
      terminal_states = [ "Done"; "Closed"; "Cancelled" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "To-Do";
      ensure_project_statuses = true;
    }
  in
  let config =
    {
      Config.workflow_path = "settings.json";
      repository_root = "/tmp/widgets";
      tracker;
      polling = { interval_ms = 1000 };
      workspace = { root = "/tmp/widgets/.symphony/workspaces" };
      git = Config.default_git;
      agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
      codex =
        {
          command = Config.default_codex_command;
          model = Config.default_model;
          reasoning_effort = Config.default_reasoning_effort;
          turn_timeout_ms = 1000;
          read_timeout_ms = 100;
          stall_timeout_ms = 1000;
      };
    server = { port = None };
    pull_request = Config.default_pull_request;
    stage_agents = { enabled = false; root = "/tmp/widgets/.symphony/agents"; default_agent = None; stages = [] };
    }
  in
  Alcotest.(check (list string)) "kanban status order" [ "To-Do"; "In progress"; "In review"; "Done" ]
    (Config.project_status_order config)

let test_bootstrap_idempotency_preserves_user_files () =
  with_temp_dir "symphony-bootstrap-" (fun root ->
      let home, first = Runtime_home.bootstrap root in
      Alcotest.(check bool) "settings created" true (Sys.file_exists home.settings_path);
      Alcotest.(check bool) "prompt created" true (Sys.file_exists home.prompt_path);
      let ignore_contents = Util.read_file (Filename.concat home.runtime_dir ".gitignore") in
      Alcotest.(check bool) "env ignored" true (String.contains ignore_contents 'e');
      Alcotest.(check bool) "state ignored" true (Util.starts_with ~prefix:"/.env" ignore_contents);
      Alcotest.(check bool) "planner agent created" true (Sys.file_exists (Filename.concat home.agents_dir "planner.md"));
      Alcotest.(check bool) "engineer agent created" true (Sys.file_exists (Filename.concat home.agents_dir "engineer.md"));
      Alcotest.(check bool) "reviewer agent created" true (Sys.file_exists (Filename.concat home.agents_dir "reviewer.md"));
      Util.write_file home.prompt_path "custom prompt {{ issue.title }}";
      let _, second = Runtime_home.bootstrap root in
      Alcotest.(check string) "prompt preserved" "custom prompt {{ issue.title }}" (Util.read_file home.prompt_path);
      Alcotest.(check bool) "created files on first run" true
        (List.exists (fun item -> item.Runtime_home.status = Runtime_home.Created) first);
      Alcotest.(check bool) "skipped files on second run" true
        (List.exists (fun item -> item.Runtime_home.status = Runtime_home.Skipped_existing) second))

let test_root_validation () =
  with_temp_dir "symphony-nongit-" (fun nongit ->
      let original = Unix.getcwd () in
      Fun.protect
        ~finally:(fun () -> Unix.chdir original)
        (fun () ->
          Unix.chdir nongit;
          match Runtime_home.require_workspace_root () with
          | Ok _ -> Alcotest.fail "non-git directories must be rejected"
          | Error msg -> Alcotest.(check bool) "mentions git repository" true (String.contains msg 'G')));
  with_temp_dir "symphony-git-" (fun root ->
      Alcotest.(check int) "git init" 0 (Sys.command ("git init -q " ^ Util.shell_quote root));
      let original = Unix.getcwd () in
      Fun.protect
        ~finally:(fun () -> Unix.chdir original)
        (fun () ->
          Unix.chdir root;
          Alcotest.(check (result string string)) "root accepted" (Ok (Unix.realpath root)) (Runtime_home.require_workspace_root ());
          Unix.mkdir "nested" 0o755;
          Unix.chdir "nested";
          match Runtime_home.require_workspace_root () with
          | Ok _ -> Alcotest.fail "nested directories must be rejected"
          | Error msg ->
              Alcotest.(check bool) "mentions repository root" true
                (String.contains msg 'r' && String.contains msg 'o' && String.contains msg 't')))

let test_settings_and_prompt_loading () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Unix.putenv "GITHUB_TOKEN" "";
  Unix.putenv "GH_TOKEN" "";
  with_temp_dir "symphony-settings-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let config = Config.from_settings_file ~workspace_root:root home.settings_path in
      Alcotest.(check string) "owner placeholder" "your-org" config.tracker.owner;
      Alcotest.(check string) "repo placeholder" "your-repo" config.tracker.repo;
      Alcotest.(check int) "project number" 1 config.tracker.project_number;
      Alcotest.(check string) "workspace root" (Filename.concat (Unix.realpath root) ".symphony/workspaces") config.workspace.root;
      Alcotest.(check int) "server port" 8080 (Option.get config.server.port);
      Alcotest.(check string) "codex model" "gpt-5.5" config.codex.model;
      Alcotest.(check string) "codex reasoning" "medium" config.codex.reasoning_effort;
      Alcotest.(check string) "codex launch command" "codex -m 'gpt-5.5' -c 'model_reasoning_effort=\"medium\"' exec"
        (Orchestrator.codex_command config);
      Alcotest.(check (option string)) "dispatch status" (Some "In progress") config.tracker.project_status_on_dispatch;
      Alcotest.(check (option string)) "review status" (Some "In review") config.tracker.project_status_on_success;
      Alcotest.(check (option string)) "retry status" (Some "To-Do") config.tracker.project_status_on_retry;
      Alcotest.(check bool) "ensure statuses" true config.tracker.ensure_project_statuses;
      Alcotest.(check bool) "stage agents enabled" true config.stage_agents.enabled;
      Alcotest.(check string) "stage agent root" (Filename.concat (Unix.realpath root) ".symphony/agents") config.stage_agents.root;
      Alcotest.(check int) "stage mappings" 3 (List.length config.stage_agents.stages);
      (match config.stage_agents.stages with
      | planner :: engineer :: _ ->
          Alcotest.(check (option string)) "planner success status" (Some "To-Do") planner.success_status;
          Alcotest.(check bool) "planner goal disabled" false (Config.stage_goal_enabled planner);
          Alcotest.(check bool) "engineer goal disabled" false (Config.stage_goal_enabled engineer);
          (match engineer.Config.commit with
          | Some commit ->
              Alcotest.(check bool) "engineer commits enabled" true commit.enabled;
              Alcotest.(check string) "engineer commit type" "feature" commit.commit_type;
              Alcotest.(check string) "engineer commit message" Config.default_commit_message commit.message
          | None -> Alcotest.fail "expected engineer commit policy")
      | _ -> Alcotest.fail "expected default stage mappings");
      let prompt = Runtime_home.load_prompt home in
      let issue = Issue.empty ~id:"I" ~identifier:"#1" ~title:"Install CLI" ~state:"Todo" in
      let rendered = Prompt.render ~issue ~attempt:(Some 3) prompt in
      Alcotest.(check bool) "rendered issue identifier" true (String.contains rendered '#');
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "placeholder owner gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "tracker.owner") gaps);
      Alcotest.(check bool) "token gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "environment.GITHUB_TOKEN") gaps));
  (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
  match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" ""

let test_runtime_env_loading () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Fun.protect
    ~finally:(fun () ->
      (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
      match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" "")
    (fun () ->
      Unix.putenv "GITHUB_TOKEN" "";
      Unix.putenv "GH_TOKEN" "";
      with_temp_dir "symphony-env-" (fun root ->
          let home, _ = Runtime_home.bootstrap root in
          Util.write_file home.env_path "GITHUB_TOKEN=github_pat_from_env_file\n";
          Runtime_home.load_env home;
          let config = Config.from_settings_file ~workspace_root:root home.settings_path in
          Alcotest.(check (option string)) "token loaded" (Some "github_pat_from_env_file") config.tracker.api_key;
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "token gap resolved" false
            (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "environment.GITHUB_TOKEN") gaps)))

let test_repo_url_readiness_gap () =
  let original_github_token = Sys.getenv_opt "GITHUB_TOKEN" in
  let original_gh_token = Sys.getenv_opt "GH_TOKEN" in
  Fun.protect
    ~finally:(fun () ->
      (match original_github_token with Some value -> Unix.putenv "GITHUB_TOKEN" value | None -> Unix.putenv "GITHUB_TOKEN" "");
      match original_gh_token with Some value -> Unix.putenv "GH_TOKEN" value | None -> Unix.putenv "GH_TOKEN" "")
    (fun () ->
      Unix.putenv "GITHUB_TOKEN" "github_pat_test";
      Unix.putenv "GH_TOKEN" "";
      with_temp_dir "symphony-repo-url-" (fun root ->
          let home, _ = Runtime_home.bootstrap root in
          Util.write_file home.settings_path
            {|{
  "tracker": {
    "kind": "github",
    "owner": "acme",
    "repo": "https://github.com/acme/widgets",
    "projectNumber": 1,
    "apiKeyEnv": "GITHUB_TOKEN"
  }
}
|};
          let config = Config.from_settings_file ~workspace_root:root home.settings_path in
          let gaps = Config.readiness_gaps config in
          Alcotest.(check bool) "repo URL gap" true
            (List.exists
               (fun (gap : Config.readiness_gap) ->
                 gap.requirement = "tracker.repo" && String.contains gap.remediation '/')
               gaps)))

let test_runtime_gitignore_contents () =
  with_temp_dir "symphony-ignore-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let contents = Util.read_file (Filename.concat home.runtime_dir ".gitignore") in
      Alcotest.(check bool) "ignores env" true (String.contains contents 'e');
      Alcotest.(check string) "exact ignore rules" "/.env\n/state/\n/workspaces/\n" contents)

let test_cli_mode_selection () =
  Alcotest.(check string) "terminal default" "terminal_console" (Cli_mode.(select ~web:false |> to_string));
  Alcotest.(check string) "web flag" "web_dashboard" (Cli_mode.(select ~web:true |> to_string))

let test_runtime_state_exposes_running_issue_details () =
  let issue =
    {
      (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Add dashboard issue list" ~state:"In progress") with
      description = Some "Show the status, title, and a concise description for each running issue.";
      url = Some "https://example.test/issues/1";
    }
  in
  let state =
    {
      (Runtime_state.empty ()) with
      issues = [ issue ];
      running =
        [
          {
            Runtime_state.issue;
            session_id = Some "pid:123";
            turn_count = 0;
            last_event = Some "launched";
            last_message = None;
            started_at = "2026-05-04T00:00:00Z";
            last_event_at = None;
            tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
            goal_usage = None;
          };
        ];
    }
  in
  let open Yojson.Safe.Util in
  let row = Runtime_state.to_yojson state |> member "running" |> to_list |> List.hd in
  Alcotest.(check string) "identifier" "#1" (row |> member "issue_identifier" |> to_string);
  Alcotest.(check string) "state" "In progress" (row |> member "state" |> to_string);
  Alcotest.(check string) "title" "Add dashboard issue list" (row |> member "title" |> to_string);
  Alcotest.(check string) "description" "Show the status, title, and a concise description for each running issue."
    (row |> member "description" |> to_string);
  let issue_row = Runtime_state.to_yojson state |> member "issues" |> to_list |> List.hd in
  Alcotest.(check string) "issue snapshot status" "In progress" (issue_row |> member "state" |> to_string);
  let ordered_state = Runtime_state.empty ~status_order:[ "Todo"; "In progress"; "In review"; "Done" ] () in
  Alcotest.(check (list string)) "status order"
    [ "Todo"; "In progress"; "In review"; "Done" ]
    (Runtime_state.to_yojson ordered_state |> member "status_order" |> to_list |> List.map to_string)

let test_runtime_state_exposes_goal_usage_when_available () =
  let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Add goal usage" ~state:"In progress" in
  let state =
    {
      (Runtime_state.empty ()) with
      running =
        [
          {
            Runtime_state.issue;
            session_id = Some "pid:123";
            turn_count = 0;
            last_event = Some "agent_output";
            last_message = Some "stdout/stderr updated";
            started_at = "2026-05-04T00:00:00Z";
            last_event_at = Some "2026-05-04T00:00:05Z";
            tokens = { input_tokens = 1; output_tokens = 2; total_tokens = 3 };
            goal_usage = Some { Runtime_state.status = Some "complete"; time_used_seconds = Some 5.; tokens_used = Some 99 };
          };
        ];
    }
  in
  let open Yojson.Safe.Util in
  let usage = Runtime_state.to_yojson state |> member "running" |> to_list |> List.hd |> member "goal_usage" in
  Alcotest.(check string) "goal status" "complete" (usage |> member "status" |> to_string);
  Alcotest.(check (float 0.01)) "goal time" 5. (usage |> member "time_used_seconds" |> to_float);
  Alcotest.(check int) "goal tokens" 99 (usage |> member "tokens_used" |> to_int);
  let retrying_state =
    {
      (Runtime_state.empty ()) with
      retrying =
        [
          {
            Runtime_state.issue_id = "I1";
            issue_identifier = "#1";
            attempt = 1;
            due_at = "2026-05-04T00:01:00Z";
            error = Some "agent exited with code 1";
            goal_usage = Some { Runtime_state.status = Some "active"; time_used_seconds = None; tokens_used = Some 42 };
          };
        ];
      issue_errors =
        [
          {
            Runtime_state.issue_id = "I2";
            issue_identifier = "#2";
            error = "commit required but agent produced no code changes";
            goal_usage = Some { Runtime_state.status = Some "blocked"; time_used_seconds = Some 2.; tokens_used = None };
          };
        ];
    }
  in
  let retry_usage = Runtime_state.to_yojson retrying_state |> member "retrying" |> to_list |> List.hd |> member "goal_usage" in
  Alcotest.(check string) "retry goal status" "active" (retry_usage |> member "status" |> to_string);
  Alcotest.(check int) "retry goal tokens" 42 (retry_usage |> member "tokens_used" |> to_int);
  let error_usage =
    Runtime_state.to_yojson retrying_state |> member "issue_errors" |> to_list |> List.hd |> member "goal_usage"
  in
  Alcotest.(check string) "error goal status" "blocked" (error_usage |> member "status" |> to_string);
  Alcotest.(check (float 0.01)) "error goal time" 2. (error_usage |> member "time_used_seconds" |> to_float)

let websocket_request () =
  {
    Server.request_line = "GET /api/v1/state/live HTTP/1.1";
    path = "/api/v1/state/live";
    headers =
      [
        ("host", "127.0.0.1");
        ("upgrade", "websocket");
        ("connection", "Upgrade");
        ("sec-websocket-key", "dGhlIHNhbXBsZSBub25jZQ==");
        ("sec-websocket-version", "13");
      ];
  }

let read_exact fd length =
  let bytes = Bytes.create length in
  let rec loop offset =
    if offset < length then
      let read = Unix.read fd bytes offset (length - offset) in
      if read = 0 then Alcotest.fail "unexpected EOF while reading websocket frame" else loop (offset + read)
  in
  loop 0;
  Bytes.unsafe_to_string bytes

let read_websocket_text_frame fd =
  let header = read_exact fd 2 in
  Alcotest.(check int) "text frame opcode" 0x81 (Char.code header.[0]);
  let len_code = Char.code header.[1] land 0x7f in
  let length =
    if len_code < 126 then len_code
    else if len_code = 126 then
      let extended = read_exact fd 2 in
      (Char.code extended.[0] lsl 8) lor Char.code extended.[1]
    else Alcotest.fail "test frames should not need 64-bit lengths"
  in
  read_exact fd length

let read_http_upgrade fd =
  let buffer = Buffer.create 256 in
  let rec loop recent =
    let next = read_exact fd 1 in
    Buffer.add_string buffer next;
    let recent = recent ^ next in
    let recent =
      if String.length recent > 4 then String.sub recent (String.length recent - 4) 4 else recent
    in
    if recent <> "\r\n\r\n" then loop recent
  in
  loop "";
  let response = Buffer.contents buffer in
  Alcotest.(check bool) "switching protocols" true (String.contains response '1');
  response

let with_websocket_client state f =
  let current_state = ref state in
  let live = Server.create_live_state ~get_state:(fun () -> !current_state) in
  let server_fd, client_fd = Unix.socketpair Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  let server_oc = Unix.out_channel_of_descr server_fd in
  let thread =
    Thread.create
      (fun () ->
        Fun.protect
          ~finally:(fun () -> close_out_noerr server_oc)
          (fun () -> Server.handle_websocket live server_fd server_oc (websocket_request ())))
      ()
  in
  Fun.protect
    ~finally:(fun () ->
      Unix.close client_fd;
      ignore (Thread.join thread))
    (fun () ->
      let _upgrade = read_http_upgrade client_fd in
      let initial = read_websocket_text_frame client_fd in
      f ~set_state:(fun state -> current_state := state) ~live ~client_fd ~initial)

let test_websocket_accept_and_initial_snapshot () =
  Alcotest.(check string) "RFC accept key" "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    (Server.websocket_accept "dGhlIHNhbXBsZSBub25jZQ==");
  let state =
    {
      (Runtime_state.empty ()) with
      issues = [ Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Live state" ~state:"Todo" ];
    }
  in
  with_websocket_client state (fun ~set_state:_ ~live:_ ~client_fd:_ ~initial ->
      let open Yojson.Safe.Util in
      let json = Yojson.Safe.from_string initial in
      Alcotest.(check string) "initial issue" "#1" (json |> member "issues" |> to_list |> List.hd |> member "issue_identifier" |> to_string))

let test_websocket_broadcast_after_state_change () =
  let state = Runtime_state.empty () in
  with_websocket_client state (fun ~set_state ~live ~client_fd ~initial:_ ->
      set_state
        {
          state with
          running =
            [
              {
                Runtime_state.issue = Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Running" ~state:"In progress";
                session_id = Some "pid:2";
                turn_count = 0;
                last_event = Some "started";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      Server.broadcast_live_state live;
      let open Yojson.Safe.Util in
      let json = read_websocket_text_frame client_fd |> Yojson.Safe.from_string in
      Alcotest.(check int) "running count" 1 (json |> member "counts" |> member "running" |> to_int))

let test_websocket_readiness_snapshot_and_http_state () =
  let state =
    Runtime_state.empty
      ~readiness_gaps:[ { Runtime_state.requirement = "tracker.owner"; remediation = "set tracker owner" } ]
      ~last_error:"tracker.owner: set tracker owner" ()
  in
  with_websocket_client state (fun ~set_state:_ ~live:_ ~client_fd:_ ~initial ->
      let open Yojson.Safe.Util in
      let json = Yojson.Safe.from_string initial in
      Alcotest.(check string) "readiness requirement" "tracker.owner"
        (json |> member "readiness_gaps" |> to_list |> List.hd |> member "requirement" |> to_string));
  let http =
    Server.handle_request (fun () -> state)
      { Server.request_line = "GET /api/v1/state HTTP/1.1"; path = "/api/v1/state"; headers = [] }
  in
  Alcotest.(check bool) "diagnostic endpoint preserved" true (String.contains http '{')

let test_orchestrator_notifies_each_state_mutation () =
  with_temp_dir "symphony-notify-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let notifications = ref 0 in
      let fetch _ = [] in
      let orchestrator =
        Orchestrator.make ~fetch ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun _ -> incr notifications)
          ()
      in
      Orchestrator.poll_once orchestrator;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "notifies repeated state writes" 2 !notifications)

let test_orchestrator_parses_final_output_when_size_was_already_seen () =
  with_temp_dir "symphony-final-output-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Fast output" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:(Filename.concat root "workspaces") issue.identifier in
      let stdout_path = Filename.concat workspace.path "stdout.log" in
      Util.write_file stdout_path
        {|input_tokens: 11
output_tokens: 13
total_tokens: 24
Goal Usage: {"status":"complete","time_used_seconds":1.5,"tokens_used":24}
|};
      let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "true" |] Unix.stdin Unix.stdout Unix.stderr in
      Unix.sleepf 0.05;
      let snapshots = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun state -> snapshots := state :: !snapshots)
          ()
      in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                session_id = Some "pid:test";
                turn_count = 0;
                last_event = Some "launched";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      orchestrator.Orchestrator.children <-
        [
          {
            Orchestrator.pid;
            issue;
            issue_id = issue.id;
            issue_identifier = issue.identifier;
            issue_title = issue.title;
            workspace;
            started_at = Unix.time ();
            last_output_at = Unix.time ();
            stdout_path = Some stdout_path;
            stderr_path = None;
            stdout_size = (Unix.stat stdout_path).Unix.st_size;
            stderr_size = 0;
          };
        ];
      Orchestrator.reap_children orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "final total tokens parsed" 24 state.codex_totals.total_tokens;
      Alcotest.(check int) "completed row removed" 0 (List.length state.running);
      let saw_goal_usage =
        List.exists
          (fun (state : Runtime_state.t) ->
            List.exists
              (fun (row : Runtime_state.running) ->
                match row.goal_usage with
                | Some usage -> usage.status = Some "complete" && usage.tokens_used = Some 24
                | None -> false)
              state.running)
          !snapshots
      in
      Alcotest.(check bool) "goal usage was exposed before completion" true saw_goal_usage)

let test_orchestrator_parses_final_output_before_timeout_retry () =
  with_temp_dir "symphony-timeout-output-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1; read_timeout_ms = 1000; stall_timeout_ms = 100000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Timeout output" ~state:"Todo" in
      let workspace = Workspace.create_for_issue ~root:(Filename.concat root "workspaces") issue.identifier in
      let stdout_path = Filename.concat workspace.path "stdout.log" in
      Util.write_file stdout_path
        {|input_tokens: 3
output_tokens: 5
total_tokens: 8
Goal Usage: {"status":"active","time_used_seconds":9,"tokens_used":8}
|};
      let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; "sleep 30" |] Unix.stdin Unix.stdout Unix.stderr in
      let snapshots = ref [] in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}"
          ~notify_state:(fun state -> snapshots := state :: !snapshots)
          ()
      in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                session_id = Some "pid:timeout";
                turn_count = 0;
                last_event = Some "launched";
                last_message = None;
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = None;
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = None;
              };
            ];
        };
      orchestrator.Orchestrator.children <-
        [
          {
            Orchestrator.pid;
            issue;
            issue_id = issue.id;
            issue_identifier = issue.identifier;
            issue_title = issue.title;
            workspace;
            started_at = Unix.time () -. 10.;
            last_output_at = Unix.time ();
            stdout_path = Some stdout_path;
            stderr_path = None;
            stdout_size = (Unix.stat stdout_path).Unix.st_size;
            stderr_size = 0;
          };
        ];
      Orchestrator.reap_children orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "timeout total tokens parsed" 8 state.codex_totals.total_tokens;
      Alcotest.(check int) "running removed" 0 (List.length state.running);
      Alcotest.(check int) "retrying added" 1 (List.length state.retrying);
      (match state.retrying with
      | retry :: _ -> (
          match retry.goal_usage with
          | Some usage ->
              Alcotest.(check (option string)) "retry goal status preserved" (Some "active") usage.status;
              Alcotest.(check (option int)) "retry goal tokens preserved" (Some 8) usage.tokens_used
          | None -> Alcotest.fail "expected retry goal usage")
      | [] -> Alcotest.fail "expected retrying row");
      let saw_goal_usage =
        List.exists
          (fun (state : Runtime_state.t) ->
            List.exists
              (fun (row : Runtime_state.running) ->
                match row.goal_usage with
                | Some usage -> usage.status = Some "active" && usage.tokens_used = Some 8
                | None -> false)
              state.running)
          !snapshots
      in
      Alcotest.(check bool) "timeout goal usage exposed before retry" true saw_goal_usage)

let test_orchestrator_preserves_goal_usage_on_blocked_issue_error () =
  with_temp_dir "symphony-blocked-goal-usage-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = None;
              project_status_on_retry = None;
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"Blocked usage" ~state:"Todo" in
      let orchestrator = Orchestrator.make ~fetch:(fun _ -> []) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.set_state orchestrator
        {
          (Runtime_state.empty ()) with
          running =
            [
              {
                Runtime_state.issue;
                session_id = Some "pid:block";
                turn_count = 0;
                last_event = Some "agent_output";
                last_message = Some "stdout/stderr updated";
                started_at = "2026-05-04T00:00:00Z";
                last_event_at = Some "2026-05-04T00:00:10Z";
                tokens = { input_tokens = 0; output_tokens = 0; total_tokens = 0 };
                goal_usage = Some { Runtime_state.status = Some "blocked"; time_used_seconds = Some 10.; tokens_used = Some 77 };
              };
            ];
        };
      Orchestrator.mark_blocked orchestrator issue.id "commit required but agent produced no code changes";
      match (Orchestrator.get_state orchestrator).issue_errors with
      | issue_error :: _ -> (
          match issue_error.goal_usage with
          | Some usage ->
              Alcotest.(check (option string)) "blocked goal status" (Some "blocked") usage.status;
              Alcotest.(check (option int)) "blocked goal tokens" (Some 77) usage.tokens_used
          | None -> Alcotest.fail "expected blocked goal usage")
      | [] -> Alcotest.fail "expected issue error")

let test_ready_terminal_mode_runs_orchestrator () =
  Alcotest.(check bool) "ready terminal loops" true
    (Runtime_policy.action ~mode:Cli_mode.Terminal_console ~readiness_gaps:[] = Runtime_policy.Run_orchestrator);
  Alcotest.(check bool) "gapped terminal serves readiness state" true
    (Runtime_policy.action ~mode:Cli_mode.Terminal_console
       ~readiness_gaps:[ { Runtime_state.requirement = "tracker.owner"; remediation = "set owner" } ]
    = Runtime_policy.Serve_readiness_state)

let test_github_project_field_parsing () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo"; "In Progress" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node =
    Yojson.Safe.from_string
      {|{
  "id": "I_1",
  "number": 42,
  "title": "Fix parser",
  "body": "Body",
  "url": "https://github.example/acme/widgets/issues/42",
  "createdAt": "2026-01-01T00:00:00Z",
  "updatedAt": "2026-01-02T00:00:00Z",
  "labels": { "nodes": [{ "name": "Bug" }] },
  "projectItems": {
    "nodes": [
      {
        "project": { "number": 99 },
        "fieldValues": { "nodes": [{ "name": "Done", "field": { "name": "Status" } }] }
      },
      {
        "project": { "number": 7 },
        "fieldValues": { "nodes": [{ "name": "In Progress", "field": { "name": "Status" } }] }
      }
    ]
  }
}|}
  in
  match Github_tracker.issue_from_project_node ~config node with
  | None -> Alcotest.fail "expected active issue from matching project"
  | Some issue ->
      Alcotest.(check string) "identifier" "#42" issue.identifier;
      Alcotest.(check string) "status" "In Progress" issue.state;
      Alcotest.(check (list string)) "labels lowercased" [ "bug" ] issue.labels

let test_github_active_state_filtering () =
  let base_config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 7;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node ?(issue_state = "OPEN") status =
    Yojson.Safe.from_string
      (Printf.sprintf
         {|{
  "id": "I_1",
  "number": 42,
  "state": %S,
  "title": "Fix parser",
  "labels": { "nodes": [] },
  "projectItems": { "nodes": [
    { "project": { "number": 7 }, "fieldValues": { "nodes": [
      { "name": %S, "field": { "name": "Status" } }
    ] } }
  ] }
}|}
         issue_state status)
  in
  Alcotest.(check bool) "todo included" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node "Todo")));
  Alcotest.(check bool) "done visible" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node "Done")));
  Alcotest.(check bool) "closed done visible" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node ~issue_state:"CLOSED" "Done")));
  Alcotest.(check bool) "closed active issue excluded" true
    (Option.is_none (Github_tracker.issue_from_project_node ~config:base_config (node ~issue_state:"CLOSED" "Todo")));
  Alcotest.(check bool) "unconfigured status excluded" true
    (Option.is_none (Github_tracker.issue_from_project_node ~config:base_config (node "In review")));
  Alcotest.(check bool) "missing project excluded" true
    (Option.is_none
       (Github_tracker.issue_from_project_node
          ~config:{ base_config with Config.project_number = 99 }
          (node "Todo")))

let test_github_empty_project_field_values_are_ignored () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 2;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "To-Do" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let node =
    Yojson.Safe.from_string
      {|{
  "id": "I_2",
  "number": 2,
  "title": "Replicate pi-agent IPC",
  "labels": { "nodes": [] },
  "projectItems": { "nodes": [
    { "project": { "number": 2 }, "fieldValues": { "nodes": [
      {},
      {},
      { "name": "To-Do", "field": { "name": "Status" } }
    ] } }
  ] }
}|}
  in
  match Github_tracker.issue_from_project_node ~config node with
  | None -> Alcotest.fail "expected empty field value placeholders to be ignored"
  | Some issue -> Alcotest.(check string) "status" "To-Do" issue.state

let test_github_status_metadata_parsing () =
  let config =
    {
      Config.kind = "github";
      owner = "acme";
      repo = "widgets";
      project_number = 2;
      api_key_env = "GITHUB_TOKEN";
      api_key = Some "token";
      active_states = [ "Todo" ];
      terminal_states = [ "Done" ];
      project_status_field = "Status";
      project_status_on_dispatch = Some "In progress";
      project_status_on_success = Some "In review";
      project_status_on_retry = Some "Todo";
      ensure_project_statuses = true;
    }
  in
  let json =
    Yojson.Safe.from_string
      {|{
  "data": {
    "repositoryOwner": {
      "projectV2": {
        "id": "PVT_1",
        "fields": { "nodes": [
          {},
          { "id": "PVTSSF_status", "name": "Status", "options": [
            { "id": "todo", "name": "Todo", "color": "GRAY", "description": "" },
            { "id": "doing", "name": "In Progress", "color": "YELLOW", "description": "" }
          ] }
        ] }
      }
    },
    "node": {
      "projectItems": { "nodes": [
        { "id": "PVTI_other", "project": { "number": 1 } },
        { "id": "PVTI_item", "project": { "number": 2 } }
      ] }
    }
  }
}|}
  in
  match Github_tracker.status_metadata_from_json ~config json with
  | Error error -> Alcotest.fail error
  | Ok metadata ->
      Alcotest.(check string) "project id" "PVT_1" metadata.project_id;
      Alcotest.(check string) "item id" "PVTI_item" metadata.item_id;
      Alcotest.(check string) "field id" "PVTSSF_status" metadata.field_id;
      Alcotest.(check int) "options" 2 (List.length metadata.options)

let test_orchestrator_dispatch_limits () =
  with_temp_dir "symphony-orchestrator-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Two" ~state:"Todo";
          Issue.empty ~id:"I3" ~identifier:"#3" ~title:"Three" ~state:"Todo";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.id :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = issues in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "running limited" 2 (List.length state.Runtime_state.running);
      Alcotest.(check int) "launch count limited" 2 (List.length !launched);
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "still capped" 2 (List.length state.Runtime_state.running))

let test_orchestrator_does_not_dispatch_terminal_issues () =
  with_temp_dir "symphony-orchestrator-terminal-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "Done";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issues =
        [
          Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo";
          Issue.empty ~id:"I2" ~identifier:"#2" ~title:"Two" ~state:"Done";
        ]
      in
      let launched = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        launched := issue.Issue.id :: !launched;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = issues in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "all board issues visible" 2 (List.length state.Runtime_state.issues);
      Alcotest.(check (list string)) "only active issue launched" [ "I1" ] (List.rev !launched))

let test_orchestrator_retries_failed_agent () =
  with_temp_dir "symphony-orchestrator-retry-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "false"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let fetch _ = [ issue ] in
      let set_status _ _ _ = Ok () in
      let orchestrator = Orchestrator.make ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "no longer running" 0 (List.length state.Runtime_state.running);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      match state.retrying with
      | retry :: _ ->
          Alcotest.(check string) "retry issue" "I1" retry.issue_id;
          Alcotest.(check int) "retry attempt" 1 retry.attempt
      | [] -> Alcotest.fail "expected retry row")

let test_orchestrator_moves_status_to_review_on_success () =
  with_temp_dir "symphony-orchestrator-status-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo"; "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let current_status = ref "Todo" in
      let fetch _ =
        if List.exists (fun status -> String.lowercase_ascii status = String.lowercase_ascii !current_status) config.tracker.active_states
        then [ { issue with state = !current_status } ]
        else []
      in
      let statuses = ref [] in
      let set_status _ issue status =
        current_status := status;
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Unix.sleepf 0.05;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list (pair string string))) "status transitions"
        [ ("#1", "In progress"); ("#1", "In review") ]
        (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "completed agent removed" 0 (List.length state.Runtime_state.running))

let test_orchestrator_uses_stage_agent_prompt_and_status () =
  with_temp_dir "symphony-stage-agent-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "reviewer.md") "Reviewer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In review" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In review" ];
                    agent = "reviewer";
                    start_status = None;
                    success_status = Some "Done";
                    retry_status = Some "In progress";
                    goal = None;
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In review" in
      let current_status = ref "In review" in
      let fetch _ = if !current_status = "In review" then [ { issue with state = !current_status } ] else [] in
      let statuses = ref [] in
      let captured_prompt = ref "" in
      let set_status _ issue status =
        current_status := status;
        statuses := (issue.Issue.identifier, status) :: !statuses;
        Ok ()
      in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }} {{ issue.title }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "reviewer prompt included" true (String.contains !captured_prompt 'R');
      Alcotest.(check bool) "base prompt included" true (String.contains !captured_prompt '#');
      Alcotest.(check (list (pair string string))) "no start status for review" [] (List.rev !statuses);
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list (pair string string))) "review moves done" [ ("#1", "Done") ] (List.rev !statuses))

let test_orchestrator_prepends_stage_goal_handoff () =
  with_temp_dir "symphony-stage-goal-prompt-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "engineer.md") "Engineer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = Some { enabled = true };
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue =
        {
          (Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo") with
          description = Some "Build the feature";
          url = Some "https://example.test/issues/1";
          labels = [ "enhancement"; "codex" ];
          priority = Some 2;
          blocked_by = [ { Issue.id = Some "I0"; identifier = Some "#0"; state = Some "Done" } ];
          created_at = Some "2026-01-01T00:00:00Z";
        }
      in
      let captured_prompt = ref "" in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator = Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Normal {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "goal command first" true (String.starts_with ~prefix:"/goal {\"kind\":\"Stage Goal Context\"" !captured_prompt);
      Alcotest.(check bool) "stage agent included" true (String.contains !captured_prompt 'E');
      Alcotest.(check bool) "normal prompt included" true (String.contains !captured_prompt '#');
      let goal_line =
        match String.split_on_char '\n' !captured_prompt with
        | first :: _ -> first
        | [] -> Alcotest.fail "expected prompt"
      in
      let goal_json = String.sub goal_line 6 (String.length goal_line - 6) |> Yojson.Safe.from_string in
      let open Yojson.Safe.Util in
      Alcotest.(check string) "goal kind" "Stage Goal Context" (goal_json |> member "kind" |> to_string);
      Alcotest.(check string) "goal issue" "#1" (goal_json |> member "issue_identifier" |> to_string);
      Alcotest.(check string) "goal description" "Build the feature" (goal_json |> member "description" |> to_string);
      Alcotest.(check (list string)) "goal labels" [ "enhancement"; "codex" ]
        (goal_json |> member "labels" |> to_list |> List.map to_string);
      Alcotest.(check int) "goal priority" 2 (goal_json |> member "priority" |> to_int);
      Alcotest.(check string) "goal blocker" "#0"
        (goal_json |> member "blocker_references" |> to_list |> List.hd |> member "identifier" |> to_string);
      Alcotest.(check bool) "created timestamp omitted" true
        (match goal_json |> member "created_at" with `Null -> true | _ -> false);
      Alcotest.(check bool) "updated timestamp omitted" true
        (match goal_json |> member "updated_at" with `Null -> true | _ -> false))

let test_orchestrator_skips_stage_goal_when_disabled () =
  with_temp_dir "symphony-stage-goal-disabled-prompt-" (fun root ->
      let agents_root = Filename.concat root "agents" in
      Unix.mkdir agents_root 0o755;
      Util.write_file (Filename.concat agents_root "engineer.md") "Engineer stage instructions";
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "Todo" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = None;
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = agents_root;
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "Todo" ];
                    agent = "engineer";
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = Some { enabled = false };
                    commit = None;
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"Todo" in
      let captured_prompt = ref "" in
      let launch ~config:_ ~workspace:_ ~prompt ~issue =
        captured_prompt := prompt;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator = Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Normal {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check bool) "no goal command" false (String.starts_with ~prefix:"/goal" !captured_prompt);
      Alcotest.(check bool) "stage agent still included" true (String.contains !captured_prompt 'E');
      Alcotest.(check bool) "normal prompt still included" true (String.contains !captured_prompt '#'))

let test_parse_goal_usage_from_codex_output () =
  with_temp_dir "symphony-goal-usage-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      Util.write_file stdout_path
        {|noise
Goal Usage: {"goal_usage":{"status":"complete","time_used_seconds":12.5,"tokens_used":345}}
|};
      match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "status" (Some "complete") usage.status;
          Alcotest.(check (option (float 0.01))) "time" (Some 12.5) usage.time_used_seconds;
          Alcotest.(check (option int)) "tokens" (Some 345) usage.tokens_used)

let test_parse_goal_usage_variants_and_ignores_invalid () =
  with_temp_dir "symphony-goal-usage-variants-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      let stderr_path = Filename.concat root "stderr.log" in
      Util.write_file stdout_path "Goal Usage: not json\n";
      Alcotest.(check bool) "invalid ignored" true (Option.is_none (Orchestrator.parse_goal_usage (Some stdout_path) None));
      Util.write_file stdout_path {|{"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      Alcotest.(check bool) "bare non-goal json ignored" true
        (Option.is_none (Orchestrator.parse_goal_usage (Some stdout_path) None));
      Util.write_file stdout_path {|Goal Usage: {"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      (match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected prefixed top-level goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "prefixed status" (Some "active") usage.status;
          Alcotest.(check (option int)) "prefixed tokens" (Some 44) usage.tokens_used);
      Util.write_file stderr_path {|goal usage: {"status":"active","timeUsedSeconds":3,"tokensUsed":44}|};
      match Orchestrator.parse_goal_usage (Some stdout_path) (Some stderr_path) with
      | None -> Alcotest.fail "expected camel case goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "status" (Some "active") usage.status;
          Alcotest.(check (option (float 0.01))) "time" (Some 3.) usage.time_used_seconds;
          Alcotest.(check (option int)) "tokens" (Some 44) usage.tokens_used)

let test_parse_goal_usage_nested_usage_fields () =
  with_temp_dir "symphony-goal-usage-nested-" (fun root ->
      let stdout_path = Filename.concat root "stdout.log" in
      Util.write_file stdout_path
        {|{"goalUsage":{"goalStatus":"complete","durationSeconds":7.25,"tokenUsage":{"totalTokens":88}}}|};
      match Orchestrator.parse_goal_usage (Some stdout_path) None with
      | None -> Alcotest.fail "expected nested goal usage"
      | Some usage ->
          Alcotest.(check (option string)) "nested status" (Some "complete") usage.status;
          Alcotest.(check (option (float 0.01))) "nested time" (Some 7.25) usage.time_used_seconds;
          Alcotest.(check (option int)) "nested tokens" (Some 88) usage.tokens_used)

let test_orchestrator_commits_stage_before_success_status () =
  with_temp_dir "symphony-stage-commit-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "fixture"; message = "<type>: <generated_message_max_90char>"; push = false };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let events = ref [] in
      let set_status _ _ status =
        events := ("status:" ^ status) :: !events;
        Ok ()
      in
      let commit_stage _ _workspace issue stage next_status =
        let message =
          match stage with
          | Some { Config.commit = Some policy; _ } -> Orchestrator.render_commit_message issue stage next_status policy
          | _ -> Alcotest.fail "expected stage commit policy"
        in
        events := ("commit:" ^ message) :: !events;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~commit_stage ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list string)) "commit before status" [ "commit:fixture: complete #1 One"; "status:In review" ] (List.rev !events))

let test_orchestrator_retries_when_success_status_move_fails () =
  with_temp_dir "symphony-status-failure-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In review" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "Done";
              project_status_on_retry = Some "In progress";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In review" in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let fetch _ = [ issue ] in
      let set_status _ _ status = if status = "Done" then Error "bad option id" else Ok () in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "running removed" 0 (List.length state.Runtime_state.running);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      match state.retrying with
      | retry :: _ ->
          Alcotest.(check string) "retry issue" "I1" retry.issue_id;
          Alcotest.(check int) "retry attempt" 1 retry.attempt
      | [] -> Alcotest.fail "expected retry row")

let test_orchestrator_retries_push_failure_before_success_status () =
  with_temp_dir "symphony-push-failure-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = true };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let commit_stage _ _ _ _ _ = Error "stage push failed: exit 1: remote rejected" in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~commit_stage ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      statuses := [];
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check (list string)) "retry status only" [ "Todo" ] (List.rev !statuses);
      Alcotest.(check int) "retry queued" 1 (List.length state.retrying);
      Alcotest.(check (option string)) "last error" (Some "stage push failed: exit 1: remote rejected") state.last_error)

let test_stage_commit_requires_code_changes () =
  with_temp_dir "symphony-empty-commit-" (fun root ->
      Alcotest.(check int) "git init" 0 (Sys.command ("git init -q " ^ Util.shell_quote root));
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let stage =
        Some
          {
            Config.states = [ "In progress" ];
            agent = "engineer";
            start_status = None;
            success_status = Some "In review";
            retry_status = Some "Todo";
            goal = None;
            commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = false };
          }
      in
      let workspace = { Workspace.path = root; workspace_key = "test"; created_now = false } in
      match Orchestrator.git_commit_stage_changes config workspace issue stage (Some "In review") with
      | Ok () -> Alcotest.fail "empty commit-required stages must fail"
      | Error error -> Alcotest.(check string) "empty commit error" "commit required but agent produced no code changes" error)

let test_orchestrator_does_not_retry_empty_commit () =
  with_temp_dir "symphony-empty-commit-block-" (fun root ->
      let config =
        {
          Config.workflow_path = "settings.json";
          repository_root = root;
          tracker =
            {
              kind = "github";
              owner = "acme";
              repo = "widgets";
              project_number = 7;
              api_key_env = "GITHUB_TOKEN";
              api_key = Some "token";
              active_states = [ "In progress" ];
              terminal_states = [ "Done" ];
              project_status_field = "Status";
              project_status_on_dispatch = Some "In progress";
              project_status_on_success = Some "In review";
              project_status_on_retry = Some "Todo";
              ensure_project_statuses = true;
            };
          polling = { interval_ms = 1000 };
          workspace = { root = Filename.concat root "workspaces" };
          git = Config.default_git;
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; model = Config.default_model; reasoning_effort = Config.default_reasoning_effort; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
          pull_request = Config.default_pull_request;
          stage_agents =
            {
              enabled = true;
              root = Filename.concat root "agents";
              default_agent = None;
              stages =
                [
                  {
                    Config.states = [ "In progress" ];
                    agent = "engineer";
                    start_status = None;
                    success_status = Some "In review";
                    retry_status = Some "Todo";
                    goal = None;
                    commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message; push = false };
                  };
                ];
            };
        }
      in
      let issue = Issue.empty ~id:"I1" ~identifier:"#1" ~title:"One" ~state:"In progress" in
      let launches = ref 0 in
      let statuses = ref [] in
      let fetch _ = [ issue ] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let commit_stage _ _ _ _ _ = Error "commit required but agent produced no code changes" in
      let orchestrator = Orchestrator.make ~launch ~fetch ~set_status ~commit_stage ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "first launch" 1 !launches;
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace = { Workspace.path = root; workspace_key = "test"; created_now = false };
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "no immediate relaunch" 1 !launches;
      Alcotest.(check (list string)) "moves no-change issue out of in-progress" [ "Todo" ] (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "not retrying" 0 (List.length state.retrying);
      Alcotest.(check int) "issue error recorded" 1 (List.length state.issue_errors);
      Alcotest.(check (option string)) "last error" (Some "commit required but agent produced no code changes") state.last_error)

let base_orchestrator_config root git =
  {
    Config.workflow_path = "settings.json";
    repository_root = root;
    tracker =
      {
        kind = "github";
        owner = "acme";
        repo = "widgets";
        project_number = 7;
        api_key_env = "GITHUB_TOKEN";
        api_key = Some "token";
        active_states = [ "Todo"; "In progress" ];
        terminal_states = [ "Done" ];
        project_status_field = "Status";
        project_status_on_dispatch = Some "In progress";
        project_status_on_success = Some "In review";
        project_status_on_retry = Some "Todo";
        ensure_project_statuses = true;
      };
    polling = { interval_ms = 1000 };
    workspace = { root = Filename.concat root ".symphony/workspaces" };
    git;
    agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
    codex =
      {
        command = "true";
        model = Config.default_model;
        reasoning_effort = Config.default_reasoning_effort;
        turn_timeout_ms = 1000;
        read_timeout_ms = 100;
        stall_timeout_ms = 1000;
    };
    server = { port = None };
    pull_request = Config.default_pull_request;
    stage_agents = { enabled = false; root = Filename.concat root "agents"; default_agent = None; stages = [] };
  }

let test_orchestrator_creates_task_worktree_and_branch () =
  with_temp_dir "symphony-task-worktree-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I1" ~identifier:"#3" ~title:"Three" ~state:"Todo" in
      let captured_workspace = ref None in
      let launch ~config:_ ~(workspace : Workspace.t) ~prompt:_ ~issue =
        captured_workspace := Some workspace;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      let workspace = match !captured_workspace with Some workspace -> workspace | None -> Alcotest.fail "expected launch" in
      Alcotest.(check bool) "under runtime workspaces" true (Workspace.is_inside ~root:config.workspace.root ~path:workspace.path);
      Alcotest.(check string) "task branch" "symphony/task-3" (run_ok ~cwd:workspace.path "branch" "git branch --show-current");
      Alcotest.(check bool) "task branch exists" true
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-3") = 0);
      Alcotest.(check (list string)) "start status moved" [ "In progress" ] (List.rev !statuses))

let pull_request_config config =
  {
    config with
    Config.pull_request =
      {
        enabled = true;
        base_branch = "main";
        title = "Symphony batch from <head_branch>";
        body = "Opened automatically by Symphony after orchestration became idle.";
      };
  }

let test_orchestrator_opens_batch_pull_request_once_when_idle () =
  with_temp_dir "symphony-batch-pr-idle-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref [] in
      let batch_pull_request_handoff _config ~head_branch =
        attempts := head_branch :: !attempts;
        Ok (Some "https://github.example/acme/widgets/pull/1")
      in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~batch_pull_request_handoff ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (list string)) "handoff attempted once" [ "feature/start" ] (List.rev !attempts);
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "status" "completed" handoff.status;
          Alcotest.(check (option string)) "url" (Some "https://github.example/acme/widgets/pull/1") handoff.url
      | None -> Alcotest.fail "expected pull request handoff state")

let test_orchestrator_retries_batch_pull_request_handoff_failure () =
  with_temp_dir "symphony-batch-pr-retry-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref 0 in
      let batch_pull_request_handoff _config ~head_branch:_ =
        incr attempts;
        if !attempts = 1 then Error "batch branch push failed: exit 1: rejected" else Ok None
      in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> []) ~batch_pull_request_handoff ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      (match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff ->
          Alcotest.(check string) "failure status" "retryable_failure" handoff.status;
          Alcotest.(check (option string)) "failure error" (Some "batch branch push failed: exit 1: rejected") handoff.error
      | None -> Alcotest.fail "expected failed handoff state");
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "retried on later idle poll" 2 !attempts;
      match (Orchestrator.get_state orchestrator).Runtime_state.pull_request with
      | Some handoff -> Alcotest.(check string) "eventual status" "completed" handoff.status
      | None -> Alcotest.fail "expected completed handoff state")

let test_orchestrator_blocks_batch_pull_request_on_attention () =
  with_temp_dir "symphony-batch-pr-attention-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) |> pull_request_config in
      let attempts = ref 0 in
      let batch_pull_request_handoff _config ~head_branch:_ =
        incr attempts;
        Ok None
      in
      let issue = Issue.empty ~id:"I-attn" ~identifier:"#99" ~title:"Needs merge" ~state:"Human attention" in
      let orchestrator =
        Orchestrator.make ~fetch:(fun _ -> [ issue ]) ~batch_pull_request_handoff ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "no handoff while attention remains" 0 !attempts;
      Alcotest.(check bool) "no handoff state" true
        (Option.is_none (Orchestrator.get_state orchestrator).Runtime_state.pull_request))

let test_batch_pull_request_handoff_reuses_existing_pr () =
  with_temp_dir "symphony-batch-pr-existing-" (fun root ->
      let remote = Filename.concat root "remote.git" in
      let repo = Filename.concat root "repo" in
      let bin = Filename.concat root "bin" in
      Unix.mkdir repo 0o755;
      Unix.mkdir bin 0o755;
      ignore (run_ok ~cwd:root "bare remote" ("git init -q --bare " ^ Util.shell_quote remote));
      init_repo repo "feature/start";
      ignore (run_ok ~cwd:repo "add origin" ("git remote add origin " ^ Util.shell_quote remote));
      let gh_log = Filename.concat root "gh.log" in
      let gh_path = Filename.concat bin "gh" in
      Util.write_file gh_path
        (Printf.sprintf
           {|#!/bin/sh
printf '%%s\n' "$*" >> %s
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  printf '[{"url":"https://github.example/acme/widgets/pull/9"}]\n'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "create" ]; then
  exit 42
fi
exit 1
|}
           (Util.shell_quote gh_log));
      Unix.chmod gh_path 0o755;
      let original_path = Sys.getenv_opt "PATH" in
      Fun.protect
        ~finally:(fun () -> match original_path with Some path -> Unix.putenv "PATH" path | None -> Unix.putenv "PATH" "")
        (fun () ->
          Unix.putenv "PATH" (bin ^ ":" ^ Option.value original_path ~default:"");
          let config = base_orchestrator_config repo (git_policy ()) |> pull_request_config in
          match Orchestrator.gh_batch_pull_request_handoff config ~head_branch:"feature/start" with
          | Error error -> Alcotest.fail error
          | Ok url ->
              Alcotest.(check (option string)) "existing PR URL" (Some "https://github.example/acme/widgets/pull/9") url;
              Alcotest.(check bool) "remote loop-start branch pushed" true
                (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/feature/start") = 0);
              let lines = Util.read_file gh_log |> Util.split_lines in
              Alcotest.(check bool) "looked for existing PR" true
                (List.exists (Util.starts_with ~prefix:"pr list") lines);
              Alcotest.(check bool) "did not create duplicate" false
                (List.exists (Util.starts_with ~prefix:"pr create") lines)))

let test_orchestrator_requires_clean_loop_start_for_new_worktree () =
  with_temp_dir "symphony-dirty-loop-" (fun root ->
      init_repo root "feature/start";
      Util.write_file (Filename.concat root "dirty.txt") "dirty\n";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I2" ~identifier:"#4" ~title:"Four" ~state:"Todo" in
      let launches = ref 0 in
      let statuses = ref [] in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "not launched" 0 !launches;
      Alcotest.(check (list string)) "moves to attention without in-progress" [ "Human attention" ] (List.rev !statuses);
      Alcotest.(check (option string)) "last error"
        (Some "loop-start worktree must be clean before creating task worktrees")
        (Orchestrator.get_state orchestrator).last_error;
      Alcotest.(check bool) "no placeholder worktree left" false
        (Sys.file_exists (Filename.concat config.workspace.root "_4")))

let test_orchestrator_reuses_existing_task_branch_on_restart () =
  with_temp_dir "symphony-reuse-task-branch-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I6" ~identifier:"#8" ~title:"Eight" ~state:"In progress" in
      ignore (run_ok ~cwd:root "create task branch" "git branch symphony/task-8 feature/start");
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Alcotest.(check string) "reused branch checked out" "symphony/task-8"
        (run_ok ~cwd:workspace.path "branch" "git branch --show-current"))

let test_orchestrator_reuses_worktree_for_existing_in_progress_task_before_launch () =
  with_temp_dir "symphony-existing-progress-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I9" ~identifier:"#11" ~title:"Eleven" ~state:"In progress" in
      ignore (run_ok ~cwd:root "create task branch" "git branch symphony/task-11 feature/start");
      let launched_branch = ref None in
      let launch ~config:_ ~(workspace : Workspace.t) ~prompt:_ ~issue =
        launched_branch := Some (run_ok ~cwd:workspace.path "branch" "git branch --show-current");
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status:(fun _ _ _ -> Ok ()) ~config
          ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check (option string)) "launched from reused task branch" (Some "symphony/task-11") !launched_branch)

let test_orchestrator_rejects_existing_non_worktree_workspace () =
  with_temp_dir "symphony-existing-non-worktree-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ()) in
      let issue = Issue.empty ~id:"I10" ~identifier:"#12" ~title:"Twelve" ~state:"In progress" in
      Util.mkdir_p config.workspace.root;
      let stale_workspace = Filename.concat config.workspace.root "_12" in
      Unix.mkdir stale_workspace 0o755;
      let launches = ref 0 in
      let launch ~config:_ ~workspace:_ ~prompt:_ ~issue =
        incr launches;
        { Orchestrator.pid = None; session_id = Some issue.Issue.id; event = "test-launch"; stdout_path = None; stderr_path = None }
      in
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator =
        Orchestrator.make ~launch ~fetch:(fun _ -> [ issue ]) ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" ()
      in
      Orchestrator.poll_once orchestrator;
      Alcotest.(check int) "not launched" 0 !launches;
      Alcotest.(check (list string)) "attention status" [ "Human attention" ] (List.rev !statuses);
      Alcotest.(check (option string)) "last error"
        (Some (stale_workspace ^ " exists but is not an Agent Worktree"))
        (Orchestrator.get_state orchestrator).last_error)

let test_stage_commit_pushes_task_branch () =
  with_temp_dir "symphony-stage-push-" (fun root ->
      let remote = Filename.concat root "remote.git" in
      let repo = Filename.concat root "repo" in
      Unix.mkdir repo 0o755;
      ignore (run_ok ~cwd:root "bare remote" ("git init -q --bare " ^ Util.shell_quote remote));
      init_repo repo "feature/start";
      ignore (run_ok ~cwd:repo "add origin" ("git remote add origin " ^ Util.shell_quote remote));
      let config = base_orchestrator_config repo (git_policy ()) in
      let issue = Issue.empty ~id:"I3" ~identifier:"#5" ~title:"Five" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "work.txt") "work\n";
      let stage =
        Some
          {
            Config.states = [ "In progress" ];
            agent = "engineer";
            start_status = None;
            success_status = Some "In review";
            retry_status = Some "Todo";
            goal = None;
            commit = Some { enabled = true; commit_type = "feat"; message = Config.default_commit_message; push = true };
          }
      in
      (match Orchestrator.git_commit_stage_changes config workspace issue stage (Some "In review") with
      | Ok () -> ()
      | Error error -> Alcotest.fail error);
      Alcotest.(check bool) "remote task branch exists" true
        (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/symphony/task-5") = 0);
      Alcotest.(check bool) "loop-start branch not pushed" false
        (Sys.command ("git --git-dir " ^ Util.shell_quote remote ^ " show-ref --verify --quiet refs/heads/feature/start") = 0))

let test_auto_merge_fast_forwards_and_removes_worktree () =
  with_temp_dir "symphony-auto-merge-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I4" ~identifier:"#6" ~title:"Six" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "merged.txt") "merged\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add merged.txt && git commit -q -m task");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "merged file present" true (Sys.file_exists (Filename.concat root "merged.txt"));
      Alcotest.(check bool) "worktree removed" false (Sys.file_exists workspace.path);
      Alcotest.(check bool) "task branch kept" true
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-6") = 0);
      Alcotest.(check (list string)) "success status after merge" [ "In review" ] (List.rev !statuses))

let test_cleanup_can_remove_task_branch_after_merge () =
  with_temp_dir "symphony-cleanup-branch-" (fun root ->
      init_repo root "feature/start";
      let git =
        {
          (git_policy ~auto_merge:true ()) with
          cleanup = { Config.remove_worktree_after_merge = true; keep_task_branch = false };
        }
      in
      let config = base_orchestrator_config root git in
      let issue = Issue.empty ~id:"I7" ~identifier:"#9" ~title:"Nine" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "cleanup.txt") "cleanup\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add cleanup.txt && git commit -q -m task");
      let orchestrator = Orchestrator.make ~set_status:(fun _ _ _ -> Ok ()) ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "task branch removed" false
        (Sys.command ("cd " ^ Util.shell_quote root ^ " && git show-ref --verify --quiet refs/heads/symphony/task-9") = 0))

let test_auto_merge_skips_protected_trunk_branch () =
  with_temp_dir "symphony-protected-trunk-" (fun root ->
      init_repo root "main";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I8" ~identifier:"#10" ~title:"Ten" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"main" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "protected.txt") "protected\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add protected.txt && git commit -q -m task");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check bool) "not merged into main" false (Sys.file_exists (Filename.concat root "protected.txt"));
      Alcotest.(check bool) "worktree kept" true (Sys.file_exists workspace.path);
      Alcotest.(check (list string)) "still advances status" [ "In review" ] (List.rev !statuses))

let test_auto_merge_failure_moves_human_attention () =
  with_temp_dir "symphony-auto-merge-fail-" (fun root ->
      init_repo root "feature/start";
      let config = base_orchestrator_config root (git_policy ~auto_merge:true ()) in
      let issue = Issue.empty ~id:"I5" ~identifier:"#7" ~title:"Seven" ~state:"In progress" in
      let workspace =
        match Orchestrator.shell_prepare_workspace config ~loop_start_branch:"feature/start" issue with
        | Ok workspace -> workspace
        | Error error -> Alcotest.fail error
      in
      Util.write_file (Filename.concat workspace.path "task.txt") "task\n";
      ignore (run_ok ~cwd:workspace.path "task commit" "git add task.txt && git commit -q -m task");
      Util.write_file (Filename.concat root "loop.txt") "loop\n";
      ignore (run_ok ~cwd:root "loop commit" "git add loop.txt && git commit -q -m loop");
      let statuses = ref [] in
      let set_status _ _ status =
        statuses := status :: !statuses;
        Ok ()
      in
      let orchestrator = Orchestrator.make ~set_status ~config ~prompt_template:"Issue {{ issue.identifier }}" () in
      Orchestrator.mark_completed orchestrator
        {
          Orchestrator.pid = 0;
          issue;
          issue_id = issue.id;
          issue_identifier = issue.identifier;
          issue_title = issue.title;
          workspace;
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list string)) "attention status only" [ "Human attention" ] (List.rev !statuses);
      let state = Orchestrator.get_state orchestrator in
      Alcotest.(check int) "issue error" 1 (List.length state.issue_errors);
      Alcotest.(check bool) "worktree kept for inspection" true (Sys.file_exists workspace.path))

let () =
  Alcotest.run "symphony-backend"
    [
      ("workflow", [ Alcotest.test_case "parse config" `Quick test_workflow_and_config ]);
      ("prompt", [ Alcotest.test_case "strict render" `Quick test_prompt_strict_rendering ]);
      ("workspace", [ Alcotest.test_case "sanitize and reuse" `Quick test_workspace_safety ]);
      ("launch", [ Alcotest.test_case "runs agent in agent worktree" `Quick test_shell_launch_runs_agent_in_agent_worktree ]);
      ( "runtime-home",
        [
          Alcotest.test_case "bootstrap is idempotent" `Quick test_bootstrap_idempotency_preserves_user_files;
          Alcotest.test_case "requires git repository root" `Quick test_root_validation;
          Alcotest.test_case "loads settings and prompt" `Quick test_settings_and_prompt_loading;
          Alcotest.test_case "loads runtime env file" `Quick test_runtime_env_loading;
          Alcotest.test_case "rejects repo URL in settings" `Quick test_repo_url_readiness_gap;
          Alcotest.test_case "writes ignore rules" `Quick test_runtime_gitignore_contents;
        ] );
      ( "config",
        [
          Alcotest.test_case "reject non-github tracker" `Quick test_invalid_tracker_kind;
          Alcotest.test_case "normalizes legacy codex app-server command" `Quick test_legacy_codex_app_server_command_normalizes_to_exec;
          Alcotest.test_case "derives kanban status order from transitions" `Quick test_project_status_order_uses_transition_flow;
          Alcotest.test_case "parses git policy and stage push" `Quick test_config_parses_git_policy_and_stage_push;
          Alcotest.test_case "parses stage goal and readiness" `Quick test_config_parses_stage_goal_and_readiness;
          Alcotest.test_case "disabled stage goal does not require codex goals" `Quick test_disabled_stage_goal_does_not_require_codex_goals;
          Alcotest.test_case "stage goal requires codex exec stdin support" `Quick test_stage_goal_requires_codex_exec_stdin_support;
          Alcotest.test_case "stage goal live stdin probe" `Quick test_stage_goal_live_stdin_probe;
          Alcotest.test_case "requires pull request base branch when enabled" `Quick test_pull_request_base_branch_readiness_gap;
        ] );
      ( "runtime-state",
        [
          Alcotest.test_case "exposes running issue details" `Quick test_runtime_state_exposes_running_issue_details;
          Alcotest.test_case "exposes goal usage when available" `Quick test_runtime_state_exposes_goal_usage_when_available;
        ] );
      ( "server",
        [
          Alcotest.test_case "handles websocket upgrade and initial snapshot" `Quick test_websocket_accept_and_initial_snapshot;
          Alcotest.test_case "broadcasts after state change" `Quick test_websocket_broadcast_after_state_change;
          Alcotest.test_case "serves readiness live snapshot and diagnostic state" `Quick test_websocket_readiness_snapshot_and_http_state;
        ] );
      ( "cli",
        [
          Alcotest.test_case "selects terminal or web mode" `Quick test_cli_mode_selection;
          Alcotest.test_case "ready terminal mode runs orchestrator" `Quick test_ready_terminal_mode_runs_orchestrator;
        ] );
      ( "github-tracker",
        [
          Alcotest.test_case "parses project status field" `Quick test_github_project_field_parsing;
          Alcotest.test_case "filters active states" `Quick test_github_active_state_filtering;
          Alcotest.test_case "ignores empty project field values" `Quick test_github_empty_project_field_values_are_ignored;
          Alcotest.test_case "parses status update metadata" `Quick test_github_status_metadata_parsing;
        ] );
      ( "orchestrator",
        [
          Alcotest.test_case "enforces dispatch limits" `Quick test_orchestrator_dispatch_limits;
          Alcotest.test_case "does not dispatch terminal issues" `Quick test_orchestrator_does_not_dispatch_terminal_issues;
          Alcotest.test_case "retries failed agents" `Quick test_orchestrator_retries_failed_agent;
          Alcotest.test_case "moves status to review on success" `Quick test_orchestrator_moves_status_to_review_on_success;
          Alcotest.test_case "uses stage agent prompt and status" `Quick test_orchestrator_uses_stage_agent_prompt_and_status;
          Alcotest.test_case "prepends stage goal handoff" `Quick test_orchestrator_prepends_stage_goal_handoff;
          Alcotest.test_case "skips stage goal handoff when disabled" `Quick test_orchestrator_skips_stage_goal_when_disabled;
          Alcotest.test_case "parses goal usage output" `Quick test_parse_goal_usage_from_codex_output;
          Alcotest.test_case "parses goal usage variants" `Quick test_parse_goal_usage_variants_and_ignores_invalid;
          Alcotest.test_case "parses nested goal usage fields" `Quick test_parse_goal_usage_nested_usage_fields;
          Alcotest.test_case "commits stage before success status" `Quick test_orchestrator_commits_stage_before_success_status;
          Alcotest.test_case "retries when success status move fails" `Quick test_orchestrator_retries_when_success_status_move_fails;
          Alcotest.test_case "retries push failure before success status"
            `Quick test_orchestrator_retries_push_failure_before_success_status;
          Alcotest.test_case "stage commit requires code changes" `Quick test_stage_commit_requires_code_changes;
          Alcotest.test_case "does not retry empty required commits" `Quick test_orchestrator_does_not_retry_empty_commit;
          Alcotest.test_case "notifies repeated state mutations" `Quick test_orchestrator_notifies_each_state_mutation;
          Alcotest.test_case "parses final output when size was already seen"
            `Quick test_orchestrator_parses_final_output_when_size_was_already_seen;
          Alcotest.test_case "parses final output before timeout retry"
            `Quick test_orchestrator_parses_final_output_before_timeout_retry;
          Alcotest.test_case "preserves goal usage on blocked issue error"
            `Quick test_orchestrator_preserves_goal_usage_on_blocked_issue_error;
          Alcotest.test_case "creates task worktree and branch" `Quick test_orchestrator_creates_task_worktree_and_branch;
          Alcotest.test_case "opens batch pull request once when idle" `Quick test_orchestrator_opens_batch_pull_request_once_when_idle;
          Alcotest.test_case "retries failed batch pull request handoff" `Quick test_orchestrator_retries_batch_pull_request_handoff_failure;
          Alcotest.test_case "blocks batch pull request on attention" `Quick test_orchestrator_blocks_batch_pull_request_on_attention;
          Alcotest.test_case "reuses existing batch pull request" `Quick test_batch_pull_request_handoff_reuses_existing_pr;
          Alcotest.test_case "requires clean loop-start worktree" `Quick test_orchestrator_requires_clean_loop_start_for_new_worktree;
          Alcotest.test_case "reuses existing task branch on restart" `Quick test_orchestrator_reuses_existing_task_branch_on_restart;
          Alcotest.test_case "reuses worktree for existing in-progress task"
            `Quick test_orchestrator_reuses_worktree_for_existing_in_progress_task_before_launch;
          Alcotest.test_case "rejects existing non-worktree workspace" `Quick test_orchestrator_rejects_existing_non_worktree_workspace;
          Alcotest.test_case "pushes task branch after stage commit" `Quick test_stage_commit_pushes_task_branch;
          Alcotest.test_case "fast-forwards task branch and removes worktree" `Quick test_auto_merge_fast_forwards_and_removes_worktree;
          Alcotest.test_case "can remove task branch after merge" `Quick test_cleanup_can_remove_task_branch_after_merge;
          Alcotest.test_case "skips auto-merge on protected trunk" `Quick test_auto_merge_skips_protected_trunk_branch;
          Alcotest.test_case "moves merge failures to human attention" `Quick test_auto_merge_failure_moves_human_attention;
        ] );
    ]
