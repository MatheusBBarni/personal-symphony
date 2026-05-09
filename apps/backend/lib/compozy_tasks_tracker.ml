type task_file = {
  path : string;
  file : string;
  index : int;
  status : string;
  title : string;
  task_type : string;
  complexity : string;
  dependencies : string list;
  retry_count : int;
  last_error : string option;
}

type frontmatter_update = {
  status : string option;
  retry_count : int option;
  last_error : string option;
}

let ok_or_error f =
  try Ok (f ())
  with
  | Sys_error msg -> Error msg
  | Unix.Unix_error (error, fn, arg) -> Error (Printf.sprintf "%s(%s): %s" fn arg (Unix.error_message error))

let starts_with ~prefix value =
  let prefix_len = String.length prefix in
  String.length value >= prefix_len && String.sub value 0 prefix_len = prefix

let ends_with ~suffix value =
  let suffix_len = String.length suffix in
  let value_len = String.length value in
  value_len >= suffix_len && String.sub value (value_len - suffix_len) suffix_len = suffix

let all_digits value =
  value <> ""
  && String.for_all (fun c -> Char.code c >= Char.code '0' && Char.code c <= Char.code '9') value

let task_index_of_filename file =
  let prefix = "task_" in
  let suffix = ".md" in
  if starts_with ~prefix file && ends_with ~suffix file then
    let start = String.length prefix in
    let len = String.length file - start - String.length suffix in
    let digits = String.sub file start len in
    if all_digits digits then int_of_string_opt digits else None
  else None

let canonical_existing kind path =
  ok_or_error (fun () -> Unix.realpath path)
  |> Result.map_error (fun msg -> Printf.sprintf "invalid Compozy %s path %s: %s" kind path msg)

let is_path_inside ~root path =
  path = root || starts_with ~prefix:(root ^ "/") path

let ensure_inside_root ~compozy_root path =
  match (canonical_existing "root" compozy_root, canonical_existing "task" path) with
  | Ok root, Ok path when is_path_inside ~root path -> Ok path
  | Ok _, Ok _ -> Error (Printf.sprintf "path outside configured Compozy root: %s" path)
  | Error error, _ | _, Error error -> Error error

let first_line_end content =
  match String.index_opt content '\n' with
  | Some index -> Some (index + 1)
  | None -> None

let line_end content start =
  match String.index_from_opt content start '\n' with
  | Some index -> (index, index + 1)
  | None -> (String.length content, String.length content)

let line_without_cr content start stop =
  let stop = if stop > start && content.[stop - 1] = '\r' then stop - 1 else stop in
  String.sub content start (stop - start)

let split_frontmatter ~file content =
  match first_line_end content with
  | None -> Error (Printf.sprintf "missing frontmatter in %s" file)
  | Some first_end ->
      let first = line_without_cr content 0 (first_end - 1) |> Util.trim in
      if first <> "---" then Error (Printf.sprintf "missing frontmatter in %s" file)
      else
        let rec find_close start =
          if start >= String.length content then Error (Printf.sprintf "malformed frontmatter in %s: missing closing ---" file)
          else
            let stop, next = line_end content start in
            let line = line_without_cr content start stop |> Util.trim in
            if line = "---" then
              let frontmatter = String.sub content first_end (start - first_end) in
              let body = String.sub content next (String.length content - next) in
              Ok (frontmatter, body)
            else find_close next
        in
        find_close first_end

let strip_quotes value =
  let value = Util.trim value in
  let len = String.length value in
  if len >= 2 && ((value.[0] = '"' && value.[len - 1] = '"') || (value.[0] = '\'' && value.[len - 1] = '\''))
  then String.sub value 1 (len - 2)
  else value

let split_key_value ~file line =
  match String.index_opt line ':' with
  | None -> Error (Printf.sprintf "malformed frontmatter in %s: expected key:value line: %s" file line)
  | Some index ->
      let key = String.sub line 0 index |> Util.trim in
      let value = String.sub line (index + 1) (String.length line - index - 1) |> Util.trim in
      if key = "" then Error (Printf.sprintf "malformed frontmatter in %s: empty key" file) else Ok (key, value)

