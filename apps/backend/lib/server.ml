let response ?(status = "200 OK") ?(content_type = "application/json") body =
  Printf.sprintf "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
    status content_type (String.length body) body

let html =
  "<!doctype html><html><head><title>Personal Symphony</title></head><body><h1>Personal Symphony</h1><p>Use /api/v1/state for JSON state.</p></body></html>"

let parse_path request =
  match String.split_on_char ' ' request with _method :: path :: _ -> path | _ -> "/"

let handle_request get_state request =
  match parse_path request with
  | "/" -> response ~content_type:"text/html" html
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
  | _ ->
      response ~status:"404 Not Found"
        (`Assoc [ ("error", `Assoc [ ("code", `String "not_found"); ("message", `String "route not found") ]) ]
        |> Yojson.Safe.to_string)

let serve ~port ~get_state =
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt socket Unix.SO_REUSEADDR true;
  Unix.bind socket (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
  Unix.listen socket 16;
  let actual_port =
    match Unix.getsockname socket with Unix.ADDR_INET (_, port) -> port | _ -> port
  in
  Printf.eprintf "event=startup outcome=completed server_port=%d\n%!" actual_port;
  while true do
    let client, _ = Unix.accept socket in
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
