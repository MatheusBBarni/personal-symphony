let with_temp_file content f =
  let path = Filename.temp_file "workflow" ".md" in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      let oc = open_out path in
      output_string oc content;
      close_out oc;
      f path)

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

let () =
  Alcotest.run "symphony-backend"
    [
      ("workflow", [ Alcotest.test_case "parse config" `Quick test_workflow_and_config ]);
      ("prompt", [ Alcotest.test_case "strict render" `Quick test_prompt_strict_rendering ]);
      ("workspace", [ Alcotest.test_case "sanitize and reuse" `Quick test_workspace_safety ]);
      ("config", [ Alcotest.test_case "reject non-github tracker" `Quick test_invalid_tracker_kind ]);
    ]
