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
  command: codex app-server
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
  Alcotest.(check string) "issue snapshot status" "In progress" (issue_row |> member "state" |> to_string)

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
  let node status =
    Yojson.Safe.from_string
      (Printf.sprintf
         {|{
  "id": "I_1",
  "number": 42,
  "title": "Fix parser",
  "labels": { "nodes": [] },
  "projectItems": { "nodes": [
    { "project": { "number": 7 }, "fieldValues": { "nodes": [
      { "name": %S, "field": { "name": "Status" } }
    ] } }
  ] }
}|}
         status)
  in
  Alcotest.(check bool) "todo included" true
    (Option.is_some (Github_tracker.issue_from_project_node ~config:base_config (node "Todo")));
  Alcotest.(check bool) "done excluded" true
    (Option.is_none (Github_tracker.issue_from_project_node ~config:base_config (node "Done")));
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
          agent = { max_concurrent_agents = 2; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "cat"; turn_timeout_ms = 1000; read_timeout_ms = 1000; stall_timeout_ms = 1000 };
          server = { port = None };
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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "false"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
          started_at = Unix.time ();
          last_output_at = Unix.time ();
          stdout_path = None;
          stderr_path = None;
          stdout_size = 0;
          stderr_size = 0;
        };
      Alcotest.(check (list (pair string string))) "review moves done" [ ("#1", "Done") ] (List.rev !statuses))

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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
                    commit = Some { enabled = true; commit_type = "fixture"; message = "<type>: <generated_message_max_90char>" };
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
      let commit_stage _ issue stage next_status =
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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
          agent = { max_concurrent_agents = 1; max_turns = 10; max_retry_backoff_ms = 1000 };
          codex = { command = "true"; turn_timeout_ms = 1000; read_timeout_ms = 100; stall_timeout_ms = 1000 };
          server = { port = None };
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
            commit = Some { enabled = true; commit_type = "feature"; message = Config.default_commit_message };
          }
      in
      match Orchestrator.git_commit_stage_changes config issue stage (Some "In review") with
      | Ok () -> Alcotest.fail "empty commit-required stages must fail"
      | Error error -> Alcotest.(check string) "empty commit error" "commit required but agent produced no code changes" error)

let () =
  Alcotest.run "symphony-backend"
    [
      ("workflow", [ Alcotest.test_case "parse config" `Quick test_workflow_and_config ]);
      ("prompt", [ Alcotest.test_case "strict render" `Quick test_prompt_strict_rendering ]);
      ("workspace", [ Alcotest.test_case "sanitize and reuse" `Quick test_workspace_safety ]);
      ( "runtime-home",
        [
          Alcotest.test_case "bootstrap is idempotent" `Quick test_bootstrap_idempotency_preserves_user_files;
          Alcotest.test_case "requires git repository root" `Quick test_root_validation;
          Alcotest.test_case "loads settings and prompt" `Quick test_settings_and_prompt_loading;
          Alcotest.test_case "loads runtime env file" `Quick test_runtime_env_loading;
          Alcotest.test_case "rejects repo URL in settings" `Quick test_repo_url_readiness_gap;
          Alcotest.test_case "writes ignore rules" `Quick test_runtime_gitignore_contents;
        ] );
      ("config", [ Alcotest.test_case "reject non-github tracker" `Quick test_invalid_tracker_kind ]);
      ("runtime-state", [ Alcotest.test_case "exposes running issue details" `Quick test_runtime_state_exposes_running_issue_details ]);
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
          Alcotest.test_case "retries failed agents" `Quick test_orchestrator_retries_failed_agent;
          Alcotest.test_case "moves status to review on success" `Quick test_orchestrator_moves_status_to_review_on_success;
          Alcotest.test_case "uses stage agent prompt and status" `Quick test_orchestrator_uses_stage_agent_prompt_and_status;
          Alcotest.test_case "commits stage before success status" `Quick test_orchestrator_commits_stage_before_success_status;
          Alcotest.test_case "retries when success status move fails" `Quick test_orchestrator_retries_when_success_status_move_fails;
          Alcotest.test_case "stage commit requires code changes" `Quick test_stage_commit_requires_code_changes;
        ] );
    ]
