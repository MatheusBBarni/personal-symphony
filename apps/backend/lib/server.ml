let response ?(status = "200 OK") ?(content_type = "application/json") body =
  Printf.sprintf "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
    status content_type (String.length body) body

let dirname path =
  let dir = Filename.dirname path in
  if dir = "." then Sys.getcwd () else dir

let frontend_dist_candidates () =
  let executable_dir = dirname Sys.executable_name in
  [
    Sys.getenv_opt "SYMPHONY_FRONTEND_DIST";
    Some (Filename.concat (Sys.getcwd ()) "apps/frontend/dist");
    Some (Filename.concat (Filename.dirname executable_dir) "apps/frontend/dist");
    Some (Filename.concat (Filename.dirname (Filename.dirname executable_dir)) "apps/frontend/dist");
  ]
  |> List.filter_map Fun.id

let frontend_dist_root () = frontend_dist_candidates () |> List.find_opt Sys.file_exists

let strip_query path =
  match String.split_on_char '?' path with
  | path :: _ -> path
  | [] -> path

let has_unsafe_path_segment path =
  path |> String.split_on_char '/' |> List.exists (fun segment -> segment = ".." || segment = "")

let static_file_path root request_path =
  let request_path = strip_query request_path in
  let relative =
    match request_path with
    | "/" -> Some "index.html"
    | path when String.length path > 1 ->
        let relative = String.sub path 1 (String.length path - 1) in
        if has_unsafe_path_segment relative then None else Some relative
    | _ -> None
  in
  Option.map (Filename.concat root) relative

let content_type_for_path path =
  match String.lowercase_ascii (Filename.extension path) with
  | ".html" -> "text/html; charset=utf-8"
  | ".js" -> "text/javascript; charset=utf-8"
  | ".css" -> "text/css; charset=utf-8"
  | ".svg" -> "image/svg+xml"
  | ".json" -> "application/json"
  | ".png" -> "image/png"
  | ".jpg" | ".jpeg" -> "image/jpeg"
  | ".ico" -> "image/x-icon"
  | _ -> "application/octet-stream"

let read_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let length = in_channel_length ic in
      really_input_string ic length)

let serve_static request_path =
  match frontend_dist_root () with
  | None -> None
  | Some root -> (
      match static_file_path root request_path with
      | None -> None
      | Some path when Sys.file_exists path && not (Sys.is_directory path) ->
          Some (response ~content_type:(content_type_for_path path) (read_file path))
      | Some _ -> None)

let missing_frontend_response () =
  response ~status:"503 Service Unavailable"
    (`Assoc
       [
         ("error", `String "frontend_dist_not_found");
         ("message", `String "Build apps/frontend with `pnpm frontend:build` before starting --web.");
         ("searched", `List (List.map (fun path -> `String path) (frontend_dist_candidates ())));
       ]
    |> Yojson.Safe.to_string)

let parse_path request =
  match String.split_on_char ' ' request with _method :: path :: _ -> path | _ -> "/"

let handle_request get_state request =
  match parse_path request with
  | "/" as path -> (
      match serve_static path with Some body -> body | None -> missing_frontend_response ())
  | "/api/v1/state" -> Runtime_state.to_yojson (get_state ()) |> Yojson.Safe.to_string |> response
  | "/api/v1/refresh" ->
      `Assoc
        [
          ("queued", `Bool true);
          ("coalesced", `Bool false);
          ("requested_at", `String (Util.now_iso8601 ()));
          ("operations", `List [ `String "poll"; `String "reconcile" ]);
        ]
      |> Yojson.Safe.to_string |> response ~status:"202 Accepted"
  | path -> (
      match serve_static path with
      | Some body -> body
      | None ->
          response ~status:"404 Not Found"
            (`Assoc [ ("error", `Assoc [ ("code", `String "not_found"); ("message", `String "route not found") ]) ]
            |> Yojson.Safe.to_string))

let colors_enabled () = Sys.getenv_opt "NO_COLOR" = None
let ansi code = if colors_enabled () then "\027[" ^ code ^ "m" else ""
let color code text = ansi code ^ text ^ ansi "0"
let blue text = color "34;1" text
let green text = color "32;1" text
let cyan text = color "36;1" text
let dim text = color "2" text

let render_server_ready ~port =
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "server") (green "ready") (dim "listening")
    (cyan (Printf.sprintf "0.0.0.0:%d" port))
    (dim (Printf.sprintf "event=startup outcome=completed server_host=0.0.0.0 server_port=%d" port))

let serve ~port ~get_state =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.set_close_on_exec socket;
  Unix.setsockopt socket Unix.SO_REUSEADDR true;
  Unix.bind socket (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen socket 16;
  let actual_port =
    match Unix.getsockname socket with Unix.ADDR_INET (_, port) -> port | _ -> port
  in
  render_server_ready ~port:actual_port;
  while true do
    let client, _ = Unix.accept socket in
    Unix.set_close_on_exec client;
    let ic = Unix.in_channel_of_descr client in
    let oc = Unix.out_channel_of_descr client in
    Fun.protect
      ~finally:(fun () -> close_in_noerr ic; close_out_noerr oc)
      (fun () ->
        let request = try input_line ic with End_of_file -> "" in
        let body = handle_request get_state request in
        output_string oc body;
        flush oc)
  done
