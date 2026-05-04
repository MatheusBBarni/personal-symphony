type launch_result = {
  pid : int option;
  session_id : string option;
  event : string;
  stdout_path : string option;
  stderr_path : string option;
}

type launch =
  config:Config.t -> workspace:Workspace.t -> prompt:string -> issue:Issue.t -> launch_result

type fetch = Github_tracker.t -> Issue.t list
type set_status = Github_tracker.t -> Issue.t -> string -> (unit, string) result
type commit_stage = Config.t -> Workspace.t -> Issue.t -> Config.stage_agent option -> string option -> (unit, string) result
type batch_pull_request_handoff = Config.t -> head_branch:string -> (string option, string) result
type notify_state = Runtime_state.t -> unit

type t = {
  config : Config.t;
  prompt_template : string;
  tracker : Github_tracker.t;
  mutable state : Runtime_state.t;
  mutable children : child list;
  retry_due : (string, float) Hashtbl.t;
  attempts : (string, int) Hashtbl.t;
  blocked : (string, string) Hashtbl.t;
  launch : launch;
  fetch : fetch;
  set_status : set_status;
  commit_stage : commit_stage;
  batch_pull_request_handoff : batch_pull_request_handoff;
  notify_state : notify_state;
  loop_start_branch : string;
  mutable batch_pull_request_completed : bool;
}

and child = {
  pid : int;
  issue : Issue.t;
  issue_id : string;
  issue_identifier : string;
  issue_title : string;
  workspace : Workspace.t;
  mutable started_at : float;
  mutable last_output_at : float;
  stdout_path : string option;
  stderr_path : string option;
  mutable stdout_size : int;
  mutable stderr_size : int;
}

exception Orchestrator_error of string

let runtime_tokens = { Runtime_state.input_tokens = 0; output_tokens = 0; total_tokens = 0 }

let colors_enabled () = Sys.getenv_opt "NO_COLOR" = None
let ansi code = if colors_enabled () then "\027[" ^ code ^ "m" else ""
let color code text = ansi code ^ text ^ ansi "0"
let blue text = color "34;1" text
let cyan text = color "36;1" text
let green text = color "32;1" text
let yellow text = color "33;1" text
let red text = color "31;1" text
let dim text = color "2" text
let clear_line = if colors_enabled () then "\r\027[2K" else "\r"

let clock_time () =
  let tm = Unix.localtime (Unix.time ()) in
  Printf.sprintf "%02d:%02d:%02d" tm.tm_hour tm.tm_min tm.tm_sec

let render_poll_started orchestrator =
  Printf.eprintf "%s%s %s %s%!" clear_line (dim (clock_time ())) (blue "poll")
    (dim
       (Printf.sprintf "checking GitHub, %d running, %d retrying" (List.length orchestrator.state.Runtime_state.running)
          (List.length orchestrator.state.retrying)))

let render_poll_completed orchestrator candidate_count =
  let running_count = List.length orchestrator.state.Runtime_state.running in
  let retrying_count = List.length orchestrator.state.retrying in
  let label, detail =
    if candidate_count = 0 && running_count = 0 && retrying_count = 0 then (green "idle", dim "no candidate issues")
    else if running_count > 0 then (cyan "active", Printf.sprintf "%d agent%s running" running_count (if running_count = 1 then "" else "s"))
    else if retrying_count > 0 then (yellow "retrying", Printf.sprintf "%d issue%s waiting" retrying_count (if retrying_count = 1 then "" else "s"))
    else (green "ready", Printf.sprintf "%d candidate%s found" candidate_count (if candidate_count = 1 then "" else "s"))
  in
  Printf.eprintf "%s%s %s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (blue "poll") label detail
    (dim "candidates") (yellow (string_of_int candidate_count)) (dim (Printf.sprintf "running %d" running_count))

let render_poll_failed msg =
  Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (blue "poll") (red "failed") msg

let render_dispatch_started issue =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch") (green "started")
    issue.Issue.identifier issue.title

let render_dispatch_retrying issue_identifier attempt error =
  Printf.eprintf "%s%s %s %s %s %s %d %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch") (yellow "retrying")
    issue_identifier (dim "attempt") attempt error

let render_dispatch_completed issue_identifier issue_title =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch") (green "completed")
    issue_identifier issue_title

let render_status_failed issue_identifier status error =
  Printf.eprintf "%s%s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "status") (red "failed")
    issue_identifier status error

let render_commit_completed issue_identifier message =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "commit") (green "created")
    issue_identifier message

let render_commit_skipped issue_identifier =
  Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "commit") (dim "skipped") issue_identifier

let render_commit_failed issue_identifier error =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "commit") (red "failed")
    issue_identifier error

