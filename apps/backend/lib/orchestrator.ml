type launch_result = {
  pid : int option;
  session_id : string option;
  event : string;
  stdout_path : string option;
  stderr_path : string option;
}

type launch =
  stage:Config.stage_agent option -> config:Config.t -> workspace:Workspace.t -> prompt:string -> issue:Issue.t -> launch_result

type fetch = Issue_tracker.t -> (Issue.t list, Issue_tracker.poll_error) result
type set_status = Issue_tracker.t -> Issue.t -> string -> (unit, string) result
type commit_stage = Config.t -> Workspace.t -> Issue.t -> Config.stage_agent option -> string option -> (unit, string) result
type batch_pull_request_handoff = Config.t -> head_branch:string -> (string option, string) result
type notify_state = Runtime_state.t -> unit

type previous_attempt_output = {
  attempt : int;
  stdout_path : string option;
  stderr_path : string option;
}

type t = {
  config : Config.t;
  prompt_template : string;
  tracker : Issue_tracker.t;
  mutable state : Runtime_state.t;
  mutable children : child list;
  retry_due : (string, float) Hashtbl.t;
  mutable tracker_retry_due : float option;
  attempts : (string, int) Hashtbl.t;
  previous_attempt_outputs : (string, previous_attempt_output) Hashtbl.t;
  blocked : (string, string) Hashtbl.t;
  launch : launch;
  fetch : fetch;
  set_status : set_status;
  commit_stage : commit_stage;
  batch_pull_request_handoff : batch_pull_request_handoff;
  notify_state : notify_state;
  loop_start_branch : string;
  mutable startup_reconciliation_done : bool;
  mutable batch_pull_request_completed : bool;
  ordered_queue : Ordered_queue.t option;
  resolved_ordered_queue : Ordered_queue.resolved_entry list option;
}

and child = {
  pid : int;
  issue : Issue.t;
  stage : Config.stage_agent option;
  harness : Config.agent_harness;
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

type protected_path_match = { path : string; pattern_name : string; pattern : string }

let harness_uses_deferred_output (harness : Config.agent_harness) =
  String.lowercase_ascii harness.kind = "pi"

let child_turn_timed_out now (child : child) =
  now -. child.started_at > float_of_int child.harness.turn_timeout_ms /. 1000.

let child_stall_timed_out now (child : child) =
  (not (harness_uses_deferred_output child.harness))
  && now -. child.last_output_at > float_of_int child.harness.stall_timeout_ms /. 1000.

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
       (Printf.sprintf "checking %s tracker, %d running, %d retrying" orchestrator.tracker.Issue_tracker.kind
          (List.length orchestrator.state.Runtime_state.running) (List.length orchestrator.state.retrying)))

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

let render_poll_paused seconds_remaining msg =
  Printf.eprintf "%s%s %s %s %s %s %ds\n%!" clear_line (dim (clock_time ())) (blue "poll") (yellow "waiting")
    msg (dim "retry_in") seconds_remaining

let runtime_gap_of_config_gap (gap : Config.readiness_gap) =
  { Runtime_state.requirement = gap.requirement; remediation = gap.remediation }

let render_dispatch_started issue =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch") (green "started")
    issue.Issue.identifier issue.title

let render_compozy_task_started issue_identifier task_file previous_task_file =
  match previous_task_file with
  | Some previous_task_file ->
      Printf.eprintf "%s%s %s %s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch")
        (green "starting") issue_identifier (dim "task") task_file (dim "from") previous_task_file
  | None ->
      Printf.eprintf "%s%s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch")
        (green "starting") issue_identifier (dim "task") task_file

let render_dispatch_retrying ?task_file issue_identifier attempt error =
  match task_file with
  | Some task_file ->
      Printf.eprintf "%s%s %s %s %s %s %s %s %d %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch")
        (yellow "retrying") issue_identifier (dim "task") task_file (dim "attempt") attempt error
  | None ->
      Printf.eprintf "%s%s %s %s %s %s %d %s\n%!" clear_line (dim (clock_time ())) (cyan "dispatch")
        (yellow "retrying") issue_identifier (dim "attempt") attempt error

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

let normalize_repo_path path =
  let path = String.map (function '\\' -> '/' | c -> c) path |> Util.trim in
  let rec drop_prefixes path =
    match Util.drop_prefix ~prefix:"./" path with Some path -> drop_prefixes path | None -> path
  in
  drop_prefixes path

let split_path path =
  normalize_repo_path path |> String.split_on_char '/' |> List.filter (fun part -> part <> "")

let has_glob text = String.exists (function '*' | '?' -> true | _ -> false) text

let glob_segment_matches pattern text =
  let pattern_len = String.length pattern in
  let text_len = String.length text in
  let rec loop p t star next_t =
    if t = text_len then
      let rec only_stars p = p = pattern_len || (pattern.[p] = '*' && only_stars (p + 1)) in
      only_stars p
    else if p < pattern_len then
      match pattern.[p] with
      | '*' -> loop (p + 1) t (Some p) t
      | '?' -> loop (p + 1) (t + 1) star next_t
      | c when c = text.[t] -> loop (p + 1) (t + 1) star next_t
      | _ -> (
          match star with
          | Some star_p when next_t < text_len -> loop (star_p + 1) (next_t + 1) star (next_t + 1)
          | _ -> false)
    else
      match star with
      | Some star_p when next_t < text_len -> loop (star_p + 1) (next_t + 1) star (next_t + 1)
      | _ -> false
  in
  loop 0 0 None 0

let rec prefix_segments_match patterns paths =
  match (patterns, paths) with
  | [], _ -> true
  | pattern :: rest_patterns, path :: rest_paths ->
      glob_segment_matches pattern path && prefix_segments_match rest_patterns rest_paths
  | _ :: _, [] -> false

let protected_pattern_matches_path (pattern : Config.protected_path_pattern) path =
  let raw_pattern = normalize_repo_path pattern.pattern in
  let directory_pattern = String.length raw_pattern > 0 && raw_pattern.[String.length raw_pattern - 1] = '/' in
  let pattern_path =
    if directory_pattern then String.sub raw_pattern 0 (String.length raw_pattern - 1) else raw_pattern
  in
  let pattern_segments = split_path pattern_path in
  let path_segments = split_path path in
  if pattern_segments = [] || path_segments = [] then false
  else if not (has_glob pattern_path) then
    let normalized_pattern = String.concat "/" pattern_segments in
    let normalized_path = String.concat "/" path_segments in
    normalized_path = normalized_pattern || Util.starts_with ~prefix:(normalized_pattern ^ "/") normalized_path
  else if String.contains pattern_path '/' then
    if directory_pattern then prefix_segments_match pattern_segments path_segments
    else
      List.length path_segments = List.length pattern_segments
      && prefix_segments_match pattern_segments path_segments
  else
    List.exists (glob_segment_matches pattern_path) path_segments

let protected_path_matches config paths =
  let seen = Hashtbl.create 16 in
  paths
  |> List.filter_map (fun path ->
         let path = normalize_repo_path path in
         if path = "" || Hashtbl.mem seen path then None
         else (
           Hashtbl.add seen path ();
           config.Config.protected_paths.patterns
           |> List.find_opt (fun pattern -> protected_pattern_matches_path pattern path)
           |> Option.map (fun (pattern : Config.protected_path_pattern) ->
                  { path; pattern_name = pattern.name; pattern = pattern.pattern })))

let issue_authorizes_protected_match config issue protected_match =
  let section = config.Config.protected_paths.authorization.issue_section |> String.lowercase_ascii in
  let lines = issue.Issue.description |> Option.value ~default:"" |> Util.split_lines in
  let authorized = ref [] in
  let in_section = ref false in
  List.iter
    (fun line ->
      let trimmed = Util.trim line in
      if Util.starts_with ~prefix:"#" trimmed then
        let title =
          trimmed |> String.split_on_char '#' |> String.concat "" |> Util.trim |> String.lowercase_ascii
        in
        in_section := title = section
      else if !in_section then
        let value =
          trimmed
          |> Util.drop_prefix ~prefix:"-"
          |> Option.value ~default:trimmed
          |> Util.trim
        in
        let value =
          if String.length value >= 2 && value.[0] = '`' && value.[String.length value - 1] = '`' then
            String.sub value 1 (String.length value - 2)
          else value
        in
        if value <> "" then authorized := value :: !authorized)
    lines;
  List.exists
    (fun value -> value = protected_match.path || value = protected_match.pattern_name)
    !authorized

let unauthorized_protected_path_matches config issue paths =
  protected_path_matches config paths
  |> List.filter (fun protected_match ->
         not (issue_authorizes_protected_match config issue protected_match))

let protected_path_attention_message matches =
  let details =
    matches
    |> List.map (fun item -> Printf.sprintf "%s (matched %s: %s)" item.path item.pattern_name item.pattern)
    |> String.concat ", "
  in
  "Protected Path Policy blocked unauthorized changes: " ^ details

let parse_name_status output =
  output |> Util.split_lines
  |> List.concat_map (fun line ->
         match String.split_on_char '\t' line with
         | status :: old_path :: new_path :: _ when status <> "" && status.[0] = 'R' -> [ old_path; new_path ]
         | _status :: path :: _ -> [ path ]
         | _ -> [])

let render_pull_request_completed head base =
  Printf.eprintf "%s%s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "pull-request") (green "ready")
    head (dim "base") base

let render_pull_request_failed head base error =
  Printf.eprintf "%s%s %s %s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "pull-request") (red "failed")
    head (dim "base") base error

let render_ordered_queue_skipped issue_identifier reason =
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (yellow "skipped")
    issue_identifier reason

let render_ordered_queue_terminal state issue_identifier reason =
  let style =
    match state with
    | "failed" -> red
    | "attention" -> yellow
    | "skipped" -> yellow
    | _ -> dim
  in
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (style state)
    issue_identifier reason

let ordered_queue_terminal_details queue state =
  queue.Runtime_state.entries
  |> List.filter (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = state)
  |> List.map (fun (entry : Runtime_state.ordered_queue_entry) ->
         match entry.skip_reason with
         | Some reason -> entry.issue_identifier ^ " (" ^ reason ^ ")"
         | None -> entry.issue_identifier)

let render_ordered_queue_finished queue =
  let completed =
    queue.Runtime_state.entries
    |> List.filter (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = "completed")
    |> List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.issue_identifier)
  in
  let skipped = ordered_queue_terminal_details queue "skipped" in
  let failed = ordered_queue_terminal_details queue "failed" in
  let attention = ordered_queue_terminal_details queue "attention" in
  let outcome =
    if skipped = [] && failed = [] && attention = [] then green "completed"
    else if failed <> [] || attention <> [] then yellow "completed-with-attention"
    else yellow "completed-with-skips"
  in
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") outcome
    (dim "completed") (String.concat "," completed);
  if skipped <> [] then
    Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (yellow "skipped")
      (String.concat "; " skipped);
  if failed <> [] then
    Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (red "failed")
      (String.concat "; " failed);
  if attention <> [] then
    Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (yellow "attention")
      (String.concat "; " attention)

let render_startup_reconciliation category issue_identifier message =
  let label =
    match category with
    | "merged" | "already_reconciled" -> green category
    | category when Util.starts_with ~prefix:"attention_" category -> yellow category
    | category when Util.starts_with ~prefix:"skipped_" category -> dim category
    | category -> category
  in
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "startup-reconcile") label
    issue_identifier message

let running_ids state = List.map (fun (row : Runtime_state.running) -> row.issue.id) state.Runtime_state.running
let is_running state issue = List.exists (( = ) issue.Issue.id) (running_ids state)
let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b
let block_key issue = issue.Issue.id ^ "\x00" ^ String.lowercase_ascii issue.Issue.state
let is_blocked orchestrator issue = Hashtbl.mem orchestrator.blocked (block_key issue)

let resolve_ordered_queue tracker = function
  | None -> None
  | Some queue -> (
      match Ordered_queue.resolve tracker queue with
      | Ok resolved -> Some resolved
      | Error problems ->
          let message =
            problems
            |> List.map (fun (problem : Ordered_queue.resolution_problem) ->
                   Printf.sprintf "%s: %s" problem.queue_identifier problem.reason)
            |> String.concat "; "
          in
          raise (Orchestrator_error ("Ordered Queue validation failed: " ^ message)))

let ordered_queue_state queue =
  {
    Runtime_state.entries =
      List.map
        (fun (entry : Ordered_queue.entry) ->
          {
            Runtime_state.issue_identifier = entry.issue_identifier;
            title = None;
            state = "pending";
            skip_reason = None;
          })
        queue.Ordered_queue.entries;
  }

let ordered_queue_state_path config =
  Filename.concat (Filename.concat config.Config.repository_root ".symphony/state") "ordered_queue.json"

let ordered_queue_state_matches queue state =
  let expected = Ordered_queue.identifiers queue in
  let actual = List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.issue_identifier) state.Runtime_state.entries in
  expected = actual

let resume_ordered_queue_state config queue =
  let path = ordered_queue_state_path config in
  if Sys.file_exists path then
    try
      match Yojson.Safe.from_file path |> Runtime_state.ordered_queue_of_yojson with
      | Some state when ordered_queue_state_matches queue state -> Some state
      | _ -> None
    with _ -> None
  else None

let load_ordered_queue_state config queue =
  match resume_ordered_queue_state config queue with Some state -> state | None -> ordered_queue_state queue

let persist_ordered_queue_state config = function
  | None -> ()
  | Some queue ->
      let path = ordered_queue_state_path config in
      Util.mkdir_p (Filename.dirname path);
      Util.write_file path (Runtime_state.ordered_queue_to_yojson queue |> Yojson.Safe.pretty_to_string)

let queue_contains_issue resolved_queue issue =
  List.exists
    (fun (entry : Ordered_queue.resolved_entry) -> entry.canonical_identifier = issue.Issue.identifier)
    resolved_queue

let queue_index resolved_queue issue =
  resolved_queue
  |> List.mapi (fun index (entry : Ordered_queue.resolved_entry) -> (index, entry.canonical_identifier))
  |> List.find_map (fun (index, canonical_identifier) ->
         if canonical_identifier = issue.Issue.identifier then Some index else None)
  |> Option.value ~default:max_int

let queue_identifier_for_canonical resolved_queue canonical_identifier =
  resolved_queue
  |> List.find_map (fun (entry : Ordered_queue.resolved_entry) ->
         if entry.canonical_identifier = canonical_identifier then Some entry.queue_identifier else None)

let canonical_identifier_for_queue_identifier resolved_queue queue_identifier =
  resolved_queue
  |> List.find_map (fun (entry : Ordered_queue.resolved_entry) ->
         if entry.queue_identifier = queue_identifier then Some entry.canonical_identifier else None)

let queue_identifier_matches_canonical resolved_queue queue_identifier canonical_identifier =
  match canonical_identifier_for_queue_identifier resolved_queue queue_identifier with
  | Some resolved -> resolved = canonical_identifier
  | None -> queue_identifier = canonical_identifier

let issue_identifier_key issue =
  let identifier = issue.Issue.identifier in
  match Util.drop_prefix ~prefix:"#" identifier with
  | Some number -> (
      match int_of_string_opt number with
      | Some parsed -> (0, parsed, identifier)
      | None -> (2, max_int, identifier))
  | None -> (
      match Util.drop_prefix ~prefix:"mb-" identifier with
      | Some number -> (
          match int_of_string_opt number with
          | Some parsed -> (1, parsed, identifier)
          | None -> (2, max_int, identifier))
      | None -> (2, max_int, identifier))

let queue_entry_allows_dispatch resolved_queue state issue =
  match state.Runtime_state.ordered_queue with
  | None -> true
  | Some queue -> (
      let queue_identifier =
        match queue_identifier_for_canonical resolved_queue issue.Issue.identifier with
        | Some identifier -> identifier
        | None -> issue.Issue.identifier
      in
      match List.find_opt (fun (entry : Runtime_state.ordered_queue_entry) -> entry.issue_identifier = queue_identifier) queue.entries with
      | Some entry -> (
          match String.lowercase_ascii entry.state with
          | "completed" | "skipped" | "failed" | "attention" -> false
          | _ -> true)
      | _ -> true)

let ordered_queue_finished orchestrator =
  match orchestrator.state.Runtime_state.ordered_queue with
  | None -> false
  | Some queue ->
      queue.entries <> []
      && orchestrator.state.running = []
      && orchestrator.state.retrying = []
      && orchestrator.children = []
      && List.for_all
           (fun (entry : Runtime_state.ordered_queue_entry) ->
             match String.lowercase_ascii entry.state with
             | "completed" | "skipped" | "failed" | "attention" -> true
             | _ -> false)
           queue.entries

let entry_state_for_issue state issue_identifier =
  let is_issue row = row.Runtime_state.issue.Issue.identifier = issue_identifier in
  let is_retry (row : Runtime_state.retrying) = row.issue_identifier = issue_identifier in
  let is_error (row : Runtime_state.issue_error) = row.issue_identifier = issue_identifier in
  if List.exists is_issue state.Runtime_state.running then Some "running"
  else if List.exists is_retry state.retrying then Some "retrying"
  else if List.exists is_error state.issue_errors then Some "attention"
  else None

let ordered_queue_entry_needs_live_source (entry : Runtime_state.ordered_queue_entry) =
  match String.lowercase_ascii entry.state with
  | "pending" | "running" | "retrying" -> true
  | _ -> false

let ordered_queue_entry_is_stale_active (entry : Runtime_state.ordered_queue_entry) =
  match String.lowercase_ascii entry.state with
  | "running" | "retrying" -> true
  | _ -> false

let queue_attention_status config status =
  string_equal_ci status config.Config.git.merge_attention_status || string_equal_ci status "human_attention"
  || string_equal_ci status "human attention"

let queue_terminal_state_for_status config status =
  let normalized = String.lowercase_ascii (Util.trim status) in
  if queue_attention_status config status then "attention"
  else match normalized with "failed" -> "failed" | "skipped" | "closed" -> "skipped" | _ -> "completed"

let queue_terminal_reason_for_status config status =
  match queue_terminal_state_for_status config status with
  | "attention" -> Some "Issue is in a human attention state."
  | "failed" -> Some "Issue is in a terminal failed state."
  | "skipped" -> Some "Issue is in a terminal skipped state."
  | _ -> None

let retrying_due orchestrator issue =
  match Hashtbl.find_opt orchestrator.retry_due issue.Issue.id with
  | None -> true
  | Some due -> Unix.time () >= due

let issue_state_is_dispatchable orchestrator state =
  (not (orchestrator.tracker.is_terminal state)) && orchestrator.tracker.is_active state

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

let stage_for_status config status =
  if not config.Config.stage_agents.enabled then None
  else
    config.stage_agents.stages
    |> List.find_opt (fun (stage : Config.stage_agent) -> List.exists (string_equal_ci status) stage.states)

let status_selects_stage config status = Option.is_some (stage_for_status config status)

let stage_key (stage : Config.stage_agent) = stage.agent ^ "\000" ^ String.concat "\000" stage.states

let running_stage_key config (row : Runtime_state.running) =
  match (row.stage_agent, row.stage_states) with
  | Some agent, states -> Some (agent ^ "\000" ^ String.concat "\000" states)
  | None, _ -> Option.map stage_key (stage_for_issue config row.issue)

let stage_from_running config row =
  match running_stage_key config row with
  | None -> None
  | Some key -> List.find_opt (fun (stage : Config.stage_agent) -> stage_key stage = key) config.Config.stage_agents.stages

let selected_stage_fields = function
  | None -> (None, [])
  | Some (stage : Config.stage_agent) -> (Some stage.agent, stage.states)

let agent_file config agent =
  Filename.concat config.Config.stage_agents.root (agent ^ ".md")

let stage_skill_load_prompt (stage : Config.stage_agent option) =
  match stage with
  | Some stage when stage.skills <> [] ->
      let skills = stage.skills |> List.map (fun skill -> "$" ^ Util.trim skill) |> String.concat "\n" in
      Some (Printf.sprintf "Stage Skill Load:\n%s" skills)
  | _ -> None

let agent_prompt ?stage config issue =
  if not config.Config.stage_agents.enabled then None
  else
    let stage = match stage with Some _ -> stage | None -> stage_for_issue config issue in
    let agent =
      match stage with
      | Some stage -> Some stage.agent
      | None -> config.stage_agents.default_agent
    in
    match agent with
    | None -> None
    | Some agent ->
        let path = agent_file config agent in
        if Sys.file_exists path then Some (agent, stage, Util.read_file path |> Util.trim) else None

let normal_prompt ?stage config issue base_prompt =
  let comments_section =
    match Issue.field issue "comments" with
    | Some comments when Util.trim comments <> "" -> Printf.sprintf "\n\n---\n\nIssue comments:\n\n%s" comments
    | _ -> ""
  in
  let base_prompt = base_prompt ^ comments_section in
  match agent_prompt ?stage config issue with
  | None -> base_prompt
  | Some (agent, stage, prompt) ->
      let stage_skill_load =
        match stage_skill_load_prompt stage with Some prompt -> "\n\n" ^ prompt | None -> ""
      in
      Printf.sprintf "%s%s\n\n---\n\nStage agent: %s\n\n%s\n" prompt stage_skill_load agent base_prompt

let stage_goal_handoff_stage ?stage config issue =
  match match stage with Some _ -> stage | None -> stage_for_issue config issue with
  | Some stage when Config.stage_goal_enabled stage -> Some stage
  | _ -> None

