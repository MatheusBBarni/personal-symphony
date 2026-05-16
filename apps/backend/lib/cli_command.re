type runtime_args = {
  workflow_path: option(string),
  port: option(int),
  once: bool,
  web: bool,
  queue_arg: option(string),
  merge_args: list(string),
  overrides: Config.runtime_invocation_overrides,
};

type callbacks = {
  run: runtime_args => int,
  init: unit => int,
  update: (~yes: bool) => int,
};

let workflow_arg =
  Cmdliner.Arg.(
    value
      & pos(0, some(string), None)
      & info([], ~docv="WORKFLOW", ~doc="Optional legacy WORKFLOW.md path.")
  );

let polling_interval_ms_flag = "polling.intervalMs";
let workspace_root_flag = "workspace.root";
let agent_max_concurrent_agents_flag = "agent.maxConcurrentAgents";
let agent_max_turns_flag = "agent.maxTurns";
let agent_max_retry_backoff_ms_flag = "agent.maxRetryBackoffMs";

let runtime_only_override_flags = [
  polling_interval_ms_flag,
  workspace_root_flag,
  agent_max_concurrent_agents_flag,
  agent_max_turns_flag,
  agent_max_retry_backoff_ms_flag,
];

let runtime_only_override_options =
  List.map(name => "--" ++ name, runtime_only_override_flags);

