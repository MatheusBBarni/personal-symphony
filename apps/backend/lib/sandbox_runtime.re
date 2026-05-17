type launch_plan = {
  command: string,
  provider: option(string),
  reuse_outcome: option(string),
  container_name: option(string),
};

type shell_result = {
  code: int,
  output: string,
};

let run_shell = command => {
  let ic = Unix.open_process_in(command ++ " 2>&1");
  let buffer = Buffer.create(128);
  let rec read_lines = () =>
    try({
      Buffer.add_string(buffer, input_line(ic));
      Buffer.add_char(buffer, '\n');
      read_lines();
    }) {
    | End_of_file => ()
    };
  read_lines();
  let code =
    switch (Unix.close_process_in(ic)) {
    | Unix.WEXITED(code) => code
    | Unix.WSIGNALED(signal) => 128 + signal
    | Unix.WSTOPPED(signal) => 128 + signal
    };
  {code, output: Buffer.contents(buffer) |> Util.trim};
};

let command_output = command => {
  let result = run_shell(command);
  if (result.code == 0) {
    Ok(result.output);
  } else {
    Error(result.output);
  };
};

let command_success = command => (run_shell(command)).code == 0;

let option_string = value =>
  switch (value) {
  | Some(value) => Util.trim(value)
  | None => "<missing>"
  };

let option_bool = value =>
  switch (value) {
  | Some(true) => "true"
  | Some(false) => "false"
  | None => "<missing>"
  };

let option_int = value =>
  switch (value) {
  | Some(value) => string_of_int(value)
  | None => "<missing>"
  };

let sandbox_fingerprint = (sandbox: Config.sandbox, mount_paths) =>
  String.concat(
    "\000",
    [
      "type=" ++ option_string(sandbox.type_),
      "image=" ++ option_string(sandbox.image),
      "bootstrap=" ++ String.concat("\000", sandbox.bootstrap_commands),
      "persistent=" ++ option_bool(sandbox.persistent),
      "networkEnabled=" ++ option_bool(sandbox.network_enabled),
      "cpuLimit=" ++ option_int(sandbox.cpu_limit),
      "memoryMb=" ++ option_int(sandbox.memory_mb),
      "mounts=" ++ String.concat("\000", mount_paths),
    ],
  );

let digest_prefix = (value, length) => {
  let digest = Digest.to_hex(Digest.string(value));
  String.sub(digest, 0, min(length, String.length(digest)));
};

let container_name = (~repository_root, ~sandbox) => {
  ignore(sandbox);
  "symphony-sandbox-" ++ digest_prefix(repository_root, 24);
};

let docker_executable = () =>
  switch (Sys.getenv_opt("SYMPHONY_DOCKER_BIN")) {
  | Some(command) when Util.trim(command) != "" => Util.trim(command)
  | _ => "docker"
  };

let docker_command = args =>
  String.concat(" ", List.map(Util.shell_quote, [docker_executable(), ...args]));

let docker_reuse_outcome = (~inspect_container, ~inspect_config, ~config_hash) =>
  if (!command_success(inspect_container)) {
    Ok("created");
  } else {
    switch (command_output(inspect_config)) {
    | Ok(existing_config_hash) when existing_config_hash == config_hash => Ok("reused")
    | Ok(_) | Error(_) => Ok("recreated")
    };
  };

let unique_paths = paths => {
  let rec loop = (seen, acc, paths) =>
    switch (paths) {
    | [] => List.rev(acc)
    | [path, ...rest] =>
      if (List.exists(existing => existing == path, seen)) {
        loop(seen, acc, rest);
      } else {
        loop([path, ...seen], [path, ...acc], rest);
      }
    };
  loop([], [], paths);
};

let mount_paths = (~repository_root, ~workspace_path) => {
  let repository_root = Unix.realpath(repository_root);
  let workspace_path = Unix.realpath(workspace_path);
  if (Workspace.is_inside(~root=repository_root, ~path=workspace_path)) {
    [repository_root];
  } else {
    unique_paths([repository_root, workspace_path]);
  };
};

