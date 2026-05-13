type entry = { issue_identifier : string }
type t = { entries : entry list }
type parse_problem = { value : string; reason : string }
type resolved_entry = {
  queue_identifier : string;
  canonical_identifier : string;
}

type resolved = { resolved_entries : resolved_entry list }
type resolution_problem = {
  queue_identifier : string;
  canonical_identifier : string option;
  reason : string;
}

type validation_gap = { requirement : string; remediation : string }

let digits_only text =
  text <> ""
  && String.for_all
       (function
         | '0' .. '9' -> true
         | _ -> false)
       text

let normalize_compozy_entry value =
  match Util.drop_prefix ~prefix:"compozy:" value with
  | Some task_name ->
      let task_name = Util.trim task_name in
      if task_name = "" then
        Error
          {
            value;
            reason = "expected a Compozy PRD-run identifier like compozy:example-feature";
          }
      else if String.contains task_name '/' || String.contains task_name ':' then
        Error
          {
            value;
            reason =
              "expected a Compozy PRD-run identifier like compozy:example-feature without path separators";
          }
      else Ok { issue_identifier = "compozy:" ^ task_name }
  | None ->
      Error
        {
          value;
          reason = "expected a Compozy PRD-run identifier like compozy:example-feature";
        }

let opaque_bare_queue_token value =
  value <> ""
  && String.for_all
       (function
         | 'a' .. 'z' | '0' .. '9' | '-' | '_' | '.' -> true
         | _ -> false)
       value

let normalize_entry raw =
  let value = Util.trim raw in
  if value = "" then Error { value; reason = "empty queue entry" }
  else if Util.starts_with ~prefix:"compozy:" value then normalize_compozy_entry value
  else if String.contains value '/' || String.contains value ':' then
    Error { value; reason = "issue URLs and cross-repository references are not supported" }
  else
    match Util.drop_prefix ~prefix:"mb-" value with
    | Some number_text ->
        if digits_only number_text then
          match int_of_string_opt number_text with
          | Some issue_number when issue_number > 0 ->
              Ok { issue_identifier = "mb-" ^ string_of_int issue_number }
          | _ -> Error { value; reason = "expected a minibeads issue identifier like mb-20" }
        else Error { value; reason = "expected a minibeads issue identifier like mb-20" }
    | None ->
        let number_text =
          match Util.drop_prefix ~prefix:"#" value with
          | Some suffix -> suffix
          | None -> value
        in
        match int_of_string_opt number_text with
        | Some issue_number when issue_number > 0 ->
            Ok { issue_identifier = "#" ^ string_of_int issue_number }
        | _ when opaque_bare_queue_token value -> Ok { issue_identifier = value }
        | _ ->
            Error
              {
                value;
                reason =
                  "expected a numeric issue identifier with optional #, a minibeads identifier like mb-20, a Compozy identifier like compozy:example-feature, or a bare queue token";
              }

let parse text : (t, parse_problem list) result =
  let parts = String.split_on_char ',' text in
  let entries, problems =
    parts
    |> List.fold_left
         (fun (entries, problems) part ->
           match normalize_entry part with
           | Ok entry -> (entry :: entries, problems)
           | Error problem -> (entries, problem :: problems))
         ([], [])
  in
  let entries = List.rev entries in
  let problems = List.rev problems in
  match problems with
  | [] -> Ok ({ entries } : t)
  | problems -> Error problems

let identifiers (queue : t) = List.map (fun entry -> entry.issue_identifier) queue.entries

let same_sequence left right = identifiers left = identifiers right

let resolved_identifiers (queue : resolved) =
  List.map (fun (entry : resolved_entry) -> entry.canonical_identifier) queue.resolved_entries

let duplicate_resolution_problems entries =
  let seen = Hashtbl.create 16 in
  entries
  |> List.filter_map (fun (entry : resolved_entry) ->
         let count = Option.value (Hashtbl.find_opt seen entry.canonical_identifier) ~default:0 + 1 in
         Hashtbl.replace seen entry.canonical_identifier count;
         if count >= 2 then
           Some
             {
               queue_identifier = entry.queue_identifier;
               canonical_identifier = Some entry.canonical_identifier;
               reason = "duplicate issue identifier";
             }
         else None)

