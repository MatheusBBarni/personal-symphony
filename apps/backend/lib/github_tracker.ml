type t = { config : Config.tracker }

exception Tracker_error of string

let make config = { config }

let candidate_query =
  {|
query($owner:String!, $repo:String!, $states:[String!]) {
  repository(owner:$owner, name:$repo) {
    issues(first:50, states:OPEN, orderBy:{field:CREATED_AT,direction:ASC}) {
      nodes {
        id
        number
        title
        body
        url
        createdAt
        updatedAt
        labels(first:20) { nodes { name } }
        projectItems(first:20) {
          nodes {
            project { number }
            fieldValues(first:20) {
              nodes {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field { ... on ProjectV2SingleSelectField { name } }
                }
              }
            }
          }
        }
      }
    }
  }
}|}

let run_gh_graphql ~query ~variables =
  let variable_flags =
    variables
    |> List.map (fun (k, v) -> Printf.sprintf "-f %s=%s" (Util.shell_quote k) (Util.shell_quote v))
    |> String.concat " "
  in
  let command = Printf.sprintf "gh api graphql %s -f query=%s" variable_flags (Util.shell_quote query) in
  let ic = Unix.open_process_in command in
  let output =
    Fun.protect
      ~finally:(fun () -> ignore (Unix.close_process_in ic))
      (fun () ->
        let buf = Buffer.create 4096 in
        (try
           while true do
             Buffer.add_string buf (input_line ic);
             Buffer.add_char buf '\n'
           done
         with End_of_file -> ());
        Buffer.contents buf)
  in
  Yojson.Safe.from_string output

let fetch_candidate_issues tracker =
  match tracker.config.api_key with
  | None -> raise (Tracker_error "missing GitHub token")
  | Some _ ->
      let json =
        run_gh_graphql ~query:candidate_query
          ~variables:
            [
              ("owner", tracker.config.owner);
              ("repo", tracker.config.repo);
              ("states", String.concat "," tracker.config.active_states);
            ]
      in
      let open Yojson.Safe.Util in
      json |> member "data" |> member "repository" |> member "issues" |> member "nodes" |> to_list
      |> List.filter_map (fun node ->
             let number = node |> member "number" |> to_int in
             let state = "Todo" in
             let active =
               List.exists (fun s -> String.lowercase_ascii s = String.lowercase_ascii state) tracker.config.active_states
             in
             if not active then None
             else
               Some
                 {
                   (Issue.empty ~id:(node |> member "id" |> to_string)
                      ~identifier:("#" ^ string_of_int number)
                      ~title:(node |> member "title" |> to_string) ~state)
                   with
                   description = node |> member "body" |> to_string_option;
                   url = node |> member "url" |> to_string_option;
                   created_at = node |> member "createdAt" |> to_string_option;
                   updated_at = node |> member "updatedAt" |> to_string_option;
                   labels =
                     node |> member "labels" |> member "nodes" |> to_list
                     |> List.filter_map (fun label -> label |> member "name" |> to_string_option)
                     |> List.map String.lowercase_ascii;
                 })

let fetch_issues_by_states _tracker states = if states = [] then [] else []
let fetch_issue_states_by_ids _tracker _ids = []
