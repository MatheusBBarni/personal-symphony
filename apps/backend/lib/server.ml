let response ?(status = "200 OK") ?(content_type = "application/json") body =
  Printf.sprintf "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"
    status content_type (String.length body) body

let html =
  {|<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Personal Symphony</title>
  <style>
    :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; background: #09090b; color: #f4f4f5; }
    body { margin: 0; min-height: 100vh; background: #09090b; }
    header { border-bottom: 1px solid #27272a; padding: 18px 24px; }
    main { max-width: 1040px; margin: 0 auto; padding: 24px; }
    h1 { font-size: 22px; margin: 0; letter-spacing: 0; }
    .muted { color: #a1a1aa; }
    .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin: 20px 0; }
    .metric, .panel { border: 1px solid #27272a; border-radius: 8px; background: #18181b; padding: 16px; }
    .metric strong { display: block; font-size: 28px; margin-top: 6px; }
    .issue { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; border-top: 1px solid #27272a; padding: 12px 0; }
    .issue:first-child { border-top: 0; }
    .status { color: #a7f3d0; border: 1px solid #065f46; border-radius: 6px; padding: 2px 8px; font-size: 12px; white-space: nowrap; }
    .gaps { border-color: #92400e; background: #431407; color: #ffedd5; }
    .gaps li { margin: 8px 0; }
    code { color: #bae6fd; }
  </style>
</head>
<body>
  <header>
    <h1>Personal Symphony</h1>
    <div class="muted">GitHub Issues + Projects orchestration</div>
  </header>
  <main>
    <section class="metrics">
      <div class="metric"><span class="muted">Running</span><strong id="running">-</strong></div>
      <div class="metric"><span class="muted">Retrying</span><strong id="retrying">-</strong></div>
      <div class="metric"><span class="muted">Total tokens</span><strong id="tokens">-</strong></div>
    </section>
    <section id="readiness" class="panel gaps" hidden>
      <strong>Readiness Gaps</strong>
      <ul id="gap-list"></ul>
    </section>
    <section class="panel">
      <div class="muted">Project Issues</div>
      <div id="issues">Loading...</div>
    </section>
    <section class="panel">
      <div class="muted">Generated</div>
      <div id="generated">Loading...</div>
      <p class="muted">State API: <code>/api/v1/state</code></p>
    </section>
  </main>
  <script>
    const text = (id, value) => { document.getElementById(id).textContent = String(value); };
    async function loadState() {
      const response = await fetch("/api/v1/state", { headers: { Accept: "application/json" } });
      const state = await response.json();
      text("running", state.counts?.running ?? 0);
      text("retrying", state.counts?.retrying ?? 0);
      text("tokens", state.codex_totals?.total_tokens ?? 0);
      text("generated", state.generated_at ?? "");
      const issueList = document.getElementById("issues");
      const issues = Array.isArray(state.issues) ? state.issues : [];
      if (issues.length === 0) {
        issueList.textContent = "No project issues were returned by the latest poll.";
      } else {
        issueList.replaceChildren(...issues.map((issue) => {
          const row = document.createElement("article");
          row.className = "issue";
          const title = document.createElement("div");
          title.textContent = `${issue.issue_identifier} ${issue.title}`;
          const status = document.createElement("span");
          status.className = "status";
          status.textContent = issue.state || "";
          row.append(title, status);
          return row;
        }));
      }
      const gaps = Array.isArray(state.readiness_gaps) ? state.readiness_gaps : [];
      const panel = document.getElementById("readiness");
      const list = document.getElementById("gap-list");
      list.replaceChildren(...gaps.map((gap) => {
        const item = document.createElement("li");
        item.textContent = `${gap.requirement}: ${gap.remediation}`;
        return item;
      }));
      panel.hidden = gaps.length === 0;
    }
    loadState().catch((error) => text("generated", error.message));
    setInterval(() => loadState().catch(() => {}), 5000);
  </script>
</body>
</html>|}

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
  Unix.setsockopt socket Unix.SO_REUSEADDR true;
  Unix.bind socket (Unix.ADDR_INET (Unix.inet_addr_any, port));
  Unix.listen socket 16;
  let actual_port =
    match Unix.getsockname socket with Unix.ADDR_INET (_, port) -> port | _ -> port
  in
  render_server_ready ~port:actual_port;
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