let parse_inline_list value =
  let value = Util.trim value in
  let len = String.length value in
  if len >= 2 && value.[0] = '[' && value.[len - 1] = ']' then
    let inner = String.sub value 1 (len - 2) in
    inner |> String.split_on_char ',' |> List.map (fun item -> strip_quotes (Util.trim item))
    |> List.filter (fun item -> item <> "")
  else [ strip_quotes value ]

let parse_frontmatter ~file frontmatter =
  let fields = Hashtbl.create 16 in
  let dependency_block = ref false in
  let dependencies = ref None in
  let remember_dependency item =
    let current = Option.value !dependencies ~default:[] in
    dependencies := Some (current @ [ strip_quotes item ])
  in
  let parse_line raw_line =
    let trimmed = Util.trim raw_line in
    if trimmed = "" || starts_with ~prefix:"#" trimmed then Ok ()
    else if raw_line <> "" && (raw_line.[0] = ' ' || raw_line.[0] = '\t') then
      if !dependency_block && starts_with ~prefix:"- " trimmed then (
        remember_dependency (String.sub trimmed 2 (String.length trimmed - 2) |> Util.trim);
        Ok ())
      else Error (Printf.sprintf "malformed frontmatter in %s: unsupported nested line: %s" file trimmed)
    else
      match split_key_value ~file trimmed with
      | Error _ as error -> error
      | Ok (key, value) ->
          dependency_block := key = "dependencies" && value = "";
          if key = "dependencies" then
            dependencies := Some (if value = "" then [] else parse_inline_list value)
          else Hashtbl.replace fields key (strip_quotes value);
          Ok ()
  in
  let rec parse_lines = function
    | [] -> Ok ()
    | line :: rest -> (
        match parse_line line with Ok () -> parse_lines rest | Error _ as error -> error)
  in
  match parse_lines (Util.split_lines frontmatter) with
  | Error _ as error -> error
  | Ok () ->
      let required key =
        match Hashtbl.find_opt fields key with
        | Some value when value <> "" -> Ok value
        | _ -> Error (Printf.sprintf "missing required frontmatter key %s in %s" key file)
      in
      let retry_count =
        match Hashtbl.find_opt fields "symphony_retry_count" with
        | None | Some "" -> Ok 0
        | Some value -> (
            match int_of_string_opt value with
            | Some count when count >= 0 -> Ok count
            | _ -> Error (Printf.sprintf "invalid symphony_retry_count in %s: %s" file value))
      in
      let last_error =
        match Hashtbl.find_opt fields "symphony_last_error" with Some value when value <> "" -> Some value | _ -> None
      in
      (match (required "status", required "title", required "type", required "complexity", !dependencies, retry_count) with
      | Ok status, Ok title, Ok task_type, Ok complexity, Some dependencies, Ok retry_count ->
          Ok (status, title, task_type, complexity, dependencies, retry_count, last_error)
      | Error error, _, _, _, _, _
      | _, Error error, _, _, _, _
      | _, _, Error error, _, _, _
      | _, _, _, Error error, _, _
      | _, _, _, _, _, Error error ->
          Error error
      | _, _, _, _, None, _ -> Error (Printf.sprintf "missing required frontmatter key dependencies in %s" file))

let parse_task_file ~compozy_root path =
  match ensure_inside_root ~compozy_root path with
  | Error _ as error -> error
  | Ok path -> (
      let file = Filename.basename path in
      match task_index_of_filename file with
      | None -> Error (Printf.sprintf "not a Compozy task file: %s" file)
      | Some index -> (
          match ok_or_error (fun () -> Util.read_file path) with
          | Error msg -> Error (Printf.sprintf "could not read %s: %s" file msg)
          | Ok content -> (
              match split_frontmatter ~file content with
              | Error _ as error -> error
              | Ok (frontmatter, _) -> (
                  match parse_frontmatter ~file frontmatter with
                  | Error _ as error -> error
                  | Ok (status, title, task_type, complexity, dependencies, retry_count, last_error) ->
                      Ok { path; file; index; status; title; task_type; complexity; dependencies; retry_count; last_error }))))

