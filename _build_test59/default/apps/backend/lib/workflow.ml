type t = { path : string; dir : string; config : (string * Simple_yaml.scalar) list; prompt_template : string }

type error =
  | Missing_workflow_file of string
  | Workflow_parse_error of string
  | Workflow_front_matter_not_a_map

exception Error of error

let string_of_error = function
  | Missing_workflow_file path -> "missing_workflow_file: " ^ path
  | Workflow_parse_error msg -> "workflow_parse_error: " ^ msg
  | Workflow_front_matter_not_a_map -> "workflow_front_matter_not_a_map"

let split_front_matter content =
  let rec drop_leading_blank = function
    | line :: rest when Util.trim line = "" -> drop_leading_blank rest
    | lines -> lines
  in
  let lines = Util.split_lines content |> drop_leading_blank in
  match lines with
  | first :: rest when Util.trim first = "---" ->
      let rec collect_front acc = function
        | [] -> raise (Error (Workflow_parse_error "unterminated front matter"))
        | line :: tail when Util.trim line = "---" -> (List.rev acc, tail)
        | line :: tail -> collect_front (line :: acc) tail
      in
      let front, body = collect_front [] rest in
      (front, String.concat "\n" body |> Util.trim)
  | _ -> ([], Util.trim content)

let load path =
  if not (Sys.file_exists path) then raise (Error (Missing_workflow_file path));
  let content = Util.read_file path in
  let front, prompt_template = split_front_matter content in
  let config =
    try Simple_yaml.parse front with Simple_yaml.Parse_error msg -> raise (Error (Workflow_parse_error msg))
  in
  { path; dir = Filename.dirname (Unix.realpath path); config; prompt_template }