let strict_positive_int = flag => {
  let parse = raw => {
    if (raw == "") {
      Error(`Msg(flag ++ " must be a positive integer"));
    } else if (
      !String.for_all(
        c => c >= '0' && c <= '9',
        raw,
      )
    ) {
      Error(`Msg(flag ++ " must be a positive integer"));
    } else {
      switch (int_of_string_opt(raw)) {
      | Some(value) when value > 0 => Ok(value)
      | _ => Error(`Msg(flag ++ " must be a positive integer"))
      };
    };
  };
  Cmdliner.Arg.conv((parse, Format.pp_print_int));
};

let polling_interval_ms_arg =
  Cmdliner.Arg.(
    value
      & opt(some(strict_positive_int(polling_interval_ms_flag)), None)
      & info(
        [polling_interval_ms_flag],
        ~docv="MS",
        ~doc="Override Runtime Settings polling.intervalMs for the current invocation only.",
      )
  );

let workspace_root_arg =
  Cmdliner.Arg.(
    value
      & opt(some(string), None)
      & info(
        [workspace_root_flag],
        ~docv="PATH",
        ~doc="Override Runtime Settings workspace.root for current-invocation Agent Worktree placement only; does not select the Workspace Repository.",
      )
  );

let agent_max_concurrent_agents_arg =
  Cmdliner.Arg.(
    value
      & opt(some(strict_positive_int(agent_max_concurrent_agents_flag)), None)
      & info(
        [agent_max_concurrent_agents_flag],
        ~docv="COUNT",
        ~doc="Override Runtime Settings agent.maxConcurrentAgents for the current invocation only.",
      )
  );

let agent_max_turns_arg =
  Cmdliner.Arg.(
    value
      & opt(some(strict_positive_int(agent_max_turns_flag)), None)
      & info(
        [agent_max_turns_flag],
        ~docv="COUNT",
        ~doc="Override Runtime Settings agent.maxTurns for the current invocation only.",
      )
  );

let agent_max_retry_backoff_ms_arg =
  Cmdliner.Arg.(
    value
      & opt(some(strict_positive_int(agent_max_retry_backoff_ms_flag)), None)
      & info(
        [agent_max_retry_backoff_ms_flag],
        ~docv="MS",
        ~doc="Override Runtime Settings agent.maxRetryBackoffMs for the current invocation only.",
      )
  );

let port_arg =
  Cmdliner.Arg.(
    value
      & opt(some(int), None)
      & info(["port"], ~docv="PORT", ~doc="HTTP server port. Overrides server.port.")
  );

let once_arg =
  Cmdliner.Arg.(
    value
      & flag
      & info(
        ["once"],
        ~doc="Validate startup and exit without starting the HTTP server.",
      )
  );

let web_arg =
  Cmdliner.Arg.(
    value
      & flag
      & info(
        ["web"],
        ~doc="Start the backend and Web Dashboard mode instead of the Terminal Console.",
      )
  );

let queue_arg =
  Cmdliner.Arg.(
    value
      & opt(some(string), None)
      & info(
        ["queue"],
        ~docv="ISSUES",
        ~doc="Run an Ordered Queue from comma-separated Workspace Repository issue identifiers. Optional # prefixes are allowed. When Runtime Settings select tracker.kind = \"compozy_tasks\", --queue also accepts bare Compozy PRD Run slugs such as docs-refresh; this shortcut is not a global selector form. Only listed issues dispatch, in listed first-admission order, while still respecting agent.maxConcurrentAgents.",
      )
  );

let merge_arg =
  Cmdliner.Arg.(
    value
      & opt_all(string, [])
      & info(
        ["merge"],
        ~docv="ISSUE",
        ~doc="Run a one-shot Manual Task Merge for Workspace Repository issue identifiers. Optional # prefixes, comma-separated values, and repeated --merge flags are allowed.",
      )
  );

let yes_arg =
  Cmdliner.Arg.(
    value
      & flag
      & info(["yes", "y"], ~doc="Update without interactive confirmation.")
  );

let runtime_term = callbacks => {
  let run = (
    workflow_path,
    polling_interval_ms,
    workspace_root,
    agent_max_concurrent_agents,
    agent_max_turns,
    agent_max_retry_backoff_ms,
    port,
    once,
    web,
    queue_arg,
    merge_args,
  ) => {
    let overrides = {
      Config.polling_interval_ms,
      workspace_root,
      agent_max_concurrent_agents,
      agent_max_turns,
      agent_max_retry_backoff_ms,
    };
    callbacks.run({
      workflow_path,
      port,
      once,
      web,
      queue_arg,
      merge_args,
      overrides,
    });
  };
  Cmdliner.Term.(
    const(run)
      $ workflow_arg
      $ polling_interval_ms_arg
      $ workspace_root_arg
      $ agent_max_concurrent_agents_arg
      $ agent_max_turns_arg
      $ agent_max_retry_backoff_ms_arg
      $ port_arg
      $ once_arg
      $ web_arg
      $ queue_arg
      $ merge_arg
  );
};

let cmd = (~version, callbacks) => {
  let doc = "Run Personal Symphony from a Git Workspace Repository root.";
  let init_cmd =
    Cmdliner.Cmd.v(
      Cmdliner.Cmd.info("init", ~doc="Create missing .symphony runtime files without overwriting edits."),
      Cmdliner.Term.(const(callbacks.init) $ const(())),
    );
  let update_cmd =
    Cmdliner.Cmd.v(
      Cmdliner.Cmd.info("update", ~doc="Update the npm-installed CLI Package to the latest npm release."),
      Cmdliner.Term.(const(yes => callbacks.update(~yes)) $ yes_arg),
    );
  Cmdliner.Cmd.group(
    Cmdliner.Cmd.info("symphony", ~doc, ~version),
    ~default=runtime_term(callbacks),
    [init_cmd, update_cmd],
  );
};

let normalize_help_argv = argv =>
  Array.map(
    fun
    | "-h" => "--help"
    | "-v" => "--version"
    | arg => arg,
    argv,
  );

let starts_with = (~prefix, value) => {
  let prefix_len = String.length(prefix);
  String.length(value) >= prefix_len
    && String.sub(value, 0, prefix_len) == prefix;
};

let runtime_only_override_option = arg =>
  List.find_opt(
    option => arg == option || starts_with(~prefix=option ++ "=", arg),
    runtime_only_override_options,
  );

let normalize_runtime_override_values = argv => {
  let argv_len = Array.length(argv);
  let rec loop = (index, acc) =>
    if (index >= argv_len) {
      Array.of_list(List.rev(acc));
    } else {
      let arg = argv[index];
      switch (runtime_only_override_option(arg)) {
      | Some(option) when arg == option && index + 1 < argv_len =>
        loop(index + 2, [option ++ "=" ++ argv[index + 1], ...acc])
      | _ => loop(index + 1, [arg, ...acc])
      };
    };
  loop(0, []);
};

let value_option_names = [
  "port",
  "queue",
  "merge",
  ...runtime_only_override_flags,
];

let option_consumes_next_value = arg =>
  switch (String.split_on_char('=', arg)) {
  | [option] when starts_with(~prefix="--", option) =>
    List.exists(name => option == "--" ++ name, value_option_names)
  | _ => false
  };

let unsupported_runtime_override_error = argv => {
  let argv_len = Array.length(argv);
  let rec scan = (index, skip_value, first_positional, override_option) =>
    if (index >= argv_len) {
      (first_positional, override_option);
    } else {
      let arg = argv[index];
      if (index == 0) {
        scan(index + 1, false, first_positional, override_option);
      } else if (skip_value) {
        scan(index + 1, false, first_positional, override_option);
      } else {
        let override_option =
          switch (override_option) {
          | Some(_) => override_option
          | None => runtime_only_override_option(arg)
          };
        if (arg == "--") {
          let first_positional =
            switch ((first_positional, index + 1 < argv_len)) {
            | (None, true) => Some(argv[index + 1])
            | _ => first_positional
            };
          scan(argv_len, false, first_positional, override_option);
        } else if (starts_with(~prefix="--", arg)) {
          scan(index + 1, option_consumes_next_value(arg), first_positional, override_option);
        } else if (starts_with(~prefix="-", arg)) {
          scan(index + 1, false, first_positional, override_option);
        } else {
          let first_positional =
            switch (first_positional) {
            | Some(_) => first_positional
            | None => Some(arg)
            };
          scan(index + 1, false, first_positional, override_option);
        };
      };
    };
  let (first_positional, override_option) = scan(0, false, None, None);
  switch ((first_positional, override_option)) {
  | (Some(_), Some(option)) =>
    Some(
      Printf.sprintf(
        "%s is a Runtime Settings Invocation Override and applies only to the default runtime command.",
        option,
      ),
    )
  | _ => None
  };
};

let eval = (~version, callbacks, ~argv) => {
  let argv = normalize_help_argv(argv);
  switch (unsupported_runtime_override_error(argv)) {
  | Some(message) =>
    Printf.eprintf("event=cli outcome=failed reason=%s\n%!", message);
    1;
  | None =>
    Cmdliner.Cmd.eval'(
      ~argv=normalize_runtime_override_values(argv),
      cmd(~version, callbacks),
    )
  };
};
