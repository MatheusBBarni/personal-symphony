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

type task_step = { file : string; title : string; status : string; retry_count : int; index : int }

type task_counts = {
  total : int;
  pending : int;
  in_progress : int;
  completed : int;
  failed : int;
  skipped : int;
}

type prd_run = {
  id : string;
  slug : string;
  path : string;
  title : string;
  state : string;
  current_step : task_step option;
  steps : task_step list;
  counts : task_counts;
  not_runnable_reason : string option;
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

let id_of_slug slug = "compozy:" ^ slug

let title_of_slug slug = "Compozy PRD run: " ^ slug

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
        let entries =
          Sys.readdir prd_dir |> Array.to_list
        |> List.filter_map (fun file ->
               match task_index_of_filename file with
               | Some index -> Some (index, file, Filename.concat prd_dir file)
               | None -> None)
        |> List.sort (fun (left_index, left_file, _) (right_index, right_file, _) ->
               match Int.compare left_index right_index with 0 -> String.compare left_file right_file | diff -> diff)
        in
        let rec duplicate_index = function
          | (left_index, left_file, _) :: (right_index, right_file, _) :: _ when left_index = right_index ->
              Some (left_index, left_file, right_file)
          | _ :: rest -> duplicate_index rest
          | [] -> None
        in
        match duplicate_index entries with
        | Some (index, left_file, right_file) ->
            Error
              (Printf.sprintf "duplicate Compozy task index %d in %s: %s and %s" index prd_dir left_file right_file)
        | None -> Ok (List.map (fun (_, _, path) -> path) entries)

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

let task_step_of_task_file (task : task_file) =
  { file = task.file; title = task.title; status = task.status; retry_count = task.retry_count; index = task.index }

let empty_counts = { total = 0; pending = 0; in_progress = 0; completed = 0; failed = 0; skipped = 0 }

let counts_of_steps steps =
  List.fold_left
    (fun counts (step : task_step) ->
      match String.lowercase_ascii step.status with
      | "pending" -> { counts with total = counts.total + 1; pending = counts.pending + 1 }
      | "in_progress" -> { counts with total = counts.total + 1; in_progress = counts.in_progress + 1 }
      | "completed" -> { counts with total = counts.total + 1; completed = counts.completed + 1 }
      | "failed" -> { counts with total = counts.total + 1; failed = counts.failed + 1 }
      | "skipped" -> { counts with total = counts.total + 1; skipped = counts.skipped + 1 }
      | _ -> { counts with total = counts.total + 1 })
    empty_counts steps

let current_step_of_steps steps =
  match List.find_opt (fun (step : task_step) -> String.lowercase_ascii step.status = "in_progress") steps with
  | Some _ as step -> step
  | None -> List.find_opt (fun (step : task_step) -> String.lowercase_ascii step.status = "pending") steps

let state_of_steps (counts : task_counts) (current_step : task_step option) =
  match current_step with
  | Some step -> step.status
  | None when counts.total = 0 -> "not_runnable"
  | None when counts.total = counts.completed -> "completed"
  | None -> "not_runnable"

let prd_run_of_directory ~compozy_root prd_dir =
  match ensure_inside_root ~compozy_root prd_dir with
  | Error _ as error -> error
  | Ok prd_dir ->
      let slug = Filename.basename prd_dir in
      let not_runnable reason =
        Ok
          {
            id = id_of_slug slug;
            slug;
            path = prd_dir;
            title = title_of_slug slug;
            state = "not_runnable";
            current_step = None;
            steps = [];
            counts = empty_counts;
            not_runnable_reason = Some reason;
          }
      in
      if not (Sys.is_directory prd_dir) then Error (Printf.sprintf "Compozy PRD path is not a directory: %s" prd_dir)
      else
        match list_task_files ~compozy_root prd_dir with
        | Error error -> not_runnable error
        | Ok tasks ->
            let steps = List.map task_step_of_task_file tasks in
            let counts = counts_of_steps steps in
            let current_step = current_step_of_steps steps in
            let state = state_of_steps counts current_step in
            let not_runnable_reason =
              if counts.total = 0 then Some (Printf.sprintf "no Compozy task files found in %s" prd_dir)
              else if state = "not_runnable" then Some "no pending or in-progress Compozy task step"
              else None
            in
            Ok
              {
                id = id_of_slug slug;
                slug;
                path = prd_dir;
                title = title_of_slug slug;
                state;
                current_step;
                steps;
                counts;
                not_runnable_reason;
              }

let list_prd_run_paths ~compozy_root =
  if not (Sys.file_exists compozy_root) then Ok []
  else if not (Sys.is_directory compozy_root) then Error (Printf.sprintf "Compozy root is not a directory: %s" compozy_root)
  else
    Sys.readdir compozy_root |> Array.to_list
    |> List.filter_map (fun name ->
           let path = Filename.concat compozy_root name in
           if Sys.file_exists path && Sys.is_directory path then Some (name, path) else None)
    |> List.sort (fun (left_name, _) (right_name, _) -> String.compare left_name right_name)
    |> List.map snd |> fun paths -> Ok paths

let discover_prd_runs ~compozy_root =
  match canonical_existing "root" compozy_root with
  | Error _ when not (Sys.file_exists compozy_root) -> Ok []
  | Error _ as error -> error
  | Ok compozy_root -> (
      match list_prd_run_paths ~compozy_root with
      | Error _ as error -> error
      | Ok paths ->
          let rec build acc = function
            | [] -> Ok (List.rev acc)
            | path :: rest -> (
                match prd_run_of_directory ~compozy_root path with
                | Ok run -> build (run :: acc) rest
                | Error _ as error -> error)
          in
          build [] paths)

let fetch_prd_runs (config : Config.t) =
  match discover_prd_runs ~compozy_root:config.tracker.compozy_root with Ok runs -> runs | Error _ -> []

let issue_of_prd_run (run : prd_run) =
  Issue.empty ~id:run.id ~identifier:run.id ~title:run.title ~state:run.state

let ensure_trailing_newline content =
  if content = "" || content.[String.length content - 1] <> '\n' then content ^ "\n" else content

let prompt_section title content =
  Printf.sprintf "## %s\n\n%s" title (ensure_trailing_newline content)

let prompt_optional_file run file title =
  let path = Filename.concat run.path file in
  if not (Sys.file_exists path) then Ok None
  else
    ok_or_error (fun () -> Util.read_file path)
    |> Result.map (fun content -> Some (prompt_section title content))
    |> Result.map_error (fun msg -> Printf.sprintf "could not read Compozy prompt context %s for %s: %s" file run.id msg)

let current_prompt (run : prd_run) =
  match run.current_step with
  | None ->
      let reason =
        match run.not_runnable_reason with
        | Some reason when Util.trim reason <> "" -> ": " ^ reason
        | _ when run.state = "completed" -> ": PRD run is completed"
        | _ when Util.trim run.state <> "" -> ": PRD run state is " ^ run.state
        | _ -> ""
      in
      Error (Printf.sprintf "no runnable Compozy task step for %s%s" run.id reason)
  | Some step -> (
      let task_path = Filename.concat run.path step.file in
      match ok_or_error (fun () -> Util.read_file task_path) with
      | Error msg -> Error (Printf.sprintf "could not read Compozy task step %s for %s: %s" step.file run.id msg)
      | Ok task_content -> (
          match prompt_optional_file run "_prd.md" "PRD (`_prd.md`)" with
          | Error _ as error -> error
          | Ok prd_section -> (
              match prompt_optional_file run "_techspec.md" "TechSpec (`_techspec.md`)" with
              | Error _ as error -> error
              | Ok techspec_section ->
                  let header =
                    Printf.sprintf
                      "# Compozy Task Step\n\nRun: %s\nPRD directory: %s\nCurrent task file: %s\nCurrent task title: %s\n"
                      run.id run.slug step.file step.title
                  in
                  let sections =
                    [
                      header;
                      prompt_section (Printf.sprintf "Current Task (`%s`)" step.file) task_content;
                    ]
                    @ List.filter_map Fun.id [ prd_section; techspec_section ]
                  in
                  Ok (String.concat "\n" sections))))

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