let stage_goal_handoff ?stage config issue =
  match stage_goal_handoff_stage ?stage config issue with
  | None -> None
  | Some stage -> (
      match Config.selected_agent_harness config (Some stage) with
      | Some harness when Config.harness_loop_handoff_enabled harness -> Some (stage, Util.trim harness.loop_command)
      | Some _ | None -> None)

let json_option_string = function Some value when Util.trim value <> "" -> `String value | _ -> `Null
let json_option_int = function Some value -> `Int value | None -> `Null
let launch_attempt_number attempt = Option.value attempt ~default:0 + 1

let blocker_to_goal_json (blocker : Issue.blocker) =
  `Assoc
    [
      ("id", json_option_string blocker.id);
      ("identifier", json_option_string blocker.identifier);
      ("state", json_option_string blocker.state);
    ]

let comment_to_goal_json (comment : Issue.comment) =
  `Assoc
    [
      ("author", json_option_string comment.author);
      ("body", `String comment.body);
      ("created_at", json_option_string comment.created_at);
      ("url", json_option_string comment.url);
    ]

let stage_goal_context issue attempt (stage : Config.stage_agent) =
  `Assoc
    [
      ("kind", `String "Stage Goal Context");
      ("issue_identifier", `String issue.Issue.identifier);
      ("title", `String issue.title);
      ("description", json_option_string issue.description);
      ("comments", `List (List.map comment_to_goal_json issue.comments));
      ("url", json_option_string issue.url);
      ("current_project_status", `String issue.state);
      ("labels", `List (List.map (fun label -> `String label) issue.labels));
      ("priority", json_option_int issue.priority);
      ("blocker_references", `List (List.map blocker_to_goal_json issue.blocked_by));
      ("attempt", `Int (launch_attempt_number attempt));
      ("stage_agent_name", `String stage.agent);
    ]
  |> Yojson.Safe.to_string

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

let stage_commit_classification_conflict_prefix = "stage commit classification conflict:"

let normalized_unique values =
  List.fold_left
    (fun acc value ->
      let value = Util.trim value |> String.lowercase_ascii in
      if value = "" || List.exists (( = ) value) acc then acc else acc @ [ value ])
    [] values

let resolved_stage_commit_classification issue (policy : Config.stage_commit) =
  let default, label_map =
    match policy.classification with
    | None -> (policy.commit_type, [])
    | Some classification -> (classification.default, classification.label_map)
  in
  let labels = normalized_unique issue.Issue.labels in
  let matches =
    label_map
    |> List.filter_map (fun (label, classification) ->
           let label = Util.trim label |> String.lowercase_ascii in
           if List.exists (( = ) label) labels then Some (label, classification) else None)
  in
  let classifications =
    List.fold_left
      (fun acc (_, classification) ->
        if List.exists (( = ) classification) acc then acc else acc @ [ classification ])
      [] matches
  in
  match classifications with
  | [] -> Ok default
  | [ classification ] -> Ok classification
  | _ ->
      let details =
        matches
        |> List.map (fun (label, classification) -> label ^ " -> " ^ classification)
        |> String.concat ", "
      in
      Error (stage_commit_classification_conflict_prefix ^ " " ^ details)

let render_commit_message_with_classification issue (stage : Config.stage_agent option) next_status policy classification =
  let agent = match stage with Some stage -> stage.agent | None -> "agent" in
  let generated =
    Printf.sprintf "complete %s %s" issue.Issue.identifier issue.title |> truncate 90
  in
  policy.Config.message
  |> replace_token ~token:"type" ~value:classification
  |> replace_token ~token:"classification" ~value:classification
  |> replace_token ~token:"tag" ~value:classification
  |> replace_token ~token:"generated_message_max_90char" ~value:generated
  |> replace_token ~token:"issue_identifier" ~value:issue.identifier
  |> replace_token ~token:"issue_title" ~value:issue.title
  |> replace_token ~token:"from_status" ~value:issue.state
  |> replace_token ~token:"to_status" ~value:(Option.value next_status ~default:"")
  |> replace_token ~token:"agent" ~value:agent
  |> Util.trim

let render_commit_message_result issue stage next_status policy =
  match resolved_stage_commit_classification issue policy with
  | Error _ as error -> error
  | Ok classification -> Ok (render_commit_message_with_classification issue stage next_status policy classification)

let render_commit_message issue stage next_status policy =
  match render_commit_message_result issue stage next_status policy with
  | Ok message -> message
  | Error error -> error

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

let changed_paths_in_worktree root =
  match run_shell_capture ~cwd:root "git diff --name-status -M HEAD --" with
  | Error error -> Error error
  | Ok tracked -> (
      match run_shell_capture ~cwd:root "git ls-files --others --exclude-standard" with
      | Error error -> Error error
      | Ok untracked -> Ok (parse_name_status tracked @ Util.split_lines untracked))

let changed_paths_between_refs root ~base_ref ~head_ref =
  run_shell_capture ~cwd:root
    (Printf.sprintf "git diff --name-status -M %s %s --" (Util.shell_quote base_ref) (Util.shell_quote head_ref))
  |> Result.map parse_name_status

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

let git_ref_contained_in_head root refname =
  match run_shell_capture ~cwd:root (Printf.sprintf "git merge-base --is-ancestor %s HEAD" (Util.shell_quote refname)) with
  | Ok _ -> true
  | Error _ -> false

let git_head_can_fast_forward_to root refname =
  match run_shell_capture ~cwd:root (Printf.sprintf "git merge-base --is-ancestor HEAD %s" (Util.shell_quote refname)) with
  | Ok _ -> true
  | Error _ -> false

let worktree_branch path =
  if Sys.file_exists path && Sys.is_directory path then
    match (run_shell_capture ~cwd:path "git rev-parse --show-toplevel", run_shell_capture ~cwd:path "git branch --show-current") with
    | Ok top_level, Ok branch when Unix.realpath top_level = Unix.realpath path && Util.trim branch <> "" -> Some (Util.trim branch)
    | _ -> None
  else None

let issue_branch_key issue =
  if Util.starts_with ~prefix:"compozy:" issue.Issue.identifier then Workspace.sanitize issue.Issue.identifier
  else
    let digits =
      issue.Issue.identifier |> String.to_seq
      |> Seq.filter (function '0' .. '9' -> true | _ -> false)
      |> String.of_seq
    in
    if digits <> "" then digits else Workspace.sanitize issue.id

let task_branch config issue = config.Config.git.task_branch_prefix ^ issue_branch_key issue

let task_workspace_path config issue =
  Filename.concat config.Config.workspace.root (Workspace.sanitize issue.Issue.identifier)

let compact_markdown_value value =
  value |> String.split_on_char '\n' |> List.map Util.trim |> List.filter (fun part -> part <> "") |> String.concat " "

let optional_line label = function
  | Some value when Util.trim value <> "" -> [ Printf.sprintf "- %s: %s" label (compact_markdown_value value) ]
  | _ -> []

let blockers_line blockers =
  let blocker_text =
    blockers
    |> List.map (fun (blocker : Issue.blocker) ->
           match (blocker.identifier, blocker.state, blocker.id) with
           | Some identifier, Some state, _ -> Printf.sprintf "%s (%s)" identifier state
           | Some identifier, None, _ -> identifier
           | None, Some state, Some id -> Printf.sprintf "%s (%s)" id state
           | None, Some state, None -> state
           | None, None, Some id -> id
           | None, None, None -> "")
    |> List.filter (fun value -> Util.trim value <> "")
  in
  if blocker_text = [] then "(none)" else String.concat ", " blocker_text

let truncate_snapshot max_output_bytes snapshot =
  if String.length snapshot <= max_output_bytes then snapshot
  else
    let marker = "\n\n[truncated]" in
    if max_output_bytes <= String.length marker then String.sub snapshot 0 max_output_bytes
    else
      let keep = max_output_bytes - String.length marker in
      String.sub snapshot 0 keep |> Util.trim |> fun text -> text ^ marker

let previous_attempt_tail_bytes = 4096

let read_file_tail path max_bytes =
  try
    let fd = Unix.openfile path [ Unix.O_RDONLY ] 0 in
    Fun.protect
      ~finally:(fun () -> Unix.close fd)
      (fun () ->
        let size = (Unix.fstat fd).Unix.st_size in
        let offset = max 0 (size - max_bytes) in
        ignore (Unix.lseek fd offset Unix.SEEK_SET);
        let length = size - offset in
        let bytes = Bytes.create length in
        let rec read_all position =
          if position >= length then ()
          else
            let read = Unix.read fd bytes position (length - position) in
            if read = 0 then () else read_all (position + read)
        in
        read_all 0;
        Some (size > max_bytes, Bytes.unsafe_to_string bytes))
  with Unix.Unix_error _ | Sys_error _ -> None

let render_previous_attempt_stream label path =
  let header = Printf.sprintf "#### %s tail" label in
  match path with
  | None -> [ header; ""; "_unavailable_" ]
  | Some path -> (
      match read_file_tail path previous_attempt_tail_bytes with
      | None -> [ header; ""; "_unavailable_" ]
      | Some (truncated, output) ->
          let marker =
            if truncated then [ Printf.sprintf "[truncated to %d bytes]" previous_attempt_tail_bytes ] else []
          in
          [ header; ""; "```text" ] @ marker @ [ output; "```" ])

let previous_attempt_lines = function
  | None -> []
  | Some previous ->
      [
        "";
        "### Previous Attempt";
        "";
        Printf.sprintf "- Previous attempt: %d" previous.attempt;
        Printf.sprintf "- stdout tail bytes: %d" previous_attempt_tail_bytes;
        Printf.sprintf "- stderr tail bytes: %d" previous_attempt_tail_bytes;
        "";
      ]
      @ render_previous_attempt_stream "stdout" previous.stdout_path
      @ [ "" ]
      @ render_previous_attempt_stream "stderr" previous.stderr_path

let context_command_input_path_env = "SYMPHONY_CONTEXT_COMMAND_INPUT_PATH"

let runtime_state_dir config = Filename.concat (Filename.concat config.Config.repository_root ".symphony") "state"

let context_command_temp_dir config = Filename.concat (runtime_state_dir config) "context-command"
let context_diagnostics_dir config = Filename.concat (runtime_state_dir config) "context-diagnostics"
let task_prompt_archive_dir config = Filename.concat (runtime_state_dir config) "task-prompts"

let remove_if_exists path = try if Sys.file_exists path then Sys.remove path with Sys_error _ | Unix.Unix_error _ -> ()

let ensure_private_runtime_dir dir =
  Util.mkdir_p (Filename.dirname dir);
  if Sys.file_exists dir then
    let stats = Unix.lstat dir in
    match stats.Unix.st_kind with
    | Unix.S_DIR -> if stats.Unix.st_perm land 0o077 <> 0 then Unix.chmod dir 0o700
    | _ -> invalid_arg (dir ^ " exists and is not a directory")
  else Unix.mkdir dir 0o700

let ensure_private_context_command_dir = ensure_private_runtime_dir

let write_context_command_input_file config input_json =
  let dir = context_command_temp_dir config in
  ensure_private_context_command_dir dir;
  let path, oc = Filename.open_temp_file ~mode:[ Open_binary ] ~perms:0o600 ~temp_dir:dir "context-" ".json" in
  try
    output_string oc input_json;
    close_out oc;
    path
  with exn ->
    close_out_noerr oc;
    remove_if_exists path;
    raise exn

let write_private_file path content =
  let oc = open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 path in
  Fun.protect ~finally:(fun () -> close_out_noerr oc) (fun () -> output_string oc content)

let goal_loop_state_dir config = Filename.concat (runtime_state_dir config) "goal-loops"

let goal_loop_state_path config (loop : Runtime_state.goal_loop) =
  Filename.concat (goal_loop_state_dir config) (Workspace.sanitize loop.issue_id ^ ".json")

let load_goal_loop_states config =
  let dir = goal_loop_state_dir config in
  if not (Sys.file_exists dir && Sys.is_directory dir) then []
  else
    Sys.readdir dir |> Array.to_list
    |> List.filter (fun name -> Filename.check_suffix name ".json")
    |> List.sort String.compare
    |> List.filter_map (fun name ->
           let path = Filename.concat dir name in
           try Yojson.Safe.from_file path |> Runtime_state.goal_loop_of_yojson
           with Sys_error _ | Yojson.Json_error _ -> None)

let persist_goal_loop_state config loop =
  let dir = goal_loop_state_dir config in
  ensure_private_runtime_dir dir;
  let path = goal_loop_state_path config loop in
  write_private_file path (Yojson.Safe.pretty_to_string (Runtime_state.goal_loop_to_yojson loop) ^ "\n")

let persist_goal_loop_states config loops =
  try
    List.iter (persist_goal_loop_state config) loops;
    None
  with
  | Sys_error error -> Some ("Goal Loop State persistence failed: " ^ error)
  | Unix.Unix_error (error, fn, arg) ->
      Some (Printf.sprintf "Goal Loop State persistence failed: %s(%s): %s" fn arg (Unix.error_message error))
  | exn -> Some ("Goal Loop State persistence failed: " ^ Printexc.to_string exn)

let env_value name env =
  let prefix = name ^ "=" in
  Array.to_list env
  |> List.find_map (fun entry ->
         match Util.drop_prefix ~prefix entry with Some value -> Some value | None -> None)

let context_command_secret_env_names = [ "GITHUB_TOKEN"; "GH_TOKEN" ]

let context_command_secret_values env =
  context_command_secret_env_names
  |> List.filter_map (fun name -> env_value name env)
  |> List.map Util.trim
  |> List.filter (fun value -> value <> "")
  |> List.sort_uniq String.compare
  |> List.sort (fun left right -> compare (String.length right) (String.length left))

let secret_matches_at text index secret =
  let length = String.length secret in
  index + length <= String.length text && String.sub text index length = secret

let redact_context_command_prefix env text prefix_length =
  let secrets = context_command_secret_values env in
  let buffer = Buffer.create prefix_length in
  let rec loop index =
    if index >= prefix_length then ()
    else
      match List.find_opt (secret_matches_at text index) secrets with
      | Some secret ->
          Buffer.add_string buffer "[redacted]";
          loop (min prefix_length (index + String.length secret))
      | None ->
          Buffer.add_char buffer text.[index];
          loop (index + 1)
  in
  loop 0;
  let output = Buffer.contents buffer in
  if String.length output > prefix_length then String.sub output 0 prefix_length else output

let redact_context_command_text env text =
  let secrets = context_command_secret_values env in
  let buffer = Buffer.create (String.length text) in
  let rec loop index =
    if index >= String.length text then ()
    else
      match List.find_opt (secret_matches_at text index) secrets with
      | Some secret ->
          Buffer.add_string buffer "[redacted]";
          loop (index + String.length secret)
      | None ->
          Buffer.add_char buffer text.[index];
          loop (index + 1)
  in
  loop 0;
  Buffer.contents buffer

type context_command_stdout_capture = {
  buffer : Buffer.t;
  read_limit : int;
  mutable total_bytes : int;
}

type context_command_stdout = {
  output : string;
  truncated : bool;
  total_bytes : int;
}

type context_command_diagnostic = {
  name : string option;
  cwd_kind : string;
  exit_code : int option;
  signal : int option;
  stopped_signal : int option;
  duration_ms : int;
  timed_out : bool;
  stdout_bytes : int;
  stderr_bytes : int;
  stdout_truncated : bool;
  stdout_persisted : bool;
  error : string option;
}

type context_command_run = {
  process_status : Unix.process_status;
  stdout : context_command_stdout;
  stderr_bytes : int;
  timed_out : bool;
  duration_ms : int;
}

type context_command_result = {
  lines : string list;
  context_status : Runtime_state.context_status;
  diagnostic : context_command_diagnostic option;
}

type context_snapshot_diagnostic = {
  enabled : bool;
  rendered_bytes : int;
  truncated : bool;
}

type context_generation_diagnostics = {
  snapshot : context_snapshot_diagnostic;
  command : context_command_diagnostic option;
}

type context_generation = {
  lines : string list;
  context_status : Runtime_state.context_status;
  context_diagnostics : context_generation_diagnostics option;
}

type prompt_composition = {
  prompt : string;
  context_status : Runtime_state.context_status;
  context_diagnostics : context_generation_diagnostics option;
}

let context_command_redaction_window env =
  context_command_secret_values env |> List.fold_left (fun acc value -> max acc (String.length value)) 0

let context_command_stdout_read_limit env max_output_bytes = max_output_bytes + context_command_redaction_window env + 1

let create_context_command_stdout_capture env max_output_bytes =
  { buffer = Buffer.create (min max_output_bytes 4096); read_limit = context_command_stdout_read_limit env max_output_bytes; total_bytes = 0 }

let capture_context_stdout_chunk capture chunk =
  let length = String.length chunk in
  let buffered = Buffer.length capture.buffer in
  let remaining = max 0 (capture.read_limit - buffered) in
  if remaining > 0 then Buffer.add_substring capture.buffer chunk 0 (min remaining length);
  capture.total_bytes <- capture.total_bytes + length

let context_command_stdout_from_capture env max_output_bytes capture =
  let raw = Buffer.contents capture.buffer in
  let prefix_length = min max_output_bytes (String.length raw) in
  {
    output = redact_context_command_prefix env raw prefix_length;
    truncated = capture.total_bytes > max_output_bytes;
    total_bytes = capture.total_bytes;
  }

let context_command_input_json config issue attempt (stage : Config.stage_agent) ~workspace =
  `Assoc
    [
      ("kind", `String "Context Command Input");
      ( "issue",
        `Assoc
          [
            ("identifier", `String issue.Issue.identifier);
            ("title", `String issue.title);
            ("status", `String issue.state);
          ] );
      ("stageAgent", `String stage.agent);
      ("attempt", `Int (launch_attempt_number attempt));
      ("workspaceRepositoryRoot", `String config.Config.repository_root);
      ("agentWorktree", `String workspace.Workspace.path);
      ("taskBranch", `String (task_branch config issue));
    ]
  |> Yojson.Safe.to_string

let context_command_cwd config workspace (command : Config.stage_context_command) =
  match command.cwd with
  | "workspaceRepositoryRoot" -> config.Config.repository_root
  | "agentWorktree" -> workspace.Workspace.path
  | _ -> workspace.Workspace.path

let context_command_name (command : Config.stage_context_command) =
  match command.argv with program :: _ -> Some program | [] -> None

let context_command_elapsed_ms start_time =
  int_of_float ((Unix.gettimeofday () -. start_time) *. 1000.) |> max 0

let make_context_command_diagnostic ?env ?exit_code ?signal ?stopped_signal ?(duration_ms = 0) ?(timed_out = false)
    ?(stdout_bytes = 0) ?(stderr_bytes = 0) ?(stdout_truncated = false) ?error command =
  let env = Option.value env ~default:(Unix.environment ()) in
  {
    name = Option.map (redact_context_command_text env) (context_command_name command);
    cwd_kind = command.Config.cwd;
    exit_code;
    signal;
    stopped_signal;
    duration_ms;
    timed_out;
    stdout_bytes;
    stderr_bytes;
    stdout_truncated;
    stdout_persisted = false;
    error = Option.map (redact_context_command_text env) error;
  }

let context_command_process_exit_code = function Unix.WEXITED code -> Some code | _ -> None
let context_command_process_signal = function Unix.WSIGNALED signal -> Some signal | _ -> None
let context_command_process_stopped_signal = function Unix.WSTOPPED signal -> Some signal | _ -> None

let context_command_diagnostic_of_run env command run =
  make_context_command_diagnostic ~env ?exit_code:(context_command_process_exit_code run.process_status)
    ?signal:(context_command_process_signal run.process_status)
    ?stopped_signal:(context_command_process_stopped_signal run.process_status) ~duration_ms:run.duration_ms
    ~timed_out:run.timed_out ~stdout_bytes:run.stdout.total_bytes ~stderr_bytes:run.stderr_bytes
    ~stdout_truncated:run.stdout.truncated command

let env_with_context_input input_path =
  let replacements = [ (context_command_input_path_env, input_path) ] in
  let replacement_names = List.map fst replacements in
  let is_replaced entry =
    match String.index_opt entry '=' with
    | None -> false
    | Some index ->
        let name = String.sub entry 0 index in
        List.exists (( = ) name) replacement_names
  in
  Array.to_list (Unix.environment ())
  |> List.filter (fun entry -> not (is_replaced entry))
  |> fun existing -> existing @ List.map (fun (name, value) -> name ^ "=" ^ value) replacements
  |> Array.of_list

let executable_file path =
  try
    Unix.access path [ Unix.X_OK ];
    true
  with Unix.Unix_error _ | Sys_error _ -> false

let context_command_path_separator = if Sys.win32 then ';' else ':'

let context_command_default_path =
  if Sys.win32 then "C:\\Windows\\System32;C:\\Windows" else "/usr/bin:/bin:/usr/sbin:/sbin"

let context_program_has_directory_part program =
  String.contains program '/' || (Sys.win32 && String.contains program '\\')

let resolve_context_executable ~cwd env program =
  if context_program_has_directory_part program then
    let path = if Filename.is_relative program then Filename.concat cwd program else program in
    if executable_file path then Ok path else Error "missing executable"
  else
    let path_value = Option.value (env_value "PATH" env) ~default:context_command_default_path in
    let dirs = String.split_on_char context_command_path_separator path_value in
    match
      List.find_map
        (fun dir ->
          let dir = if dir = "" then cwd else dir in
          let path = Filename.concat dir program in
          if executable_file path then Some path else None)
        dirs
    with
    | Some path -> Ok path
    | None -> Error "missing executable"

let close_noerr fd = try Unix.close fd with Unix.Unix_error _ -> ()

let with_context_command_cwd cwd f =
  let original_cwd = Sys.getcwd () in
  if original_cwd = cwd then f ()
  else
    Fun.protect
      ~finally:(fun () -> Sys.chdir original_cwd)
      (fun () ->
        Sys.chdir cwd;
        f ())

let spawn_context_command ~cwd ~env ~stdin_path ~stdout_fd ~stderr_fd ~executable argv =
  let stdin_fd = Unix.openfile stdin_path [ Unix.O_RDONLY ] 0 in
  Fun.protect
    ~finally:(fun () -> close_noerr stdin_fd)
    (fun () ->
      with_context_command_cwd cwd (fun () ->
          Unix.create_process_env executable (Array.of_list argv) env stdin_fd stdout_fd stderr_fd))

let kill_context_process_group pid =
  try Unix.kill (-pid) Sys.sigkill
  with Unix.Unix_error _ -> (try Unix.kill pid Sys.sigkill with Unix.Unix_error _ -> ())

let read_pipe_chunk fd =
  let bytes = Bytes.create 4096 in
  try
    match Unix.read fd bytes 0 (Bytes.length bytes) with
    | 0 -> `Eof
    | read -> `Data (Bytes.sub_string bytes 0 read)
  with
  | Unix.Unix_error ((Unix.EAGAIN | Unix.EWOULDBLOCK | Unix.EINTR), _, _) -> `Would_block
  | Unix.Unix_error (Unix.EBADF, _, _) -> `Eof

let drain_pipe fd open_ref ~on_data =
  let rec loop () =
    match read_pipe_chunk fd with
    | `Data chunk ->
        on_data chunk;
        loop ()
    | `Eof ->
        open_ref := false;
        close_noerr fd
    | `Would_block -> ()
  in
  loop ()

let context_command_pipe_output env max_output_bytes capture =
  context_command_stdout_from_capture env max_output_bytes capture

let wait_context_command env pid timeout_ms stdout_fd stderr_fd max_output_bytes =
  let started_at = Unix.gettimeofday () in
  let deadline = started_at +. (float_of_int timeout_ms /. 1000.) in
  let stdout_capture = create_context_command_stdout_capture env max_output_bytes in
  let stderr_bytes = ref 0 in
  let stdout_open = ref true in
  let stderr_open = ref true in
  let status = ref None in
  let timed_out = ref false in
  let capture_stderr_chunk chunk = stderr_bytes := !stderr_bytes + String.length chunk in
  let close_if_open fd open_ref =
    if !open_ref then (
      open_ref := false;
      close_noerr fd)
  in
  let close_open_pipes () =
    close_if_open stdout_fd stdout_open;
    close_if_open stderr_fd stderr_open
  in
  let record_status process_status =
    match !status with
    | Some _ -> ()
    | None ->
        kill_context_process_group pid;
        status := Some process_status
  in
  let rec loop () =
    (match !status with
    | Some _ -> ()
    | None -> (
        match Unix.waitpid [ Unix.WNOHANG ] pid with
        | 0, _ -> ()
        | _, process_status -> record_status process_status));
    if (not !timed_out) && Unix.gettimeofday () >= deadline then (
      kill_context_process_group pid;
      (match !status with
      | Some _ -> ()
      | None ->
          let _, process_status = Unix.waitpid [] pid in
          status := Some process_status);
      timed_out := true;
      close_open_pipes ());
    let open_fds = (if !stdout_open then [ stdout_fd ] else []) @ (if !stderr_open then [ stderr_fd ] else []) in
    (if open_fds = [] then ()
     else
       let timeout =
         match !status with
         | Some _ -> 0.01
         | None -> max 0.0 (min 0.01 (deadline -. Unix.gettimeofday ()))
       in
       let ready, _, _ = Unix.select open_fds [] [] timeout in
       List.iter
         (fun fd ->
           if fd = stdout_fd then drain_pipe fd stdout_open ~on_data:(capture_context_stdout_chunk stdout_capture)
           else if fd = stderr_fd then drain_pipe fd stderr_open ~on_data:capture_stderr_chunk)
         ready;
       match !status with
       | Some _ ->
           if !stdout_open then (
             drain_pipe stdout_fd stdout_open ~on_data:(capture_context_stdout_chunk stdout_capture);
             if !stdout_open then (
               stdout_open := false;
               close_noerr stdout_fd));
           if !stderr_open then (
             drain_pipe stderr_fd stderr_open ~on_data:capture_stderr_chunk;
             if !stderr_open then (
               stderr_open := false;
               close_noerr stderr_fd))
       | None -> ());
    match (!status, !stdout_open, !stderr_open) with
    | Some process_status, false, false ->
        {
          process_status;
          stdout = context_command_pipe_output env max_output_bytes stdout_capture;
          stderr_bytes = !stderr_bytes;
          timed_out = !timed_out;
          duration_ms = context_command_elapsed_ms started_at;
        }
    | _ ->
        if open_fds = [] then Unix.sleepf 0.01;
        loop ()
  in
  loop ()

let bounded_warning text =
  let text = Util.trim text in
  if String.length text <= 512 then text else (String.sub text 0 512 |> Util.trim) ^ " [truncated]"

let context_command_warning_lines warning =
  [ ""; "### Context Command"; ""; Printf.sprintf "[warning: %s]" (bounded_warning warning) ]

let context_command_stdout_lines ~max_output_bytes ~truncated output =
  if (not truncated) && output = "" then []
  else
    let warning =
      if truncated then
        [ Printf.sprintf "[warning: stdout exceeded maxOutputBytes; truncated to %d bytes]" max_output_bytes; "" ]
      else []
    in
    [ ""; "### Context Command"; "" ] @ warning @ [ output ]

let context_status state summary = Runtime_state.make_context_status ~state ~summary ()

let context_warning_summary subject warning =
  Printf.sprintf "%s %s; prompt contains bounded warning." subject (bounded_warning warning)

let context_command_result ?diagnostic state summary lines = { lines; context_status = context_status state summary; diagnostic }

let context_command_status_result (command : Config.stage_context_command) env run =
  let diagnostic = context_command_diagnostic_of_run env command run in
  if run.timed_out then
      let warning = Printf.sprintf "timed out after %dms" command.timeout_ms in
      context_command_result ~diagnostic "timed_out" (context_warning_summary "Context Command" warning)
        (context_command_warning_lines warning)
  else
    match run.process_status with
    | Unix.WEXITED 0 ->
      let lines =
        context_command_stdout_lines ~max_output_bytes:command.max_output_bytes ~truncated:run.stdout.truncated
          run.stdout.output
      in
      if run.stdout.truncated then
        context_command_result ~diagnostic "warning"
          (context_warning_summary "Context Command" "stdout exceeded maxOutputBytes")
          lines
      else context_command_result ~diagnostic "succeeded" "Context Command succeeded." lines
    | Unix.WEXITED code ->
      let warning = Printf.sprintf "exited with code %d" code in
      context_command_result ~diagnostic "warning" (context_warning_summary "Context Command" warning)
        (context_command_warning_lines warning)
    | Unix.WSIGNALED signal ->
      let warning = Printf.sprintf "terminated by signal %d" signal in
      context_command_result ~diagnostic "warning" (context_warning_summary "Context Command" warning)
        (context_command_warning_lines warning)
    | Unix.WSTOPPED signal ->
      let warning = Printf.sprintf "stopped by signal %d" signal in
      context_command_result ~diagnostic "warning" (context_warning_summary "Context Command" warning)
        (context_command_warning_lines warning)

let with_context_command_pipes f =
  let stdout_read, stdout_write = Unix.pipe () in
  let stderr_read, stderr_write = Unix.pipe () in
  Fun.protect
    ~finally:(fun () -> List.iter close_noerr [ stdout_read; stdout_write; stderr_read; stderr_write ])
    (fun () ->
      Unix.set_nonblock stdout_read;
      Unix.set_nonblock stderr_read;
      f ~stdout_read ~stdout_write ~stderr_read ~stderr_write)

let context_command_failure_result ?env ?duration_ms command warning =
  let diagnostic = make_context_command_diagnostic ?env ?duration_ms ~error:warning command in
  context_command_result ~diagnostic "failed" (context_warning_summary "Context Command" warning)
    (context_command_warning_lines warning)

let run_context_command config issue attempt (stage : Config.stage_agent) ~workspace command =
  let started_at = Unix.gettimeofday () in
  try
    let input_json = context_command_input_json config issue attempt stage ~workspace in
    let input_path = write_context_command_input_file config input_json in
    Fun.protect
      ~finally:(fun () -> remove_if_exists input_path)
      (fun () ->
        let env = env_with_context_input input_path in
        let cwd = context_command_cwd config workspace command in
        match command.argv with
        | [] ->
            context_command_failure_result ~env ~duration_ms:(context_command_elapsed_ms started_at) command
              "command argv is empty"
        | program :: _ -> (
            match resolve_context_executable ~cwd env program with
            | Error error ->
                context_command_failure_result ~env ~duration_ms:(context_command_elapsed_ms started_at) command error
            | Ok executable ->
                with_context_command_pipes (fun ~stdout_read ~stdout_write ~stderr_read ~stderr_write ->
                    let pid =
                      spawn_context_command ~cwd ~env ~stdin_path:input_path ~stdout_fd:stdout_write
                        ~stderr_fd:stderr_write ~executable command.argv
                    in
                    close_noerr stdout_write;
                    close_noerr stderr_write;
                    let run = wait_context_command env pid command.timeout_ms stdout_read stderr_read command.max_output_bytes in
                    context_command_status_result command env run)))
  with exn ->
    let warning = "failed: " ^ Printexc.to_string exn in
    context_command_failure_result ~duration_ms:(context_command_elapsed_ms started_at) command warning

let context_command_result config issue attempt (stage : Config.stage_agent) ~workspace =
  match stage.context_command with
  | Some command when Config.stage_context_command_enabled stage -> Some (run_context_command config issue attempt stage ~workspace command)
  | _ -> None

let stage_context_snapshot_requested (stage : Config.stage_agent) =
  Config.stage_context_snapshot_enabled stage || Config.stage_context_command_enabled stage

let stage_context_snapshot_max_output_bytes (stage : Config.stage_agent) =
  match stage.context_snapshot with
  | Some snapshot when Config.stage_context_snapshot_enabled stage -> snapshot.max_output_bytes
  | _ -> Config.default_context_snapshot_max_output_bytes

let agent_context_snapshot_result ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch :
    context_generation =
  match match stage with Some _ -> stage | None -> stage_for_issue config issue with
  | Some stage when stage_context_snapshot_requested stage ->
      let command_result = context_command_result config issue attempt stage ~workspace in
      let lines =
        [
          "## Agent Context Snapshot";
          "";
          Printf.sprintf "- Issue: %s %s" issue.Issue.identifier (compact_markdown_value issue.title);
          Printf.sprintf "- Project status: %s" issue.state;
          Printf.sprintf "- Labels: %s" (if issue.labels = [] then "(none)" else String.concat ", " issue.labels);
          Printf.sprintf "- Blockers: %s" (blockers_line issue.blocked_by);
          Printf.sprintf "- Attempt: %d" (launch_attempt_number attempt);
          Printf.sprintf "- Stage Agent: %s" stage.agent;
          Printf.sprintf "- Task Branch: %s" (task_branch config issue);
          Printf.sprintf "- Agent Worktree: %s" workspace.Workspace.path;
        ]
        @ optional_line "Loop-Start Branch" loop_start_branch
        @ previous_attempt_lines previous_attempt_output
        @ (match command_result with Some result -> result.lines | None -> [])
      in
      let raw_snapshot = String.concat "\n" lines in
      let max_output_bytes = stage_context_snapshot_max_output_bytes stage in
      let context_status =
        match command_result with
        | Some { context_status = { Runtime_state.state = "succeeded"; _ }; _ } ->
            context_status "succeeded" "Agent Context Snapshot generated; Context Command succeeded."
        | Some result -> result.context_status
        | None -> context_status "succeeded" "Agent Context Snapshot generated."
      in
      let diagnostics =
        {
          snapshot =
            {
              enabled = true;
              rendered_bytes = String.length raw_snapshot;
              truncated = String.length raw_snapshot > max_output_bytes;
            };
          command = Option.bind command_result (fun result -> result.diagnostic);
        }
      in
      { lines = [ truncate_snapshot max_output_bytes raw_snapshot ]; context_status; context_diagnostics = Some diagnostics }
  | _ ->
      {
        lines = [];
        context_status = Runtime_state.skipped_context_status;
        context_diagnostics = None;
      }

let agent_context_snapshot ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch =
  match (agent_context_snapshot_result ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch).lines with
  | [ snapshot ] -> Some snapshot
  | _ -> None

let compose_prompt_result ?stage ?previous_attempt_output config issue attempt base_prompt ~workspace ~loop_start_branch =
  let snapshot_result = agent_context_snapshot_result ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch in
  let prompt =
    match snapshot_result.lines with
    | [] -> normal_prompt ?stage config issue base_prompt
    | [ snapshot ] -> Printf.sprintf "%s\n\n---\n\n%s" (normal_prompt ?stage config issue base_prompt |> Util.trim) snapshot
    | snapshots ->
        Printf.sprintf "%s\n\n---\n\n%s" (normal_prompt ?stage config issue base_prompt |> Util.trim)
          (String.concat "\n" snapshots)
  in
  let prompt =
    match stage_goal_handoff ?stage config issue with
    | None -> prompt
    | Some (stage, loop_command) ->
        Printf.sprintf "%s %s\n\n---\n\n%s" loop_command (stage_goal_context issue attempt stage) prompt
  in
  {
    prompt;
    context_status = snapshot_result.context_status;
    context_diagnostics = snapshot_result.context_diagnostics;
  }

let compose_prompt ?stage ?previous_attempt_output config issue attempt base_prompt ~workspace ~loop_start_branch =
  (compose_prompt_result ?stage ?previous_attempt_output config issue attempt base_prompt ~workspace ~loop_start_branch).prompt

let compose_compozy_task_step_prompt_result ?stage ?issue ?previous_attempt_output config run attempt ~workspace
    ~loop_start_branch =
  match Compozy_tasks_tracker.current_prompt run with
  | Error _ as error -> error
  | Ok base_prompt ->
      let issue = Option.value issue ~default:(Compozy_tasks_tracker.issue_of_prd_run run) in
      Ok (compose_prompt_result ?stage ?previous_attempt_output config issue attempt base_prompt ~workspace ~loop_start_branch)

let compose_compozy_task_step_prompt ?stage ?previous_attempt_output config run attempt ~workspace ~loop_start_branch =
  compose_compozy_task_step_prompt_result ?stage ?previous_attempt_output config run attempt ~workspace ~loop_start_branch
  |> Result.map (fun composition -> composition.prompt)

let context_command_diagnostic_to_yojson diagnostic =
  `Assoc
    [
      ("name", json_option_string diagnostic.name);
      ("cwdKind", `String diagnostic.cwd_kind);
      ("exitCode", json_option_int diagnostic.exit_code);
      ("signal", json_option_int diagnostic.signal);
      ("stoppedSignal", json_option_int diagnostic.stopped_signal);
      ("durationMs", `Int diagnostic.duration_ms);
      ("timedOut", `Bool diagnostic.timed_out);
      ("stdoutBytes", `Int diagnostic.stdout_bytes);
      ("stderrBytes", `Int diagnostic.stderr_bytes);
      ("stdoutTruncated", `Bool diagnostic.stdout_truncated);
      ("stdoutPersisted", `Bool diagnostic.stdout_persisted);
      ("error", json_option_string diagnostic.error);
    ]

