type request = { request_line : string; path : string; headers : (string * string) list }

type live_client = {
  oc : out_channel;
  write_mutex : Mutex.t;
}

type live_state = {
  get_state : unit -> Runtime_state.t;
  mutable clients : live_client list;
  mutex : Mutex.t;
}

type dashboard_identity = {
  workspace_root : string;
  runtime_home : string;
  mode : string;
  auth_required : bool;
  server_host : string;
  server_port : int;
}

let create_live_state ~get_state = { get_state; clients = []; mutex = Mutex.create () }

let make_dashboard_identity ~workspace_root ~runtime_home ~mode ~auth_required ~server_host ~server_port =
  { workspace_root; runtime_home; mode; auth_required; server_host; server_port }

let dashboard_identity_to_yojson identity =
  `Assoc
    [
      ("workspace_root", `String identity.workspace_root);
      ("runtime_home", `String identity.runtime_home);
      ("mode", `String identity.mode);
      ("auth_required", `Bool identity.auth_required);
      ("server_host", `String identity.server_host);
      ("server_port", `Int identity.server_port);
    ]

let response ?(status = "200 OK") ?(content_type = "application/json") body =
  Printf.sprintf "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
    status content_type (String.length body) body

let unauthorized_response () =
  response ~status:"401 Unauthorized"
    (`Assoc
       [
         ("error", `Assoc [ ("code", `String "unauthorized"); ("message", `String "dashboard auth token required") ]);
       ]
    |> Yojson.Safe.to_string)

let websocket_response accept_key =
  Printf.sprintf
    "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n"
    accept_key

let default_host = "127.0.0.1"

let normalize_host host =
  match String.trim host |> String.lowercase_ascii with "" | "localhost" -> default_host | value -> value

let inet_addr_of_host host =
  let host = normalize_host host in
  if String.contains host ':' then invalid_arg "server host must be an IPv4 bind address";
  try Unix.inet_addr_of_string host with Unix.Unix_error _ | Failure _ -> invalid_arg "server host must be an IPv4 bind address"

let host_requires_auth host =
  let host = Unix.string_of_inet_addr (inet_addr_of_host host) in
  not (host = "127.0.0.1" || (String.length host >= 4 && String.sub host 0 4 = "127."))

let hex bytes =
  let alphabet = "0123456789abcdef" in
  let len = Bytes.length bytes in
  let out = Bytes.create (len * 2) in
  for i = 0 to len - 1 do
    let value = Char.code (Bytes.get bytes i) in
    Bytes.set out (i * 2) alphabet.[value lsr 4];
    Bytes.set out ((i * 2) + 1) alphabet.[value land 0x0f]
  done;
  Bytes.unsafe_to_string out

let random_bytes_from_urandom length =
  let fd = Unix.openfile "/dev/urandom" [ Unix.O_RDONLY ] 0 in
  Unix.set_close_on_exec fd;
  Fun.protect
    ~finally:(fun () -> Unix.close fd)
    (fun () ->
      let bytes = Bytes.create length in
      let rec loop offset =
        if offset < length then
          let read = Unix.read fd bytes offset (length - offset) in
          if read = 0 then failwith "short read from /dev/urandom" else loop (offset + read)
      in
      loop 0;
      bytes)

let generate_auth_token () = random_bytes_from_urandom 32 |> hex

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

let parse_path request_line =
  match String.split_on_char ' ' request_line with _method :: path :: _ -> strip_query path | _ -> "/"

let parse_target request_line =
  match String.split_on_char ' ' request_line with _method :: target :: _ -> target | _ -> "/"

let parse_header line =
  match String.index_opt line ':' with
  | None -> None
  | Some index ->
      let name = String.sub line 0 index |> String.lowercase_ascii |> String.trim in
      let value = String.sub line (index + 1) (String.length line - index - 1) |> String.trim in
      Some (name, value)

let read_request ic =
  let request_line = try input_line ic with End_of_file -> "" in
  let rec loop acc =
    match input_line ic with
    | "" | "\r" -> List.rev acc
    | line ->
        let line =
          if String.length line > 0 && line.[String.length line - 1] = '\r' then
            String.sub line 0 (String.length line - 1)
          else line
        in
        loop (match parse_header line with Some header -> header :: acc | None -> acc)
    | exception End_of_file -> List.rev acc
  in
  { request_line; path = parse_path request_line; headers = loop [] }

let header request name = List.assoc_opt (String.lowercase_ascii name) request.headers

let query request =
  let target = parse_target request.request_line in
  match String.index_opt target '?' with
  | None -> []
  | Some index ->
      String.sub target (index + 1) (String.length target - index - 1)
      |> String.split_on_char '&'
      |> List.filter_map (fun pair ->
             match String.split_on_char '=' pair with
             | [ key; value ] -> Some (key, value)
             | [ key ] -> Some (key, "")
             | key :: value_parts -> Some (key, String.concat "=" value_parts)
             | [] -> None)

let constant_time_equal a b =
  let len_a = String.length a in
  let len_b = String.length b in
  let max_len = max len_a len_b in
  let diff = ref (len_a lxor len_b) in
  for i = 0 to max_len - 1 do
    let char_a = if i < len_a then Char.code a.[i] else 0 in
    let char_b = if i < len_b then Char.code b.[i] else 0 in
    diff := !diff lor (char_a lxor char_b)
  done;
  !diff = 0

let bearer_token value =
  let prefix = "Bearer " in
  if String.length value > String.length prefix
     && String.lowercase_ascii (String.sub value 0 (String.length prefix)) = String.lowercase_ascii prefix
  then
    Some (String.sub value (String.length prefix) (String.length value - String.length prefix))
  else None

let request_auth_token request =
  match header request "x-symphony-auth" with
  | Some token -> Some token
  | None -> (
      match Option.bind (header request "authorization") bearer_token with
      | Some token -> Some token
      | None -> List.assoc_opt "symphony_auth" (query request))

let authenticated ?auth_token request =
  match auth_token with
  | None -> true
  | Some token -> (
      match request_auth_token request with Some candidate -> constant_time_equal token candidate | None -> false)

let has_token header_value token =
  header_value |> String.split_on_char ','
  |> List.exists (fun value -> String.lowercase_ascii (String.trim value) = token)

let is_websocket_upgrade request =
  match (header request "upgrade", header request "connection", header request "sec-websocket-key") with
  | Some upgrade, Some connection, Some _ ->
      String.lowercase_ascii upgrade = "websocket" && has_token connection "upgrade"
  | _ -> false

let int32_logor_list values = List.fold_left Int32.logor 0l values

let sha1 message =
  let left_rotate value bits =
    Int32.logor (Int32.shift_left value bits) (Int32.shift_right_logical value (32 - bits))
  in
  let original_len = String.length message in
  let bit_len = Int64.mul (Int64.of_int original_len) 8L in
  let padding_len = (56 - ((original_len + 1) mod 64) + 64) mod 64 in
  let total_len = original_len + 1 + padding_len + 8 in
  let bytes = Bytes.make total_len '\000' in
  Bytes.blit_string message 0 bytes 0 original_len;
  Bytes.set bytes original_len '\128';
  for i = 0 to 7 do
    let shift = (7 - i) * 8 in
    Bytes.set bytes (total_len - 8 + i)
      (Char.chr (Int64.(to_int (logand (shift_right_logical bit_len shift) 0xffL))))
  done;
  let h0 = ref 0x67452301l in
  let h1 = ref 0xefcdab89l in
  let h2 = ref 0x98badcfel in
  let h3 = ref 0x10325476l in
  let h4 = ref 0xc3d2e1f0l in
  let w = Array.make 80 0l in
  for chunk = 0 to (total_len / 64) - 1 do
    let offset = chunk * 64 in
    for i = 0 to 15 do
      let j = offset + (i * 4) in
      w.(i) <-
        int32_logor_list
          [
            Int32.shift_left (Int32.of_int (Char.code (Bytes.get bytes j))) 24;
            Int32.shift_left (Int32.of_int (Char.code (Bytes.get bytes (j + 1)))) 16;
            Int32.shift_left (Int32.of_int (Char.code (Bytes.get bytes (j + 2)))) 8;
            Int32.of_int (Char.code (Bytes.get bytes (j + 3)));
          ]
    done;
    for i = 16 to 79 do
      w.(i) <- left_rotate (Int32.logxor (Int32.logxor w.(i - 3) w.(i - 8)) (Int32.logxor w.(i - 14) w.(i - 16))) 1
    done;
    let a = ref !h0 and b = ref !h1 and c = ref !h2 and d = ref !h3 and e = ref !h4 in
    for i = 0 to 79 do
      let f, k =
        if i < 20 then
          (Int32.logor (Int32.logand !b !c) (Int32.logand (Int32.lognot !b) !d), 0x5a827999l)
        else if i < 40 then (Int32.logxor (Int32.logxor !b !c) !d, 0x6ed9eba1l)
        else if i < 60 then
          ( Int32.logor (Int32.logor (Int32.logand !b !c) (Int32.logand !b !d)) (Int32.logand !c !d),
            0x8f1bbcdcl )
        else (Int32.logxor (Int32.logxor !b !c) !d, 0xca62c1d6l)
      in
      let temp = Int32.add (Int32.add (Int32.add (Int32.add (left_rotate !a 5) f) !e) k) w.(i) in
      e := !d;
      d := !c;
      c := left_rotate !b 30;
      b := !a;
      a := temp
    done;
    h0 := Int32.add !h0 !a;
    h1 := Int32.add !h1 !b;
    h2 := Int32.add !h2 !c;
    h3 := Int32.add !h3 !d;
    h4 := Int32.add !h4 !e
  done;
  let digest = Bytes.create 20 in
  [ !h0; !h1; !h2; !h3; !h4 ]
  |> List.iteri (fun i word ->
         for b = 0 to 3 do
           Bytes.set digest ((i * 4) + b)
             (Char.chr (Int32.(to_int (logand (shift_right_logical word ((3 - b) * 8)) 0xffl))))
         done);
  Bytes.unsafe_to_string digest

let base64 input =
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" in
  let len = String.length input in
  let out = Buffer.create (((len + 2) / 3) * 4) in
  let byte i = Char.code input.[i] in
  let rec loop i =
    if i < len then (
      let b0 = byte i in
      let b1 = if i + 1 < len then byte (i + 1) else 0 in
      let b2 = if i + 2 < len then byte (i + 2) else 0 in
      let triple = (b0 lsl 16) lor (b1 lsl 8) lor b2 in
      Buffer.add_char out alphabet.[(triple lsr 18) land 0x3f];
      Buffer.add_char out alphabet.[(triple lsr 12) land 0x3f];
      Buffer.add_char out (if i + 1 < len then alphabet.[(triple lsr 6) land 0x3f] else '=');
      Buffer.add_char out (if i + 2 < len then alphabet.[triple land 0x3f] else '=');
      loop (i + 3))
  in
  loop 0;
  Buffer.contents out

let websocket_accept key = base64 (sha1 (key ^ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))

let websocket_text_frame text =
  let len = String.length text in
  let buffer = Buffer.create (len + 10) in
  Buffer.add_char buffer (Char.chr 0x81);
  if len < 126 then Buffer.add_char buffer (Char.chr len)
  else if len <= 0xffff then (
    Buffer.add_char buffer (Char.chr 126);
    Buffer.add_char buffer (Char.chr ((len lsr 8) land 0xff));
    Buffer.add_char buffer (Char.chr (len land 0xff)))
  else (
    Buffer.add_char buffer (Char.chr 127);
    for _ = 7 downto 4 do
      Buffer.add_char buffer (Char.chr 0)
    done;
    Buffer.add_char buffer (Char.chr ((len lsr 24) land 0xff));
    Buffer.add_char buffer (Char.chr ((len lsr 16) land 0xff));
    Buffer.add_char buffer (Char.chr ((len lsr 8) land 0xff));
    Buffer.add_char buffer (Char.chr (len land 0xff)));
  Buffer.add_string buffer text;
  Buffer.contents buffer

let snapshot_payload live = Runtime_state.to_yojson (live.get_state ()) |> Yojson.Safe.to_string

let remove_client live client =
  Mutex.lock live.mutex;
  live.clients <- List.filter (fun candidate -> candidate != client) live.clients;
  Mutex.unlock live.mutex

let send_frame live client payload =
  Mutex.lock client.write_mutex;
  try
    output_string client.oc (websocket_text_frame payload);
    flush client.oc;
    Mutex.unlock client.write_mutex;
    true
  with Sys_error _ | Unix.Unix_error _ ->
    Mutex.unlock client.write_mutex;
    remove_client live client;
    false

let broadcast_live_state live =
  let payload = snapshot_payload live in
  ignore
    (Thread.create
       (fun () ->
         Mutex.lock live.mutex;
         let clients = live.clients in
         Mutex.unlock live.mutex;
         List.iter (fun oc -> ignore (send_frame live oc payload)) clients)
       ())

let make_client oc = { oc; write_mutex = Mutex.create () }

let register_client live client =
  Mutex.lock live.mutex;
  live.clients <- client :: live.clients;
  Mutex.unlock live.mutex;
  client

let drain_websocket fd =
  let buffer = Bytes.create 1024 in
  let rec loop () =
    match Unix.read fd buffer 0 1024 with
    | 0 -> ()
    | _ -> loop ()
    | exception Unix.Unix_error _ -> ()
  in
  loop ()

let handle_request ?auth_token ?identity get_state request =
  match request.path with
  | ("/api/v1/state" | "/api/v1/refresh" | "/api/v1/dashboard/identity") when not (authenticated ?auth_token request) ->
      unauthorized_response ()
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
  | "/api/v1/dashboard/identity" -> (
      match identity with
      | Some identity -> dashboard_identity_to_yojson identity |> Yojson.Safe.to_string |> response
      | None ->
          response ~status:"404 Not Found"
            (`Assoc
               [
                 ( "error",
                   `Assoc [ ("code", `String "not_found"); ("message", `String "dashboard identity unavailable") ] );
               ]
            |> Yojson.Safe.to_string))
  | path -> (
      match serve_static path with
      | Some body -> body
      | None ->
          response ~status:"404 Not Found"
            (`Assoc [ ("error", `Assoc [ ("code", `String "not_found"); ("message", `String "route not found") ]) ]
            |> Yojson.Safe.to_string))

let handle_websocket ?auth_token live fd oc request =
  if not (authenticated ?auth_token request) then (
    output_string oc (unauthorized_response ());
    flush oc)
  else match header request "sec-websocket-key" with
  | None ->
      output_string oc (response ~status:"400 Bad Request" (`Assoc [ ("error", `String "missing websocket key") ] |> Yojson.Safe.to_string));
      flush oc
  | Some key ->
      output_string oc (websocket_response (websocket_accept key));
      flush oc;
      let client = make_client oc in
      if send_frame live client (snapshot_payload live) then (
        ignore (register_client live client);
        drain_websocket fd;
        remove_client live client)

let colors_enabled () = Sys.getenv_opt "NO_COLOR" = None
let ansi code = if colors_enabled () then "\027[" ^ code ^ "m" else ""
let color code text = ansi code ^ text ^ ansi "0"
let blue text = color "34;1" text
let green text = color "32;1" text
let cyan text = color "36;1" text
let dim text = color "2" text

let render_server_ready ~host ~port =
  Printf.eprintf "%s %s %s %s %s\n%!" (blue "server") (green "ready") (dim "listening")
    (cyan (Printf.sprintf "%s:%d" host port))
    (dim (Printf.sprintf "event=startup outcome=completed server_host=%s server_port=%d" host port))

let serve ?live ?auth_token ?identity ?on_ready ?(host = default_host) ~port ~get_state () =
  let host = normalize_host host in
  if host_requires_auth host && auth_token = None then invalid_arg "non-loopback dashboard host requires an auth token";
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.set_close_on_exec socket;
  Unix.setsockopt socket Unix.SO_REUSEADDR true;
  Unix.bind socket (Unix.ADDR_INET (inet_addr_of_host host, port));
  Unix.listen socket 16;
  let actual_port =
    match Unix.getsockname socket with Unix.ADDR_INET (_, port) -> port | _ -> port
  in
  render_server_ready ~host ~port:actual_port;
  Option.iter (fun callback -> callback actual_port) on_ready;
  while true do
    let client, _ = Unix.accept socket in
    Unix.set_close_on_exec client;
    ignore
      (Thread.create
         (fun client ->
           let ic = Unix.in_channel_of_descr client in
           let oc = Unix.out_channel_of_descr client in
           Fun.protect
             ~finally:(fun () -> close_in_noerr ic; close_out_noerr oc)
             (fun () ->
               let request = read_request ic in
               match live with
               | Some live when request.path = "/api/v1/state/live" && is_websocket_upgrade request ->
                   handle_websocket ?auth_token live client oc request
               | _ ->
                   let body = handle_request ?auth_token ?identity get_state request in
                   output_string oc body;
                   flush oc))
         client)
  done
