type t = { path : string; workspace_key : string; created_now : bool }

exception Workspace_error of string

let sanitize identifier =
  String.map
    (function
      | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '.' | '_' | '-' as c -> c
      | _ -> '_')
    identifier

let is_inside ~root ~path =
  let root = Unix.realpath root in
  let path = Unix.realpath path in
  path = root || Util.starts_with ~prefix:(root ^ Filename.dir_sep) path

let create_for_issue ~root identifier =
  Util.mkdir_p root;
  let workspace_key = sanitize identifier in
  let path = Filename.concat root workspace_key in
  let created_now =
    if Sys.file_exists path then (
      if not (Sys.is_directory path) then raise (Workspace_error (path ^ " exists and is not a directory"));
      false)
    else (
      Unix.mkdir path 0o755;
      true)
  in
  if not (is_inside ~root ~path) then raise (Workspace_error "workspace escaped configured root");
  { path = Unix.realpath path; workspace_key; created_now }
