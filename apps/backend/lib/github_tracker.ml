type t = { config : Config.tracker }
type project_issue = { issue : Issue.t; project_status : string option; closed : bool }

exception Tracker_error of string
exception Tracker_rate_limited of string * int

let rate_limit_retry_delay_ms = 300000

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
    issues(first:50, states:[OPEN,CLOSED], orderBy:{field:CREATED_AT,direction:ASC}) {
      nodes {
        id
        number
        state
        title
        body
        url
        createdAt
        updatedAt
        comments(first:50) {
          nodes {
            body
            createdAt
            url
            author { login }
          }
        }
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

let queue_issue_query numbers =
  let fields =
    numbers
    |> List.map (fun number ->
           Printf.sprintf
             {|issue_%d: issue(number:%d) {
        id
        number
        state
        title
        body
        url
        createdAt
        updatedAt
        comments(first:50) {
          nodes {
            body
            createdAt
            url
            author { login }
          }
        }
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
      }|}
             number number)
    |> String.concat "\n"
  in
  Printf.sprintf
    {|query($owner:String!, $repo:String!) {
  repository(owner:$owner, name:$repo) {
    %s
  }
}|}
    fields

let status_metadata_query =
  {|
query($owner:String!, $projectNumber:Int!, $issueId:ID!) {
  repositoryOwner(login:$owner) {
    ... on User {
      projectV2(number:$projectNumber) {
        id
        fields(first:50) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
              options {
                id
                name
                color
                description
              }
            }
          }
        }
      }
    }
    ... on Organization {
      projectV2(number:$projectNumber) {
        id
        fields(first:50) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
              options {
                id
                name
                color
                description
              }
            }
          }
        }
      }
    }
  }
  node(id:$issueId) {
    ... on Issue {
      projectItems(first:20) {
        nodes {
          id
          project { number }
        }
      }
    }
  }
}|}

let update_item_status_mutation =
  {|
mutation($projectId:ID!, $itemId:ID!, $fieldId:ID!, $optionId:String!) {
  updateProjectV2ItemFieldValue(input:{
    projectId:$projectId,
    itemId:$itemId,
    fieldId:$fieldId,
    value:{ singleSelectOptionId:$optionId }
  }) {
    projectV2Item { id }
  }
}|}

let run_gh_graphql ~query ~variables =
  let variable_flags =
    variables
    |> List.map (fun (k, v) ->
           let flag = if k = "projectNumber" then "-F" else "-f" in
           Printf.sprintf "%s %s=%s" flag (Util.shell_quote k) (Util.shell_quote v))
    |> String.concat " "
  in
  let command = Printf.sprintf "gh api graphql %s -f query=%s 2>&1" variable_flags (Util.shell_quote query) in
  let ic = Unix.open_process_in command in
  let buf = Buffer.create 4096 in
  let read_output () =
    try
      while true do
        Buffer.add_string buf (input_line ic);
        Buffer.add_char buf '\n'
      done
    with End_of_file -> ()
  in
  let status =
    try
      read_output ();
      Unix.close_process_in ic
    with exn ->
      ignore (Unix.close_process_in ic);
      raise exn
  in
  let output = Buffer.contents buf |> Util.trim in
  match Yojson.Safe.from_string output with
  | json -> json
  | exception Yojson.Json_error _ ->
      let status_text =
        match status with
        | Unix.WEXITED code -> Printf.sprintf "exit code %d" code
        | Unix.WSIGNALED signal -> Printf.sprintf "signal %d" signal
        | Unix.WSTOPPED signal -> Printf.sprintf "stopped by signal %d" signal
      in
      let detail = if output = "" then status_text else output in
      raise (Tracker_error ("GitHub API request failed: " ^ detail))

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

let contains_substring ~needle text =
  let needle_len = String.length needle in
  let text_len = String.length text in
  let rec loop index =
    if needle_len = 0 then true
    else if index + needle_len > text_len then false
    else if String.sub text index needle_len = needle then true
    else loop (index + 1)
  in
  loop 0

