type blocker = { id : string option; identifier : string option; state : string option }
type comment = { author : string option; body : string; created_at : string option; url : string option }

type t = {
  id : string;
  identifier : string;
  title : string;
  description : string option;
  comments : comment list;
  priority : int option;
  state : string;
  branch_name : string option;
  url : string option;
  labels : string list;
  blocked_by : blocker list;
  created_at : string option;
  updated_at : string option;
}

let empty ~id ~identifier ~title ~state =
  {
    id;
    identifier;
    title;
    description = None;
    comments = [];
    priority = None;
    state;
    branch_name = None;
    url = None;
    labels = [];
    blocked_by = [];
    created_at = None;
    updated_at = None;
  }

let option_string = function Some s -> `String s | None -> `Null
let option_int = function Some i -> `Int i | None -> `Null

let comment_to_yojson comment =
  `Assoc
    [
      ("author", option_string comment.author);
      ("body", `String comment.body);
      ("created_at", option_string comment.created_at);
      ("url", option_string comment.url);
    ]

let blocker_to_yojson (b : blocker) =
  `Assoc
    [
      ("id", option_string b.id);
      ("identifier", option_string b.identifier);
      ("state", option_string b.state);
    ]

let to_yojson issue =
  `Assoc
    [
      ("id", `String issue.id);
      ("identifier", `String issue.identifier);
      ("title", `String issue.title);
      ("description", option_string issue.description);
      ("comments", `List (List.map comment_to_yojson issue.comments));
      ("priority", option_int issue.priority);
      ("state", `String issue.state);
      ("branch_name", option_string issue.branch_name);
      ("url", option_string issue.url);
      ("labels", `List (List.map (fun label -> `String label) issue.labels));
      ("blocked_by", `List (List.map blocker_to_yojson issue.blocked_by));
      ("created_at", option_string issue.created_at);
      ("updated_at", option_string issue.updated_at);
    ]

let field issue = function
  | "id" -> Some issue.id
  | "identifier" -> Some issue.identifier
  | "title" -> Some issue.title
  | "description" -> Some (Option.value issue.description ~default:"")
  | "comments" ->
      Some
        (issue.comments
        |> List.map (fun comment ->
               let prefix =
                 match (comment.author, comment.created_at) with
                 | Some author, Some created_at -> Printf.sprintf "%s at %s" author created_at
                 | Some author, None -> author
                 | None, Some created_at -> created_at
                 | None, None -> "comment"
               in
               Printf.sprintf "%s:\n%s" prefix comment.body)
        |> String.concat "\n\n")
  | "state" -> Some issue.state
  | "branch_name" -> Some (Option.value issue.branch_name ~default:"")
  | "url" -> Some (Option.value issue.url ~default:"")
  | "created_at" -> Some (Option.value issue.created_at ~default:"")
  | "updated_at" -> Some (Option.value issue.updated_at ~default:"")
  | "priority" -> Some (Option.value (Option.map string_of_int issue.priority) ~default:"")
  | _ -> None