let pairs = (flag, values) =>
  values |> List.map(value => [flag, value]) |> List.concat;

let indented = lines => List.map(line => "    " ++ line, lines);

let required_string = (~field, value) =>
  switch (value) {
  | Some(value) when Util.trim(value) != "" => Ok(Util.trim(value))
  | _ => Error("Sandbox launch requires " ++ field ++ " when sandbox.enabled is true.")
  };

let required_bool = (~field, value) =>
  switch (value) {
  | Some(value) => Ok(value)
  | None => Error("Sandbox launch requires " ++ field ++ " when sandbox.enabled is true.")
  };

let required_positive_int = (~field, value) =>
  switch (value) {
  | Some(value) when value > 0 => Ok(value)
  | _ =>
    Error(
      "Sandbox launch requires "
      ++ field
      ++ " to be a positive integer when sandbox.enabled is true.",
    )
  };

let host_command = (~workspace_path, ~harness_command, ~prompt_path, ~stdout_path, ~stderr_path) =>
  Printf.sprintf(
    "cd %s && %s < %s > %s 2> %s",
    Util.shell_quote(workspace_path),
    harness_command,
    Util.shell_quote(prompt_path),
    Util.shell_quote(stdout_path),
    Util.shell_quote(stderr_path),
  );

let host_launch_plan = (~workspace_path, ~harness_command, ~prompt_path, ~stdout_path, ~stderr_path) =>
  {
    command: host_command(~workspace_path, ~harness_command, ~prompt_path, ~stdout_path, ~stderr_path),
    provider: None,
    reuse_outcome: None,
    container_name: None,
  };

let docker_run_command =
    (
      ~container_name,
      ~repository_root,
      ~config_hash,
      ~image,
      ~mount_paths,
      ~network_enabled,
      ~cpu_limit,
      ~memory_mb,
    ) => {
  let network_args =
    switch (network_enabled) {
    | true => []
    | false => ["--network", "none"]
    };
  let volume_args = pairs("-v", List.map(path => path ++ ":" ++ path, mount_paths));
  let args =
    [
      "run",
      "-d",
      "--name",
      container_name,
      "--label",
      "personal-symphony.repository-root-hash=" ++ digest_prefix(repository_root, 24),
      "--label",
      "personal-symphony.sandbox-config-hash=" ++ config_hash,
      "--cpus",
      string_of_int(cpu_limit),
      "--memory",
      string_of_int(memory_mb) ++ "m",
    ]
    @ network_args
    @ volume_args
    @ [
      image,
      "sh",
      "-lc",
      "while :; do sleep 3600; done",
    ];
  docker_command(args);
};

let docker_exec_shell = (~container_name, ~workdir, ~interactive=false, command) => {
  let interactive_args = interactive ? ["-i"] : [];
  docker_command(["exec"] @ interactive_args @ ["-w", workdir, container_name, "/bin/sh", "-lc", command]);
};

