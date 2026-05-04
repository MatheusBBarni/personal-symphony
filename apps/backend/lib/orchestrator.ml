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
type commit_stage = Config.t -> Issue.t -> Config.stage_agent option -> string option -> (unit, string) result

type t = {
  config : Config.t;
  prompt_template : string;
  tracker : Github_tracker.t;
  mutable state : Runtime_state.t;
  mutable children : child list;
  retry_due : (string, float) Hashtbl.t;
  attempts : (string, int) Hashtbl.t;
  launch : launch;
  fetch : fetch;
  set_status : set_status;
  commit_stage : commit_stage;
}

and child = {
  pid : int;
  issue : Issue.t;
  issue_id : string;
  issue_identifier : string;
  issue_title : string;
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

let running_ids state = List.map (fun (row : Runtime_state.running) -> row.issue.id) state.Runtime_state.running
let is_running state issue = List.exists (( = ) issue.Issue.id) (running_ids state)
let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b
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

let has_worktree_changes root =
  match run_shell_capture ~cwd:root "git status --porcelain" with
  | Ok output -> Ok (output <> "")
  | Error error -> Error ("git status failed: " ^ error)

let git_commit_stage_changes config issue stage next_status =
  match stage with
  | None -> Ok ()
  | Some stage -> (
      match stage.Config.commit with
      | None -> Ok ()
      | Some policy when not policy.enabled -> Ok ()
      | Some policy ->
          let root = config.Config.repository_root in
          match has_worktree_changes root with
          | Error error -> Error error
          | Ok false ->
              render_commit_skipped issue.Issue.identifier;
              Ok ()
          | Ok true ->
              let message = render_commit_message issue (Some stage) next_status policy in
              match run_shell_capture ~cwd:root "git add -A" with
              | Error error -> Error ("git add failed: " ^ error)
              | Ok _ -> (
                  match run_shell_capture ~cwd:root "git diff --cached --quiet" with
                  | Ok _ ->
                      render_commit_skipped issue.Issue.identifier;
                      Ok ()
                  | Error _ ->
                      let command = Printf.sprintf "git commit -m %s" (Util.shell_quote message) in
                      match run_shell_capture ~cwd:root command with
                      | Ok _ ->
                          render_commit_completed issue.Issue.identifier message;
                          Ok ()
                      | Error error -> Error error))

let shell_launch ~config ~workspace ~prompt ~issue =
  let prompt_path = write_prompt workspace prompt in
  let stdout_path = Filename.concat workspace.Workspace.path "stdout.log" in
  let stderr_path = Filename.concat workspace.Workspace.path "stderr.log" in
  let command =
    Printf.sprintf "cd %s && %s < %s > %s 2> %s" (Util.shell_quote workspace.path) config.Config.codex.command
      (Util.shell_quote prompt_path) (Util.shell_quote stdout_path) (Util.shell_quote stderr_path)
  in
  let pid = Unix.create_process "/bin/sh" [| "/bin/sh"; "-lc"; command |] Unix.stdin Unix.stdout Unix.stderr in
  {
    pid = Some pid;
    session_id = Some (Printf.sprintf "pid:%d" pid);
    event = Printf.sprintf "launched issue=%s workspace=%s" issue.Issue.identifier workspace.Workspace.path;
    stdout_path = Some stdout_path;
    stderr_path = Some stderr_path;
  }

let make ?(launch = shell_launch) ?(fetch = Github_tracker.fetch_candidate_issues) ?(set_status = Github_tracker.update_issue_status)
    ?(commit_stage = git_commit_stage_changes) ~config ~prompt_template () =
  {
    config;
    prompt_template;
    tracker = Github_tracker.make config.tracker;
    state = Runtime_state.empty ();
    children = [];
    retry_due = Hashtbl.create 16;
    attempts = Hashtbl.create 16;
    launch;
    fetch;
    set_status;
    commit_stage;
  }

let get_state orchestrator = orchestrator.state

let set_error orchestrator msg =
  orchestrator.state <- { orchestrator.state with Runtime_state.last_error = Some msg }

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
  orchestrator.state <-
    {
      orchestrator.state with
      running =
        List.map
          (fun (row : Runtime_state.running) ->
            if row.issue.id = issue_id then f row else row)
          orchestrator.state.running;
    }

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

let dispatch_issue orchestrator issue =
  let can_dispatch =
    match start_status orchestrator issue with
    | None -> true
    | Some status -> move_issue_status orchestrator issue status
  in
  if can_dispatch then (
  let workspace = Workspace.create_for_issue ~root:orchestrator.config.workspace.root issue.Issue.identifier in
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
  orchestrator.state <-
    {
      orchestrator.state with
      running = row :: orchestrator.state.running;
      retrying = List.filter (fun retry -> retry.Runtime_state.issue_id <> issue.id) orchestrator.state.retrying;
      last_error = None;
    };
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
      orchestrator.state <-
        {
          orchestrator.state with
          running = List.filter (fun (running : Runtime_state.running) -> running.issue.id <> issue_id) orchestrator.state.running;
          retrying =
            {
              Runtime_state.issue_id;
              issue_identifier = row.issue.identifier;
              attempt = next_attempt;
              due_at;
              error = Some error;
            }
            :: List.filter (fun retry -> retry.Runtime_state.issue_id <> issue_id) orchestrator.state.retrying;
          last_error = Some error;
        };
      (match retry_status orchestrator row.issue with
      | None -> ()
      | Some status -> ignore (move_issue_status orchestrator row.issue status));
      render_dispatch_retrying row.issue.identifier next_attempt error

let mark_completed orchestrator child =
  let issue_id = child.issue_id in
  let stage = stage_for_issue orchestrator.config child.issue in
  let next_status = success_status orchestrator child.issue in
  match orchestrator.commit_stage orchestrator.config child.issue stage next_status with
  | Error error ->
      set_error orchestrator error;
      render_commit_failed child.issue_identifier error;
      mark_retrying orchestrator issue_id error
  | Ok () ->
      (match next_status with
      | None -> ()
      | Some status -> ignore (move_issue_status orchestrator child.issue status));
      Hashtbl.remove orchestrator.attempts issue_id;
      Hashtbl.remove orchestrator.retry_due issue_id;
      orchestrator.state <-
        {
          orchestrator.state with
          running = List.filter (fun (row : Runtime_state.running) -> row.issue.id <> issue_id) orchestrator.state.running;
          retrying = List.filter (fun retry -> retry.Runtime_state.issue_id <> issue_id) orchestrator.state.retrying;
        };
      render_dispatch_completed child.issue_identifier child.issue_title

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
    orchestrator.state <- { orchestrator.state with codex_totals = max_tokens orchestrator.state.codex_totals tokens };
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
    let available = orchestrator.config.agent.max_concurrent_agents - List.length orchestrator.state.running in
    if available > 0 then
      candidates
      |> List.filter (fun issue -> (not (is_running orchestrator.state issue)) && retrying_due orchestrator issue)
      |> take available
      |> List.iter (dispatch_issue orchestrator);
    render_poll_completed orchestrator (List.length candidates)
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