let context_generation_diagnostics_to_yojson issue attempt (stage : Config.stage_agent) diagnostic_id diagnostics =
  `Assoc
    [
      ("kind", `String "Context Diagnostics");
      ("diagnosticId", `String diagnostic_id);
      ("createdAt", `String (Util.now_iso8601 ()));
      ("issueIdentifier", `String issue.Issue.identifier);
      ("stageAgent", `String stage.agent);
      ("attempt", `Int (launch_attempt_number attempt));
      ( "snapshot",
        `Assoc
          [
            ("enabled", `Bool diagnostics.snapshot.enabled);
            ("renderedBytes", `Int diagnostics.snapshot.rendered_bytes);
            ("truncated", `Bool diagnostics.snapshot.truncated);
          ] );
      ("command", (match diagnostics.command with Some command -> context_command_diagnostic_to_yojson command | None -> `Null));
    ]

let context_diagnostic_id issue attempt =
  Printf.sprintf "%s-attempt-%d-%d" (Workspace.sanitize issue.Issue.identifier) (launch_attempt_number attempt)
    (int_of_float (Unix.gettimeofday () *. 1000000.))

let task_prompt_archive_id issue attempt =
  Printf.sprintf "%s-attempt-%d-%d" (Workspace.sanitize issue.Issue.identifier) (launch_attempt_number attempt)
    (int_of_float (Unix.gettimeofday () *. 1000000.))