let render_pull_request_completed head base =
  Printf.eprintf "%s%s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "pull-request") (green "ready")
    head (dim "base") base

let render_pull_request_failed head base error =
  Printf.eprintf "%s%s %s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "pull-request") (red "failed")
    head (dim "base") base error

let running_ids state = List.map (fun (row : Runtime_state.running) -> row.issue.id) state.Runtime_state.running
let is_running state issue = List.exists (( = ) issue.Issue.id) (running_ids state)
let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b
let block_key issue = issue.Issue.id ^ "\x00" ^ String.lowercase_ascii issue.Issue.state
let is_blocked orchestrator issue = Hashtbl.mem orchestrator.blocked (block_key issue)

let retrying_due orchestrator issue =
  match Hashtbl.find_opt orchestrator.retry_due issue.Issue.id with
  | None -> true
  | Some due -> Unix.time () >= due

let take n list =
  let rec loop remaining acc = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | x :: xs -> loop (remaining - 1) (x :: acc) xs
  in
  loop n [] list

let write_prompt workspace prompt =
  let path = Filename.concat workspace.Workspace.path "prompt.md" in
  Util.write_file path prompt;
  path

let stage_for_issue config issue =
  if not config.Config.stage_agents.enabled then None
  else
    config.stage_agents.stages
    |> List.find_opt (fun (stage : Config.stage_agent) ->
           List.exists (fun state -> string_equal_ci state issue.Issue.state) stage.states)

let agent_file config agent =
  Filename.concat config.Config.stage_agents.root (agent ^ ".md")

let agent_prompt config issue =
  if not config.Config.stage_agents.enabled then None
  else
    let agent =
      match stage_for_issue config issue with
      | Some stage -> Some stage.agent
      | None -> config.stage_agents.default_agent
    in
    match agent with
    | None -> None
    | Some agent ->
        let path = agent_file config agent in
        if Sys.file_exists path then Some (agent, Util.read_file path |> Util.trim) else None

let compose_prompt config issue base_prompt =
  match agent_prompt config issue with
  | None -> base_prompt
  | Some (agent, prompt) ->
      Printf.sprintf "%s\n\n---\n\nStage agent: %s\n\n%s\n" prompt agent base_prompt

let replace_token ~token ~value text =
  String.split_on_char '<' text
  |> List.mapi (fun index part ->
         if index = 0 then part
         else
           match String.split_on_char '>' part with
           | key :: rest when key = token -> value ^ String.concat ">" rest
           | _ -> "<" ^ part)
  |> String.concat ""

let truncate max_len text =
  let text = Util.trim text in
  if String.length text <= max_len then text else String.sub text 0 max_len |> Util.trim

let render_commit_message issue (stage : Config.stage_agent option) next_status policy =
  let agent = match stage with Some stage -> stage.agent | None -> "agent" in
  let generated =
    Printf.sprintf "complete %s %s" issue.Issue.identifier issue.title |> truncate 90
  in
  policy.Config.message
  |> replace_token ~token:"type" ~value:policy.Config.commit_type
  |> replace_token ~token:"generated_message_max_90char" ~value:generated
  |> replace_token ~token:"issue_identifier" ~value:issue.identifier
  |> replace_token ~token:"issue_title" ~value:issue.title
  |> replace_token ~token:"from_status" ~value:issue.state
  |> replace_token ~token:"to_status" ~value:(Option.value next_status ~default:"")
  |> replace_token ~token:"agent" ~value:agent
  |> Util.trim

