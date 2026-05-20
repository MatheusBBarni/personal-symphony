type dashboard_result =
  | Started(string)
  | Reused(string)
  | Conflict(string)
  | Failed(string);

type identity_decode =
  | Decoded(Server.dashboard_identity)
  | Decode_error(string);

type probe_result =
  | No_listener
  | Probe_identity(Server.dashboard_identity)
  | Probe_conflict(string);

type start_signal = {
  mutex: Mutex.t,
  condition: Condition.t,
  mutable result: option(dashboard_result),
};

let web_dashboard_mode = "web_dashboard";
let terminal_console_mode = "terminal_console";

let auth_required = auth_token =>
  switch (auth_token) {
  | Some(_) => true
  | None => false
  };

let dashboard_url = (~host, ~port) => Printf.sprintf("http://%s:%d/", host, port);

let make_identity =
    (~workspace_root, ~runtime_home, ~mode, ~auth_token, ~host, ~port) =>
  Server.make_dashboard_identity(
    ~workspace_root,
    ~runtime_home,
    ~mode,
    ~auth_required=auth_required(auth_token),
    ~server_host=Server.normalize_host(host),
    ~server_port=port,
  );

let identity_of_json = json =>
  try({
    let open Yojson.Safe.Util;
    Decoded(
      Server.make_dashboard_identity(
        ~workspace_root=json |> member("workspace_root") |> to_string,
        ~runtime_home=json |> member("runtime_home") |> to_string,
        ~mode=json |> member("mode") |> to_string,
        ~auth_required=json |> member("auth_required") |> to_bool,
        ~server_host=json |> member("server_host") |> to_string,
        ~server_port=json |> member("server_port") |> to_int,
      ),
    );
  }) {
  | Yojson.Safe.Util.Type_error(msg, _) =>
    Decode_error("malformed dashboard identity: " ++ msg)
  };

let identity_of_string = body =>
  try(Yojson.Safe.from_string(body) |> identity_of_json) {
  | Yojson.Json_error(msg) => Decode_error("malformed dashboard identity JSON: " ++ msg)
  };

let conflict = message => Conflict(message);

let evaluate_identity = (~expected, ~actual, ~url) =>
  if (actual.Server.workspace_root != expected.Server.workspace_root) {
    conflict("Port is occupied by a Web Dashboard for a different Workspace Repository.");
  } else if (actual.Server.runtime_home != expected.Server.runtime_home) {
    conflict("Port is occupied by a Web Dashboard for a different Runtime Home.");
  } else if (actual.Server.mode != expected.Server.mode) {
    conflict("Port is occupied by a Web Dashboard started in a different mode.");
  } else if (actual.Server.auth_required != expected.Server.auth_required) {
    conflict("Port is occupied by a Web Dashboard with different auth requirements.");
  } else if (actual.Server.server_port != expected.Server.server_port) {
    conflict("Port is occupied by a Web Dashboard reporting a different server port.");
  } else {
    Reused(url);
  };

let start_or_reuse_from_probe = (~expected, ~url, ~probe_result, ~start) =>
  switch (probe_result) {
  | Probe_identity(actual) => evaluate_identity(~expected, ~actual, ~url)
  | Probe_conflict(reason) => Conflict(reason)
  | No_listener => start()
  };

let response_body = response =>
  switch (String.index_opt(response, '\r')) {
  | None => response
  | Some(_) =>
    let marker = "\r\n\r\n";
    let marker_len = String.length(marker);
    let rec find = index =>
      if (index + marker_len > String.length(response)) {
        None;
      } else if (String.sub(response, index, marker_len) == marker) {
        Some(index + marker_len);
      } else {
        find(index + 1);
      };
    switch (find(0)) {
    | Some(index) => String.sub(response, index, String.length(response) - index)
    | None => response
    };
  };

let response_status = response =>
  switch (String.index_opt(response, '\r')) {
  | Some(index) => String.sub(response, 0, index)
  | None =>
    switch (String.index_opt(response, '\n')) {
    | Some(index) => String.sub(response, 0, index)
    | None => response
    }
  };