let task_prompt_archive_metadata_to_yojson issue attempt stage (harness : Config.agent_harness) (workspace : Workspace.t)
    archive_id prompt_path =
  let stage_agent, stage_states = selected_stage_fields stage in
  `Assoc
    [
      ("kind", `String "Agent Prompt Archive");
      ("archiveId", `String archive_id);
      ("createdAt", `String (Util.now_iso8601 ()));
      ("issueId", `String issue.Issue.id);
      ("issueIdentifier", `String issue.identifier);
      ("issueTitle", `String issue.title);
      ("issueState", `String issue.state);
      ("attempt", `Int (launch_attempt_number attempt));
      ("stageAgent", json_option_string stage_agent);
      ("stageStates", `List (List.map (fun state -> `String state) stage_states));
      ("harnessName", `String harness.name);
      ("harnessKind", `String harness.kind);
      ("workspacePath", `String workspace.Workspace.path);
      ("promptPath", `String prompt_path);
    ]

let persist_task_prompt_archive config issue stage harness attempt workspace prompt =
  let dir = task_prompt_archive_dir config in
  ensure_private_runtime_dir dir;
  let archive_id = task_prompt_archive_id issue attempt in
  let prompt_path = Filename.concat dir (archive_id ^ ".md") in
  let metadata_path = Filename.concat dir (archive_id ^ ".json") in
  write_private_file prompt_path prompt;
  let metadata = task_prompt_archive_metadata_to_yojson issue attempt stage harness workspace archive_id prompt_path in
  write_private_file metadata_path (Yojson.Safe.pretty_to_string metadata ^ "\n");
  prompt_path

let max_context_diagnostic_summaries = 100

let context_diagnostic_file_entry dir name =
  if Filename.check_suffix name ".json" then
    let path = Filename.concat dir name in
    try
      let stat = Unix.stat path in
      if stat.Unix.st_kind = Unix.S_REG then Some (path, stat.Unix.st_mtime) else None
    with Unix.Unix_error _ | Sys_error _ -> None
  else None

let prune_context_diagnostic_files ~keep_path dir =
  let files =
    Sys.readdir dir |> Array.to_list |> List.filter_map (context_diagnostic_file_entry dir)
    |> List.sort (fun (left_path, left_mtime) (right_path, right_mtime) ->
           let mtime_compare = compare right_mtime left_mtime in
           if mtime_compare <> 0 then mtime_compare else String.compare right_path left_path)
  in
  let keep_files, other_files = List.partition (fun (path, _) -> path = keep_path) files in
  let files = keep_files @ other_files in
  let rec loop kept = function
    | [] -> ()
    | _ :: rest when kept < max_context_diagnostic_summaries -> loop (kept + 1) rest
    | (path, _) :: rest ->
        remove_if_exists path;
        loop kept rest
  in
  loop 0 files

let persist_context_generation_diagnostics config issue stage attempt diagnostics =
  let dir = context_diagnostics_dir config in
  ensure_private_runtime_dir dir;
  let diagnostic_id = context_diagnostic_id issue attempt in
  let path = Filename.concat dir (diagnostic_id ^ ".json") in
  let json = context_generation_diagnostics_to_yojson issue attempt stage diagnostic_id diagnostics in
  write_private_file path (Yojson.Safe.pretty_to_string json ^ "\n");
  prune_context_diagnostic_files ~keep_path:path dir;
  let command = diagnostics.command in
  {
    Runtime_state.issue_id = issue.Issue.id;
    issue_identifier = issue.identifier;
    stage_agent = Some stage.agent;
    diagnostic_id;
    diagnostic_path = path;
    command_name = Option.bind command (fun (command : context_command_diagnostic) -> command.name);
    cwd_kind = Option.map (fun (command : context_command_diagnostic) -> command.cwd_kind) command;
    timed_out = Option.map (fun (command : context_command_diagnostic) -> command.timed_out) command;
    exit_code = Option.bind command (fun (command : context_command_diagnostic) -> command.exit_code);
    stdout_bytes = Option.map (fun (command : context_command_diagnostic) -> command.stdout_bytes) command;
    stderr_bytes = Option.map (fun (command : context_command_diagnostic) -> command.stderr_bytes) command;
    stdout_truncated = Option.map (fun (command : context_command_diagnostic) -> command.stdout_truncated) command;
  }

let rec drop_first count rows =
  if count <= 0 then rows
  else match rows with [] -> [] | _ :: rest -> drop_first (count - 1) rest

let append_context_diagnostic_summary rows row =
  let rows = rows @ [ row ] in
  drop_first (List.length rows - max_context_diagnostic_summaries) rows

let require_clean_loop_start root =
  match run_shell_capture ~cwd:root "git status --porcelain" with
  | Ok "" -> Ok ()
  | Ok _ -> Error "loop-start worktree must be clean before creating task worktrees"
  | Error error -> Error ("git status failed: " ^ error)

let prune_stale_worktrees root =
  match run_shell_capture ~cwd:root "git worktree prune" with
  | Ok _ -> Ok ()
  | Error error -> Error ("git worktree prune failed: " ^ error)

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
          let prepare_workspace () =
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
            match create_branch with
            | Error error -> Error ("task branch creation failed: " ^ error)
            | Ok _ -> (
                match
                  run_shell_capture ~cwd:config.repository_root
                    (Printf.sprintf "git worktree add %s %s" (Util.shell_quote workspace.path) (Util.shell_quote branch))
                with
                | Ok _ -> Ok workspace
                | Error error -> Error ("agent worktree creation failed: " ^ error))
          in
          match prune_stale_worktrees config.repository_root with
          | Error _ as error -> error
          | Ok () -> prepare_workspace ()

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

let render_task_pull_request_issue_template issue text =
  text
  |> replace_token ~token:"issue_identifier" ~value:issue.Issue.identifier
  |> replace_token ~token:"issue_title" ~value:issue.Issue.title
  |> Util.trim

let config_with_task_pull_request_issue config issue =
  let pull_request = config.Config.pull_request in
  {
    config with
    pull_request =
      {
        pull_request with
        title = render_task_pull_request_issue_template issue pull_request.title;
        body = render_task_pull_request_issue_template issue pull_request.body;
      };
  }

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

let pull_request_repo_arg config =
  let owner = Util.trim config.Config.tracker.owner in
  let repo = Util.trim config.tracker.repo in
  if owner = "" || repo = "" then ""
  else Printf.sprintf " --repo %s" (Util.shell_quote (owner ^ "/" ^ repo))

let existing_batch_pull_request config ~head_branch =
  let command =
    Printf.sprintf "gh pr list%s --state open --head %s --base %s --limit 1 --json url"
      (pull_request_repo_arg config) (Util.shell_quote head_branch)
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
  let title = render_pull_request_template config ~head_branch config.pull_request.title in
  let body = render_pull_request_template config ~head_branch config.pull_request.body in
  let command =
    Printf.sprintf "gh pr create%s --head %s --base %s --title %s --body %s" (pull_request_repo_arg config)
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

let git_commit_stage_changes config workspace issue stage next_status =
  let commit_with_policy root policy message =
    match run_shell_capture ~cwd:root "git add -A" with
    | Error error -> Error ("git add failed: " ^ error)
    | Ok _ -> (
        match run_shell_capture ~cwd:root "git diff --cached --quiet" with
        | Ok _ ->
            render_commit_skipped issue.Issue.identifier;
            Error "commit required but no staged changes were found"
        | Error _ -> (
            let command = Printf.sprintf "git commit -m %s" (Util.shell_quote message) in
            match run_shell_capture ~cwd:root command with
            | Error error -> Error error
            | Ok _ ->
                render_commit_completed issue.Issue.identifier message;
                if policy.Config.push then
                  match push_current_branch root with
                  | Ok _ -> Ok ()
                  | Error error -> Error ("stage push failed: " ^ error)
                else Ok ()))
  in
  match stage with
  | None -> Ok ()
  | Some stage -> (
      match stage.Config.commit with
      | None -> Ok ()
      | Some policy when not policy.enabled -> Ok ()
      | Some policy -> (
          let root = workspace.Workspace.path in
          match has_worktree_changes root with
          | Error error -> Error error
          | Ok false ->
              render_commit_skipped issue.Issue.identifier;
              Error "commit required but agent produced no code changes"
          | Ok true -> (
              match changed_paths_in_worktree root with
              | Error error -> Error error
              | Ok paths -> (
                  match unauthorized_protected_path_matches config issue paths with
                  | [] -> (
                      match render_commit_message_result issue (Some stage) next_status policy with
                      | Error _ as error -> error
                      | Ok message -> commit_with_policy root policy message)
                  | matches -> Error (protected_path_attention_message matches)))))

let replace_first_word command replacement =
  let command = Util.trim command in
  match String.split_on_char ' ' command with
  | [] -> replacement
  | _ :: rest -> String.concat " " (replacement :: rest)

let render_harness_command (harness : Config.agent_harness) =
  let command = Util.trim harness.command in
  let model = Util.trim harness.model in
  let reasoning = Util.trim harness.reasoning_effort in
  let with_tokens =
    command
    |> replace_token ~token:"model" ~value:(Util.shell_quote model)
    |> replace_token ~token:"reasoning" ~value:(Util.shell_quote reasoning)
  in
  if with_tokens <> command || harness.kind <> "codex" then with_tokens
  else
    match String.split_on_char ' ' command with
    | "codex" :: _ ->
        let overrides =
          Printf.sprintf "codex -m %s -c %s" (Util.shell_quote model)
            (Util.shell_quote (Printf.sprintf "model_reasoning_effort=%s" (Yojson.Safe.to_string (`String reasoning))))
        in
        replace_first_word command overrides
    | _ -> command

let codex_command config =
  Config.default_agent_harness config |> render_harness_command

let spawn_shell_command command =
  match Unix.fork () with
  | 0 ->
      (try
         ignore (Unix.setsid ());
         Unix.execv "/bin/sh" [| "/bin/sh"; "-lc"; command |]
       with _ -> Unix._exit 127)
  | pid -> pid

let failed_launch_command ~workspace_path ~stdout_path ~stderr_path error =
  Printf.sprintf "cd %s && : > %s && printf %s %s > %s; exit 1" (Util.shell_quote workspace_path)
    (Util.shell_quote stdout_path) (Util.shell_quote "%s\n") (Util.shell_quote error) (Util.shell_quote stderr_path)

let sandbox_event_suffix (plan : Sandbox_runtime.launch_plan) =
  match plan.provider with
  | None -> ""
  | Some provider ->
      let reuse =
        match plan.reuse_outcome with
        | Some reuse_outcome -> " sandbox_reuse_outcome=" ^ reuse_outcome
        | None -> ""
      in
      let container =
        match plan.container_name with
        | Some container_name -> " sandbox_container=" ^ container_name
        | None -> ""
      in
      " sandbox_provider=" ^ provider ^ reuse ^ container

let launch_event_field key event =
  let prefix = key ^ "=" in
  event |> String.split_on_char ' ' |> List.rev |> List.find_map (Util.drop_prefix ~prefix)

let sandbox_metadata_from_launch (config : Config.t) event =
  if config.sandbox.enabled then
    (Some true, launch_event_field "sandbox_provider" event, launch_event_field "sandbox_reuse_outcome" event)
  else (None, None, None)

let shell_launch ~stage ~config ~workspace ~prompt ~issue =
  let stage = match stage with Some _ -> stage | None -> stage_for_issue config issue in
  let harness = Option.value (Config.selected_agent_harness config stage) ~default:(Config.default_agent_harness config) in
  let prompt_path = write_prompt workspace prompt in
  let stdout_path = Filename.concat workspace.Workspace.path "stdout.log" in
  let stderr_path = Filename.concat workspace.Workspace.path "stderr.log" in
  let plan =
    Sandbox_runtime.launch_plan ~config ~workspace_path:workspace.Workspace.path ~harness_command:(render_harness_command harness)
      ~prompt_path ~stdout_path ~stderr_path
  in
  let command, event_suffix =
    match plan with
    | Ok plan -> (plan.command, sandbox_event_suffix plan)
    | Error error -> (failed_launch_command ~workspace_path:workspace.Workspace.path ~stdout_path ~stderr_path error, " sandbox_error=plan")
  in
  let pid = spawn_shell_command command in
  {
    pid = Some pid;
    session_id = Some (Printf.sprintf "pid:%d" pid);
    event =
      Printf.sprintf "launched issue=%s repository=%s workspace=%s%s" issue.Issue.identifier config.repository_root
        workspace.Workspace.path event_suffix;
    stdout_path = Some stdout_path;
    stderr_path = Some stderr_path;
  }

let default_fetch tracker = tracker.Issue_tracker.fetch_candidates ()
let default_set_status tracker issue status = tracker.Issue_tracker.update_status issue status

let make ?ordered_queue ?(launch : launch = shell_launch) ?(fetch = default_fetch)
    ?(set_status = default_set_status)
    ?(commit_stage = git_commit_stage_changes) ?(batch_pull_request_handoff = gh_batch_pull_request_handoff)
    ?(notify_state = fun _ -> ()) ~(config : Config.t) ~prompt_template () =
  let workspace_repository_name = Filename.basename config.repository_root in
  let tracker = Issue_tracker.make config in
  let resolved_ordered_queue = resolve_ordered_queue tracker ordered_queue in
  {
    config;
    prompt_template;
    tracker;
    state =
      Runtime_state.empty ~workspace_repository_name ~tracker_kind:tracker.kind ~status_order:(Config.project_status_order config)
        ?ordered_queue:(Option.map (load_ordered_queue_state config) ordered_queue)
        ~goal_loops:(load_goal_loop_states config)
        ?compozy_progress:(Runtime_state.initial_compozy_progress config)
        ~compozy_progresses:(Runtime_state.initial_compozy_progresses config)
        ();
    children = [];
    retry_due = Hashtbl.create 16;
    tracker_retry_due = None;
    attempts = Hashtbl.create 16;
    previous_attempt_outputs = Hashtbl.create 16;
    blocked = Hashtbl.create 16;
    launch;
    fetch;
    set_status;
    commit_stage;
    batch_pull_request_handoff;
    notify_state;
    loop_start_branch = current_branch config.repository_root;
    startup_reconciliation_done = false;
    batch_pull_request_completed = false;
    ordered_queue;
    resolved_ordered_queue;
  }

let get_state orchestrator = orchestrator.state

let set_state orchestrator state =
  let state =
    match persist_goal_loop_states orchestrator.config state.Runtime_state.goal_loops with
    | None -> state
    | Some error -> { state with Runtime_state.last_error = Some error }
  in
  orchestrator.state <- state;
  persist_ordered_queue_state orchestrator.config state.Runtime_state.ordered_queue;
  orchestrator.notify_state state

let update_state orchestrator f = set_state orchestrator (f orchestrator.state)

let goal_loop_budget_of_config (budget : Config.stage_goal_loop_budget) : Goal_loop.budget =
  { Goal_loop.max_turns = budget.max_turns; max_runtime_ms = budget.max_runtime_ms; max_tokens = budget.max_tokens }

let goal_loop_budget_of_runtime_state (budget : Runtime_state.goal_loop_budget) : Goal_loop.budget =
  { Goal_loop.max_turns = budget.max_turns; max_runtime_ms = budget.max_runtime_ms; max_tokens = budget.max_tokens }

let runtime_goal_loop_budget_of_goal_loop (budget : Goal_loop.budget) : Runtime_state.goal_loop_budget =
  { Runtime_state.max_turns = budget.max_turns; max_runtime_ms = budget.max_runtime_ms; max_tokens = budget.max_tokens }

let goal_loop_of_runtime_state (loop : Runtime_state.goal_loop) : Goal_loop.t =
  {
    Goal_loop.issue_id = loop.issue_id;
    issue_identifier = loop.issue_identifier;
    run_id = loop.run_id;
    goal = loop.goal;
    state = loop.state;
    stage_agent = loop.stage_agent;
    harness_name = loop.harness_name;
    harness_kind = loop.harness_kind;
    attempt_count = loop.attempt_count;
    budget = goal_loop_budget_of_runtime_state loop.budget;
    latest_evidence = loop.latest_evidence;
    stop_outcome = loop.stop_outcome;
    stop_reason = loop.stop_reason;
    next_action = loop.next_action;
    diagnostics_path = loop.diagnostics_path;
    updated_at = loop.updated_at;
  }

let runtime_goal_loop_of_goal_loop (loop : Goal_loop.t) : Runtime_state.goal_loop =
  {
    Runtime_state.issue_id = loop.issue_id;
    issue_identifier = loop.issue_identifier;
    run_id = loop.run_id;
    goal = loop.goal;
    state = loop.state;
    stage_agent = loop.stage_agent;
    harness_name = loop.harness_name;
    harness_kind = loop.harness_kind;
    attempt_count = loop.attempt_count;
    budget = runtime_goal_loop_budget_of_goal_loop loop.budget;
    latest_evidence = loop.latest_evidence;
    stop_outcome = loop.stop_outcome;
    stop_reason = loop.stop_reason;
    next_action = loop.next_action;
    diagnostics_path = loop.diagnostics_path;
    updated_at = loop.updated_at;
  }

let upsert_goal_loop (loop : Runtime_state.goal_loop) (loops : Runtime_state.goal_loop list) =
  loop :: List.filter (fun (existing : Runtime_state.goal_loop) -> existing.issue_id <> loop.issue_id) loops

let stage_goal_loop_config = function
  | Some (stage : Config.stage_agent) when Config.stage_goal_loop_enabled stage ->
      Option.map (fun goal_loop -> (stage, goal_loop)) stage.goal_loop
  | _ -> None

let goal_loop_goal issue =
  match Util.trim issue.Issue.title with
  | "" -> Printf.sprintf "Complete %s" issue.identifier
  | title -> Printf.sprintf "Complete %s: %s" issue.identifier title

let goal_loop_run_id state issue =
  match Runtime_state.goal_loop_for_issue state issue.Issue.id with
  | Some loop when not (Goal_loop.terminal_state loop.state) -> loop.run_id
  | _ -> Printf.sprintf "goal-loop-%s-%d" (Workspace.sanitize issue.identifier) (int_of_float (Unix.time ()))

let goal_loop_for_dispatch state issue stage (harness : Config.agent_harness) attempt now =
  match stage_goal_loop_config stage with
  | None -> None
  | Some (stage, goal_loop_config) ->
      let run_id = goal_loop_run_id state issue in
      let attempt_count = launch_attempt_number attempt in
      Some
        (Goal_loop.create issue.id issue.identifier run_id (goal_loop_goal issue) (Some stage.agent)
           (Some harness.name) (Some harness.kind) attempt_count
           (goal_loop_budget_of_config goal_loop_config.budget)
           now
        |> runtime_goal_loop_of_goal_loop)

let update_goal_loop_in_state issue_id update state =
  match Runtime_state.goal_loop_for_issue state issue_id with
  | None -> state
  | Some loop ->
      let updated = goal_loop_of_runtime_state loop |> update |> runtime_goal_loop_of_goal_loop in
      { state with Runtime_state.goal_loops = upsert_goal_loop updated state.goal_loops }

let update_goal_loop_state orchestrator issue_id update =
  update_state orchestrator (update_goal_loop_in_state issue_id update)

let goal_loop_attempt_count orchestrator issue_id =
  match Runtime_state.goal_loop_for_issue orchestrator.state issue_id with
  | Some loop -> loop.attempt_count
  | None -> launch_attempt_number (Hashtbl.find_opt orchestrator.attempts issue_id)

let record_goal_loop_activity orchestrator issue_id latest_activity next_action =
  let attempt_count = goal_loop_attempt_count orchestrator issue_id in
  let updated_at = Util.now_iso8601 () in
  update_goal_loop_state orchestrator issue_id (fun loop ->
      Goal_loop.record_activity loop attempt_count latest_activity next_action updated_at)

let mark_goal_loop_budget_exhausted orchestrator issue_id reason =
  let updated_at = Util.now_iso8601 () in
  update_goal_loop_state orchestrator issue_id (fun loop -> Goal_loop.stop_budget_exhausted loop reason updated_at)

let mark_goal_loop_goal_met orchestrator issue_id evidence =
  let updated_at = Util.now_iso8601 () in
  update_goal_loop_state orchestrator issue_id (fun loop -> Goal_loop.stop_goal_met loop evidence updated_at)

let running_row_for_child orchestrator child =
  List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = child.issue_id) orchestrator.state.running

let goal_loop_budget_exhaustion orchestrator child =
  match Runtime_state.goal_loop_for_issue orchestrator.state child.issue_id with
  | None -> None
  | Some loop when Goal_loop.terminal_state loop.state -> None
  | Some loop ->
      let elapsed_ms = int_of_float ((Unix.time () -. child.started_at) *. 1000.) in
      let total_tokens =
        match running_row_for_child orchestrator child with Some row -> row.tokens.total_tokens | None -> 0
      in
      (match loop.budget.max_turns with
      | Some max_turns when loop.attempt_count > max_turns ->
          Some
            (Printf.sprintf "Goal Loop budget exhausted: maxTurns %d reached before attempt %d." max_turns
               loop.attempt_count)
      | _ -> (
          match loop.budget.max_runtime_ms with
          | Some max_runtime_ms when elapsed_ms >= max_runtime_ms ->
              Some
                (Printf.sprintf "Goal Loop budget exhausted: maxRuntimeMs %d reached after %dms." max_runtime_ms
                   elapsed_ms)
          | _ -> (
              match loop.budget.max_tokens with
              | Some max_tokens when total_tokens >= max_tokens ->
                  Some
                    (Printf.sprintf "Goal Loop budget exhausted: maxTokens %d reached with %d tokens." max_tokens
                       total_tokens)
              | _ -> None)))

let context_command_of_goal_loop_evidence (command : Config.stage_goal_loop_evidence_command) :
    Config.stage_context_command =
  {
    argv = command.argv;
    cwd = command.cwd;
    timeout_ms = command.timeout_ms;
    max_output_bytes = command.max_output_bytes;
    validation_error = None;
  }

type goal_loop_evidence_result =
  | Goal_loop_evidence_passed of string
  | Goal_loop_evidence_failed of string

let goal_loop_evidence_failure_summary run =
  if run.timed_out then "Goal Loop evidence command timed out."
  else
    match run.process_status with
    | Unix.WEXITED code -> Printf.sprintf "Goal Loop evidence command exited with code %d." code
    | Unix.WSIGNALED signal -> Printf.sprintf "Goal Loop evidence command terminated by signal %d." signal
    | Unix.WSTOPPED signal -> Printf.sprintf "Goal Loop evidence command stopped by signal %d." signal

