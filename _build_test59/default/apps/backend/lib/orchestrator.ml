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

type previous_attempt_output = {
  attempt : int;
  stdout_path : string option;
  stderr_path : string option;
}

type t = {
  config : Config.t;
  prompt_template : string;
  tracker : Github_tracker.t;
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

let render_poll_paused seconds_remaining msg =
  Printf.eprintf "%s%s %s %s %s %s %ds\n%!" clear_line (dim (clock_time ())) (blue "poll") (yellow "waiting")
    msg (dim "retry_in") seconds_remaining

let runtime_gap_of_config_gap (gap : Config.readiness_gap) =
  { Runtime_state.requirement = gap.requirement; remediation = gap.remediation }

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

let render_ordered_queue_finished queue =
  let completed =
    queue.Runtime_state.entries
    |> List.filter (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = "completed")
    |> List.map (fun (entry : Runtime_state.ordered_queue_entry) -> entry.issue_identifier)
  in
  let skipped =
    queue.entries
    |> List.filter (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = "skipped")
    |> List.map (fun (entry : Runtime_state.ordered_queue_entry) ->
           match entry.skip_reason with
           | Some reason -> entry.issue_identifier ^ " (" ^ reason ^ ")"
           | None -> entry.issue_identifier)
  in
  let outcome = if skipped = [] then green "completed" else yellow "completed-with-skips" in
  Printf.eprintf "%s%s %s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") outcome
    (dim "completed") (String.concat "," completed);
  if skipped <> [] then
    Printf.eprintf "%s%s %s %s %s\n%!" clear_line (dim (clock_time ())) (cyan "ordered-queue") (yellow "skipped")
      (String.concat "; " skipped)

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

let load_ordered_queue_state config queue =
  let path = ordered_queue_state_path config in
  if Sys.file_exists path then
    try
      match Yojson.Safe.from_file path |> Runtime_state.ordered_queue_of_yojson with
      | Some state when ordered_queue_state_matches queue state -> state
      | _ -> ordered_queue_state queue
    with _ -> ordered_queue_state queue
  else ordered_queue_state queue

let persist_ordered_queue_state config = function
  | None -> ()
  | Some queue ->
      let path = ordered_queue_state_path config in
      Util.mkdir_p (Filename.dirname path);
      Util.write_file path (Runtime_state.ordered_queue_to_yojson queue |> Yojson.Safe.pretty_to_string)

let queue_issue_number issue =
  match Util.drop_prefix ~prefix:"#" issue.Issue.identifier with
  | Some number -> int_of_string_opt number
  | None -> None

let issue_numeric_key issue = Option.value (queue_issue_number issue) ~default:max_int

let queue_contains_issue queue issue =
  match queue_issue_number issue with
  | None -> false
  | Some number -> List.exists (fun (entry : Ordered_queue.entry) -> entry.issue_number = number) queue.Ordered_queue.entries

let queue_index queue issue =
  match queue_issue_number issue with
  | None -> max_int
  | Some number ->
      queue.Ordered_queue.entries
      |> List.mapi (fun index (entry : Ordered_queue.entry) -> (index, entry.issue_number))
      |> List.find_map (fun (index, candidate_number) -> if candidate_number = number then Some index else None)
      |> Option.value ~default:max_int