let compozy_style_resolution_problems (tracker : Issue_tracker.t) entries =
  if tracker.kind <> "compozy_tasks" then []
  else
    let styles =
      entries
      |> List.filter_map (fun (entry : resolved_entry) ->
             if not (Util.starts_with ~prefix:"compozy:" entry.canonical_identifier) then None
             else if Util.starts_with ~prefix:"compozy:" (Util.trim entry.queue_identifier) then Some `Canonical
             else Some `Bare)
    in
    let has_bare = List.exists (( = ) `Bare) styles in
    let has_canonical = List.exists (( = ) `Canonical) styles in
    if has_bare && has_canonical then
      match entries with
      | [] -> []
      | entry :: _ ->
          [
            {
              queue_identifier = entry.queue_identifier;
              canonical_identifier = None;
              reason =
                "mixed bare and canonical Compozy queue entries are not supported; use either bare slugs or compozy:<slug> selectors";
            };
          ]
    else []

let resolve (tracker : Issue_tracker.t) (queue : t) : (resolved, resolution_problem list) result =
  let entries, problems =
    queue.entries
    |> List.fold_left
         (fun (entries, problems) (entry : entry) ->
           let queue_identifier = entry.issue_identifier in
           match tracker.normalize_identifier queue_identifier with
           | Ok canonical_identifier ->
               ({ queue_identifier; canonical_identifier } :: entries, problems)
           | Error reason ->
               ( entries,
                 {
                   queue_identifier;
                   canonical_identifier = None;
                   reason;
                 }
                 :: problems ))
         ([], [])
  in
  let entries = List.rev entries in
  let problems = List.rev problems in
  match problems with
  | _ :: _ -> Error problems
  | [] -> (
      match duplicate_resolution_problems entries with
      | _ :: _ as problems -> Error problems
      | [] -> (
          match compozy_style_resolution_problems tracker entries with
          | _ :: _ as problems -> Error problems
          | [] -> Ok { resolved_entries = entries } ))

let validation_gap_of_resolution_problem (tracker : Issue_tracker.t) problem =
  let requirement =
    "orderedQueue." ^ if problem.queue_identifier = "" then "<empty>" else problem.queue_identifier
  in
  let remediation =
    match problem.canonical_identifier with
    | Some canonical_identifier when problem.reason = "duplicate issue identifier" ->
        Printf.sprintf "Duplicate queue entry resolves to %s." canonical_identifier
    | _ ->
        Printf.sprintf "Ordered Queue entry %S is invalid for %s Issue Tracker: %s" problem.queue_identifier
          tracker.kind problem.reason
  in
  { requirement; remediation }

let validation_gaps (tracker : Issue_tracker.t) queue =
  match resolve tracker queue with
  | Error problems -> List.map (validation_gap_of_resolution_problem tracker) problems
  | Ok resolved_queue -> (
  match tracker.fetch_by_identifiers_detailed (resolved_identifiers resolved_queue) with
  | Error message ->
      [
        {
          requirement = "orderedQueue.validation";
          remediation = "Ordered Queue validation failed: " ^ message;
        };
      ]
  | Ok results ->
      List.combine resolved_queue.resolved_entries results
      |> List.filter_map (fun ((entry : resolved_entry), (result : Issue_tracker.lookup_result)) ->
             let queue_identifier = entry.queue_identifier in
             let issue_gap issue =
               if tracker.is_terminal issue.Issue.state then
                 Some
                   {
                     requirement = "orderedQueue." ^ queue_identifier;
                     remediation = Printf.sprintf "Issue is terminal in tracker state %S." issue.state;
                   }
               else if not (tracker.is_active issue.Issue.state) then
                 Some
                   {
                     requirement = "orderedQueue." ^ queue_identifier;
                     remediation = Printf.sprintf "Issue is not dispatchable in tracker state %S." issue.state;
                   }
               else None
             in
             match result.diagnostics with
             | Issue_tracker.Missing_issue :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ queue_identifier;
                     remediation = "Issue is missing from the selected Issue Tracker.";
                   }
             | Issue_tracker.Missing_project_membership project_number :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ queue_identifier;
                     remediation = Printf.sprintf "Issue is absent from GitHub Project #%d." project_number;
                   }
             | Issue_tracker.Closed_issue :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ queue_identifier;
                     remediation = "Issue is closed in the selected Issue Tracker.";
                   }
             | [] -> (
                 match result.issue with
                 | Some issue -> issue_gap issue
                 | None ->
                     Some
                       {
                         requirement = "orderedQueue." ^ queue_identifier;
                         remediation = "Issue is missing from the selected Issue Tracker.";
                       })))