let run_goal_loop_evidence_command orchestrator child (command : Config.stage_goal_loop_evidence_command) =
  let started_at = Unix.gettimeofday () in
  let context_command = context_command_of_goal_loop_evidence command in
  try
    let input_path =
      write_context_command_input_file orchestrator.config
        (Yojson.Safe.to_string
           (`Assoc
          [
            ("kind", `String "Goal Loop Evidence Input");
            ("issueIdentifier", `String child.issue_identifier);
            ("workspaceRepositoryRoot", `String orchestrator.config.Config.repository_root);
            ("agentWorktree", `String child.workspace.Workspace.path);
          ]))
    in
    Fun.protect
      ~finally:(fun () -> remove_if_exists input_path)
      (fun () ->
        let env = env_with_context_input input_path in
        let cwd = context_command_cwd orchestrator.config child.workspace context_command in
        match command.argv with
        | [] -> Goal_loop_evidence_failed "Goal Loop evidence command argv is empty."
        | program :: _ -> (
            match resolve_context_executable ~cwd env program with
            | Error error -> Goal_loop_evidence_failed ("Goal Loop evidence command " ^ error ^ ".")
            | Ok executable ->
                with_context_command_pipes (fun ~stdout_read ~stdout_write ~stderr_read ~stderr_write ->
                    let pid =
                      spawn_context_command ~cwd ~env ~stdin_path:input_path ~stdout_fd:stdout_write
                        ~stderr_fd:stderr_write ~executable command.argv
                    in
                    close_noerr stdout_write;
                    close_noerr stderr_write;
                    let run =
                      wait_context_command env pid command.timeout_ms stdout_read stderr_read command.max_output_bytes
                    in
                    if run.timed_out then Goal_loop_evidence_failed (goal_loop_evidence_failure_summary run)
                    else
                      match run.process_status with
                      | Unix.WEXITED 0 ->
                          let evidence = Util.trim run.stdout.output in
                          if evidence = "" then
                            Goal_loop_evidence_failed
                              "Goal Loop evidence command succeeded but produced no deterministic evidence."
                          else Goal_loop_evidence_passed evidence
                      | _ -> Goal_loop_evidence_failed (goal_loop_evidence_failure_summary run))))
  with exn ->
    let elapsed_ms = context_command_elapsed_ms started_at in
    Goal_loop_evidence_failed
      (Printf.sprintf "Goal Loop evidence command failed after %dms: %s" elapsed_ms (Printexc.to_string exn))

let goal_loop_completion_gate orchestrator child =
  let stage = match child.stage with Some _ -> child.stage | None -> stage_for_issue orchestrator.config child.issue in
  match stage_goal_loop_config stage with
  | None -> `Complete
  | Some (_stage, goal_loop_config) -> (
      match goal_loop_config.evidence_command with
      | None -> `Fail "Goal Loop evidence command is not configured."
      | Some command -> (
          match run_goal_loop_evidence_command orchestrator child command with
          | Goal_loop_evidence_passed evidence ->
              mark_goal_loop_goal_met orchestrator child.issue_id evidence;
              `Complete
          | Goal_loop_evidence_failed reason -> `Fail reason))

let is_compozy_prd_run_child orchestrator issue =
  orchestrator.tracker.kind = "compozy_tasks" && Util.starts_with ~prefix:"compozy:" issue.Issue.identifier

let compozy_workspace_root config (workspace : Workspace.t) =
  let repository_root = Unix.realpath config.Config.repository_root in
  let compozy_root = Unix.realpath config.Config.tracker.compozy_root in
  if compozy_root = repository_root then workspace.path
  else
    let prefix = repository_root ^ Filename.dir_sep in
    match Util.drop_prefix ~prefix compozy_root with
    | Some relative -> Filename.concat workspace.path relative
    | None -> compozy_root

let compozy_prd_run_for_issue_identifier ~compozy_root issue_identifier =
  match Compozy_tasks_tracker.discover_prd_runs ~compozy_root with
  | Error error -> Error error
  | Ok runs -> (
      match List.find_opt (fun (run : Compozy_tasks_tracker.prd_run) -> run.id = issue_identifier) runs with
      | Some run -> Ok run
      | None -> Error (Printf.sprintf "Compozy PRD run not found for %s" issue_identifier))

let compozy_prd_run_for_root_issue config issue =
  compozy_prd_run_for_issue_identifier ~compozy_root:config.Config.tracker.compozy_root issue.Issue.identifier

let compozy_prd_run_for_workspace_issue config workspace issue =
  let compozy_root = compozy_workspace_root config workspace in
  compozy_prd_run_for_issue_identifier ~compozy_root issue.Issue.identifier

let dispatch_retry_task_file ?workspace config issue =
  if config.Config.tracker.kind <> "compozy_tasks" then None
  else if not (Util.starts_with ~prefix:"compozy:" issue.Issue.identifier) then None
  else
    let run_result =
      match workspace with
      | Some workspace -> compozy_prd_run_for_workspace_issue config workspace issue
      | None -> compozy_prd_run_for_root_issue config issue
    in
    match run_result with
    | Ok run -> Option.map (fun (step : Compozy_tasks_tracker.task_step) -> step.file) run.current_step
    | Error _ -> None

let previous_compozy_step_file (step : Compozy_tasks_tracker.task_step) steps =
  steps
  |> List.fold_left
       (fun previous (candidate : Compozy_tasks_tracker.task_step) ->
         if candidate.index >= step.index then previous
         else
           match previous with
           | None -> Some candidate
           | Some previous when candidate.index > previous.index -> Some candidate
           | Some _ -> previous)
       None
  |> Option.map (fun (step : Compozy_tasks_tracker.task_step) -> step.file)

let compozy_task_start_context config workspace issue =
  match compozy_prd_run_for_workspace_issue config workspace issue with
  | Error _ -> None
  | Ok run -> (
      match run.current_step with
      | None -> None
      | Some step -> Some (step.file, previous_compozy_step_file step run.steps))

let update_compozy_workspace_step_status config workspace (run : Compozy_tasks_tracker.prd_run)
    (step : Compozy_tasks_tracker.task_step) status =
  let compozy_root = compozy_workspace_root config workspace in
  match status with
  | "in_progress" -> Compozy_tasks_tracker.mark_step_started ~compozy_root run step
  | "completed" -> Compozy_tasks_tracker.mark_step_finished ~compozy_root run step
  | status ->
      let path = Filename.concat (Filename.concat compozy_root run.slug) step.file in
      Compozy_tasks_tracker.update_status ~compozy_root path status

let update_compozy_progress orchestrator run =
  let progress = Runtime_state.compozy_progress_of_prd_run_for_runtime orchestrator.config run in
  let upsert_progress progresses =
    let replaced = ref false in
    let progresses =
      List.map
        (fun existing ->
          if existing.Runtime_state.run_id = progress.run_id then (
            replaced := true;
            progress)
          else existing)
        progresses
    in
    if !replaced then progresses else progress :: progresses
  in
  update_state orchestrator (fun state ->
    {
      state with
      Runtime_state.compozy_progress = Some progress;
      compozy_progresses = upsert_progress state.compozy_progresses;
    })

let update_ordered_queue_entries orchestrator ?completed_identifier ?pending_identifier ?failed ?attention ?skipped
    ?(skip_missing = false) ~candidates () =
  match orchestrator.state.Runtime_state.ordered_queue with
  | None -> ()
  | Some queue ->
      let resolved_queue = Option.value orchestrator.resolved_ordered_queue ~default:[] in
      let canonical_identifier queue_identifier =
        canonical_identifier_for_queue_identifier resolved_queue queue_identifier |> Option.value ~default:queue_identifier
      in
      let entry_matches_identifier queue_identifier identifier =
        queue_identifier_matches_canonical resolved_queue queue_identifier identifier
      in
      let candidate_for queue_identifier =
        let canonical_identifier = canonical_identifier queue_identifier in
        List.find_opt (fun issue -> issue.Issue.identifier = canonical_identifier) candidates
      in
      let candidate_not_dispatchable queue_identifier =
        match candidate_for queue_identifier with
        | Some issue -> not (issue_state_is_dispatchable orchestrator issue.Issue.state)
        | None -> false
      in
      let candidate_dispatchable queue_identifier =
        match candidate_for queue_identifier with
        | Some issue -> issue_state_is_dispatchable orchestrator issue.Issue.state
        | None -> false
      in
      let candidate_missing queue_identifier = candidate_for queue_identifier = None in
      let skipped_identifier, skipped_reason =
        match skipped with Some (identifier, reason) -> (Some identifier, reason) | None -> (None, None)
      in
      let failed_identifier, failed_reason =
        match failed with Some (identifier, reason) -> (Some identifier, reason) | None -> (None, None)
      in
      let attention_identifier, attention_reason =
        match attention with Some (identifier, reason) -> (Some identifier, reason) | None -> (None, None)
      in
      let old_entries = queue.entries in
      let next_entries state =
        old_entries
        |> List.map (fun (entry : Runtime_state.ordered_queue_entry) ->
               let title = match candidate_for entry.issue_identifier with Some issue -> Some issue.Issue.title | None -> entry.title in
               let canonical_identifier = canonical_identifier entry.issue_identifier in
               let explicit_outcome =
                 match completed_identifier with
                 | Some identifier when entry_matches_identifier entry.issue_identifier identifier -> Some ("completed", None)
                 | _ -> (
                     match pending_identifier with
                     | Some identifier when entry_matches_identifier entry.issue_identifier identifier -> Some ("pending", None)
                     | _ -> (
                         match failed_identifier with
                         | Some identifier when entry_matches_identifier entry.issue_identifier identifier ->
                             Some ("failed", failed_reason)
                         | _ -> (
                             match attention_identifier with
                             | Some identifier when entry_matches_identifier entry.issue_identifier identifier ->
                                 Some ("attention", attention_reason)
                             | _ -> (
                                 match skipped_identifier with
                                 | Some identifier when entry_matches_identifier entry.issue_identifier identifier ->
                                     Some ("skipped", skipped_reason)
                                 | _ -> None))))
               in
               let inferred_state =
                 match entry_state_for_issue state canonical_identifier with
                 | Some state -> state
                 | None
                   when skip_missing
                        && ordered_queue_entry_needs_live_source entry
                        && (candidate_missing entry.issue_identifier || candidate_not_dispatchable entry.issue_identifier) ->
                     if candidate_missing entry.issue_identifier then "skipped"
                     else
                       (match candidate_for entry.issue_identifier with
                       | Some issue -> queue_terminal_state_for_status orchestrator.config issue.Issue.state
                       | None -> "skipped")
                 | None
                   when skip_missing
                        && ordered_queue_entry_is_stale_active entry
                        && candidate_not_dispatchable entry.issue_identifier ->
                     (match candidate_for entry.issue_identifier with
                     | Some issue -> queue_terminal_state_for_status orchestrator.config issue.Issue.state
                     | None -> entry.state)
                 | None
                   when skip_missing
                        && (entry.state = "completed" || ordered_queue_entry_is_stale_active entry)
                        && candidate_dispatchable entry.issue_identifier ->
                     "pending"
                 | None -> entry.state
               in
               let state_name = match explicit_outcome with Some (state, _) -> state | None -> inferred_state in
               let skip_reason =
                 match explicit_outcome with
                 | Some ("failed", reason) | Some ("attention", reason) | Some ("skipped", reason) -> reason
                 | Some ("completed", _) | Some ("pending", _) -> None
                 | Some (_, reason) -> reason
                 | None when skip_missing && ordered_queue_entry_needs_live_source entry && candidate_missing entry.issue_identifier ->
                     Some "Issue became unavailable or not dispatchable before admission."
                 | None
                   when skip_missing && ordered_queue_entry_needs_live_source entry
                        && candidate_not_dispatchable entry.issue_identifier ->
                     (match candidate_for entry.issue_identifier with
                     | Some issue -> queue_terminal_reason_for_status orchestrator.config issue.Issue.state
                     | None -> Some "Issue is no longer in a dispatchable project state.")
                 | None
                   when skip_missing
                        && ordered_queue_entry_is_stale_active entry
                        && candidate_not_dispatchable entry.issue_identifier ->
                     (match candidate_for entry.issue_identifier with
                     | Some issue -> queue_terminal_reason_for_status orchestrator.config issue.Issue.state
                     | None -> entry.skip_reason)
                 | None -> entry.skip_reason
               in
               { entry with title; state = state_name; skip_reason })
      in
      let new_entries = next_entries orchestrator.state in
      update_state orchestrator (fun state -> { state with ordered_queue = Some { Runtime_state.entries = next_entries state } });
      List.iter2
        (fun (old_entry : Runtime_state.ordered_queue_entry) (new_entry : Runtime_state.ordered_queue_entry) ->
          if old_entry.state <> "skipped" && new_entry.state = "skipped" then
            render_ordered_queue_skipped new_entry.issue_identifier (Option.value new_entry.skip_reason ~default:"")
          else if old_entry.state <> "failed" && new_entry.state = "failed" then
            render_ordered_queue_terminal "failed" new_entry.issue_identifier
              (Option.value new_entry.skip_reason ~default:"")
          else if old_entry.state <> "attention" && new_entry.state = "attention" then
            render_ordered_queue_terminal "attention" new_entry.issue_identifier
              (Option.value new_entry.skip_reason ~default:""))
        old_entries new_entries

let set_error orchestrator msg = update_state orchestrator (fun state -> { state with Runtime_state.last_error = Some msg })

let apply_compozy_lifecycle_update orchestrator run result =
  match result with
  | Ok _lifecycle ->
      update_compozy_progress orchestrator run;
      Ok ()
  | Error error -> Error ("could not update Compozy lifecycle: " ^ error)

let note_compozy_lifecycle_update orchestrator run result =
  match apply_compozy_lifecycle_update orchestrator run result with
  | Ok () -> ()
  | Error error -> set_error orchestrator error

let refresh_compozy_child_progress orchestrator child =
  if is_compozy_prd_run_child orchestrator child.issue then
    match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
    | Ok run -> update_compozy_progress orchestrator run
    | Error error -> set_error orchestrator error

let compozy_task_step_retry_reason (step : Compozy_tasks_tracker.task_step) retry_count error =
  Printf.sprintf "Compozy Task Step %s will retry after attempt %d failed: %s" step.file retry_count error

let compozy_task_step_failed_reason (step : Compozy_tasks_tracker.task_step) retry_count error =
  Printf.sprintf "Compozy Task Step %s failed after %d attempts: %s" step.file retry_count error

let mark_compozy_child_blocked orchestrator child reason =
  if is_compozy_prd_run_child orchestrator child.issue then
    match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
    | Ok run -> note_compozy_lifecycle_update orchestrator run (Compozy_lifecycle.mark_blocked orchestrator.config run ~reason)
    | Error error -> set_error orchestrator error

let mark_compozy_run_completed orchestrator run =
  let result =
    if run.Compozy_tasks_tracker.counts.failed > 0 then
      Compozy_lifecycle.mark_failed orchestrator.config run ~reason:""
    else if run.counts.skipped > 0 then Compozy_lifecycle.mark_skipped orchestrator.config run ~reason:""
    else if String.lowercase_ascii run.state = "completed" then
      Compozy_lifecycle.mark_completed orchestrator.config run
    else
      Compozy_lifecycle.mark_not_pr_ready orchestrator.config run
        ~reason:"Compozy PRD Run finished without all task steps completing."
  in
  note_compozy_lifecycle_update orchestrator run result

let compozy_issue_with_lifecycle_dispatch_state config run =
  let issue = Compozy_tasks_tracker.issue_of_prd_run run in
  match Compozy_lifecycle.load_or_backfill_reconciled config run with
  | Ok lifecycle -> { issue with Issue.state = lifecycle.dispatch_state }
  | Error _ -> issue

let current_compozy_prd_run_for_progress orchestrator =
  if orchestrator.tracker.kind <> "compozy_tasks" then Ok None
  else
    match orchestrator.state.Runtime_state.compozy_progress with
    | None -> Ok None
    | Some progress -> (
        match Compozy_tasks_tracker.discover_prd_runs ~compozy_root:orchestrator.config.Config.tracker.compozy_root with
        | Error _ as error -> error
        | Ok runs ->
            Ok (List.find_opt (fun (run : Compozy_tasks_tracker.prd_run) -> run.id = progress.run_id) runs))

let note_current_compozy_batch_handoff orchestrator status reason =
  match current_compozy_prd_run_for_progress orchestrator with
  | Error error -> set_error orchestrator ("could not update Compozy Batch Pull Request lifecycle: " ^ error)
  | Ok None -> ()
  | Ok (Some run) ->
      note_compozy_lifecycle_update orchestrator run
        (Compozy_lifecycle.mark_pr_handoff orchestrator.config run ~status ~reason)

let compozy_pr_readiness_allows_batch_handoff = function
  | Compozy_lifecycle.Ready
  | Compozy_lifecycle.Handoff_attempting
  | Compozy_lifecycle.Handoff_failed ->
      true
  | Compozy_lifecycle.Disabled
  | Compozy_lifecycle.Not_ready
  | Compozy_lifecycle.Handoff_completed ->
      false

let current_compozy_batch_handoff_ready orchestrator =
  if orchestrator.tracker.kind <> "compozy_tasks" then true
  else
    match current_compozy_prd_run_for_progress orchestrator with
    | Error error ->
        set_error orchestrator ("could not read Compozy Batch Pull Request readiness: " ^ error);
        false
    | Ok None -> false
    | Ok (Some run) -> (
        match Compozy_lifecycle.load_or_backfill_reconciled orchestrator.config run with
        | Error error ->
            set_error orchestrator ("could not read Compozy Batch Pull Request readiness: " ^ error);
            false
        | Ok lifecycle ->
            update_compozy_progress orchestrator run;
            compozy_pr_readiness_allows_batch_handoff lifecycle.pr_readiness)

let seconds_until timestamp =
  max 1 (int_of_float (ceil (timestamp -. Unix.time ())))

let tracker_retry_pause_message seconds =
  Printf.sprintf "Issue Tracker poll rate-limited; retrying tracker poll in %d seconds" seconds

let file_size = function
  | None -> 0
  | Some path -> (
      try (Unix.stat path).Unix.st_size with Unix.Unix_error _ -> 0)

let ignored_activity_dir = function ".git" | "_build" | "node_modules" -> true | _ -> false

let latest_workspace_file_mtime workspace_path excluded_paths =
  let excluded = List.filter_map Fun.id excluded_paths in
  let excluded_path path = List.exists (( = ) path) excluded in
  let rec latest newest path =
    try
      let stat = Unix.lstat path in
      match stat.Unix.st_kind with
      | Unix.S_REG -> if excluded_path path then newest else max newest stat.Unix.st_mtime
      | Unix.S_DIR ->
          let name = Filename.basename path in
          if path <> workspace_path && ignored_activity_dir name then newest
          else
            Sys.readdir path
            |> Array.fold_left (fun acc entry -> latest acc (Filename.concat path entry)) newest
      | _ -> newest
    with Unix.Unix_error _ | Sys_error _ -> newest
  in
  latest 0. workspace_path

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

let json_member name = function
  | `Assoc fields -> List.assoc_opt name fields
  | _ -> None

let json_string_member name json =
  match json_member name json with Some (`String value) when Util.trim value <> "" -> Some value | _ -> None

let json_int_member name json =
  match json_member name json with
  | Some (`Int value) -> Some value
  | Some (`Float value) -> Some (int_of_float value)
  | Some (`String value) -> int_of_string_opt (Util.trim value)
  | _ -> None

let json_float_member name json =
  match json_member name json with
  | Some (`Float value) -> Some value
  | Some (`Int value) -> Some (float_of_int value)
  | Some (`String value) -> (try Some (float_of_string (Util.trim value)) with Failure _ -> None)
  | _ -> None

let first_some values = List.find_map Fun.id values

let nested_json_member names json =
  names
  |> List.find_map (fun name ->
         match json_member name json with Some (`Assoc _ as value) -> Some value | _ -> None)

let nested_int_member containers keys json =
  containers
  |> List.find_map (fun container ->
         match nested_json_member [ container ] json with
         | Some nested -> first_some (List.map (fun key -> json_int_member key nested) keys)
         | None -> None)

let goal_usage_from_json ?(allow_top_level = false) json =
  let source =
    match json_member "goal_usage" json with
    | Some (`Assoc _ as usage) -> Some usage
    | _ -> (
        match json_member "goalUsage" json with
        | Some (`Assoc _ as usage) -> Some usage
        | _ -> (
            match json_member "goal" json with
            | Some (`Assoc _ as goal) -> (
                match json_member "usage" goal with Some (`Assoc _ as usage) -> Some usage | _ -> Some goal)
            | _ -> if allow_top_level then Some json else None))
  in
  match source with
  | None -> None
  | Some usage ->
      let result =
        {
          Runtime_state.status = first_some [ json_string_member "status" usage; json_string_member "goal_status" usage; json_string_member "goalStatus" usage ];
          time_used_seconds =
            first_some
              [
                json_float_member "time_used_seconds" usage;
                json_float_member "timeUsedSeconds" usage;
                json_float_member "duration_seconds" usage;
                json_float_member "durationSeconds" usage;
              ];
          tokens_used =
            first_some
              [
                json_int_member "tokens_used" usage;
                json_int_member "tokensUsed" usage;
                nested_int_member [ "tokens"; "token_usage"; "tokenUsage" ]
                  [ "total_tokens"; "totalTokens"; "tokens_used"; "tokensUsed" ]
                  usage;
              ];
        }
      in
      if result.status = None && result.time_used_seconds = None && result.tokens_used = None then None else Some result

let parse_goal_usage_from_line line =
  let line = Util.trim line in
  let lower_line = String.lowercase_ascii line in
  let json_text =
    if String.starts_with ~prefix:"goal usage:" lower_line then
      Some (true, String.sub line 11 (String.length line - 11) |> Util.trim)
    else if String.length line > 0 && line.[0] = '{' then Some (false, line)
    else None
  in
  match json_text with
  | None -> None
  | Some (allow_top_level, text) -> (
      try Yojson.Safe.from_string text |> goal_usage_from_json ~allow_top_level with Yojson.Json_error _ -> None)

let parse_goal_usage stdout_path stderr_path =
  let content = file_contents stdout_path ^ "\n" ^ file_contents stderr_path in
  content |> String.split_on_char '\n' |> List.filter_map parse_goal_usage_from_line |> List.rev |> List.find_opt (fun _ -> true)

let max_tokens a b =
  {
    Runtime_state.input_tokens = max a.Runtime_state.input_tokens b.Runtime_state.input_tokens;
    output_tokens = max a.output_tokens b.output_tokens;
    total_tokens = max a.total_tokens b.total_tokens;
  }

type claude_stream_activity = {
  claude_seen : bool;
  claude_last_event : string option;
  claude_last_message : string option;
  claude_tokens : Runtime_state.tokens;
}

let empty_claude_stream_activity =
  {
    claude_seen = false;
    claude_last_event = None;
    claude_last_message = None;
    claude_tokens = runtime_tokens;
  }

let json_assoc_member name = function
  | Some (`Assoc _ as json) -> json_member name json
  | _ -> None

let json_list_member name json =
  match json_member name json with Some (`List values) -> values | _ -> []

let nonempty_option value =
  let value = Util.trim value in
  if value = "" then None else Some value

let content_text content =
  content
  |> List.filter_map (fun item ->
         match json_member "type" item with
         | Some (`String "text") -> json_string_member "text" item
         | _ -> None)
  |> String.concat ""
  |> nonempty_option

let content_text_preserving_whitespace content =
  let text =
    content
    |> List.filter_map (fun item ->
           match json_member "type" item with
           | Some (`String "text") -> json_string_member "text" item
           | _ -> None)
    |> String.concat ""
  in
  if Util.trim text = "" then None else Some text

let content_tool_name content =
  content
  |> List.find_map (fun item ->
         match json_member "type" item with
         | Some (`String "tool_use") -> json_string_member "name" item
         | Some (`String "tool_result") -> Some "tool result"
         | _ -> None)

let append_claude_message existing chunk =
  match existing with
  | Some text when Util.trim text <> "" -> text ^ chunk
  | _ -> chunk

let int_member_any names json = first_some (List.map (fun name -> json_int_member name json) names)

let tokens_from_usage_json usage =
  let input_tokens =
    first_some
      [
        int_member_any [ "input_tokens"; "inputTokens" ] usage;
        nested_int_member [ "usage"; "token_usage"; "tokenUsage" ] [ "input_tokens"; "inputTokens" ] usage;
      ]
    |> Option.value ~default:0
  in
  let output_tokens =
    first_some
      [
        int_member_any [ "output_tokens"; "outputTokens" ] usage;
        nested_int_member [ "usage"; "token_usage"; "tokenUsage" ] [ "output_tokens"; "outputTokens" ] usage;
      ]
    |> Option.value ~default:0
  in
  let total_tokens =
    first_some
      [
        int_member_any [ "total_tokens"; "totalTokens"; "tokens_used"; "tokensUsed" ] usage;
        nested_int_member [ "usage"; "token_usage"; "tokenUsage" ]
          [ "total_tokens"; "totalTokens"; "tokens_used"; "tokensUsed" ]
          usage;
      ]
    |> Option.value ~default:(input_tokens + output_tokens)
  in
  { Runtime_state.input_tokens = input_tokens; output_tokens; total_tokens }