let read_response = fd => {
  let buffer = Bytes.create(4096);
  let output = Buffer.create(4096);
  let rec loop = total =>
    if (total > 65536) {
      Error("dashboard identity response is too large");
    } else {
      switch (Unix.select([fd], [], [], 1.0)) {
      | ([], _, _) => Error("dashboard identity endpoint timed out")
      | _ =>
        switch (Unix.read(fd, buffer, 0, Bytes.length(buffer))) {
        | 0 => Ok(Buffer.contents(output))
        | read =>
          Buffer.add_subbytes(output, buffer, 0, read);
          loop(total + read);
        }
      };
    };
  loop(0);
};

let close_fd = fd =>
  try(Unix.close(fd)) {
  | Unix.Unix_error(_) => ()
  };

let probe_identity = (~host, ~port, ~auth_token) => {
  let socket = Unix.socket(Unix.PF_INET, Unix.SOCK_STREAM, 0);
  Unix.set_close_on_exec(socket);
  Fun.protect(
    ~finally=() => close_fd(socket),
    () =>
      try({
        Unix.connect(socket, Unix.ADDR_INET(Server.inet_addr_of_host(host), port));
        let auth_header =
          switch (auth_token) {
          | None => ""
          | Some(token) => "Authorization: Bearer " ++ token ++ "\r\n"
          };
        let request =
          Printf.sprintf(
            "GET /api/v1/dashboard/identity HTTP/1.1\r\nHost: %s:%d\r\n%sConnection: close\r\n\r\n",
            Server.normalize_host(host),
            port,
            auth_header,
          );
        ignore(Unix.write_substring(socket, request, 0, String.length(request)));
        switch (read_response(socket)) {
        | Error(reason) => Probe_conflict(reason)
        | Ok(response) =>
          let status = response_status(response);
          if (String.starts_with(~prefix="HTTP/1.1 200", status)
              || String.starts_with(~prefix="HTTP/1.0 200", status)) {
            switch (identity_of_string(response_body(response))) {
            | Decoded(identity) => Probe_identity(identity)
            | Decode_error(reason) => Probe_conflict(reason)
            };
          } else if (String.starts_with(~prefix="HTTP/1.1 401", status)
                     || String.starts_with(~prefix="HTTP/1.0 401", status)) {
            Probe_conflict("dashboard identity requires different auth credentials");
          } else {
            Probe_conflict("dashboard identity endpoint is unavailable");
          };
        };
      }) {
      | Unix.Unix_error(Unix.ECONNREFUSED, _, _)
      | Unix.Unix_error(Unix.ENOENT, _, _)
      | Unix.Unix_error(Unix.ENOTCONN, _, _) =>
        No_listener
      | Unix.Unix_error(error, fn, _) =>
        Probe_conflict(Printf.sprintf("%s: %s", fn, Unix.error_message(error)))
      | exn => Probe_conflict(Printexc.to_string(exn))
      },
  );
};

let secret_free_exception = exn =>
  switch (exn) {
  | Unix.Unix_error(error, fn, _) =>
    Printf.sprintf("%s: %s", fn, Unix.error_message(error))
  | Invalid_argument(message) => message
  | Failure(message) => message
  | _ => Printexc.to_string(exn)
  };

let render_service_event = (~outcome, ~host, ~port, ~workspace_root, ~runtime_home, ~auth_token) =>
  Printf.eprintf(
    "event=dashboard_service outcome=%s server_host=%s server_port=%d workspace_root=%s runtime_home=%s auth_required=%s\n%!",
    outcome,
    Server.normalize_host(host),
    port,
    workspace_root,
    runtime_home,
    auth_required(auth_token) ? "true" : "false",
  );

let publish_signal = (signal, result) => {
  Mutex.lock(signal.mutex);
  signal.result = Some(result);
  Condition.broadcast(signal.condition);
  Mutex.unlock(signal.mutex);
};