let list_task_paths ~compozy_root prd_dir =
  match ensure_inside_root ~compozy_root prd_dir with
  | Error _ as error -> error
  | Ok prd_dir ->
      if not (Sys.is_directory prd_dir) then Error (Printf.sprintf "Compozy PRD path is not a directory: %s" prd_dir)
      else
        Sys.readdir prd_dir |> Array.to_list
        |> List.filter_map (fun file ->
               match task_index_of_filename file with
               | Some index -> Some (index, file, Filename.concat prd_dir file)
               | None -> None)
        |> List.sort (fun (left_index, left_file, _) (right_index, right_file, _) ->
               match Int.compare left_index right_index with 0 -> String.compare left_file right_file | diff -> diff)
        |> List.map (fun (_, _, path) -> path)
        |> fun paths -> Ok paths

let list_task_files ~compozy_root prd_dir =
  match list_task_paths ~compozy_root prd_dir with
  | Error _ as error -> error
  | Ok paths ->
      let rec parse acc = function
        | [] -> Ok (List.rev acc)
        | path :: rest -> (
            match parse_task_file ~compozy_root path with
            | Ok task -> parse (task :: acc) rest
            | Error _ as error -> error)
      in
      parse [] paths

let yaml_line_value = function
  | `Status status -> status
  | `Retry_count count -> string_of_int count
  | `Last_error error ->
      let buffer = Buffer.create (String.length error + 8) in
      Buffer.add_char buffer '"';
      String.iter
        (function
          | '\\' -> Buffer.add_string buffer "\\\\"
          | '"' -> Buffer.add_string buffer "\\\""
          | '\n' | '\r' -> Buffer.add_char buffer ' '
          | c -> Buffer.add_char buffer c)
        error;
      Buffer.add_char buffer '"';
      Buffer.contents buffer

let replace_or_append_line ~key ~value lines =
  let replacement = key ^ ": " ^ value in
  let replaced = ref false in
  let lines =
    List.map
      (fun line ->
        let trimmed = Util.trim line in
        if (not !replaced) && line = trimmed && starts_with ~prefix:(key ^ ":") trimmed then (
          replaced := true;
          replacement)
        else line)
      lines
  in
  if !replaced then lines else lines @ [ replacement ]

let update_frontmatter_text update frontmatter =
  let lines = Util.split_lines frontmatter in
  let lines =
    match update.status with
    | Some status -> replace_or_append_line ~key:"status" ~value:(yaml_line_value (`Status status)) lines
    | None -> lines
  in
  let lines =
    match update.retry_count with
    | Some retry_count ->
        replace_or_append_line ~key:"symphony_retry_count" ~value:(yaml_line_value (`Retry_count retry_count)) lines
    | None -> lines
  in
  let lines =
    match update.last_error with
    | Some last_error ->
        replace_or_append_line ~key:"symphony_last_error" ~value:(yaml_line_value (`Last_error last_error)) lines
    | None -> lines
  in
  String.concat "\n" lines ^ "\n"

let update_task_frontmatter ~compozy_root path update =
  match ensure_inside_root ~compozy_root path with
  | Error _ as error -> error
  | Ok path -> (
      let file = Filename.basename path in
      match task_index_of_filename file with
      | None -> Error (Printf.sprintf "not a Compozy task file: %s" file)
      | Some _ -> (
          match ok_or_error (fun () -> Util.read_file path) with
          | Error msg -> Error (Printf.sprintf "could not read %s: %s" file msg)
          | Ok content -> (
              match split_frontmatter ~file content with
              | Error _ as error -> error
              | Ok (frontmatter, body) ->
                  let updated = "---\n" ^ update_frontmatter_text update frontmatter ^ "---\n" ^ body in
                  ok_or_error (fun () -> Util.write_file path updated)
                  |> Result.map_error (fun msg -> Printf.sprintf "could not write %s: %s" file msg))))

let update_status ~compozy_root path status =
  update_task_frontmatter ~compozy_root path { status = Some status; retry_count = None; last_error = None }

let update_retry_count ~compozy_root path retry_count =
  if retry_count < 0 then Error (Printf.sprintf "invalid symphony_retry_count for %s: %d" (Filename.basename path) retry_count)
  else update_task_frontmatter ~compozy_root path { status = None; retry_count = Some retry_count; last_error = None }

let update_last_error ~compozy_root path last_error =
  update_task_frontmatter ~compozy_root path { status = None; retry_count = None; last_error = Some last_error }