let docker_launch_command =
    (
      ~config,
      ~workspace_path,
      ~harness_command,
      ~prompt_path,
      ~stdout_path,
      ~stderr_path,
    ) => {
  let config: Config.t = config;
  let sandbox = config.sandbox;
  switch (sandbox.type_) {
  | Some("docker") =>
    switch (
      required_string(~field="sandbox.image", sandbox.image),
      required_bool(~field="sandbox.persistent", sandbox.persistent),
      required_bool(~field="sandbox.networkEnabled", sandbox.network_enabled),
      required_positive_int(~field="sandbox.cpuLimit", sandbox.cpu_limit),
      required_positive_int(~field="sandbox.memoryMb", sandbox.memory_mb),
    ) {
    | (Ok(image), Ok(true), Ok(network_enabled), Ok(cpu_limit), Ok(memory_mb)) =>
      let mount_paths = mount_paths(~repository_root=config.repository_root, ~workspace_path);
      let container_name = container_name(~repository_root=config.repository_root, ~sandbox);
      let config_hash = digest_prefix(sandbox_fingerprint(sandbox, mount_paths), 32);
      let inspect_container = docker_command(["container", "inspect", container_name]);
      let inspect_config =
        docker_command([
          "inspect",
          "-f",
          "{{ index .Config.Labels \"personal-symphony.sandbox-config-hash\" }}",
          container_name,
        ]);
      let inspect_running = docker_command(["inspect", "-f", "{{.State.Running}}", container_name]);
      let remove_container = docker_command(["rm", "-f", container_name]);
      let start_container = docker_command(["start", container_name]);
      let reuse_outcome = docker_reuse_outcome(~inspect_container, ~inspect_config, ~config_hash);
      let create_container =
        docker_run_command(
          ~container_name,
          ~repository_root=config.repository_root,
          ~config_hash,
          ~image,
          ~mount_paths,
          ~network_enabled,
          ~cpu_limit,
          ~memory_mb,
        );
      let bootstrap_lines =
        sandbox.bootstrap_commands
        |> List.map(command =>
             docker_exec_shell(~container_name, ~workdir=config.repository_root, command)
           );
      let create_lines = [create_container ++ " >/dev/null", ...bootstrap_lines];
      let exec_agent =
        docker_exec_shell(~container_name, ~workdir=workspace_path, ~interactive=true, harness_command)
        ++ " < "
        ++ Util.shell_quote(prompt_path);
      let script =
        (
          [
          "set -eu",
          "if " ++ inspect_container ++ " >/dev/null 2>&1; then",
          "  existing_config_hash=$(" ++ inspect_config ++ " 2>/dev/null || true)",
          "  if [ \"$existing_config_hash\" != " ++ Util.shell_quote(config_hash) ++ " ]; then",
          "    " ++ remove_container ++ " >/dev/null 2>&1 || true",
        ]
        @ indented(create_lines)
        @ [
          "  fi",
          "else",
        ]
        @ indented(create_lines)
        @ [
          "fi",
          "running=$(" ++ inspect_running ++ " 2>/dev/null || printf false)",
          "if [ \"$running\" != \"true\" ]; then",
          "  " ++ start_container ++ " >/dev/null",
          "fi",
          "exec " ++ exec_agent,
        ]
        )
        |> String.concat("\n");
      switch (reuse_outcome) {
      | Ok(reuse_outcome) =>
        Ok((
          Printf.sprintf(
            "cd %s && (\n%s\n) > %s 2> %s",
            Util.shell_quote(workspace_path),
            script,
            Util.shell_quote(stdout_path),
            Util.shell_quote(stderr_path),
          ),
          reuse_outcome,
        ))
      | Error(_) as error => error
      };
    | (Ok(_), Ok(false), _, _, _) =>
      Error("Sandbox launch requires sandbox.persistent to be true for named-container reuse in V1.")
    | (Error(error), _, _, _, _)
    | (_, Error(error), _, _, _)
    | (_, _, Error(error), _, _)
    | (_, _, _, Error(error), _)
    | (_, _, _, _, Error(error)) =>
      Error(error)
    }
  | Some(_) =>
    Error("Sandbox launch requires sandbox.type to be docker. Docker is the only supported sandbox type in V1.")
  | None => Error("Sandbox launch requires sandbox.type when sandbox.enabled is true.")
  };
};

let launch_plan =
    (
      ~config,
      ~workspace_path,
      ~harness_command,
      ~prompt_path,
      ~stdout_path,
      ~stderr_path,
    ) =>
  {
  let config: Config.t = config;
  if (!config.sandbox.enabled) {
    Ok(host_launch_plan(~workspace_path, ~harness_command, ~prompt_path, ~stdout_path, ~stderr_path));
  } else {
    switch (
      docker_launch_command(
        ~config,
        ~workspace_path,
        ~harness_command,
        ~prompt_path,
        ~stdout_path,
        ~stderr_path,
      )
    ) {
    | Ok((command, reuse_outcome)) =>
      Ok({
        command,
        provider: Some("docker"),
        reuse_outcome: Some(reuse_outcome),
        container_name: Some(container_name(~repository_root=config.repository_root, ~sandbox=config.sandbox)),
      })
    | Error(_) as error => error
    };
  };
  };