let rate_limit_message message =
  contains_substring ~needle:"rate limit" (String.lowercase_ascii message)

let github_api_error_messages json =
  let graphql_messages = graphql_error_messages json in
  let rest_messages =
    match member "message" json with
    | `String message -> [ message ]
    | _ -> []
  in
  graphql_messages @ rest_messages

let github_api_error_remediation messages =
  let message = String.concat "; " messages in
  if List.exists rate_limit_message messages then
    "GitHub API rate limit exceeded. Wait for the GitHub rate-limit window to reset, or authenticate gh with GH_TOKEN/GITHUB_TOKEN that has available quota. Original message: "
    ^ message
  else "GitHub API returned: " ^ message

let github_api_error json =
  match github_api_error_messages json with
  | [] -> None
  | messages ->
      let remediation = github_api_error_remediation messages in
      if List.exists rate_limit_message messages then Some (`Rate_limited remediation) else Some (`Error remediation)

let has_data path json =
  let value = List.fold_left (fun current name -> member name current) json path in
  match value with `Null -> false | _ -> true

let string_equal_ci a b = String.lowercase_ascii a = String.lowercase_ascii b

let safe_to_list = function `List values -> values | _ -> []
let safe_to_int_option = function `Int i -> Some i | `Intlit s -> int_of_string_opt s | _ -> None
let safe_to_string_option = function `String s -> Some s | _ -> None
let safe_to_string = function `String s -> s | _ -> ""

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

let status_is_visible ~config status =
  status_is_active ~active_states:config.Config.active_states status
  || List.exists (string_equal_ci status) config.terminal_states

let status_is_terminal ~config status =
  List.exists (string_equal_ci status) config.Config.terminal_states

let issue_is_closed node =
  match node |> member "state" |> safe_to_string_option with
  | Some state -> string_equal_ci state "CLOSED"
  | None -> false

let comment_from_node node =
  match node |> member "body" |> safe_to_string_option with
  | None -> None
  | Some body ->
      Some
        {
          Issue.author = node |> member "author" |> member "login" |> safe_to_string_option;
          body;
          created_at = node |> member "createdAt" |> safe_to_string_option;
          url = node |> member "url" |> safe_to_string_option;
        }

let comment_nodes node =
  match node |> member "comments" with
  | `Assoc _ as comments -> comments |> member "nodes" |> safe_to_list
  | _ -> []

let project_issue_from_node ~(config : Config.tracker) node =
  let number = node |> member "number" |> safe_to_int_option in
  match number with
  | None -> None
  | Some number ->
      let project_status = issue_project_status ~project_number:config.project_number ~status_field:config.project_status_field node in
      let state = Option.value project_status ~default:(node |> member "state" |> safe_to_string) in
      let issue =
        {
          (Issue.empty ~id:(node |> member "id" |> safe_to_string)
             ~identifier:("#" ^ string_of_int number)
             ~title:(node |> member "title" |> safe_to_string) ~state)
          with
          description = node |> member "body" |> safe_to_string_option;
          comments = comment_nodes node |> List.filter_map comment_from_node;
          url = node |> member "url" |> safe_to_string_option;
          created_at = node |> member "createdAt" |> safe_to_string_option;
          updated_at = node |> member "updatedAt" |> safe_to_string_option;
          labels =
            node |> member "labels" |> member "nodes" |> safe_to_list
            |> List.filter_map (fun label -> label |> member "name" |> safe_to_string_option)
            |> List.map String.lowercase_ascii;
        }
      in
      Some { issue; project_status; closed = issue_is_closed node }

let issue_from_project_node ~(config : Config.tracker) node =
  let open Yojson.Safe.Util in
  match issue_project_status ~project_number:config.project_number ~status_field:config.project_status_field node with
  | None -> None
  | Some state when not (status_is_visible ~config state) -> None
  | Some state when issue_is_closed node && not (status_is_terminal ~config state) -> None
  | Some state ->
      let number = node |> member "number" |> to_int in
      Some
        {
          (Issue.empty ~id:(node |> member "id" |> to_string)
             ~identifier:("#" ^ string_of_int number)
             ~title:(node |> member "title" |> to_string) ~state)
          with
          description = node |> member "body" |> to_string_option;
          comments =
            comment_nodes node
            |> List.filter_map (fun comment ->
                   match comment |> member "body" |> to_string_option with
                   | None -> None
                   | Some body ->
                       Some
                         {
                           Issue.author = comment |> member "author" |> member "login" |> to_string_option;
                           body;
                           created_at = comment |> member "createdAt" |> to_string_option;
                           url = comment |> member "url" |> to_string_option;
                         });
          url = node |> member "url" |> to_string_option;
          created_at = node |> member "createdAt" |> to_string_option;
          updated_at = node |> member "updatedAt" |> to_string_option;
          labels =
            node |> member "labels" |> member "nodes" |> to_list
            |> List.filter_map (fun label -> label |> member "name" |> to_string_option)
            |> List.map String.lowercase_ascii;
        }

type status_option = { id : string option; name : string; color : string; description : string }

type status_metadata = {
  project_id : string;
  item_id : string;
  field_id : string;
  options : status_option list;
}

let option_from_json json =
  {
    id = json |> member "id" |> safe_to_string_option;
    name = json |> member "name" |> safe_to_string;
    color = json |> member "color" |> safe_to_string;
    description = json |> member "description" |> safe_to_string;
  }

let field_options_by_name ~status_field fields =
  fields
  |> List.find_map (fun field ->
         match field |> member "name" |> safe_to_string_option with
         | Some name when string_equal_ci name status_field ->
             Some
               ( field |> member "id" |> safe_to_string,
                 field |> member "options" |> safe_to_list |> List.map option_from_json )
         | _ -> None)

let project_item_id_by_project_number ~project_number items =
  items
  |> List.find_map (fun item ->
         match project_item_number item with
         | Some n when n = project_number -> item |> member "id" |> safe_to_string_option
         | _ -> None)

let status_metadata_from_json ~(config : Config.tracker) json =
  let data = member "data" json in
  let project = data |> member "repositoryOwner" |> member "projectV2" in
  let project_id = project |> member "id" |> safe_to_string in
  let fields = project |> member "fields" |> member "nodes" |> safe_to_list in
  let items = data |> member "node" |> member "projectItems" |> member "nodes" |> safe_to_list in
  match (field_options_by_name ~status_field:config.project_status_field fields, project_item_id_by_project_number ~project_number:config.project_number items) with
  | Some (field_id, options), Some item_id when project_id <> "" && field_id <> "" ->
      Ok { project_id; item_id; field_id; options }
  | None, _ -> Error ("Project status field not found: " ^ config.project_status_field)
  | _, None -> Error (Printf.sprintf "Issue is not attached to GitHub Project #%d" config.project_number)
  | _ -> Error "GitHub Project status metadata was incomplete"

let graphql_string s = Yojson.Safe.to_string (`String s)

let option_input option =
  let id_part = match option.id with Some id -> "id:" ^ graphql_string id ^ "," | None -> "" in
  Printf.sprintf "{%s name:%s, color:%s, description:%s}" id_part (graphql_string option.name)
    (if option.color = "" then "GRAY" else option.color)
    (graphql_string option.description)

let update_field_options_mutation ~field_id ~options =
  Printf.sprintf
    {|mutation {
  updateProjectV2Field(input:{fieldId:%s, singleSelectOptions:[%s]}) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        options { id name color description }
      }
    }
  }
}|}
    (graphql_string field_id)
    (options |> List.map option_input |> String.concat ",")

let options_from_update_field_json json =
  json |> member "data" |> member "updateProjectV2Field" |> member "projectV2Field" |> member "options" |> safe_to_list
  |> List.map option_from_json

let find_option_id ~status options =
  options
  |> List.find_map (fun option ->
         match option.id with
         | Some id when string_equal_ci option.name status -> Some id
         | _ -> None)

let ensure_status_option tracker metadata status =
  match find_option_id ~status metadata.options with
  | Some option_id -> Ok option_id
  | None when not tracker.config.ensure_project_statuses ->
      Error
        (Printf.sprintf "Project status option %S is missing from field %S" status tracker.config.project_status_field)
  | None ->
      let new_option = { id = None; name = status; color = "GRAY"; description = "Created by Personal Symphony" } in
      let query = update_field_options_mutation ~field_id:metadata.field_id ~options:(metadata.options @ [ new_option ]) in
      let json = run_gh_graphql ~query ~variables:[] in
      let errors = github_api_error_messages json in
      if errors <> [] then Error (github_api_error_remediation errors)
      else
        match find_option_id ~status (options_from_update_field_json json) with
        | Some option_id -> Ok option_id
        | None -> Error (Printf.sprintf "GitHub did not return a created option id for %S" status)

let load_status_metadata tracker issue =
  let json =
    run_gh_graphql ~query:status_metadata_query
      ~variables:
        [
          ("owner", tracker.config.owner);
          ("projectNumber", string_of_int tracker.config.project_number);
          ("issueId", issue.Issue.id);
        ]
  in
  match github_api_error_messages json with
  | [] -> status_metadata_from_json ~config:tracker.config json
  | errors -> Error (github_api_error_remediation errors)

let update_issue_status tracker issue status =
  match tracker.config.api_key with
  | None -> Error "missing GitHub token"
  | Some _ -> (
      match load_status_metadata tracker issue with
      | Error _ as error -> error
      | Ok metadata -> (
          match ensure_status_option tracker metadata status with
          | Error _ as error -> error
          | Ok option_id ->
              let json =
                run_gh_graphql ~query:update_item_status_mutation
                  ~variables:
                    [
                      ("projectId", metadata.project_id);
                      ("itemId", metadata.item_id);
                      ("fieldId", metadata.field_id);
                      ("optionId", option_id);
                    ]
              in
              match github_api_error_messages json with
              | [] -> Ok ()
              | errors -> Error (github_api_error_remediation errors)))

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
        let errors = github_api_error_messages json in
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
              (github_api_error_remediation messages));
        List.rev !gaps
      with
      | Tracker_error msg ->
        [
          {
            Config.requirement = "github.api";
            remediation = msg;
          };
        ]
      | exn ->
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
      (match github_api_error json with
      | None -> ()
      | Some (`Rate_limited message) -> raise (Tracker_rate_limited (message, rate_limit_retry_delay_ms))
      | Some (`Error message) -> raise (Tracker_error message));
      let open Yojson.Safe.Util in
      json |> member "data" |> member "repository" |> member "issues" |> member "nodes" |> to_list
      |> List.filter_map (issue_from_project_node ~config:tracker.config)

let fetch_project_issues_by_numbers tracker numbers =
  match tracker.config.api_key with
  | None -> raise (Tracker_error "missing GitHub token")
  | Some _ ->
      let numbers = List.sort_uniq compare numbers in
      if numbers = [] then []
      else
        let json =
          run_gh_graphql ~query:(queue_issue_query numbers)
            ~variables:[ ("owner", tracker.config.owner); ("repo", tracker.config.repo) ]
        in
        (match github_api_error json with
        | None -> ()
        | Some (`Rate_limited message) -> raise (Tracker_rate_limited (message, rate_limit_retry_delay_ms))
        | Some (`Error message) -> raise (Tracker_error message));
        let repository = json |> member "data" |> member "repository" in
        numbers
        |> List.map (fun number ->
               let node = repository |> member ("issue_" ^ string_of_int number) in
               match node with
               | `Null -> (number, None)
               | _ -> (number, project_issue_from_node ~config:tracker.config node))

let fetch_issues_by_states _tracker states = if states = [] then [] else []
let fetch_issue_states_by_ids _tracker _ids = []
