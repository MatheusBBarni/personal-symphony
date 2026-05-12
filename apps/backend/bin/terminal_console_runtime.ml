type branch =
  | Manual_merge
  | Once
  | Web_dashboard of Runtime_policy.action
  | Terminal_console_readiness
  | Terminal_console_orchestrator

type state_handoff = {
  mutex : Mutex.t;
  condition : Condition.t;
  mutable latest : Runtime_state.t;
  mutable version : int;
  mutable closed : bool;
}

type start_orchestration = notify_state:(Runtime_state.t -> unit) -> unit

(* The handoff keeps one latest Runtime State snapshot. Updates published before
   a subscriber starts are intentionally coalesced to the latest snapshot. *)

let select_branch ~once ~mode ~merge_args ~(readiness_gaps : Runtime_state.readiness_gap list) =
  if merge_args <> [] then Manual_merge
  else if once then Once
  else
    let action = Runtime_policy.action ~mode ~readiness_gaps in
    match mode with
    | Cli_mode.Web_dashboard -> Web_dashboard action
    | Cli_mode.Terminal_console -> (
        match action with
        | Runtime_policy.Serve_readiness_state -> Terminal_console_readiness
        | Runtime_policy.Run_orchestrator -> Terminal_console_orchestrator)

let create_state_handoff initial_state =
  {
    mutex = Mutex.create ();
    condition = Condition.create ();
    latest = initial_state;
    version = 0;
    closed = false;
  }

let with_lock handoff f =
  Mutex.lock handoff.mutex;
  Fun.protect ~finally:(fun () -> Mutex.unlock handoff.mutex) f

let latest_state handoff = with_lock handoff (fun () -> handoff.latest)
let version handoff = with_lock handoff (fun () -> handoff.version)

let publish_state handoff state =
  with_lock handoff (fun () ->
      if not handoff.closed then (
        handoff.latest <- state;
        handoff.version <- handoff.version + 1;
        Condition.broadcast handoff.condition))

let close_state_handoff handoff =
  with_lock handoff (fun () ->
      handoff.closed <- true;
      Condition.broadcast handoff.condition)

let subscribe_state handoff dispatch =
  let snapshot () =
    with_lock handoff (fun () -> (handoff.latest, handoff.version, handoff.closed))
  in
  let state, initial_version, closed = snapshot () in
  dispatch state;
  if not closed then
    let rec loop seen_version =
      let next =
        with_lock handoff (fun () ->
            while (not handoff.closed) && handoff.version = seen_version do
              Condition.wait handoff.condition handoff.mutex
            done;
            if handoff.closed && handoff.version = seen_version then None
            else Some (handoff.latest, handoff.version))
      in
      match next with
      | None -> ()
      | Some (state, next_version) ->
          dispatch state;
          loop next_version
    in
    loop initial_version

let runtime_of_handoff ?(safe_aid = fun _ -> ()) handoff : Terminal_console_mosaic.runtime =
  {
    initial_state = latest_state handoff;
    subscribe = (fun dispatch -> subscribe_state handoff dispatch);
    safe_aid;
  }

let run ?(run_ui = Terminal_console_mosaic.run) ?start_orchestration ~initial_state () =
  let handoff = create_state_handoff initial_state in
  Fun.protect
    ~finally:(fun () -> close_state_handoff handoff)
    (fun () ->
      Option.iter (fun start -> start ~notify_state:(publish_state handoff)) start_orchestration;
      run_ui (runtime_of_handoff handoff))
