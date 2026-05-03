let trim = String.trim

let starts_with ~prefix s =
  let lp = String.length prefix in
  String.length s >= lp && String.sub s 0 lp = prefix

let drop_prefix ~prefix s =
  if starts_with ~prefix s then
    Some (String.sub s (String.length prefix) (String.length s - String.length prefix))
  else
    None

let split_lines s =
  let rec loop acc start i =
    if i = String.length s then
      List.rev (String.sub s start (i - start) :: acc)
    else if s.[i] = '\n' then
      let line =
        let len = if i > start && s.[i - 1] = '\r' then i - start - 1 else i - start in
        String.sub s start len
      in
      loop (line :: acc) (i + 1) (i + 1)
    else
      loop acc start (i + 1)
  in
  if s = "" then [] else loop [] 0 0

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let len = in_channel_length ic in
      really_input_string ic len)

let write_stdout_line s =
  output_string stdout (s ^ "\n");
  flush stdout

let shell_quote s =
  "'" ^ String.concat "'\\''" (String.split_on_char '\'' s) ^ "'"

let getenv_nonempty name =
  match Sys.getenv_opt name with
  | Some v when String.trim v <> "" -> Some v
  | _ -> None

let now_iso8601 () =
  let tm = Unix.gmtime (Unix.time ()) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec

let rec mkdir_p path =
  if path = "" || path = Filename.dirname path then ()
  else if Sys.file_exists path then (
    if not (Sys.is_directory path) then invalid_arg (path ^ " exists and is not a directory"))
  else (
    mkdir_p (Filename.dirname path);
    Unix.mkdir path 0o755)