let run_shell_capture ~cwd command =
  let command = Printf.sprintf "cd %s && %s 2>&1" (Util.shell_quote cwd) command in
  let ic = Unix.open_process_in command in
  let output =
    Fun.protect ~finally:(fun () -> ()) (fun () ->
        let buffer = Buffer.create 256 in
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

let current_branch root =
  match run_shell_capture ~cwd:root "git branch --show-current" with
  | Ok branch when Util.trim branch <> "" -> Util.trim branch
  | _ -> (
      match run_shell_capture ~cwd:root "git rev-parse --short HEAD" with Ok sha -> sha | Error _ -> "HEAD")

let is_git_repository root =
  match run_shell_capture ~cwd:root "git rev-parse --is-inside-work-tree" with
  | Ok "true" -> true
  | _ -> false

let git_ref_exists root refname =
  match run_shell_capture ~cwd:root (Printf.sprintf "git show-ref --verify --quiet refs/heads/%s" (Util.shell_quote refname)) with
  | Ok _ -> true
  | Error _ -> false

let worktree_branch path =
  if Sys.file_exists path && Sys.is_directory path then
    match (run_shell_capture ~cwd:path "git rev-parse --show-toplevel", run_shell_capture ~cwd:path "git branch --show-current") with
    | Ok top_level, Ok branch when Unix.realpath top_level = Unix.realpath path && Util.trim branch <> "" -> Some (Util.trim branch)
    | _ -> None
  else None

let issue_branch_key issue =
  let digits =
    issue.Issue.identifier |> String.to_seq
    |> Seq.filter (function '0' .. '9' -> true | _ -> false)
    |> String.of_seq
  in
  if digits <> "" then digits else Workspace.sanitize issue.id

let task_branch config issue = config.Config.git.task_branch_prefix ^ issue_branch_key issue

let require_clean_loop_start root =
  match run_shell_capture ~cwd:root "git status --porcelain" with
  | Ok "" -> Ok ()
  | Ok _ -> Error "loop-start worktree must be clean before creating task worktrees"
  | Error error -> Error ("git status failed: " ^ error)

let shell_prepare_workspace config ~loop_start_branch issue =
  let branch = task_branch config issue in
  if not (is_git_repository config.repository_root) then
    Ok (Workspace.create_for_issue ~root:config.Config.workspace.root issue.Issue.identifier)
  else
    let workspace_key = Workspace.sanitize issue.Issue.identifier in
    let workspace_path = Filename.concat config.Config.workspace.root workspace_key in
    match worktree_branch workspace_path with
    | Some existing when existing = branch -> Ok (Workspace.create_for_issue ~root:config.Config.workspace.root issue.Issue.identifier)
    | Some existing -> Error (Printf.sprintf "agent worktree uses %s but expected %s" existing branch)
    | None when Sys.file_exists workspace_path -> Error (workspace_path ^ " exists but is not an Agent Worktree")
    | None ->
      match require_clean_loop_start config.repository_root with
      | Error _ as error -> error
      | Ok () ->
          let workspace = Workspace.create_for_issue ~root:config.Config.workspace.root issue.Issue.identifier in
          let create_branch =
            if git_ref_exists config.repository_root branch then Ok ()
            else
              match
                run_shell_capture ~cwd:config.repository_root
                  (Printf.sprintf "git branch %s %s" (Util.shell_quote branch) (Util.shell_quote loop_start_branch))
              with
              | Ok _ -> Ok ()
              | Error _ as error -> error
          in
          (match create_branch with
          | Error error -> Error ("task branch creation failed: " ^ error)
          | Ok _ -> (
              match
                run_shell_capture ~cwd:config.repository_root
                  (Printf.sprintf "git worktree add %s %s" (Util.shell_quote workspace.path) (Util.shell_quote branch))
              with
              | Ok _ -> Ok workspace
              | Error error -> Error ("agent worktree creation failed: " ^ error)))

let has_worktree_changes root =
  match run_shell_capture ~cwd:root "git status --porcelain" with
  | Ok output -> Ok (output <> "")
  | Error error -> Error ("git status failed: " ^ error)

let push_current_branch root =
  match run_shell_capture ~cwd:root "git rev-parse --abbrev-ref --symbolic-full-name @{u}" with
  | Ok _ -> run_shell_capture ~cwd:root "git push"
  | Error _ ->
      run_shell_capture ~cwd:root "git push -u origin HEAD"

let render_pull_request_template config ~head_branch text =
  text
  |> replace_token ~token:"head_branch" ~value:head_branch
  |> replace_token ~token:"base_branch" ~value:config.Config.pull_request.base_branch
  |> Util.trim

let batch_branch_push config ~head_branch =
  if not (is_git_repository config.Config.repository_root) then Error "batch pull request requires a Git repository"
  else
    let command =
      Printf.sprintf "git push -u origin refs/heads/%s:refs/heads/%s" (Util.shell_quote head_branch)
        (Util.shell_quote head_branch)
    in
    match run_shell_capture ~cwd:config.repository_root command with
    | Ok _ -> Ok ()
    | Error error -> Error ("batch branch push failed: " ^ error)

let existing_batch_pull_request config ~head_branch =
  let repo_full_name = config.Config.tracker.owner ^ "/" ^ config.tracker.repo in
  let head_filter = config.tracker.owner ^ ":" ^ head_branch in
  let command =
    Printf.sprintf "gh pr list --repo %s --state open --head %s --base %s --limit 1 --json url"
      (Util.shell_quote repo_full_name) (Util.shell_quote head_filter)
      (Util.shell_quote config.pull_request.base_branch)
  in
  match run_shell_capture ~cwd:config.repository_root command with
  | Error error -> Error ("batch pull request lookup failed: " ^ error)
  | Ok output -> (
      try
        match Yojson.Safe.from_string output with
        | `List (`Assoc fields :: _) -> (
            match List.assoc_opt "url" fields with Some (`String url) -> Ok (Some url) | _ -> Ok (Some ""))
        | `List [] -> Ok None
        | _ -> Ok None
      with Yojson.Json_error msg -> Error ("batch pull request lookup returned invalid JSON: " ^ msg))

let create_batch_pull_request config ~head_branch =
  let repo_full_name = config.Config.tracker.owner ^ "/" ^ config.tracker.repo in
  let title = render_pull_request_template config ~head_branch config.pull_request.title in
  let body = render_pull_request_template config ~head_branch config.pull_request.body in
  let command =
    Printf.sprintf "gh pr create --repo %s --head %s --base %s --title %s --body %s" (Util.shell_quote repo_full_name)
      (Util.shell_quote head_branch)
      (Util.shell_quote config.pull_request.base_branch)
      (Util.shell_quote title) (Util.shell_quote body)
  in
  match run_shell_capture ~cwd:config.repository_root command with
  | Ok output -> Ok (Some (Util.trim output))
  | Error error -> Error ("batch pull request creation failed: " ^ error)

let gh_batch_pull_request_handoff config ~head_branch =
  match batch_branch_push config ~head_branch with
  | Error _ as error -> error
  | Ok () -> (
      match existing_batch_pull_request config ~head_branch with
      | Error _ as error -> error
      | Ok (Some url) -> Ok (if Util.trim url = "" then None else Some url)
      | Ok None -> create_batch_pull_request config ~head_branch)

let git_commit_stage_changes _config workspace issue stage next_status =
  match stage with
  | None -> Ok ()
  | Some stage -> (
      match stage.Config.commit with
      | None -> Ok ()
      | Some policy when not policy.enabled -> Ok ()
      | Some policy ->
          let root = workspace.Workspace.path in
          match has_worktree_changes root with
          | Error error -> Error error
          | Ok false ->
              render_commit_skipped issue.Issue.identifier;
              Error "commit required but agent produced no code changes"
          | Ok true ->
              let message = render_commit_message issue (Some stage) next_status policy in
              match run_shell_capture ~cwd:root "git add -A" with
              | Error error -> Error ("git add failed: " ^ error)
              | Ok _ -> (
                  match run_shell_capture ~cwd:root "git diff --cached --quiet" with
                  | Ok _ ->
                      render_commit_skipped issue.Issue.identifier;
                      Error "commit required but no staged changes were found"
                  | Error _ ->
                      let command = Printf.sprintf "git commit -m %s" (Util.shell_quote message) in
                      match run_shell_capture ~cwd:root command with
                      | Ok _ ->
                          render_commit_completed issue.Issue.identifier message;
                          if policy.Config.push then
                            match push_current_branch root with
                            | Ok _ -> Ok ()
                            | Error error -> Error ("stage push failed: " ^ error)
                          else Ok ()
                      | Error error -> Error error))

let replace_first_word command replacement =
  let command = Util.trim command in
  match String.split_on_char ' ' command with
  | [] -> replacement
  | _ :: rest -> String.concat " " (replacement :: rest)

let codex_command config =
  let command = Util.trim config.Config.codex.command in
  let model = Util.trim config.codex.model in
  let reasoning = Util.trim config.codex.reasoning_effort in
  let with_tokens =
    command
    |> replace_token ~token:"model" ~value:(Util.shell_quote model)
    |> replace_token ~token:"reasoning" ~value:(Util.shell_quote reasoning)
  in
  if with_tokens <> command then with_tokens
  else
    match String.split_on_char ' ' command with
    | "codex" :: _ ->
        let overrides =
          Printf.sprintf "codex -m %s -c %s" (Util.shell_quote model)
            (Util.shell_quote (Printf.sprintf "model_reasoning_effort=%s" (Yojson.Safe.to_string (`String reasoning))))
        in
        replace_first_word command overrides
    | _ -> command

let shell_launch ~config ~workspace ~prompt ~issue =
  let prompt_path = write_prompt workspace prompt in
  let stdout_path = Filename.concat workspace.Workspace.path "stdout.log" in
  let stderr_path = Filename.concat workspace.Workspace.path "stderr.log" in
  let command =
    Printf.sprintf "cd %s && %s < %s > %s 2> %s" (Util.shell_quote workspace.Workspace.path) (codex_command config)
      (Util.shell_quote prompt_path) (Util.shell_quote stdout_path) (Util.shell_quote stderr_path)
  in
  let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; command |] Unix.stdin Unix.stdout Unix.stderr in
  {
    pid = Some pid;
    session_id = Some (Printf.sprintf "pid:%d" pid);
    event =
      Printf.sprintf "launched issue=%s repository=%s workspace=%s" issue.Issue.identifier config.repository_root
        workspace.Workspace.path;
    stdout_path = Some stdout_path;
    stderr_path = Some stderr_path;
  }

let make ?(launch = shell_launch) ?(fetch = Github_tracker.fetch_candidate_issues) ?(set_status = Github_tracker.update_issue_status)
    ?(commit_stage = git_commit_stage_changes) ?(batch_pull_request_handoff = gh_batch_pull_request_handoff)
    ?(notify_state = fun _ -> ()) ~config ~prompt_template () =
  {
    config;
    prompt_template;
    tracker = Github_tracker.make config.tracker;
    state = Runtime_state.empty ~status_order:(Config.project_status_order config) ();
    children = [];
    retry_due = Hashtbl.create 16;
    attempts = Hashtbl.create 16;
    blocked = Hashtbl.create 16;
    launch;
    fetch;
    set_status;
    commit_stage;
    batch_pull_request_handoff;
    notify_state;
    loop_start_branch = current_branch config.repository_root;
    batch_pull_request_completed = false;
  }

let get_state orchestrator = orchestrator.state

let set_state orchestrator state =
  orchestrator.state <- state;
  orchestrator.notify_state state

let update_state orchestrator f = set_state orchestrator (f orchestrator.state)

let set_error orchestrator msg = update_state orchestrator (fun state -> { state with Runtime_state.last_error = Some msg })

let file_size = function
  | None -> 0
  | Some path -> (
      try (Unix.stat path).Unix.st_size with Unix.Unix_error _ -> 0)

let file_contents = function
  | None -> ""
  | Some path -> (
      try Util.read_file path with Sys_error _ -> "")

let parse_int_after s idx =
  let len = String.length s in
  let rec skip i =
    if i >= len then None
    else
      match s.[i] with
      | '0' .. '9' -> digits i i
      | ':' | '=' | ' ' | '\t' | '"' | '\'' -> skip (i + 1)
      | _ -> None
  and digits start i =
    if i < len then
      match s.[i] with
      | '0' .. '9' -> digits start (i + 1)
      | _ -> Some (String.sub s start (i - start) |> int_of_string)
    else Some (String.sub s start (i - start) |> int_of_string)
  in
  skip idx

let find_int_key key s =
  let len = String.length s and key_len = String.length key in
  let rec loop i found =
    if i + key_len > len then found
    else if String.sub s i key_len = key then
      loop (i + key_len) (parse_int_after s (i + key_len) |> Option.value ~default:found)
    else loop (i + 1) found
  in
  loop 0 0

let parse_tokens stdout_path stderr_path =
  let content = file_contents stdout_path ^ "\n" ^ file_contents stderr_path in
  {
    Runtime_state.input_tokens = find_int_key "input_tokens" content;
    output_tokens = find_int_key "output_tokens" content;
    total_tokens = find_int_key "total_tokens" content;
  }

let max_tokens a b =
  {
    Runtime_state.input_tokens = max a.Runtime_state.input_tokens b.Runtime_state.input_tokens;
    output_tokens = max a.output_tokens b.output_tokens;
    total_tokens = max a.total_tokens b.total_tokens;
  }

let update_running orchestrator issue_id f =
  update_state orchestrator (fun state ->
    {
      state with
      running =
        List.map
          (fun (row : Runtime_state.running) ->
            if row.issue.id = issue_id then f row else row)
          state.running;
    })

let move_issue_status orchestrator issue status =
  match orchestrator.set_status orchestrator.tracker issue status with
  | Ok () -> true
  | Error error ->
      set_error orchestrator error;
      render_status_failed issue.Issue.identifier status error;
      false

let start_status orchestrator issue =
  match stage_for_issue orchestrator.config issue with
  | Some stage -> stage.start_status
  | None -> orchestrator.config.tracker.project_status_on_dispatch

let success_status orchestrator issue =
  match stage_for_issue orchestrator.config issue with
  | Some stage -> stage.success_status
  | None -> orchestrator.config.tracker.project_status_on_success

let retry_status orchestrator issue =
  match stage_for_issue orchestrator.config issue with
  | Some stage -> stage.retry_status
  | None -> orchestrator.config.tracker.project_status_on_retry

let issue_is_active orchestrator issue =
  Github_tracker.status_is_active ~active_states:orchestrator.config.tracker.active_states issue.Issue.state

let issue_needs_attention orchestrator issue =
  string_equal_ci issue.Issue.state orchestrator.config.git.merge_attention_status || is_blocked orchestrator issue

let set_pull_request_handoff orchestrator status ?url ?error () =
  let policy = orchestrator.config.Config.pull_request in
  update_state orchestrator (fun state ->
    {
      state with
      pull_request =
        Some
          {
            Runtime_state.enabled = policy.enabled;
            head_branch = Some orchestrator.loop_start_branch;
            base_branch = Some policy.base_branch;
            status;
            url;
            error;
          };
      last_error = (match error with Some error -> Some error | None -> state.last_error);
    })

let maybe_open_batch_pull_request orchestrator ~candidates ~dispatchable_count =
  let policy = orchestrator.config.Config.pull_request in
  if policy.enabled && not orchestrator.batch_pull_request_completed then
    let has_attention = List.exists (issue_needs_attention orchestrator) candidates || orchestrator.state.issue_errors <> [] in
    let idle =
      dispatchable_count = 0
      && orchestrator.state.running = []
      && orchestrator.state.retrying = []
      && Hashtbl.length orchestrator.retry_due = 0
      && orchestrator.children = []
      && not has_attention
    in
    if idle then (
      set_pull_request_handoff orchestrator "attempting" ();
      match orchestrator.batch_pull_request_handoff orchestrator.config ~head_branch:orchestrator.loop_start_branch with
      | Ok url ->
          orchestrator.batch_pull_request_completed <- true;
          set_pull_request_handoff orchestrator "completed" ?url ();
          render_pull_request_completed orchestrator.loop_start_branch policy.base_branch
      | Error error ->
          set_pull_request_handoff orchestrator "retryable_failure" ~error ();
          render_pull_request_failed orchestrator.loop_start_branch policy.base_branch error)

let dispatch_issue orchestrator issue =
  let target_start_status = start_status orchestrator issue in
  match shell_prepare_workspace orchestrator.config ~loop_start_branch:orchestrator.loop_start_branch issue with
  | Error error ->
      set_error orchestrator error;
      render_dispatch_retrying issue.identifier 0 error;
      ignore (move_issue_status orchestrator issue orchestrator.config.git.merge_attention_status)
  | Ok workspace ->
      let can_dispatch =
        match target_start_status with
        | None -> true
        | Some status -> move_issue_status orchestrator issue status
      in
      if can_dispatch then (
        let issue = match target_start_status with Some state -> { issue with Issue.state } | None -> issue in
        let attempt = Hashtbl.find_opt orchestrator.attempts issue.id in
        let rendered = Prompt.render ~issue ~attempt orchestrator.prompt_template in
        let prompt = compose_prompt orchestrator.config issue rendered in
        let launched = orchestrator.launch ~config:orchestrator.config ~workspace ~prompt ~issue in
        let now = Util.now_iso8601 () in
        let row =
          {
            Runtime_state.issue;
            session_id = launched.session_id;
            turn_count = 0;
            last_event = Some launched.event;
            last_message = None;
            started_at = now;
            last_event_at = Some now;
            tokens = runtime_tokens;
          }
        in
        Hashtbl.remove orchestrator.retry_due issue.id;
        update_state orchestrator (fun state ->
          {
            state with
            issues = List.map (fun candidate -> if candidate.Issue.id = issue.id then issue else candidate) state.issues;
            running = row :: state.running;
            retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue.id) state.retrying;
            issue_errors =
              List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue.id) state.issue_errors;
            last_error = None;
          });
        (match launched.pid with
        | Some pid ->
            let now_float = Unix.time () in
            orchestrator.children <-
              {
                pid;
                issue;
                issue_id = issue.id;
                issue_identifier = issue.identifier;
                issue_title = issue.title;
                workspace;
                started_at = now_float;
                last_output_at = now_float;
                stdout_path = launched.stdout_path;
                stderr_path = launched.stderr_path;
                stdout_size = file_size launched.stdout_path;
                stderr_size = file_size launched.stderr_path;
              }
              :: orchestrator.children
        | None -> ());
        render_dispatch_started issue)

let mark_retrying orchestrator issue_id error =
  match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = issue_id) orchestrator.state.running with
  | None -> ()
  | Some row ->
      let next_attempt = Option.value (Hashtbl.find_opt orchestrator.attempts issue_id) ~default:0 + 1 in
      Hashtbl.replace orchestrator.attempts issue_id next_attempt;
      let backoff_ms =
        min orchestrator.config.agent.max_retry_backoff_ms (1000 * int_of_float (2. ** float_of_int (next_attempt - 1)))
      in
      let due = Unix.time () +. (float_of_int backoff_ms /. 1000.) in
      Hashtbl.replace orchestrator.retry_due issue_id due;
      let due_at =
        let tm = Unix.gmtime due in
        Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday tm.tm_hour
          tm.tm_min tm.tm_sec
      in
      update_state orchestrator (fun state ->
        {
          state with
          running = List.filter (fun (running : Runtime_state.running) -> running.issue.id <> issue_id) state.running;
          retrying =
            {
              Runtime_state.issue_id;
              issue_identifier = row.issue.identifier;
              attempt = next_attempt;
              due_at;
              error = Some error;
            }
            :: List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
          issue_errors =
            List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
          last_error = Some error;
        });
      (match retry_status orchestrator row.issue with
      | None -> ()
      | Some status -> ignore (move_issue_status orchestrator row.issue status));
      render_dispatch_retrying row.issue.identifier next_attempt error

let non_retryable_completion_error = function
  | "commit required but agent produced no code changes" | "commit required but no staged changes were found" -> true
  | _ -> false

let mark_blocked orchestrator issue_id error =
  match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = issue_id) orchestrator.state.running with
  | None -> ()
  | Some row ->
      Hashtbl.remove orchestrator.attempts issue_id;
      Hashtbl.remove orchestrator.retry_due issue_id;
      Hashtbl.replace orchestrator.blocked (block_key row.issue) error;
      (match retry_status orchestrator row.issue with
      | None -> ()
      | Some status ->
          if move_issue_status orchestrator row.issue status then
            Hashtbl.replace orchestrator.blocked (block_key { row.issue with Issue.state = status }) error);
      update_state orchestrator (fun state ->
        {
          state with
          running = List.filter (fun (running : Runtime_state.running) -> running.issue.id <> issue_id) state.running;
          retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
          issue_errors =
            {
              Runtime_state.issue_id;
              issue_identifier = row.issue.identifier;
              error;
            }
            :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
          last_error = Some error;
        })

let complete_child orchestrator child =
  let issue_id = child.issue_id in
  Hashtbl.remove orchestrator.attempts issue_id;
  Hashtbl.remove orchestrator.retry_due issue_id;
  update_state orchestrator (fun state ->
    {
      state with
      running = List.filter (fun (row : Runtime_state.running) -> row.issue.id <> issue_id) state.running;
      retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
      issue_errors =
        List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
    });
  render_dispatch_completed child.issue_identifier child.issue_title

let protected_loop_start orchestrator =
  List.exists
    (fun branch -> String.lowercase_ascii branch = String.lowercase_ascii orchestrator.loop_start_branch)
    orchestrator.config.git.protected_trunk_branches

let cleanup_task_worktree orchestrator child =
  if orchestrator.config.git.cleanup.remove_worktree_after_merge then
    ignore
      (run_shell_capture ~cwd:orchestrator.config.repository_root
         (Printf.sprintf "git worktree remove %s" (Util.shell_quote child.workspace.path)));
  if not orchestrator.config.git.cleanup.keep_task_branch then
    ignore
      (run_shell_capture ~cwd:orchestrator.config.repository_root
         (Printf.sprintf "git branch -d %s" (Util.shell_quote (task_branch orchestrator.config child.issue))))

let auto_merge_child orchestrator child =
  if (not (is_git_repository orchestrator.config.repository_root)) || (not orchestrator.config.git.auto_merge) || protected_loop_start orchestrator then Ok ()
  else
    let branch = task_branch orchestrator.config child.issue in
    match
      run_shell_capture ~cwd:orchestrator.config.repository_root
        (Printf.sprintf "git merge --ff-only %s" (Util.shell_quote branch))
    with
    | Ok _ ->
        cleanup_task_worktree orchestrator child;
        Ok ()
    | Error error -> Error ("auto-merge failed: " ^ error)

let mark_merge_attention orchestrator child error =
  set_error orchestrator error;
  ignore (move_issue_status orchestrator child.issue orchestrator.config.git.merge_attention_status);
  update_state orchestrator (fun state ->
    {
      state with
      running = List.filter (fun (row : Runtime_state.running) -> row.issue.id <> child.issue_id) state.running;
      retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> child.issue_id) state.retrying;
      issue_errors =
        {
          Runtime_state.issue_id = child.issue_id;
          issue_identifier = child.issue_identifier;
          error;
        }
        :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> child.issue_id) state.issue_errors;
      last_error = Some error;
    })

let mark_completed orchestrator child =
  let issue_id = child.issue_id in
  let stage = stage_for_issue orchestrator.config child.issue in
  let next_status = success_status orchestrator child.issue in
  match orchestrator.commit_stage orchestrator.config child.workspace child.issue stage next_status with
  | Error error ->
      set_error orchestrator error;
      render_commit_failed child.issue_identifier error;
      if non_retryable_completion_error error then mark_blocked orchestrator issue_id error
      else mark_retrying orchestrator issue_id error
  | Ok () ->
      (match auto_merge_child orchestrator child with
      | Error error -> mark_merge_attention orchestrator child error
      | Ok () -> (
          match next_status with
          | None -> complete_child orchestrator child
          | Some status ->
              if not (move_issue_status orchestrator child.issue status) then
                mark_retrying orchestrator issue_id (Printf.sprintf "could not move issue to %s" status)
              else complete_child orchestrator child))

let kill_child child =
  try Unix.kill child.pid Sys.sigterm with Unix.Unix_error _ -> ()

let refresh_child_output orchestrator child =
  let stdout_size = file_size child.stdout_path in
  let stderr_size = file_size child.stderr_path in
  if stdout_size <> child.stdout_size || stderr_size <> child.stderr_size then (
    child.stdout_size <- stdout_size;
    child.stderr_size <- stderr_size;
    child.last_output_at <- Unix.time ();
    let now = Util.now_iso8601 () in
    let tokens = parse_tokens child.stdout_path child.stderr_path in
    update_state orchestrator (fun state -> { state with codex_totals = max_tokens state.codex_totals tokens });
    update_running orchestrator child.issue_id (fun row ->
        {
          row with
          Runtime_state.last_event = Some "agent_output";
          last_message = Some "stdout/stderr updated";
          last_event_at = Some now;
          tokens = max_tokens row.tokens tokens;
        }))

let reap_children orchestrator =
  let now = Unix.time () in
  let finished, still_running =
    List.fold_left
      (fun (finished, running) child ->
        refresh_child_output orchestrator child;
        if
          now -. child.started_at > float_of_int orchestrator.config.codex.turn_timeout_ms /. 1000.
          || now -. child.last_output_at > float_of_int orchestrator.config.codex.stall_timeout_ms /. 1000.
        then (
          kill_child child;
          mark_retrying orchestrator child.issue_id "agent timed out";
          (child.issue_id :: finished, running))
        else
          match Unix.waitpid [ Unix.WNOHANG ] child.pid with
          | 0, _ -> (finished, child :: running)
          | _, Unix.WEXITED 0 ->
              mark_completed orchestrator child;
              (child.issue_id :: finished, running)
          | _, Unix.WEXITED code ->
              mark_retrying orchestrator child.issue_id (Printf.sprintf "agent exited with code %d" code);
              (child.issue_id :: finished, running)
          | _, Unix.WSIGNALED signal ->
              mark_retrying orchestrator child.issue_id (Printf.sprintf "agent signaled %d" signal);
              (child.issue_id :: finished, running)
          | _, Unix.WSTOPPED signal ->
              set_error orchestrator (Printf.sprintf "agent for %s stopped by signal %d" child.issue_id signal);
              (finished, child :: running)
          | exception Unix.Unix_error (Unix.ECHILD, _, _) ->
              mark_completed orchestrator child;
              (child.issue_id :: finished, running))
      ([], []) orchestrator.children
  in
  orchestrator.children <- List.rev still_running;
  ignore finished

let poll_once orchestrator =
  reap_children orchestrator;
  render_poll_started orchestrator;
  try
    let candidates = orchestrator.fetch orchestrator.tracker in
    let last_error = if Hashtbl.length orchestrator.blocked = 0 then None else orchestrator.state.last_error in
    update_state orchestrator (fun state -> { state with Runtime_state.issues = candidates; last_error });
    let available = orchestrator.config.agent.max_concurrent_agents - List.length orchestrator.state.running in
    let dispatchable =
      candidates
      |> List.filter (fun issue ->
             issue_is_active orchestrator issue
             && (not (is_running orchestrator.state issue))
             && (not (is_blocked orchestrator issue))
             && retrying_due orchestrator issue)
    in
    if available > 0 then dispatchable |> take available |> List.iter (dispatch_issue orchestrator);
    maybe_open_batch_pull_request orchestrator ~candidates ~dispatchable_count:(List.length dispatchable);
    render_poll_completed orchestrator (List.length dispatchable)
  with exn ->
    let msg = Printexc.to_string exn in
    set_error orchestrator msg;
    render_poll_failed msg

let run_forever orchestrator =
  while true do
    poll_once orchestrator;
    let interval_ms = max 1 orchestrator.config.polling.interval_ms in
    let read_timeout_ms = max 1 orchestrator.config.codex.read_timeout_ms in
    let rec sleep_and_reap elapsed_ms =
      if elapsed_ms < interval_ms then (
        let remaining_ms = interval_ms - elapsed_ms in
        let chunk_ms = min read_timeout_ms remaining_ms in
        Unix.sleepf (float_of_int chunk_ms /. 1000.);
        reap_children orchestrator;
        sleep_and_reap (elapsed_ms + chunk_ms))
    in
    sleep_and_reap 0
  done