let usage_json_candidates json =
  [
    json_member "usage" json;
    json_assoc_member "usage" (json_member "message" json);
    json_assoc_member "usage" (json_member "event" json);
    json_assoc_member "usage" (json_assoc_member "message" (json_member "event" json));
    json_assoc_member "usage" (json_assoc_member "delta" (json_member "event" json));
  ]

let update_claude_tokens activity json =
  usage_json_candidates json
  |> List.fold_left
       (fun activity usage ->
         match usage with
         | Some (`Assoc _ as usage) ->
             {
               claude_seen = true;
               claude_last_event =
                 (match activity.claude_last_event with Some _ -> activity.claude_last_event | None -> Some "claude_usage");
               claude_last_message =
                 (match activity.claude_last_message with
                 | Some _ -> activity.claude_last_message
                 | None -> Some "Claude usage updated");
               claude_tokens = max_tokens activity.claude_tokens (tokens_from_usage_json usage);
             }
         | _ -> activity)
       activity

let claude_activity_from_stream_event activity event =
  match json_string_member "type" event with
  | Some "content_block_delta" -> (
      match json_member "delta" event with
      | Some (`Assoc _ as delta) -> (
          match json_string_member "type" delta with
          | Some "text_delta" -> (
              match json_string_member "text" delta with
              | Some text ->
                  {
                    activity with
                    claude_seen = true;
                    claude_last_event = Some "claude_message";
                    claude_last_message = Some (append_claude_message activity.claude_last_message text);
                  }
              | None -> activity)
          | Some "input_json_delta" ->
              {
                activity with
                claude_seen = true;
                claude_last_event = Some "claude_tool_input";
                claude_last_message =
                  (match json_string_member "partial_json" delta with
                  | Some chunk -> Some ("Tool input: " ^ chunk)
                  | None -> activity.claude_last_message);
              }
          | _ -> activity)
      | _ -> activity)
  | Some "content_block_start" -> (
      match json_member "content_block" event with
      | Some (`Assoc _ as block) -> (
          match json_string_member "type" block with
          | Some "tool_use" ->
              let tool_name = Option.value (json_string_member "name" block) ~default:"tool" in
              {
                activity with
                claude_seen = true;
                claude_last_event = Some "claude_tool";
                claude_last_message = Some ("Using " ^ tool_name);
              }
          | Some "text" ->
              {
                activity with
                claude_seen = true;
                claude_last_event = Some "claude_message";
                claude_last_message =
                  (match json_string_member "text" block with
                  | Some text -> Some (append_claude_message activity.claude_last_message text)
                  | None -> activity.claude_last_message);
              }
          | _ -> activity)
      | _ -> activity)
  | Some "message_delta" ->
      update_claude_tokens
        {
          activity with
          claude_seen = true;
          claude_last_event = Some "claude_usage";
          claude_last_message =
            (match activity.claude_last_message with Some _ -> activity.claude_last_message | None -> Some "Claude usage updated");
        }
        (`Assoc [ ("event", event) ])
  | Some "message_stop" -> { activity with claude_seen = true }
  | _ -> activity

let claude_activity_from_json activity json =
  let activity = update_claude_tokens activity json in
  match json_string_member "type" json with
  | Some "stream_event" -> (
      match json_member "event" json with
      | Some (`Assoc _ as event) -> claude_activity_from_stream_event activity event
      | _ -> activity)
  | Some "assistant" -> (
      match json_member "message" json with
      | Some (`Assoc _ as message) -> (
          match content_text (json_list_member "content" message) with
          | Some text ->
              {
                activity with
                claude_seen = true;
                claude_last_event = Some "claude_message";
                claude_last_message = Some text;
              }
          | None -> (
              match content_tool_name (json_list_member "content" message) with
              | Some tool_name ->
                  {
                    activity with
                    claude_seen = true;
                    claude_last_event = Some "claude_tool";
                    claude_last_message = Some ("Using " ^ tool_name);
                  }
              | None -> activity))
      | _ -> activity)
  | Some "result" ->
      let message =
        first_some
          [
            json_string_member "result" json;
            json_string_member "message" json;
            json_string_member "summary" json;
          ]
      in
      {
        activity with
        claude_seen = true;
        claude_last_event = Some "claude_result";
        claude_last_message = (match message with Some _ -> message | None -> activity.claude_last_message);
      }
  | Some "system" -> (
      match json_string_member "subtype" json with
      | Some "api_retry" ->
          let attempt = json_int_member "attempt" json |> Option.value ~default:0 in
          {
            activity with
            claude_seen = true;
            claude_last_event = Some "claude_api_retry";
            claude_last_message = Some (Printf.sprintf "Claude API retry attempt %d" attempt);
          }
      | Some "init" -> { activity with claude_seen = true }
      | _ -> activity)
  | _ -> activity

let parse_claude_stream_activity stdout_path stderr_path =
  let content = file_contents stdout_path ^ "\n" ^ file_contents stderr_path in
  content |> String.split_on_char '\n'
  |> List.fold_left
       (fun activity line ->
         let line = Util.trim line in
         if line = "" then activity
         else
           try Yojson.Safe.from_string line |> claude_activity_from_json activity
           with Yojson.Json_error _ -> activity)
       empty_claude_stream_activity

type cursor_stream_activity = {
  cursor_seen : bool;
  cursor_last_event : string option;
  cursor_last_message : string option;
  cursor_tokens : Runtime_state.tokens;
}

let empty_cursor_stream_activity =
  {
    cursor_seen = false;
    cursor_last_event = None;
    cursor_last_message = None;
    cursor_tokens = runtime_tokens;
  }

let update_cursor_tokens activity json =
  usage_json_candidates json
  |> List.fold_left
       (fun activity usage ->
         match usage with
         | Some (`Assoc _ as usage) ->
             {
               cursor_seen = true;
               cursor_last_event =
                 (match activity.cursor_last_event with Some _ -> activity.cursor_last_event | None -> Some "cursor_usage");
               cursor_last_message =
                 (match activity.cursor_last_message with
                 | Some _ -> activity.cursor_last_message
                 | None -> Some "Cursor usage updated");
               cursor_tokens = max_tokens activity.cursor_tokens (tokens_from_usage_json usage);
             }
         | _ -> activity)
       activity

let cursor_tool_label name =
  let suffix = "ToolCall" in
  if String.ends_with ~suffix name then String.sub name 0 (String.length name - String.length suffix) else name

let cursor_tool_call_name json =
  match json_member "tool_call" json with
  | Some (`Assoc ((name, _) :: _)) -> Some (cursor_tool_label name)
  | _ -> None

let append_cursor_message existing chunk =
  match existing with
  | Some text when Util.trim text <> "" -> text ^ chunk
  | _ -> chunk

let cursor_activity_from_json activity json =
  let activity = update_cursor_tokens activity json in
  match json_string_member "type" json with
  | Some "system" -> (
      match json_string_member "subtype" json with
      | Some "init" ->
          {
            activity with
            cursor_seen = true;
            cursor_last_event = Some "cursor_init";
            cursor_last_message =
              (match json_string_member "model" json with
              | Some model -> Some ("Cursor initialized " ^ model)
              | None -> activity.cursor_last_message);
          }
      | Some subtype ->
          {
            activity with
            cursor_seen = true;
            cursor_last_event = Some ("cursor_system_" ^ subtype);
          }
      | None -> { activity with cursor_seen = true })
  | Some "assistant" -> (
      match json_member "message" json with
      | Some (`Assoc _ as message) -> (
          match content_text_preserving_whitespace (json_list_member "content" message) with
          | Some text ->
              {
                activity with
                cursor_seen = true;
                cursor_last_event = Some "cursor_message";
                cursor_last_message = Some (append_cursor_message activity.cursor_last_message text);
              }
          | None -> activity)
      | _ -> activity)
  | Some "tool_call" ->
      let subtype = Option.value (json_string_member "subtype" json) ~default:"event" in
      let tool_name = Option.value (cursor_tool_call_name json) ~default:"tool" in
      {
        activity with
        cursor_seen = true;
        cursor_last_event = Some ("cursor_tool_" ^ subtype);
        cursor_last_message = Some (Printf.sprintf "%s %s" (String.capitalize_ascii subtype) tool_name);
      }
  | Some "result" ->
      let message =
        first_some
          [
            json_string_member "result" json;
            json_string_member "message" json;
            json_string_member "summary" json;
          ]
      in
      {
        activity with
        cursor_seen = true;
        cursor_last_event = Some "cursor_result";
        cursor_last_message = (match message with Some _ -> message | None -> activity.cursor_last_message);
      }
  | Some "user" -> { activity with cursor_seen = true }
  | _ -> activity

let parse_cursor_stream_activity stdout_path stderr_path =
  let content = file_contents stdout_path ^ "\n" ^ file_contents stderr_path in
  content |> String.split_on_char '\n'
  |> List.fold_left
       (fun activity line ->
         let line = Util.trim line in
         if line = "" then activity
         else
           try Yojson.Safe.from_string line |> cursor_activity_from_json activity
           with Yojson.Json_error _ -> activity)
       empty_cursor_stream_activity

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

let start_status ?stage orchestrator issue =
  match match stage with Some _ -> stage | None -> stage_for_issue orchestrator.config issue with
  | Some stage -> stage.start_status
  | None -> orchestrator.config.tracker.project_status_on_dispatch

let success_status ?stage orchestrator issue =
  match match stage with Some _ -> stage | None -> stage_for_issue orchestrator.config issue with
  | Some stage -> stage.success_status
  | None -> orchestrator.config.tracker.project_status_on_success

let retry_status ?stage orchestrator issue =
  match match stage with Some _ -> stage | None -> stage_for_issue orchestrator.config issue with
  | Some stage -> stage.retry_status
  | None -> orchestrator.config.tracker.project_status_on_retry

let issue_is_active orchestrator issue =
  issue_state_is_dispatchable orchestrator issue.Issue.state

let issue_has_admission_artifact orchestrator issue =
  Hashtbl.mem orchestrator.attempts issue.Issue.id
  || Hashtbl.mem orchestrator.previous_attempt_outputs issue.Issue.id
  || List.exists (fun (row : Runtime_state.retrying) -> row.issue_id = issue.Issue.id) orchestrator.state.retrying
  || Sys.file_exists (task_workspace_path orchestrator.config issue)
  ||
  if is_git_repository orchestrator.config.repository_root then
    git_ref_exists orchestrator.config.repository_root (task_branch orchestrator.config issue)
  else false

let issue_allows_dispatch orchestrator issue =
  if issue_has_admission_artifact orchestrator issue then issue_is_active orchestrator issue
  else (orchestrator.tracker.first_admission issue).eligible

let intake_state_of_decision (decision : Issue_tracker.admission_decision) =
  if decision.eligible then "ready"
  else if Util.starts_with ~prefix:"Compozy _tasks.md readiness parse failed" decision.reason then "parse_blocked"
  else "not_ready"

let nonempty_reason reason =
  match Util.trim reason with "" -> None | reason -> Some reason

let ordered_queue_intake_block orchestrator issue (decision : Issue_tracker.admission_decision) =
  match orchestrator.ordered_queue with
  | None -> None
  | Some _ ->
      let resolved_queue = Option.value orchestrator.resolved_ordered_queue ~default:[] in
      let issue_in_queue = queue_contains_issue resolved_queue issue in
      if issue_in_queue && not decision.eligible then
        Some ("Ordered Queue entry is waiting for first-admission eligibility: " ^ decision.reason)
      else if (not issue_in_queue) && decision.eligible then
        Some "Ordered Queue is active and this work item is not listed in the queue."
      else if decision.eligible && not (queue_entry_allows_dispatch resolved_queue orchestrator.state issue) then
        Some "Ordered Queue entry is already completed or skipped."
      else None

let intake_evaluation_for_issue orchestrator issue =
  if issue_has_admission_artifact orchestrator issue then
    {
      Runtime_state.issue_identifier = issue.Issue.identifier;
      eligible = true;
      state = "admitted";
      reason = Some "Work item was already admitted; lifecycle, retry, and stage state now control execution.";
    }
  else
    let decision = orchestrator.tracker.first_admission issue in
    match ordered_queue_intake_block orchestrator issue decision with
    | Some reason ->
        {
          Runtime_state.issue_identifier = issue.Issue.identifier;
          eligible = decision.eligible;
          state = "queue_blocked";
          reason = Some reason;
        }
    | None ->
        {
          Runtime_state.issue_identifier = issue.Issue.identifier;
          eligible = decision.eligible;
          state = intake_state_of_decision decision;
          reason = nonempty_reason decision.reason;
        }

let intake_evaluations_for_candidates orchestrator candidates =
  List.map (intake_evaluation_for_issue orchestrator) candidates

let issue_needs_attention orchestrator issue =
  string_equal_ci issue.Issue.state orchestrator.config.git.merge_attention_status || is_blocked orchestrator issue

let protected_loop_start orchestrator =
  List.exists
    (fun branch -> String.lowercase_ascii branch = String.lowercase_ascii orchestrator.loop_start_branch)
    orchestrator.config.git.protected_trunk_branches

let completed_stage_success_statuses config =
  if not config.Config.stage_agents.enabled then []
  else
    config.stage_agents.stages
    |> List.filter_map (fun (stage : Config.stage_agent) -> stage.success_status)

let issue_is_completed_stage config issue =
  completed_stage_success_statuses config
  |> List.exists (fun status -> string_equal_ci status issue.Issue.state)

let startup_candidate_order config left right =
  match compare (issue_identifier_key left) (issue_identifier_key right) with
  | 0 -> compare (task_branch config left) (task_branch config right)
  | result -> result

let record_startup_reconciliation orchestrator ?issue ?task_branch ?workspace_path category message =
  let row =
    {
      Runtime_state.issue_id = Option.map (fun issue -> issue.Issue.id) issue;
      issue_identifier = Option.map (fun issue -> issue.Issue.identifier) issue;
      task_branch;
      workspace_path;
      category;
      message;
    }
  in
  update_state orchestrator (fun state ->
    { state with startup_reconciliation = state.startup_reconciliation @ [ row ] });
  let issue_identifier = match issue with Some issue -> issue.Issue.identifier | None -> "-" in
  render_startup_reconciliation category issue_identifier message

let record_startup_attention orchestrator issue branch workspace_path category message =
  record_startup_reconciliation orchestrator ~issue ~task_branch:branch ~workspace_path category message;
  ignore (move_issue_status orchestrator issue orchestrator.config.git.merge_attention_status);
  Hashtbl.replace orchestrator.blocked (block_key issue) message;
  Hashtbl.replace orchestrator.blocked (block_key { issue with Issue.state = orchestrator.config.git.merge_attention_status }) message;
  update_state orchestrator (fun state ->
    {
      state with
      issue_errors =
        {
          Runtime_state.issue_id = issue.id;
          issue_identifier = issue.identifier;
          error = message;
          goal_usage = None;
        }
        :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue.id) state.issue_errors;
      last_error = Some message;
    })

let set_pull_request_handoff orchestrator ?issue ?head_branch status ?url ?error () =
  let policy = orchestrator.config.Config.pull_request in
  let head_branch = Option.value head_branch ~default:orchestrator.loop_start_branch in
  let issue_identifier = Option.map (fun issue -> issue.Issue.identifier) issue in
  let row =
    {
      Runtime_state.enabled = policy.enabled;
      mode = policy.mode;
      issue_identifier;
      head_branch = Some head_branch;
      base_branch = Some policy.base_branch;
      status;
      url;
      error;
    }
  in
  let same_handoff existing =
    existing.Runtime_state.mode = row.mode
    && existing.issue_identifier = row.issue_identifier
    && existing.head_branch = row.head_branch
    && existing.base_branch = row.base_branch
  in
  update_state orchestrator (fun state ->
    {
      state with
      pull_request = Some row;
      pull_requests = row :: List.filter (fun existing -> not (same_handoff existing)) state.pull_requests;
      last_error = (match error with Some error -> Some error | None -> state.last_error);
    })

let attempt_batch_pull_request orchestrator =
  let policy = orchestrator.config.Config.pull_request in
  set_pull_request_handoff orchestrator "attempting" ();
  note_current_compozy_batch_handoff orchestrator "attempting" None;
  match orchestrator.batch_pull_request_handoff orchestrator.config ~head_branch:orchestrator.loop_start_branch with
  | Ok url ->
      orchestrator.batch_pull_request_completed <- true;
      set_pull_request_handoff orchestrator "completed" ?url ();
      note_current_compozy_batch_handoff orchestrator "completed" None;
      render_pull_request_completed orchestrator.loop_start_branch policy.base_branch
  | Error error ->
      set_pull_request_handoff orchestrator "retryable_failure" ~error ();
      note_current_compozy_batch_handoff orchestrator "retryable_failure" (Some error);
      render_pull_request_failed orchestrator.loop_start_branch policy.base_branch error

let attempt_task_pull_request orchestrator issue =
  let config = config_with_task_pull_request_issue orchestrator.config issue in
  let policy = config.Config.pull_request in
  let head_branch = task_branch config issue in
  set_pull_request_handoff orchestrator ~issue ~head_branch "attempting" ();
  match orchestrator.batch_pull_request_handoff config ~head_branch with
  | Ok url ->
      set_pull_request_handoff orchestrator ~issue ~head_branch "completed" ?url ();
      render_pull_request_completed head_branch policy.base_branch
  | Error error ->
      set_pull_request_handoff orchestrator ~issue ~head_branch "retryable_failure" ~error ();
      render_pull_request_failed head_branch policy.base_branch error

let startup_task_pull_request_enabled config =
  config.Config.pull_request.enabled && config.Config.pull_request.mode = "task"

let attempt_startup_task_pull_request orchestrator issue branch workspace_path =
  attempt_task_pull_request orchestrator issue;
  record_startup_reconciliation orchestrator ~issue ~task_branch:branch ~workspace_path
    "task_pull_request_handoff" "Task Branch Pull Request handoff attempted for completed worktree"

let cleanup_task_worktree_for_issue config issue workspace_path =
  if config.Config.git.cleanup.remove_worktree_after_merge then
    ignore
      (run_shell_capture ~cwd:config.repository_root
         (Printf.sprintf "git worktree remove %s" (Util.shell_quote workspace_path)));
  if not config.git.cleanup.keep_task_branch then
    ignore
      (run_shell_capture ~cwd:config.repository_root
         (Printf.sprintf "git branch -d %s" (Util.shell_quote (task_branch config issue))))

type task_branch_integration_result =
  | Already_contained
  | Direct_fast_forward
  | Updated_task_branch_then_fast_forward

let task_branch_integration_result_name = function
  | Already_contained -> "already_contained"
  | Direct_fast_forward -> "direct_fast_forward"
  | Updated_task_branch_then_fast_forward -> "updated_task_branch_then_fast_forwarded"

let task_branch_integration_message = function
  | Already_contained -> "Task Branch is already contained in the Loop-Start Branch"
  | Direct_fast_forward -> "Task Branch fast-forwarded directly into the Loop-Start Branch"
  | Updated_task_branch_then_fast_forward ->
      "Task Branch was updated from the Loop-Start Branch, then fast-forwarded into the Loop-Start Branch"

let record_task_branch_integration orchestrator issue ?workspace_path result =
  let result_name = task_branch_integration_result_name result in
  let row =
    {
      Runtime_state.issue_id = issue.Issue.id;
      issue_identifier = issue.identifier;
      task_branch = task_branch orchestrator.config issue;
      workspace_path;
      result = result_name;
      direct_fast_forward = (result = Direct_fast_forward);
      task_branch_updated_from_loop_start = (result = Updated_task_branch_then_fast_forward);
      attention = None;
      message = task_branch_integration_message result;
    }
  in
  update_state orchestrator (fun state ->
    { state with task_branch_integrations = state.task_branch_integrations @ [ row ] })

let record_task_branch_integration_attention orchestrator issue ?workspace_path attention message =
  let row =
    {
      Runtime_state.issue_id = issue.Issue.id;
      issue_identifier = issue.identifier;
      task_branch = task_branch orchestrator.config issue;
      workspace_path;
      result = "attention";
      direct_fast_forward = false;
      task_branch_updated_from_loop_start = false;
      attention = Some attention;
      message;
    }
  in
  update_state orchestrator (fun state ->
    { state with task_branch_integrations = state.task_branch_integrations @ [ row ] })

let unauthorized_protected_task_branch_changes config issue ~base_ref ~head_ref =
  match changed_paths_between_refs config.Config.repository_root ~base_ref ~head_ref with
  | Error error -> Error ("Protected Path Policy changed-path inspection failed: " ^ error)
  | Ok paths -> (
      match unauthorized_protected_path_matches config issue paths with
      | [] -> Ok ()
      | matches -> Error (protected_path_attention_message matches))

let integrate_task_branch config ~loop_start_branch ~workspace_path branch =
  let root = config.Config.repository_root in
  let update_task_branch_then_fast_forward () =
    let merge_command =
      Printf.sprintf "git merge --no-edit %s" (Util.shell_quote loop_start_branch)
    in
    match run_shell_capture ~cwd:workspace_path merge_command with
    | Error error -> Error ("Task Branch could not update from the Loop-Start Branch: " ^ error)
    | Ok _ -> (
        match run_shell_capture ~cwd:root (Printf.sprintf "git merge --ff-only %s" (Util.shell_quote branch)) with
        | Ok _ -> Ok Updated_task_branch_then_fast_forward
        | Error error -> Error ("updated Task Branch could not fast-forward: " ^ error))
  in
  if git_ref_contained_in_head root branch then Ok Already_contained
  else if git_head_can_fast_forward_to root branch then
    match run_shell_capture ~cwd:root (Printf.sprintf "git merge --ff-only %s" (Util.shell_quote branch)) with
    | Ok _ -> Ok Direct_fast_forward
    | Error _ -> update_task_branch_then_fast_forward ()
  else update_task_branch_then_fast_forward ()

let reconcile_startup_candidate orchestrator issue =
  let workspace_path = task_workspace_path orchestrator.config issue in
  let branch = task_branch orchestrator.config issue in
  match worktree_branch workspace_path with
  | None ->
      record_startup_attention orchestrator issue branch workspace_path "skipped_not_git_worktree"
        (workspace_path ^ " exists but is not an Agent Worktree")
  | Some existing_branch when existing_branch <> branch ->
      record_startup_attention orchestrator issue branch workspace_path "attention_wrong_branch"
        (Printf.sprintf "Agent Worktree is on %s but expected %s" existing_branch branch)
  | Some _ when not (git_ref_exists orchestrator.config.repository_root branch) ->
      record_startup_attention orchestrator issue branch workspace_path "attention_missing_task_branch"
        ("expected Task Branch is missing: " ^ branch)
  | Some _ -> (
      match has_worktree_changes workspace_path with
      | Error error -> record_startup_attention orchestrator issue branch workspace_path "attention_uncommitted_changes" error
      | Ok true ->
          record_startup_attention orchestrator issue branch workspace_path "attention_uncommitted_changes"
            "Agent Worktree has uncommitted changes"
      | Ok false ->
          let root = orchestrator.config.repository_root in
          if git_ref_contained_in_head root branch then (
            cleanup_task_worktree_for_issue orchestrator.config issue workspace_path;
            record_task_branch_integration orchestrator issue ~workspace_path Already_contained;
            record_startup_reconciliation orchestrator ~issue ~task_branch:branch ~workspace_path "already_reconciled"
              "Task Branch is already contained in the Loop-Start Branch")
          else
            match unauthorized_protected_task_branch_changes orchestrator.config issue ~base_ref:"HEAD" ~head_ref:branch with
            | Error error ->
                record_task_branch_integration_attention orchestrator issue ~workspace_path
                  "attention_protected_paths" error;
                record_startup_attention orchestrator issue branch workspace_path "attention_protected_paths" error
            | Ok () ->
                let attempted_task_pull_request =
                  if startup_task_pull_request_enabled orchestrator.config then (
                    attempt_startup_task_pull_request orchestrator issue branch workspace_path;
                    true)
                  else false
                in
                if protected_loop_start orchestrator then (
                  if not attempted_task_pull_request then
                    record_startup_attention orchestrator issue branch workspace_path "attention_protected_trunk"
                      "committed Task Branch work exists but Loop-Start Branch is protected")
                else
                  match
                    integrate_task_branch orchestrator.config ~loop_start_branch:orchestrator.loop_start_branch
                      ~workspace_path branch
                  with
                  | Ok result ->
                      cleanup_task_worktree_for_issue orchestrator.config issue workspace_path;
                      record_task_branch_integration orchestrator issue ~workspace_path result;
                      record_startup_reconciliation orchestrator ~issue ~task_branch:branch ~workspace_path
                        (task_branch_integration_result_name result)
                        (task_branch_integration_message result)
                  | Error error ->
                      record_task_branch_integration_attention orchestrator issue ~workspace_path
                        "attention_integration_failed" error;
                      record_startup_attention orchestrator issue branch workspace_path "attention_integration_failed" error)

let reconcile_startup orchestrator candidates =
  if not orchestrator.startup_reconciliation_done then (
    orchestrator.startup_reconciliation_done <- true;
    let candidates =
      candidates
      |> List.filter (issue_is_completed_stage orchestrator.config)
      |> List.filter (fun issue -> Sys.file_exists (task_workspace_path orchestrator.config issue))
      |> List.sort (startup_candidate_order orchestrator.config)
    in
    if candidates <> [] then
      match require_clean_loop_start orchestrator.config.repository_root with
      | Error error ->
          let message = "Startup Reconciliation blocked: " ^ error in
          record_startup_reconciliation orchestrator "startup_blocked_dirty_loop_start" message;
          set_error orchestrator message
      | Ok () -> List.iter (reconcile_startup_candidate orchestrator) candidates)

let status_is_review_status config status =
  match config.Config.tracker.project_status_on_success with
  | Some review_status -> string_equal_ci status review_status
  | None -> false

let maybe_open_review_pull_request orchestrator issue status =
  let policy = orchestrator.config.Config.pull_request in
  if policy.enabled && status_is_review_status orchestrator.config status then
    if policy.mode = "task" then attempt_task_pull_request orchestrator issue
    else if policy.open_on_review && (not orchestrator.batch_pull_request_completed) then
      attempt_batch_pull_request orchestrator

let task_pull_request_before_auto_merge orchestrator status =
  let policy = orchestrator.config.Config.pull_request in
  policy.enabled && policy.mode = "task" && status_is_review_status orchestrator.config status

let maybe_open_batch_pull_request orchestrator ~candidates ~dispatchable_count =
  let policy = orchestrator.config.Config.pull_request in
  if policy.enabled && policy.mode = "batch" && not orchestrator.batch_pull_request_completed then
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
      if current_compozy_batch_handoff_ready orchestrator then attempt_batch_pull_request orchestrator)

let stage_running_counts config running =
  let counts = Hashtbl.create 8 in
  List.iter
    (fun row ->
      match running_stage_key config row with
      | None -> ()
      | Some key -> Hashtbl.replace counts key (Option.value (Hashtbl.find_opt counts key) ~default:0 + 1))
    running;
  counts

let stage_has_capacity counts = function
  | None -> true
  | Some (stage : Config.stage_agent) -> (
      match stage.max_concurrent_agents with
      | None -> true
      | Some cap -> Option.value (Hashtbl.find_opt counts (stage_key stage)) ~default:0 < cap)

let reserve_stage_capacity counts = function
  | None -> ()
  | Some (stage : Config.stage_agent) -> (
      match stage.max_concurrent_agents with
      | None -> ()
      | Some _ ->
          let key = stage_key stage in
          Hashtbl.replace counts key (Option.value (Hashtbl.find_opt counts key) ~default:0 + 1))

let take_admissible_by_stage orchestrator available issues =
  let counts = stage_running_counts orchestrator.config orchestrator.state.running in
  let rec loop remaining selected = function
    | [] -> List.rev selected
    | _ when remaining <= 0 -> List.rev selected
    | issue :: rest ->
        let stage = stage_for_issue orchestrator.config issue in
        if stage_has_capacity counts stage then (
          reserve_stage_capacity counts stage;
          loop (remaining - 1) (issue :: selected) rest)
        else loop remaining selected rest
  in
  loop available [] issues

let dispatch_issue orchestrator issue =
  let stage = stage_for_issue orchestrator.config issue in
  let target_start_status = start_status ?stage orchestrator issue in
  match shell_prepare_workspace orchestrator.config ~loop_start_branch:orchestrator.loop_start_branch issue with
  | Error error ->
      set_error orchestrator error;
      render_dispatch_retrying ?task_file:(dispatch_retry_task_file orchestrator.config issue) issue.identifier 0 error;
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
        let previous_attempt_output = Hashtbl.find_opt orchestrator.previous_attempt_outputs issue.id in
        let composition_result =
          if is_compozy_prd_run_child orchestrator issue then (
            match compozy_prd_run_for_workspace_issue orchestrator.config workspace issue with
            | Error _ as error -> error
            | Ok run -> (
                match run.current_step with
                | None when Compozy_tasks_tracker.completed_prd_run run ->
                    let stage_agent = Option.map (fun (stage : Config.stage_agent) -> stage.agent) stage in
                    let lifecycle_result =
                      Compozy_lifecycle.mark_stage_started orchestrator.config run ~stage_agent
                        ~dispatch_state:issue.Issue.state
                    in
                    (match apply_compozy_lifecycle_update orchestrator run lifecycle_result with
                    | Error _ as error -> error
                    | Ok () ->
                        (match Compozy_tasks_tracker.stage_prompt run with
                        | Error _ as error -> error
                        | Ok base_prompt ->
                            Ok
                              (compose_prompt_result ?stage ?previous_attempt_output orchestrator.config issue attempt
                                 base_prompt ~workspace ~loop_start_branch:(Some orchestrator.loop_start_branch))))
                | None -> Error (Printf.sprintf "no runnable Compozy task step for %s" run.id)
                | Some step -> (
                    match update_compozy_workspace_step_status orchestrator.config workspace run step "in_progress" with
                    | Error _ as error -> error
                    | Ok () -> (
                        match compozy_prd_run_for_workspace_issue orchestrator.config workspace issue with
                        | Error _ as error -> error
                        | Ok run ->
                            let stage_agent = Option.map (fun (stage : Config.stage_agent) -> stage.agent) stage in
                            let lifecycle_result =
                              Compozy_lifecycle.mark_stage_started orchestrator.config run ~stage_agent
                                ~dispatch_state:issue.Issue.state
                            in
                            (match apply_compozy_lifecycle_update orchestrator run lifecycle_result with
                            | Error _ as error -> error
                            | Ok () ->
                                compose_compozy_task_step_prompt_result ?stage ~issue ?previous_attempt_output
                                  orchestrator.config run attempt ~workspace
                                  ~loop_start_branch:(Some orchestrator.loop_start_branch))))))
          else
            Ok
              (compose_prompt_result ?stage ?previous_attempt_output orchestrator.config issue attempt rendered ~workspace
                 ~loop_start_branch:(Some orchestrator.loop_start_branch))
        in
        match composition_result with
        | Error error ->
            set_error orchestrator error;
            render_dispatch_retrying ?task_file:(dispatch_retry_task_file ~workspace orchestrator.config issue) issue.identifier
              0 error;
            ignore (move_issue_status orchestrator issue orchestrator.config.git.merge_attention_status)
        | Ok composition ->
            let context_diagnostic_result =
              match (composition.context_diagnostics, stage) with
              | Some diagnostics, Some stage -> (
                  try Ok (Some (persist_context_generation_diagnostics orchestrator.config issue stage attempt diagnostics))
                  with exn -> Error ("Context Diagnostics persistence failed: " ^ Printexc.to_string exn))
              | _ -> Ok None
            in
            let context_diagnostic_summary, context_diagnostic_error =
              match context_diagnostic_result with Ok summary -> (summary, None) | Error error -> (None, Some error)
            in
            let context_status =
              match context_diagnostic_summary with
              | Some summary -> { composition.context_status with Runtime_state.diagnostics_path = Some summary.diagnostic_path }
              | None -> composition.context_status
            in
            let prompt = composition.prompt in
            let harness =
              Option.value (Config.selected_agent_harness orchestrator.config stage)
                ~default:(Config.default_agent_harness orchestrator.config)
            in
            let prompt_archive_error =
              try
                ignore (persist_task_prompt_archive orchestrator.config issue stage harness attempt workspace prompt);
                None
              with exn -> Some ("Agent Prompt Archive persistence failed: " ^ Printexc.to_string exn)
            in
            (match
               if is_compozy_prd_run_child orchestrator issue then
                 compozy_task_start_context orchestrator.config workspace issue
               else None
             with
            | Some (task_file, previous_task_file) ->
                render_compozy_task_started issue.identifier task_file previous_task_file
            | None -> ());
            let launched = orchestrator.launch ~stage ~config:orchestrator.config ~workspace ~prompt ~issue in
            let now = Util.now_iso8601 () in
            let stage_agent, stage_states = selected_stage_fields stage in
            let sandbox_enabled, sandbox_provider, sandbox_reuse_outcome =
              sandbox_metadata_from_launch orchestrator.config launched.event
            in
            let row =
              {
                Runtime_state.issue;
                stage_agent;
                harness_name = Some harness.name;
                harness_kind = Some harness.kind;
                sandbox_enabled;
                sandbox_provider;
                sandbox_reuse_outcome;
                stage_states;
                session_id = launched.session_id;
                turn_count = 0;
                last_event = Some launched.event;
                last_message = None;
                started_at = now;
                last_event_at = Some now;
                tokens = runtime_tokens;
                goal_usage = None;
              }
            in
            let goal_loop = goal_loop_for_dispatch orchestrator.state issue stage harness attempt now in
            Hashtbl.remove orchestrator.retry_due issue.id;
            Hashtbl.remove orchestrator.previous_attempt_outputs issue.id;
            update_state orchestrator (fun state ->
              {
                state with
                issues = List.map (fun candidate -> if candidate.Issue.id = issue.id then issue else candidate) state.issues;
                running = row :: state.running;
                retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue.id) state.retrying;
                issue_errors =
                  List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue.id) state.issue_errors;
                context_diagnostics =
                  (match context_diagnostic_summary with
                  | Some summary -> append_context_diagnostic_summary state.context_diagnostics summary
                  | None -> state.context_diagnostics);
                goal_loops =
                  (match goal_loop with
                  | Some loop -> upsert_goal_loop loop state.goal_loops
                  | None -> state.goal_loops);
                last_error =
                  (match (context_diagnostic_error, prompt_archive_error) with
                  | None, None -> None
                  | Some error, None | None, Some error -> Some error
                  | Some left, Some right -> Some (left ^ "; " ^ right));
              }
              |> Runtime_state.set_context_status issue.id context_status);
            update_ordered_queue_entries orchestrator ~candidates:[ issue ] ();
            (match launched.pid with
            | Some pid ->
                let now_float = Unix.time () in
                orchestrator.children <-
                  {
                    pid;
                    issue;
                    stage;
                    harness;
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

let mark_terminal_retry_attention ?child orchestrator (row : Runtime_state.running) status error =
  let issue_id = row.issue.id in
  Hashtbl.remove orchestrator.attempts issue_id;
  Hashtbl.remove orchestrator.retry_due issue_id;
  Hashtbl.remove orchestrator.previous_attempt_outputs issue_id;
  Hashtbl.replace orchestrator.blocked (block_key row.issue) error;
  let next_issue =
    if move_issue_status orchestrator row.issue status then (
      let next_issue = { row.issue with Issue.state = status } in
      Hashtbl.replace orchestrator.blocked (block_key next_issue) error;
      next_issue)
    else row.issue
  in
  (match child with Some child -> mark_compozy_child_blocked orchestrator child error | None -> ());
  let goal_loop_updated_at = Util.now_iso8601 () in
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
            goal_usage = row.goal_usage;
          }
          :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id)
               state.issue_errors;
        last_error = Some error;
      }
      |> Runtime_state.clear_context_status issue_id
      |> update_goal_loop_in_state issue_id (fun loop ->
             Goal_loop.stop_needs_attention loop error goal_loop_updated_at));
  update_ordered_queue_entries orchestrator ~attention:(row.issue.identifier, Some error) ~candidates:[ next_issue ] ()

let mark_retrying ?(terminal_attention = false) ?child orchestrator issue_id error =
  match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = issue_id) orchestrator.state.running with
  | None -> ()
  | Some row ->
      let stage = stage_from_running orchestrator.config row in
      let target_retry_status = retry_status ?stage orchestrator row.issue in
      (match target_retry_status with
      | Some status when terminal_attention && not (issue_state_is_dispatchable orchestrator status) ->
          mark_terminal_retry_attention ?child orchestrator row status error
      | _ ->
      let next_attempt = Option.value (Hashtbl.find_opt orchestrator.attempts issue_id) ~default:0 + 1 in
      Hashtbl.replace orchestrator.attempts issue_id next_attempt;
      let retry_child = List.find_opt (fun child -> child.issue_id = issue_id) orchestrator.children in
      let previous_attempt_output =
        match retry_child with
        | None -> { attempt = next_attempt; stdout_path = None; stderr_path = None }
        | Some child -> { attempt = next_attempt; stdout_path = child.stdout_path; stderr_path = child.stderr_path }
      in
      Hashtbl.replace orchestrator.previous_attempt_outputs issue_id previous_attempt_output;
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
      let goal_loop_updated_at = Util.now_iso8601 () in
      update_state orchestrator (fun state ->
        let state =
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
                goal_usage = row.goal_usage;
              }
              :: List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
            issue_errors =
              List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id)
                state.issue_errors;
            last_error = Some error;
          }
        in
        update_goal_loop_in_state issue_id
          (fun loop -> Goal_loop.schedule_retry loop (next_attempt + 1) error goal_loop_updated_at)
          state);
      (match target_retry_status with
      | None -> ()
      | Some status -> ignore (move_issue_status orchestrator row.issue status));
      render_dispatch_retrying
        ?task_file:
          (dispatch_retry_task_file
             ?workspace:(Option.map (fun (child : child) -> child.workspace) retry_child)
             orchestrator.config row.issue)
        row.issue.identifier next_attempt error;
      update_ordered_queue_entries orchestrator ~candidates:[ row.issue ] ())

type compozy_failure =
  | Not_compozy_failure
  | Compozy_completed_run_failure
  | Compozy_retry_step
  | Compozy_next_after_failure of Compozy_tasks_tracker.prd_run
  | Compozy_finished_after_failure of Compozy_tasks_tracker.prd_run * string

let record_compozy_task_step_failure orchestrator child error =
  if not (is_compozy_prd_run_child orchestrator child.issue) then Ok Not_compozy_failure
  else
    match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
    | Error _ as error -> error
    | Ok run -> (
        match run.current_step with
        | None when Compozy_tasks_tracker.completed_prd_run run -> Ok Compozy_completed_run_failure
        | None -> Error (Printf.sprintf "no runnable Compozy task step for %s" run.id)
        | Some step ->
            let retry_count = step.retry_count + 1 in
            let over_limit = retry_count >= orchestrator.config.tracker.compozy_max_task_step_retries in
            let compozy_root = compozy_workspace_root orchestrator.config child.workspace in
            match
              Compozy_tasks_tracker.record_step_failure ~compozy_root run step ~retry_count ~last_error:error
                ~over_limit
            with
            | Error _ as error -> error
            | Ok () -> (
                match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
                | Error _ as error -> error
                | Ok updated_run ->
                    let lifecycle_result =
                      if over_limit then
                        Compozy_lifecycle.mark_failed orchestrator.config updated_run
                          ~reason:(compozy_task_step_failed_reason step retry_count error)
                      else
                        Compozy_lifecycle.mark_retrying orchestrator.config updated_run
                          ~reason:(compozy_task_step_retry_reason step retry_count error)
                    in
                    (match apply_compozy_lifecycle_update orchestrator updated_run lifecycle_result with
                    | Error _ as error -> error
                    | Ok () ->
                        if not over_limit then Ok Compozy_retry_step
                        else
                          match updated_run.current_step with
                          | Some _ -> Ok (Compozy_next_after_failure updated_run)
                          | None ->
                              Ok
                                (Compozy_finished_after_failure
                                   (updated_run, compozy_task_step_failed_reason step retry_count error)))))

let non_retryable_completion_error = function
  | "commit required but agent produced no code changes" | "commit required but no staged changes were found" -> true
  | _ -> false

let protected_path_completion_error error =
  Util.starts_with ~prefix:"Protected Path Policy blocked unauthorized changes:" error

let human_attention_completion_error error =
  protected_path_completion_error error ||
  Util.starts_with ~prefix:stage_commit_classification_conflict_prefix error

let mark_blocked ?child orchestrator issue_id error =
  match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = issue_id) orchestrator.state.running with
  | None -> ()
  | Some row ->
      Hashtbl.remove orchestrator.attempts issue_id;
      Hashtbl.remove orchestrator.retry_due issue_id;
      Hashtbl.remove orchestrator.previous_attempt_outputs issue_id;
      Hashtbl.replace orchestrator.blocked (block_key row.issue) error;
      let stage = stage_from_running orchestrator.config row in
      (match retry_status ?stage orchestrator row.issue with
      | None -> ()
      | Some status ->
          if move_issue_status orchestrator row.issue status then
            Hashtbl.replace orchestrator.blocked (block_key { row.issue with Issue.state = status }) error);
      let lifecycle_child =
        match child with
        | Some child when child.issue_id = issue_id -> Some child
        | _ -> List.find_opt (fun child -> child.issue_id = issue_id) orchestrator.children
      in
      (match lifecycle_child with Some child -> mark_compozy_child_blocked orchestrator child error | None -> ());
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
              goal_usage = row.goal_usage;
            }
            :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
          last_error = Some error;
        }
        |> Runtime_state.clear_context_status issue_id);
      update_ordered_queue_entries orchestrator ~attention:(row.issue.identifier, Some error) ~candidates:[ row.issue ] ()

let complete_child ?next_status ?queue_terminal_state ?queue_terminal_reason orchestrator child =
  let issue_id = child.issue_id in
  let next_issue =
    match next_status with
    | Some state -> { child.issue with Issue.state }
    | None -> child.issue
  in
  let has_active_next_stage =
    match next_status with
    | Some state -> issue_state_is_dispatchable orchestrator state
    | None -> false
  in
  let terminal_queue_state =
    match queue_terminal_state with
    | Some state when Util.trim state <> "" -> Some (String.lowercase_ascii (Util.trim state))
    | _ ->
        if has_active_next_stage then None
        else
          Some
            (match next_status with
            | Some status -> queue_terminal_state_for_status orchestrator.config status
            | None -> "completed")
  in
  let terminal_queue_reason =
    match queue_terminal_reason with
    | Some reason -> Some reason
    | None -> Option.bind next_status (queue_terminal_reason_for_status orchestrator.config)
  in
  let completed_identifier = match terminal_queue_state with Some "completed" -> Some child.issue_identifier | _ -> None in
  let pending_identifier = if has_active_next_stage then Some child.issue_identifier else None in
  let failed =
    match terminal_queue_state with Some "failed" -> Some (child.issue_identifier, terminal_queue_reason) | _ -> None
  in
  let attention =
    match terminal_queue_state with Some "attention" -> Some (child.issue_identifier, terminal_queue_reason) | _ -> None
  in
  let skipped =
    match terminal_queue_state with Some "skipped" -> Some (child.issue_identifier, terminal_queue_reason) | _ -> None
  in
  Hashtbl.remove orchestrator.attempts issue_id;
  Hashtbl.remove orchestrator.retry_due issue_id;
  Hashtbl.remove orchestrator.previous_attempt_outputs issue_id;
  update_state orchestrator (fun state ->
    {
      state with
      running = List.filter (fun (row : Runtime_state.running) -> row.issue.id <> issue_id) state.running;
      retrying = List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
      issue_errors =
        List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
    }
    |> Runtime_state.clear_context_status issue_id);
  update_ordered_queue_entries orchestrator ?completed_identifier ?pending_identifier ?failed ?attention ?skipped
    ~candidates:[ next_issue ] ();
  render_dispatch_completed child.issue_identifier child.issue_title

let mark_child_failed orchestrator child error =
  match record_compozy_task_step_failure orchestrator child error with
  | Error failure_error ->
      render_commit_failed child.issue_identifier failure_error;
      mark_retrying ~child orchestrator child.issue_id failure_error
  | Ok Not_compozy_failure -> mark_retrying ~child orchestrator child.issue_id error
  | Ok Compozy_completed_run_failure -> mark_retrying ~terminal_attention:true ~child orchestrator child.issue_id error
  | Ok Compozy_retry_step ->
      mark_retrying ~child orchestrator child.issue_id error;
      refresh_compozy_child_progress orchestrator child
  | Ok (Compozy_next_after_failure run) ->
      let next_issue = compozy_issue_with_lifecycle_dispatch_state orchestrator.config run in
      complete_child ~next_status:next_issue.state orchestrator child;
      dispatch_issue orchestrator next_issue
  | Ok (Compozy_finished_after_failure (run, reason)) ->
      complete_child ~next_status:run.state ~queue_terminal_state:"failed" ~queue_terminal_reason:reason orchestrator child

let cleanup_task_worktree orchestrator child =
  cleanup_task_worktree_for_issue orchestrator.config child.issue child.workspace.path

let auto_merge_child orchestrator child =
  if (not (is_git_repository orchestrator.config.repository_root)) || (not orchestrator.config.git.auto_merge) || protected_loop_start orchestrator then Ok ()
  else
    let branch = task_branch orchestrator.config child.issue in
    match has_worktree_changes child.workspace.path with
    | Error error ->
        record_task_branch_integration_attention orchestrator child.issue ~workspace_path:child.workspace.path
          "attention_uncommitted_changes" error;
        Error ("auto-merge failed: " ^ error)
    | Ok true ->
        let error = "Agent Worktree has uncommitted changes" in
        record_task_branch_integration_attention orchestrator child.issue ~workspace_path:child.workspace.path
          "attention_uncommitted_changes" error;
        Error ("auto-merge failed: " ^ error)
    | Ok false -> (
        match unauthorized_protected_task_branch_changes orchestrator.config child.issue ~base_ref:"HEAD" ~head_ref:branch with
        | Error error ->
            record_task_branch_integration_attention orchestrator child.issue ~workspace_path:child.workspace.path
              "attention_protected_paths" error;
            Error ("auto-merge failed: " ^ error)
        | Ok () -> (
            match
              integrate_task_branch orchestrator.config ~loop_start_branch:orchestrator.loop_start_branch
                ~workspace_path:child.workspace.path branch
            with
        | Ok result ->
            record_task_branch_integration orchestrator child.issue ~workspace_path:child.workspace.path result;
            cleanup_task_worktree orchestrator child;
            Ok ()
        | Error error ->
            record_task_branch_integration_attention orchestrator child.issue ~workspace_path:child.workspace.path
              "attention_integration_failed" error;
            Error ("auto-merge failed: " ^ error)))

let mark_merge_attention orchestrator child error =
  set_error orchestrator error;
  ignore (move_issue_status orchestrator child.issue orchestrator.config.git.merge_attention_status);
  mark_compozy_child_blocked orchestrator child error;
  let goal_usage =
    match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = child.issue_id) orchestrator.state.running with
    | Some row -> row.goal_usage
    | None -> None
  in
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
          goal_usage;
        }
        :: List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> child.issue_id) state.issue_errors;
      last_error = Some error;
    }
    |> Runtime_state.clear_context_status child.issue_id);
  update_ordered_queue_entries orchestrator ~attention:(child.issue_identifier, Some error) ~candidates:[ child.issue ] ()

type compozy_completion =
  | Not_compozy_child
  | Compozy_stage_only_completed_run of Compozy_tasks_tracker.prd_run
  | Compozy_final_step of Compozy_tasks_tracker.prd_run * Compozy_tasks_tracker.task_step
  | Compozy_next_step of Compozy_tasks_tracker.prd_run

let complete_compozy_task_step orchestrator child =
  if not (is_compozy_prd_run_child orchestrator child.issue) then Ok Not_compozy_child
  else
    match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
    | Error _ as error -> error
    | Ok run -> (
        match run.current_step with
        | None when Compozy_tasks_tracker.completed_prd_run run -> Ok (Compozy_stage_only_completed_run run)
        | None -> Error (Printf.sprintf "no runnable Compozy task step for %s" run.id)
        | Some step -> (
            match update_compozy_workspace_step_status orchestrator.config child.workspace run step "completed" with
            | Error _ as error -> error
            | Ok () -> (
                match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
                | Error _ as error -> error
                | Ok updated_run ->
                    match updated_run.current_step with
                    | Some _ ->
                        update_compozy_progress orchestrator updated_run;
                        Ok (Compozy_next_step updated_run)
                    | None -> Ok (Compozy_final_step (updated_run, step)))))

let restore_compozy_final_step_for_retry orchestrator child run step =
  match update_compozy_workspace_step_status orchestrator.config child.workspace run step "in_progress" with
  | Error error -> Error error
  | Ok () -> (
      match compozy_prd_run_for_workspace_issue orchestrator.config child.workspace child.issue with
      | Error _ as error -> error
      | Ok restored_run ->
          update_compozy_progress orchestrator restored_run;
          Ok ())

let mark_completed orchestrator child =
  let issue_id = child.issue_id in
  let stage = match child.stage with Some _ -> child.stage | None -> stage_for_issue orchestrator.config child.issue in
  let next_status = success_status ?stage orchestrator child.issue in
  match complete_compozy_task_step orchestrator child with
  | Error error ->
      render_commit_failed child.issue_identifier error;
      mark_retrying orchestrator issue_id error
  | Ok (Compozy_next_step run) ->
      let next_issue = compozy_issue_with_lifecycle_dispatch_state orchestrator.config run in
      complete_child ~next_status:next_issue.state orchestrator child;
      dispatch_issue orchestrator next_issue
  | Ok (Not_compozy_child | Compozy_stage_only_completed_run _ | Compozy_final_step _) as completion -> (
      match orchestrator.commit_stage orchestrator.config child.workspace child.issue stage next_status with
      | Error error ->
          let error =
            match completion with
            | Ok (Compozy_final_step (run, step)) -> (
                match restore_compozy_final_step_for_retry orchestrator child run step with
                | Ok () -> error
                | Error restore_error ->
                    Printf.sprintf "%s; could not restore final Compozy task step for retry: %s" error restore_error)
            | _ -> error
          in
          render_commit_failed child.issue_identifier error;
          if human_attention_completion_error error then mark_merge_attention orchestrator child error
          else if non_retryable_completion_error error then (
            set_error orchestrator error;
            mark_blocked ~child orchestrator issue_id error)
          else mark_retrying orchestrator issue_id error
      | Ok () ->
          let final_compozy_run =
            match completion with
            | Ok (Compozy_final_step (run, _step)) -> Some run
            | Ok (Compozy_stage_only_completed_run run) -> Some run
            | _ -> None
          in
          let final_compozy_has_next_stage status = Option.is_some final_compozy_run && status_selects_stage orchestrator.config status in
          let should_open_task_pull_request_before_auto_merge status =
            if final_compozy_has_next_stage status then false
            else
              task_pull_request_before_auto_merge orchestrator status
              ||
              match final_compozy_run with
              | Some _ ->
                  let policy = orchestrator.config.Config.pull_request in
                  policy.enabled && policy.mode = "task"
              | None -> false
          in
          let mark_final_compozy_completion () =
            match final_compozy_run with
            | None -> ()
            | Some run -> (
                match next_status with
                | Some status when status_selects_stage orchestrator.config status ->
                    let next_stage = stage_for_status orchestrator.config status in
                    let stage_agent = Option.map (fun (stage : Config.stage_agent) -> stage.agent) next_stage in
                    note_compozy_lifecycle_update orchestrator run
                      (Compozy_lifecycle.mark_stage_started orchestrator.config run ~stage_agent
                         ~dispatch_state:status)
                | _ -> mark_compozy_run_completed orchestrator run)
          in
          let status_moved_before_merge =
            match next_status with
            | Some status when should_open_task_pull_request_before_auto_merge status ->
                if move_issue_status orchestrator child.issue status then (
                  attempt_task_pull_request orchestrator child.issue;
                  Some true)
                else (
                  mark_retrying orchestrator issue_id (Printf.sprintf "could not move issue to %s" status);
                  None)
            | _ -> Some false
          in
          match status_moved_before_merge with
          | None -> ()
          | Some status_moved_before_merge -> (
              match auto_merge_child orchestrator child with
              | Error error -> mark_merge_attention orchestrator child error
              | Ok () -> (
                  match next_status with
                  | None ->
                      mark_final_compozy_completion ();
                      (match final_compozy_run with
                      | Some _ ->
                          let policy = orchestrator.config.Config.pull_request in
                          if policy.enabled && policy.mode = "task" then attempt_task_pull_request orchestrator child.issue
                      | None -> ());
                      complete_child orchestrator child
                  | Some status ->
                      if status_moved_before_merge then (
                        mark_final_compozy_completion ();
                        complete_child ~next_status:status orchestrator child)
                      else if not (move_issue_status orchestrator child.issue status) then
                        mark_retrying orchestrator issue_id (Printf.sprintf "could not move issue to %s" status)
                      else (
                        mark_final_compozy_completion ();
                        if not (final_compozy_has_next_stage status) then
                          maybe_open_review_pull_request orchestrator child.issue status;
                        complete_child ~next_status:status orchestrator child))))

let signal_child child signal =
  try Unix.kill (-child.pid) signal
  with Unix.Unix_error _ -> (try Unix.kill child.pid signal with Unix.Unix_error _ -> ())

let child_reaped child =
  try
    match Unix.waitpid [ Unix.WNOHANG ] child.pid with
    | 0, _ -> false
    | _ -> true
  with Unix.Unix_error (Unix.ECHILD, _, _) -> true

let kill_child child =
  signal_child child Sys.sigterm;
  Unix.sleepf 0.02;
  if not (child_reaped child) then (
    signal_child child Sys.sigkill;
    ignore (try Unix.waitpid [] child.pid with Unix.Unix_error _ -> (0, Unix.WEXITED 0)))

let refresh_child_output ?(force = false) orchestrator child =
  let stdout_size = file_size child.stdout_path in
  let stderr_size = file_size child.stderr_path in
  let workspace_activity_at =
    latest_workspace_file_mtime child.workspace.Workspace.path [ child.stdout_path; child.stderr_path ]
  in
  let workspace_activity_changed = workspace_activity_at > child.last_output_at in
  if force || stdout_size <> child.stdout_size || stderr_size <> child.stderr_size then (
    child.stdout_size <- stdout_size;
    child.stderr_size <- stderr_size;
    child.last_output_at <- Unix.time ();
    let now = Util.now_iso8601 () in
    let tokens = parse_tokens child.stdout_path child.stderr_path in
    let claude_activity =
      if child.harness.kind = "claude" then parse_claude_stream_activity child.stdout_path child.stderr_path
      else empty_claude_stream_activity
    in
    let cursor_activity =
      if child.harness.kind = "cursor" then parse_cursor_stream_activity child.stdout_path child.stderr_path
      else empty_cursor_stream_activity
    in
    let tokens = max_tokens tokens (max_tokens claude_activity.claude_tokens cursor_activity.cursor_tokens) in
    let goal_usage = parse_goal_usage child.stdout_path child.stderr_path in
    let latest_event =
      match claude_activity.claude_last_event with
      | Some _ -> claude_activity.claude_last_event
      | None -> (
          match cursor_activity.cursor_last_event with
          | Some _ -> cursor_activity.cursor_last_event
          | None -> Some "agent_output")
    in
    let latest_message =
      match claude_activity.claude_last_message with
      | Some _ -> claude_activity.claude_last_message
      | None -> (
          match cursor_activity.cursor_last_message with
          | Some _ -> cursor_activity.cursor_last_message
          | None -> Some "stdout/stderr updated")
    in
    update_state orchestrator (fun state -> { state with usage_totals = max_tokens state.usage_totals tokens });
    update_running orchestrator child.issue_id (fun row ->
        {
          row with
          Runtime_state.last_event = latest_event;
          last_message = latest_message;
          last_event_at = Some now;
          tokens = max_tokens row.tokens tokens;
          goal_usage = (match goal_usage with Some _ -> goal_usage | None -> row.goal_usage);
        });
    record_goal_loop_activity orchestrator child.issue_id
      (Option.value latest_message ~default:"Agent output updated.")
      "Continue monitoring agent activity.")
  else if workspace_activity_changed then (
    child.last_output_at <- Unix.time ();
    let now = Util.now_iso8601 () in
    update_running orchestrator child.issue_id (fun row ->
        {
          row with
          Runtime_state.last_event = Some "agent_activity";
          last_message = Some "workspace files updated";
          last_event_at = Some now;
        });
    record_goal_loop_activity orchestrator child.issue_id "Workspace files updated."
      "Continue monitoring workspace activity.")

let reap_children orchestrator =
  let now = Unix.time () in
  let original_children = orchestrator.children in
  let finished, still_running =
    List.fold_left
      (fun (finished, running) child ->
        refresh_child_output orchestrator child;
        match goal_loop_budget_exhaustion orchestrator child with
        | Some reason ->
            refresh_child_output ~force:true orchestrator child;
            kill_child child;
            mark_goal_loop_budget_exhausted orchestrator child.issue_id reason;
            mark_blocked ~child orchestrator child.issue_id reason;
            (child.issue_id :: finished, running)
        | None ->
            if child_turn_timed_out now child || child_stall_timed_out now child then (
              refresh_child_output ~force:true orchestrator child;
              kill_child child;
              mark_child_failed orchestrator child "agent timed out";
              (child.issue_id :: finished, running))
            else
              match Unix.waitpid [ Unix.WNOHANG ] child.pid with
          | 0, _ -> (finished, child :: running)
          | _, Unix.WEXITED 0 ->
              refresh_child_output ~force:true orchestrator child;
              (match goal_loop_completion_gate orchestrator child with
              | `Complete -> mark_completed orchestrator child
              | `Fail reason -> mark_child_failed orchestrator child reason);
              (child.issue_id :: finished, running)
          | _, Unix.WEXITED code ->
              refresh_child_output ~force:true orchestrator child;
              mark_child_failed orchestrator child (Printf.sprintf "agent exited with code %d" code);
              (child.issue_id :: finished, running)
          | _, Unix.WSIGNALED signal ->
              refresh_child_output ~force:true orchestrator child;
              mark_child_failed orchestrator child (Printf.sprintf "agent signaled %d" signal);
              (child.issue_id :: finished, running)
          | _, Unix.WSTOPPED signal ->
              set_error orchestrator (Printf.sprintf "agent for %s stopped by signal %d" child.issue_id signal);
              (finished, child :: running)
          | exception Unix.Unix_error (Unix.ECHILD, _, _) ->
              (match goal_loop_completion_gate orchestrator child with
              | `Complete -> mark_completed orchestrator child
              | `Fail reason -> mark_child_failed orchestrator child reason);
              (child.issue_id :: finished, running))
      ([], []) orchestrator.children
  in
  (* Completion handlers may synchronously dispatch a follow-up child, for
     example the next Compozy Task Step. Keep those children when replacing the
     original reaped set. *)
  let launched_during_reap =
    orchestrator.children
    |> List.filter (fun child -> not (List.exists (fun original -> original == child) original_children))
  in
  orchestrator.children <- List.rev still_running @ List.rev launched_during_reap;
  ignore finished

let poll_once orchestrator =
  try
    reap_children orchestrator;
    render_poll_started orchestrator;
    match Config.allowed_loop_start_branch_policy_gap orchestrator.config with
  | Some gap ->
      let runtime_gap = runtime_gap_of_config_gap gap in
      update_state orchestrator (fun state ->
        {
          state with
          readiness_gaps = [ runtime_gap ];
          last_error = Some (gap.requirement ^ ": " ^ gap.remediation);
        });
      render_poll_failed ("readiness gap: " ^ gap.requirement)
  | None -> (
      if
        List.exists
          (fun (existing : Runtime_state.readiness_gap) -> existing.requirement = "git.allowedLoopStartBranches")
          orchestrator.state.readiness_gaps
      then
        update_state orchestrator (fun state ->
          {
            state with
            readiness_gaps =
              List.filter
                (fun (existing : Runtime_state.readiness_gap) -> existing.requirement <> "git.allowedLoopStartBranches")
                state.readiness_gaps;
          });
      match orchestrator.tracker_retry_due with
  | Some due when Unix.time () < due ->
      let seconds = seconds_until due in
      let msg = tracker_retry_pause_message seconds in
      set_error orchestrator msg;
      render_poll_paused seconds msg
  | _ -> (
      orchestrator.tracker_retry_due <- None;
      let poll_result =
        try orchestrator.fetch orchestrator.tracker with exn -> Error (Issue_tracker.Failed (Printexc.to_string exn))
      in
      match poll_result with
      | Ok candidates ->
        let last_error = if Hashtbl.length orchestrator.blocked = 0 then None else orchestrator.state.last_error in
        let intake_evaluations = intake_evaluations_for_candidates orchestrator candidates in
        update_state orchestrator (fun state -> { state with Runtime_state.issues = candidates; intake_evaluations; last_error });
        reconcile_startup orchestrator candidates;
        update_ordered_queue_entries orchestrator ~skip_missing:true ~candidates ();
        let available = orchestrator.config.agent.max_concurrent_agents - List.length orchestrator.state.running in
        let dispatchable =
          candidates
          |> List.filter (fun issue ->
                 issue_allows_dispatch orchestrator issue
                 && (not (is_running orchestrator.state issue))
                 && (not (is_blocked orchestrator issue))
                 && retrying_due orchestrator issue)
          |> (fun issues ->
               match orchestrator.ordered_queue with
               | None -> issues
               | Some queue ->
                   let resolved_queue =
                     match orchestrator.resolved_ordered_queue with
                     | Some resolved_queue -> resolved_queue
                     | None -> resolve_ordered_queue orchestrator.tracker (Some queue) |> Option.value ~default:[]
                   in
                   issues
                   |> List.filter (queue_contains_issue resolved_queue)
                   |> List.filter (queue_entry_allows_dispatch resolved_queue orchestrator.state)
                   |> List.sort (fun left right -> compare (queue_index resolved_queue left) (queue_index resolved_queue right)))
        in
        update_ordered_queue_entries orchestrator ~skip_missing:true ~candidates ();
        if available > 0 then dispatchable |> take_admissible_by_stage orchestrator available |> List.iter (dispatch_issue orchestrator);
        maybe_open_batch_pull_request orchestrator ~candidates ~dispatchable_count:(List.length dispatchable);
        render_poll_completed orchestrator (List.length dispatchable)
      | Error (Issue_tracker.Rate_limited (msg, retry_after_ms)) ->
          let retry_after_ms = max 1 retry_after_ms in
          let due = Unix.time () +. (float_of_int retry_after_ms /. 1000.) in
          orchestrator.tracker_retry_due <- Some due;
          let seconds = seconds_until due in
          let pause_msg = tracker_retry_pause_message seconds ^ ": " ^ msg in
          set_error orchestrator pause_msg;
          render_poll_paused seconds msg
      | Error (Issue_tracker.Failed msg) ->
          set_error orchestrator msg;
          render_poll_failed msg))
  with exn ->
    let msg = Printexc.to_string exn in
    set_error orchestrator msg;
    render_poll_failed msg

let run_forever orchestrator =
  let finished_reported = ref false in
  while not !finished_reported do
    poll_once orchestrator;
    if ordered_queue_finished orchestrator then (
      (match orchestrator.state.Runtime_state.ordered_queue with
      | Some queue -> render_ordered_queue_finished queue
      | None -> ());
      finished_reported := true)
    else
      let interval_ms = max 1 orchestrator.config.polling.interval_ms in
      let read_timeout_ms =
        match orchestrator.children with
        | [] -> orchestrator.config.codex.read_timeout_ms
        | child :: rest ->
            rest
            |> List.fold_left
                 (fun interval child -> min interval child.harness.Config.read_timeout_ms)
                 child.harness.Config.read_timeout_ms
        |> max 1
      in
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
