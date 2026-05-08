type entry = { issue_identifier : string }
type t = { entries : entry list }
type parse_problem = { value : string; reason : string }
type validation_gap = { requirement : string; remediation : string }

let digits_only text =
  text <> ""
  && String.for_all
       (function
         | '0' .. '9' -> true
         | _ -> false)
       text

let normalize_entry raw =
  let value = Util.trim raw in
  if value = "" then Error { value; reason = "empty queue entry" }
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
        | _ ->
            Error
              {
                value;
                reason = "expected a numeric issue identifier with optional # or a minibeads identifier like mb-20";
              }

let parse text =
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
  let seen = Hashtbl.create 16 in
  let duplicates =
    entries
    |> List.filter_map (fun entry ->
           let count = Option.value (Hashtbl.find_opt seen entry.issue_identifier) ~default:0 + 1 in
           Hashtbl.replace seen entry.issue_identifier count;
           if count = 2 then Some { value = entry.issue_identifier; reason = "duplicate issue identifier" } else None)
  in
  match problems @ duplicates with
  | [] -> Ok { entries }
  | problems -> Error problems

let identifiers queue = List.map (fun entry -> entry.issue_identifier) queue.entries

let same_sequence left right = identifiers left = identifiers right

let validation_gaps (tracker : Issue_tracker.t) queue =
  match tracker.fetch_by_identifiers_detailed (identifiers queue) with
  | Error message ->
      [
        {
          requirement = "orderedQueue.validation";
          remediation = "Ordered Queue validation failed: " ^ message;
        };
      ]
  | Ok results ->
      results
      |> List.filter_map (fun (result : Issue_tracker.lookup_result) ->
             let issue_gap issue =
               if tracker.is_terminal issue.Issue.state then
                 Some
                   {
                     requirement = "orderedQueue." ^ result.identifier;
                     remediation = Printf.sprintf "Issue is terminal in tracker state %S." issue.state;
                   }
               else if not (tracker.is_active issue.Issue.state) then
                 Some
                   {
                     requirement = "orderedQueue." ^ result.identifier;
                     remediation = Printf.sprintf "Issue is not dispatchable in tracker state %S." issue.state;
                   }
               else None
             in
             match result.diagnostics with
             | Issue_tracker.Missing_issue :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ result.identifier;
                     remediation = "Issue is missing from the selected Issue Tracker.";
                   }
             | Issue_tracker.Missing_project_membership project_number :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ result.identifier;
                     remediation = Printf.sprintf "Issue is absent from GitHub Project #%d." project_number;
                   }
             | Issue_tracker.Closed_issue :: _ ->
                 Some
                   {
                     requirement = "orderedQueue." ^ result.identifier;
                     remediation = "Issue is closed in the selected Issue Tracker.";
                   }
             | [] -> (
                 match result.issue with
                 | Some issue -> issue_gap issue
                 | None ->
                     Some
                       {
                         requirement = "orderedQueue." ^ result.identifier;
                         remediation = "Issue is missing from the selected Issue Tracker.";
                       }))
