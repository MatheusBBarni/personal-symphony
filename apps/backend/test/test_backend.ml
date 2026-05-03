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
  with_temp_dir "symphony-settings-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let config = Config.from_settings_file ~workspace_root:root home.settings_path in
      Alcotest.(check string) "owner placeholder" "your-org" config.tracker.owner;
      Alcotest.(check string) "repo placeholder" "your-repo" config.tracker.repo;
      Alcotest.(check int) "project number" 1 config.tracker.project_number;
      Alcotest.(check string) "workspace root" (Filename.concat (Unix.realpath root) ".symphony/workspaces") config.workspace.root;
      Alcotest.(check int) "server port" 8080 (Option.get config.server.port);
      let prompt = Runtime_home.load_prompt home in
      let issue = Issue.empty ~id:"I" ~identifier:"#1" ~title:"Install CLI" ~state:"Todo" in
      let rendered = Prompt.render ~issue ~attempt:(Some 3) prompt in
      Alcotest.(check bool) "rendered issue identifier" true (String.contains rendered '#');
      let gaps = Config.readiness_gaps config in
      Alcotest.(check bool) "placeholder owner gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "tracker.owner") gaps);
      Alcotest.(check bool) "token gap" true
        (List.exists (fun (gap : Config.readiness_gap) -> gap.requirement = "environment.GITHUB_TOKEN") gaps))

let test_runtime_gitignore_contents () =
  with_temp_dir "symphony-ignore-" (fun root ->
      let home, _ = Runtime_home.bootstrap root in
      let contents = Util.read_file (Filename.concat home.runtime_dir ".gitignore") in
      Alcotest.(check bool) "ignores env" true (String.contains contents 'e');
      Alcotest.(check string) "exact ignore rules" "/.env\n/state/\n/workspaces/\n" contents)

let test_cli_mode_selection () =
  Alcotest.(check string) "terminal default" "terminal_console" (Cli_mode.(select ~web:false |> to_string));
  Alcotest.(check string) "web flag" "web_dashboard" (Cli_mode.(select ~web:true |> to_string))

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
          Alcotest.test_case "writes ignore rules" `Quick test_runtime_gitignore_contents;
        ] );
      ("config", [ Alcotest.test_case "reject non-github tracker" `Quick test_invalid_tracker_kind ]);
      ("cli", [ Alcotest.test_case "selects terminal or web mode" `Quick test_cli_mode_selection ]);
    ]
