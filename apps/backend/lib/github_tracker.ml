type t = { config : Config.tracker }

exception Tracker_error of string

let make config = { config }

let remote_readiness_query =
  {|
query($owner:String!, $repo:String!, $projectNumber:Int!) {
  repository(owner:$owner, name:$repo) {
    id
    nameWithOwner
  }
  repositoryOwner(login:$owner) {
    id
    login
    ... on User {
      projectV2(number:$projectNumber) {
        id
        title
      }
    }
    ... on Organization {
      projectV2(number:$projectNumber) {
        id
        title
      }
    }
  }
}|}

let candidate_query =
  {|
query($owner:String!, $repo:String!) {
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
    |> List.map (fun (k, v) -> Printf.sprintf "-F %s=%s" (Util.shell_quote k) (Util.shell_quote v))
    |> String.concat " "
  in
  let command = Printf.sprintf "gh api graphql %s -f query=%s 2>/dev/null" variable_flags (Util.shell_quote query) in
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

let member name = function
  | `Assoc fields -> List.assoc_opt name fields |> Option.value ~default:`Null
  | _ -> `Null

let graphql_error_messages json =
  match member "errors" json with
  | `List errors ->
      errors
      |> List.filter_map (fun error ->
             match member "message" error with `String message -> Some message | _ -> None)
  | _ -> []

let has_data path json =
  let value = List.fold_left (fun current name -> member name current) json path in
  match value with `Null -> false | _ -> true

let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b

let safe_to_list = function `List values -> values | _ -> []
let safe_to_int_option = function `Int i -> Some i | `Intlit s -> int_of_string_opt s | _ -> None
let safe_to_string_option = function `String s -> Some s | _ -> None

let project_item_number item =
  item |> member "project" |> member "number" |> safe_to_int_option

let single_select_field_name value =
  value |> member "field" |> member "name" |> safe_to_string_option

let single_select_value_name value =
  value |> member "name" |> safe_to_string_option

let project_item_status ~project_number ~status_field item =
  match project_item_number item with
  | Some n when n = project_number ->
      item |> member "fieldValues" |> member "nodes" |> safe_to_list
      |> List.find_map (fun value ->
             match (single_select_field_name value, single_select_value_name value) with
             | Some field_name, Some status when string_equal_ci field_name status_field -> Some status
             | _ -> None)
  | _ -> None

let issue_project_status ~project_number ~status_field node =
  node |> member "projectItems" |> member "nodes" |> safe_to_list
  |> List.find_map (project_item_status ~project_number ~status_field)

let status_is_active ~active_states status =
  List.exists (string_equal_ci status) active_states

let issue_from_project_node ~(config : Config.tracker) node =
  let open Yojson.Safe.Util in
  match issue_project_status ~project_number:config.project_number ~status_field:config.project_status_field node with
  | None -> None
  | Some state when not (status_is_active ~active_states:config.active_states state) -> None
  | Some state ->
      let number = node |> member "number" |> to_int in
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
        }

let remote_readiness_gaps config =
  match config.Config.tracker.api_key with
  | None -> []
  | Some _ -> (
      try
        let json =
          run_gh_graphql ~query:remote_readiness_query
            ~variables:
              [
                ("owner", config.tracker.owner);
                ("repo", config.tracker.repo);
                ("projectNumber", string_of_int config.tracker.project_number);
              ]
        in
        let errors = graphql_error_messages json in
        let data = member "data" json in
        let gaps = ref [] in
        let add requirement remediation = gaps := { Config.requirement; remediation } :: !gaps in
        if not (has_data [ "repository"; "id" ] data) then
          add "github.repository"
            (Printf.sprintf
               "GitHub API could not read %s/%s. Check tracker.owner, tracker.repo, and that the token has repository access."
               config.tracker.owner config.tracker.repo);
        if
          not (has_data [ "repositoryOwner"; "projectV2"; "id" ] data)
        then
          add "github.project"
            (Printf.sprintf
               "GitHub API could not read project number %d for %s. For a user-owned project, use a classic PAT with read:project or project. Fine-grained PATs only work for organization-owned Projects that allow fine-grained token access."
               config.tracker.project_number config.tracker.owner);
        (match errors with
        | [] -> ()
        | messages ->
            add "github.api"
              ("GitHub API returned: " ^ String.concat "; " messages));
        List.rev !gaps
      with exn ->
        [
          {
            Config.requirement = "github.api";
            remediation = "GitHub API readiness check failed: " ^ Printexc.to_string exn;
          };
        ])

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
            ]
      in
      let open Yojson.Safe.Util in
      json |> member "data" |> member "repository" |> member "issues" |> member "nodes" |> to_list
      |> List.filter_map (issue_from_project_node ~config:tracker.config)

let fetch_issues_by_states _tracker states = if states = [] then [] else []
let fetch_issue_states_by_ids _tracker _ids = []