let wait_signal = signal => {
  Mutex.lock(signal.mutex);
  while (signal.result == None) {
    Condition.wait(signal.condition, signal.mutex);
  };
  let result =
    switch (signal.result) {
    | Some(result) => result
    | None => Failed("dashboard service did not report startup status")
    };
  Mutex.unlock(signal.mutex);
  result;
};

let serve_foreground =
    (~workspace_root, ~runtime_home, ~host, ~port, ~mode, ~auth_token, ~live, ~get_state, ()) => {
  let identity = make_identity(~workspace_root, ~runtime_home, ~mode, ~auth_token, ~host, ~port);
  switch (auth_token) {
  | None => Server.serve(~identity, ~live, ~host, ~port, ~get_state, ())
  | Some(token) => Server.serve(~identity, ~auth_token=token, ~live, ~host, ~port, ~get_state, ())
  };
};

let start_background_without_probe =
    (~workspace_root, ~runtime_home, ~host, ~port, ~mode, ~auth_token, ~live, ~get_state, ()) => {
  let signal = {mutex: Mutex.create(), condition: Condition.create(), result: None};
  let identity = make_identity(~workspace_root, ~runtime_home, ~mode, ~auth_token, ~host, ~port);
  ignore(
    Thread.create(
      () =>
        try(
          switch (auth_token) {
          | None =>
            Server.serve(
              ~identity,
              ~live,
              ~host,
              ~port,
              ~get_state,
              ~on_ready=actual_port =>
                publish_signal(signal, Started(dashboard_url(~host=Server.normalize_host(host), ~port=actual_port))),
              (),
            )
          | Some(token) =>
            Server.serve(
              ~identity,
              ~auth_token=token,
              ~live,
              ~host,
              ~port,
              ~get_state,
              ~on_ready=actual_port =>
                publish_signal(signal, Started(dashboard_url(~host=Server.normalize_host(host), ~port=actual_port))),
              (),
            )
          }
        ) {
        | exn => publish_signal(signal, Failed(secret_free_exception(exn)))
        },
      (),
    ),
  );
  let result = wait_signal(signal);
  switch (result) {
  | Started(_) =>
    render_service_event(
      ~outcome="started",
      ~host,
      ~port,
      ~workspace_root,
      ~runtime_home,
      ~auth_token,
    )
  | Failed(_) =>
    render_service_event(
      ~outcome="failed",
      ~host,
      ~port,
      ~workspace_root,
      ~runtime_home,
      ~auth_token,
    )
  | Reused(_) | Conflict(_) => ()
  };
  result;
};

let start_or_reuse_background =
    (~workspace_root, ~runtime_home, ~host, ~port, ~mode, ~auth_token, ~live, ~get_state, ()) => {
  let normalized_host = Server.normalize_host(host);
  let url = dashboard_url(~host=normalized_host, ~port);
  let expected = make_identity(~workspace_root, ~runtime_home, ~mode, ~auth_token, ~host, ~port);
  let probe_result = probe_identity(~host=normalized_host, ~port, ~auth_token);
  let result =
    start_or_reuse_from_probe(
      ~expected,
      ~url,
      ~probe_result,
      ~start=() =>
        start_background_without_probe(
          ~workspace_root,
          ~runtime_home,
          ~host,
          ~port,
          ~mode,
          ~auth_token,
          ~live,
          ~get_state,
          (),
        ),
    );
  switch (result) {
  | Reused(_) =>
    render_service_event(
      ~outcome="reused",
      ~host,
      ~port,
      ~workspace_root,
      ~runtime_home,
      ~auth_token,
    )
  | Conflict(_) =>
    render_service_event(
      ~outcome="conflict",
      ~host,
      ~port,
      ~workspace_root,
      ~runtime_home,
      ~auth_token,
    )
  | Started(_) | Failed(_) => ()
  };
  result;
};

let start_terminal_console =
    (~workspace_root, ~runtime_home, ~port, ~live, ~get_state, ()) =>
  start_or_reuse_background(
    ~workspace_root,
    ~runtime_home,
    ~host=Server.default_host,
    ~port,
    ~mode=terminal_console_mode,
    ~auth_token=None,
    ~live,
    ~get_state,
    (),
  );
