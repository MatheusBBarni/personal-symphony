type entry = { issue_number : int; issue_identifier : string }
type t = { entries : entry list }
type parse_problem = { value : string; reason : string }

let normalize_entry raw =
  let value = Util.trim raw in
  if value = "" then Error { value; reason = "empty queue entry" }
  else
    let number_text =
      match Util.drop_prefix ~prefix:"#" value with
      | Some suffix -> suffix
      | None -> value
    in
    if String.contains number_text '/' || String.contains number_text ':' then
      Error { value; reason = "issue URLs and cross-repository references are not supported" }
    else
      match int_of_string_opt number_text with
      | Some issue_number when issue_number > 0 ->
          Ok { issue_number; issue_identifier = "#" ^ string_of_int issue_number }
      | _ -> Error { value; reason = "expected a numeric issue identifier with optional #" }

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
           let count = Option.value (Hashtbl.find_opt seen entry.issue_number) ~default:0 + 1 in
           Hashtbl.replace seen entry.issue_number count;
           if count = 2 then Some { value = entry.issue_identifier; reason = "duplicate issue identifier" } else None)
  in
  match problems @ duplicates with
  | [] -> Ok { entries }
  | problems -> Error problems

let identifiers queue = List.map (fun entry -> entry.issue_identifier) queue.entries
let numbers queue = List.map (fun entry -> entry.issue_number) queue.entries

let same_sequence left right = numbers left = numbers right