let queue_entry_allows_dispatch state issue =
  match state.Runtime_state.ordered_queue with
  | None -> true
  | Some queue -> (
      match List.find_opt (fun (entry : Runtime_state.ordered_queue_entry) -> entry.issue_identifier = issue.Issue.identifier) queue.entries with
      | Some entry when entry.state = "completed" || entry.state = "skipped" -> false
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
           (fun (entry : Runtime_state.ordered_queue_entry) -> entry.state = "completed" || entry.state = "skipped")
           queue.entries

let entry_state_for_issue state issue_identifier =
  let is_issue row = row.Runtime_state.issue.Issue.identifier = issue_identifier in
  let is_retry (row : Runtime_state.retrying) = row.issue_identifier = issue_identifier in
  let is_error (row : Runtime_state.issue_error) = row.issue_identifier = issue_identifier in
  if List.exists is_issue state.Runtime_state.running then Some "running"
  else if List.exists is_retry state.retrying then Some "retrying"
  else if List.exists is_error state.issue_errors then Some "skipped"
  else None

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

let json_option_string = function Some value when Util.trim value <> "" -> `String value | _ -> `Null
let json_option_int = function Some value -> `Int value | None -> `Null

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
      ("attempt", `Int (Option.value attempt ~default:0));
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

let agent_context_snapshot ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch =
  match match stage with Some _ -> stage | None -> stage_for_issue config issue with
  | Some stage when Config.stage_context_snapshot_enabled stage -> (
      match stage.Config.context_snapshot with
      | Some snapshot ->
          let lines =
            [
              "## Agent Context Snapshot";
              "";
              Printf.sprintf "- Issue: %s %s" issue.Issue.identifier (compact_markdown_value issue.title);
              Printf.sprintf "- Project status: %s" issue.state;
              Printf.sprintf "- Labels: %s" (if issue.labels = [] then "(none)" else String.concat ", " issue.labels);
              Printf.sprintf "- Blockers: %s" (blockers_line issue.blocked_by);
              Printf.sprintf "- Attempt: %d" (Option.value attempt ~default:0);
              Printf.sprintf "- Stage Agent: %s" stage.agent;
              Printf.sprintf "- Task Branch: %s" (task_branch config issue);
              Printf.sprintf "- Agent Worktree: %s" workspace.Workspace.path;
            ]
            @ optional_line "Loop-Start Branch" loop_start_branch
            @ previous_attempt_lines previous_attempt_output
          in
          Some (String.concat "\n" lines |> truncate_snapshot snapshot.max_output_bytes)
      | None -> None)
  | _ -> None

let compose_prompt ?stage ?previous_attempt_output config issue attempt base_prompt ~workspace ~loop_start_branch =
  let prompt =
    match agent_context_snapshot ?stage ?previous_attempt_output config issue attempt ~workspace ~loop_start_branch with
    | None -> normal_prompt ?stage config issue base_prompt
    | Some snapshot -> Printf.sprintf "%s\n\n---\n\n%s" (normal_prompt ?stage config issue base_prompt |> Util.trim) snapshot
  in
  match stage_goal_handoff_stage ?stage config issue with
  | None -> prompt
  | Some stage -> Printf.sprintf "/goal %s\n\n---\n\n%s" (stage_goal_context issue attempt stage) prompt

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
  let command =
    Printf.sprintf "gh pr list --repo %s --state open --head %s --base %s --limit 1 --json url"
      (Util.shell_quote repo_full_name) (Util.shell_quote head_branch)
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

let shell_launch ~stage ~config ~workspace ~prompt ~issue =
  let stage = match stage with Some _ -> stage | None -> stage_for_issue config issue in
  let harness = Option.value (Config.selected_agent_harness config stage) ~default:(Config.default_agent_harness config) in
  let prompt_path = write_prompt workspace prompt in
  let stdout_path = Filename.concat workspace.Workspace.path "stdout.log" in
  let stderr_path = Filename.concat workspace.Workspace.path "stderr.log" in
  let command =
    Printf.sprintf "cd %s && %s < %s > %s 2> %s" (Util.shell_quote workspace.Workspace.path) (render_harness_command harness)
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

let make ?ordered_queue ?(launch : launch = shell_launch) ?(fetch = Github_tracker.fetch_candidate_issues)
    ?(set_status = Github_tracker.update_issue_status)
    ?(commit_stage = git_commit_stage_changes) ?(batch_pull_request_handoff = gh_batch_pull_request_handoff)
    ?(notify_state = fun _ -> ()) ~config ~prompt_template () =
  {
    config;
    prompt_template;
    tracker = Github_tracker.make config.tracker;
    state =
      Runtime_state.empty ~status_order:(Config.project_status_order config)
        ?ordered_queue:(Option.map (load_ordered_queue_state config) ordered_queue)
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
  }

let get_state orchestrator = orchestrator.state

let set_state orchestrator state =
  orchestrator.state <- state;
  persist_ordered_queue_state orchestrator.config state.Runtime_state.ordered_queue;
  orchestrator.notify_state state

let update_state orchestrator f = set_state orchestrator (f orchestrator.state)

let update_ordered_queue_entries orchestrator ?completed_identifier ?pending_identifier ?skipped ?(skip_missing = false) ~candidates
    () =
  match orchestrator.state.Runtime_state.ordered_queue with
  | None -> ()
  | Some queue ->
      let candidate_for identifier = List.find_opt (fun issue -> issue.Issue.identifier = identifier) candidates in
      let candidate_not_dispatchable identifier =
        match candidate_for identifier with
        | Some issue -> not (Github_tracker.status_is_active ~active_states:orchestrator.config.tracker.active_states issue.Issue.state)
        | None -> false
      in
      let candidate_dispatchable identifier =
        match candidate_for identifier with
        | Some issue -> Github_tracker.status_is_active ~active_states:orchestrator.config.tracker.active_states issue.Issue.state
        | None -> false
      in
      let candidate_missing identifier = candidate_for identifier = None in
      let skipped_identifier, skipped_reason =
        match skipped with Some (identifier, reason) -> (Some identifier, Some reason) | None -> (None, None)
      in
      let old_entries = queue.entries in
      let next_entries state =
        old_entries
        |> List.map (fun (entry : Runtime_state.ordered_queue_entry) ->
               let title = match candidate_for entry.issue_identifier with Some issue -> Some issue.Issue.title | None -> entry.title in
               let state_name =
                 match completed_identifier with
                 | Some identifier when identifier = entry.issue_identifier -> "completed"
                 | _ -> (
                     match pending_identifier with
                     | Some identifier when identifier = entry.issue_identifier -> "pending"
                     | _ -> (
                         match skipped_identifier with
                         | Some identifier when identifier = entry.issue_identifier -> "skipped"
                         | _ -> (
                             match entry_state_for_issue state entry.issue_identifier with
                             | Some state -> state
                             | None
                               when skip_missing && entry.state = "pending"
                                    && (candidate_missing entry.issue_identifier || candidate_not_dispatchable entry.issue_identifier) ->
                                 "skipped"
                             | None when skip_missing && entry.state = "completed" && candidate_dispatchable entry.issue_identifier ->
                                 "pending"
                             | None -> entry.state)))
               in
               let skip_reason =
                 match skipped_identifier with
                 | Some identifier when identifier = entry.issue_identifier -> skipped_reason
                 | _ when pending_identifier = Some entry.issue_identifier -> None
                 | _ when skip_missing && entry.state = "pending" && candidate_missing entry.issue_identifier ->
                     Some "Issue became unavailable or not dispatchable before admission."
                 | _ when skip_missing && entry.state = "pending" && candidate_not_dispatchable entry.issue_identifier ->
                     Some "Issue is no longer in a dispatchable project state."
                 | _ -> entry.skip_reason
               in
               { entry with title; state = state_name; skip_reason })
      in
      let new_entries = next_entries orchestrator.state in
      update_state orchestrator (fun state -> { state with ordered_queue = Some { Runtime_state.entries = next_entries state } });
      List.iter2
        (fun (old_entry : Runtime_state.ordered_queue_entry) (new_entry : Runtime_state.ordered_queue_entry) ->
          if old_entry.state <> "skipped" && new_entry.state = "skipped" then
            render_ordered_queue_skipped new_entry.issue_identifier (Option.value new_entry.skip_reason ~default:""))
        old_entries new_entries

let set_error orchestrator msg = update_state orchestrator (fun state -> { state with Runtime_state.last_error = Some msg })

let seconds_until timestamp =
  max 1 (int_of_float (ceil (timestamp -. Unix.time ())))

let tracker_retry_pause_message seconds =
  Printf.sprintf "GitHub API rate limit exceeded; retrying tracker poll in %d seconds" seconds

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
  Github_tracker.status_is_active ~active_states:orchestrator.config.tracker.active_states issue.Issue.state

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
  match compare (issue_numeric_key left) (issue_numeric_key right) with
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
                if protected_loop_start orchestrator then
                  record_startup_attention orchestrator issue branch workspace_path "attention_protected_trunk"
                    "committed Task Branch work exists but Loop-Start Branch is protected"
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
  match orchestrator.batch_pull_request_handoff orchestrator.config ~head_branch:orchestrator.loop_start_branch with
  | Ok url ->
      orchestrator.batch_pull_request_completed <- true;
      set_pull_request_handoff orchestrator "completed" ?url ();
      render_pull_request_completed orchestrator.loop_start_branch policy.base_branch
  | Error error ->
      set_pull_request_handoff orchestrator "retryable_failure" ~error ();
      render_pull_request_failed orchestrator.loop_start_branch policy.base_branch error

let attempt_task_pull_request orchestrator issue =
  let policy = orchestrator.config.Config.pull_request in
  let head_branch = task_branch orchestrator.config issue in
  set_pull_request_handoff orchestrator ~issue ~head_branch "attempting" ();
  match orchestrator.batch_pull_request_handoff orchestrator.config ~head_branch with
  | Ok url ->
      set_pull_request_handoff orchestrator ~issue ~head_branch "completed" ?url ();
      render_pull_request_completed head_branch policy.base_branch
  | Error error ->
      set_pull_request_handoff orchestrator ~issue ~head_branch "retryable_failure" ~error ();
      render_pull_request_failed head_branch policy.base_branch error

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
      attempt_batch_pull_request orchestrator)

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
      render_dispatch_retrying issue.identifier 0 error;
      ignore (move_issue_status orchestrator issue orchestrator.config.git.merge_attention_status)
  | Ok workspace ->
      let can_dispatch =
        match target_start_status with
        | None -> true
        | Some status -> move_issue_status orchestrator issue status
      in
      if can_dispatch then (
        let launch_issue = issue in
        let issue = match target_start_status with Some state -> { issue with Issue.state } | None -> issue in
        let attempt = Hashtbl.find_opt orchestrator.attempts issue.id in
        let rendered = Prompt.render ~issue ~attempt orchestrator.prompt_template in
        let previous_attempt_output = Hashtbl.find_opt orchestrator.previous_attempt_outputs issue.id in
        let prompt =
          compose_prompt ?stage ?previous_attempt_output orchestrator.config issue attempt rendered ~workspace
            ~loop_start_branch:(Some orchestrator.loop_start_branch)
        in
        let harness =
          Option.value (Config.selected_agent_harness orchestrator.config stage)
            ~default:(Config.default_agent_harness orchestrator.config)
        in
        let launched = orchestrator.launch ~stage ~config:orchestrator.config ~workspace ~prompt ~issue:launch_issue in
        let now = Util.now_iso8601 () in
        let stage_agent, stage_states = selected_stage_fields stage in
        let row =
          {
            Runtime_state.issue;
            stage_agent;
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
            last_error = None;
          });
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

let mark_retrying orchestrator issue_id error =
  match List.find_opt (fun (row : Runtime_state.running) -> row.issue.id = issue_id) orchestrator.state.running with
  | None -> ()
  | Some row ->
      let next_attempt = Option.value (Hashtbl.find_opt orchestrator.attempts issue_id) ~default:0 + 1 in
      Hashtbl.replace orchestrator.attempts issue_id next_attempt;
      let previous_attempt_output =
        match List.find_opt (fun child -> child.issue_id = issue_id) orchestrator.children with
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
              goal_usage = row.goal_usage;
            }
            :: List.filter (fun (retry : Runtime_state.retrying) -> retry.issue_id <> issue_id) state.retrying;
          issue_errors =
            List.filter (fun (issue_error : Runtime_state.issue_error) -> issue_error.issue_id <> issue_id) state.issue_errors;
          last_error = Some error;
        });
      let stage = stage_from_running orchestrator.config row in
      (match retry_status ?stage orchestrator row.issue with
      | None -> ()
      | Some status -> ignore (move_issue_status orchestrator row.issue status));
      render_dispatch_retrying row.issue.identifier next_attempt error;
      update_ordered_queue_entries orchestrator ~candidates:[ row.issue ] ()

let non_retryable_completion_error = function
  | "commit required but agent produced no code changes" | "commit required but no staged changes were found" -> true
  | _ -> false

let protected_path_completion_error error =
  Util.starts_with ~prefix:"Protected Path Policy blocked unauthorized changes:" error

let human_attention_completion_error error =
  protected_path_completion_error error ||
  Util.starts_with ~prefix:stage_commit_classification_conflict_prefix error

let mark_blocked orchestrator issue_id error =
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
        });
      update_ordered_queue_entries orchestrator ~skipped:(row.issue.identifier, error) ~candidates:[ row.issue ] ()

let complete_child ?next_status orchestrator child =
  let issue_id = child.issue_id in
  let next_issue =
    match next_status with
    | Some state -> { child.issue with Issue.state }
    | None -> child.issue
  in
  let has_active_next_stage =
    match next_status with
    | Some state -> Github_tracker.status_is_active ~active_states:orchestrator.config.tracker.active_states state
    | None -> false
  in
  let completed_identifier = if has_active_next_stage then None else Some child.issue_identifier in
  let pending_identifier = if has_active_next_stage then Some child.issue_identifier else None in
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
    });
  update_ordered_queue_entries orchestrator ?completed_identifier ?pending_identifier ~candidates:[ next_issue ] ();
  render_dispatch_completed child.issue_identifier child.issue_title

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
    });
  update_ordered_queue_entries orchestrator ~skipped:(child.issue_identifier, error) ~candidates:[ child.issue ] ()

let mark_completed orchestrator child =
  let issue_id = child.issue_id in
  let stage = match child.stage with Some _ -> child.stage | None -> stage_for_issue orchestrator.config child.issue in
  let next_status = success_status ?stage orchestrator child.issue in
  match orchestrator.commit_stage orchestrator.config child.workspace child.issue stage next_status with
  | Error error ->
      render_commit_failed child.issue_identifier error;
      if human_attention_completion_error error then mark_merge_attention orchestrator child error
      else if non_retryable_completion_error error then (
        set_error orchestrator error;
        mark_blocked orchestrator issue_id error)
      else mark_retrying orchestrator issue_id error
  | Ok () ->
      let status_moved_before_merge =
        match next_status with
        | Some status when task_pull_request_before_auto_merge orchestrator status ->
            if move_issue_status orchestrator child.issue status then (
              attempt_task_pull_request orchestrator child.issue;
              Some true)
            else (
              mark_retrying orchestrator issue_id (Printf.sprintf "could not move issue to %s" status);
              None)
        | _ -> Some false
      in
      (match status_moved_before_merge with
      | None -> ()
      | Some status_moved_before_merge -> (
          match auto_merge_child orchestrator child with
          | Error error -> mark_merge_attention orchestrator child error
          | Ok () -> (
              match next_status with
              | None -> complete_child orchestrator child
              | Some status ->
                  if status_moved_before_merge then complete_child ~next_status:status orchestrator child
                  else if not (move_issue_status orchestrator child.issue status) then
                    mark_retrying orchestrator issue_id (Printf.sprintf "could not move issue to %s" status)
                  else (
                    maybe_open_review_pull_request orchestrator child.issue status;
                    complete_child ~next_status:status orchestrator child))))

let kill_child child =
  try Unix.kill child.pid Sys.sigterm with Unix.Unix_error _ -> ()

let refresh_child_output ?(force = false) orchestrator child =
  let stdout_size = file_size child.stdout_path in
  let stderr_size = file_size child.stderr_path in
  if force || stdout_size <> child.stdout_size || stderr_size <> child.stderr_size then (
    child.stdout_size <- stdout_size;
    child.stderr_size <- stderr_size;
    child.last_output_at <- Unix.time ();
    let now = Util.now_iso8601 () in
    let tokens = parse_tokens child.stdout_path child.stderr_path in
    let goal_usage = parse_goal_usage child.stdout_path child.stderr_path in
    update_state orchestrator (fun state -> { state with codex_totals = max_tokens state.codex_totals tokens });
    update_running orchestrator child.issue_id (fun row ->
        {
          row with
          Runtime_state.last_event = Some "agent_output";
          last_message = Some "stdout/stderr updated";
          last_event_at = Some now;
          tokens = max_tokens row.tokens tokens;
          goal_usage = (match goal_usage with Some _ -> goal_usage | None -> row.goal_usage);
        }))

let reap_children orchestrator =
  let now = Unix.time () in
  let finished, still_running =
    List.fold_left
      (fun (finished, running) child ->
        refresh_child_output orchestrator child;
        if
          now -. child.started_at > float_of_int child.harness.turn_timeout_ms /. 1000.
          || now -. child.last_output_at > float_of_int child.harness.stall_timeout_ms /. 1000.
        then (
          refresh_child_output ~force:true orchestrator child;
          kill_child child;
          mark_retrying orchestrator child.issue_id "agent timed out";
          (child.issue_id :: finished, running))
        else
          match Unix.waitpid [ Unix.WNOHANG ] child.pid with
          | 0, _ -> (finished, child :: running)
          | _, Unix.WEXITED 0 ->
              refresh_child_output ~force:true orchestrator child;
              mark_completed orchestrator child;
              (child.issue_id :: finished, running)
          | _, Unix.WEXITED code ->
              refresh_child_output ~force:true orchestrator child;
              mark_retrying orchestrator child.issue_id (Printf.sprintf "agent exited with code %d" code);
              (child.issue_id :: finished, running)
          | _, Unix.WSIGNALED signal ->
              refresh_child_output ~force:true orchestrator child;
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
      try
        let candidates = orchestrator.fetch orchestrator.tracker in
        let last_error = if Hashtbl.length orchestrator.blocked = 0 then None else orchestrator.state.last_error in
        update_state orchestrator (fun state -> { state with Runtime_state.issues = candidates; last_error });
        reconcile_startup orchestrator candidates;
        update_ordered_queue_entries orchestrator ~skip_missing:true ~candidates ();
        let available = orchestrator.config.agent.max_concurrent_agents - List.length orchestrator.state.running in
        let dispatchable =
          candidates
          |> List.filter (fun issue ->
                 issue_is_active orchestrator issue
                 && (not (is_running orchestrator.state issue))
                 && (not (is_blocked orchestrator issue))
                 && retrying_due orchestrator issue)
          |> (fun issues ->
               match orchestrator.ordered_queue with
               | None -> issues
               | Some queue ->
                   issues
                   |> List.filter (queue_contains_issue queue)
                   |> List.filter (queue_entry_allows_dispatch orchestrator.state)
                   |> List.sort (fun left right -> compare (queue_index queue left) (queue_index queue right)))
        in
        update_ordered_queue_entries orchestrator ~skip_missing:true ~candidates ();
        if available > 0 then dispatchable |> take_admissible_by_stage orchestrator available |> List.iter (dispatch_issue orchestrator);
        maybe_open_batch_pull_request orchestrator ~candidates ~dispatchable_count:(List.length dispatchable);
        render_poll_completed orchestrator (List.length dispatchable)
      with
      | Github_tracker.Tracker_rate_limited (msg, retry_after_ms) ->
          let retry_after_ms = max 1 retry_after_ms in
          let due = Unix.time () +. (float_of_int retry_after_ms /. 1000.) in
          orchestrator.tracker_retry_due <- Some due;
          let seconds = seconds_until due in
          let pause_msg = tracker_retry_pause_message seconds ^ ": " ^ msg in
          set_error orchestrator pause_msg;
          render_poll_paused seconds msg
      | exn ->
          let msg = Printexc.to_string exn in
          set_error orchestrator msg;
          render_poll_failed msg))

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
