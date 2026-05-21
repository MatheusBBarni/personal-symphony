type command_result = {
  code: int,
  output: string,
};

type install_shape =
  | Npm_package({
      launcher_path: string,
      package_root: string,
      install_prefix: string,
    })
  | Source_checkout(string)
  | Unsupported(string);

let package_name = "symphony-orchestrator";

let rec find_ancestor_with = (name, path) => {
  let candidate = Filename.concat(path, name);
  if (Sys.file_exists(candidate)) {
    Some(path);
  } else {
    let parent = Filename.dirname(path);
    if (parent == path) {
      None;
    } else {
      find_ancestor_with(name, parent);
    };
  };
};

let realpath_opt = path =>
  try(Some(Unix.realpath(path))) {
  | Unix.Unix_error(_) => None
  };

let is_source_checkout_path = path => {
  let start =
    if (Sys.file_exists(path) && Sys.is_directory(path)) {
      path;
    } else {
      Filename.dirname(path);
    };
  switch (find_ancestor_with("dune-project", start)) {
  | Some(root) => Some(root)
  | None => None
  };
};

let read_package_name = package_root => {
  let package_json = Filename.concat(package_root, "package.json");
  if (!Sys.file_exists(package_json)) {
    None;
  } else {
    try(
      switch (Yojson.Basic.from_file(package_json)) {
      | `Assoc(fields) =>
        switch (List.assoc_opt("name", fields)) {
        | Some(`String(name)) => Some(name)
        | _ => None
        }
      | _ => None
      }
    ) {
    | _ => None
    };
  };
};

let infer_prefix_from_launcher = launcher_path => {
  let parent = Filename.dirname(launcher_path);
  if (Filename.basename(parent) == "bin") {
    Some(Filename.dirname(parent));
  } else {
    None;
  };
};

let infer_prefix_from_package_root = package_root => {
  let node_modules = Filename.dirname(package_root);
  if (Filename.basename(node_modules) != "node_modules") {
    None;
  } else {
    let lib_dir = Filename.dirname(node_modules);
    if (Filename.basename(lib_dir) == "lib") {
      Some(Filename.dirname(lib_dir));
    } else {
      None;
    };
  };
};

let is_symlink = path =>
  try(Unix.lstat(path).st_kind == Unix.S_LNK) {
  | Unix.Unix_error(_) => false
  };

let infer_prefix =
    (~raw_launcher_path, ~resolved_launcher_path, ~package_root) =>
  if (is_symlink(raw_launcher_path)) {
    switch (realpath_opt(raw_launcher_path)) {
    | Some(raw_real) when raw_real == resolved_launcher_path =>
      infer_prefix_from_launcher(raw_launcher_path)
    | _ => infer_prefix_from_package_root(package_root)
    };
  } else {
    infer_prefix_from_package_root(package_root);
  };

let detect_install_shape = (~launcher_path) => {
  let raw_launcher_path = launcher_path;
  let resolved_launcher_path =
    switch (realpath_opt(launcher_path)) {
    | Some(real) => real
    | None => launcher_path
    };

  switch (is_source_checkout_path(resolved_launcher_path)) {
  | Some(root) => Source_checkout(root)
  | None =>
    let package_root =
      Filename.dirname(Filename.dirname(resolved_launcher_path));
    if (read_package_name(package_root) == Some(package_name)) {
      let install_prefix =
        infer_prefix(
          ~raw_launcher_path,
          ~resolved_launcher_path,
          ~package_root,
        );
      switch (install_prefix) {
      | Some(install_prefix) =>
        Npm_package({
          launcher_path: resolved_launcher_path,
          package_root,
          install_prefix,
        })
      | None =>
        Unsupported(
          "could not identify the Install Prefix that owns "
          ++ resolved_launcher_path,
        )
      };
    } else {
      Unsupported(
        "current symphony command is not an npm-installed "
        ++ package_name
        ++ " CLI Package",
      );
    };
  };
};

let shell = command => {
  let ic = Unix.open_process_in(command ++ " 2>&1");
  let output = {
    let buffer = Buffer.create(256);
    try(
      while (true) {
        Buffer.add_string(buffer, input_line(ic));
        Buffer.add_char(buffer, '\n');
      }
    ) {
    | End_of_file => ()
    };
    Buffer.contents(buffer) |> Util.trim;
  };

  let code =
    switch (Unix.close_process_in(ic)) {
    | Unix.WEXITED(code) => code
    | Unix.WSIGNALED(signal) => 128 + signal
    | Unix.WSTOPPED(signal) => 128 + signal
    };

  {
    code,
    output,
  };
};

let command_success = command => {
  let result = shell(command);
  if (result.code == 0) {
    Ok(result.output);
  } else {
    Error(result.output);
  };
};

let split_once = (sep, text) =>
  switch (String.index_opt(text, sep)) {
  | None => (text, None)
  | Some(index) => (
      String.sub(text, 0, index),
      Some(String.sub(text, index + 1, String.length(text) - index - 1)),
    )
  };

let all_digits = text =>
  String.length(text) > 0
  && String.for_all(
       fun
       | '0' .. '9' => true
       | _ => false,
       text,
     );

let valid_version_identifier = text =>
  String.length(text) > 0
  && String.for_all(
       fun
       | 'A' .. 'Z'
       | 'a' .. 'z'
       | '0' .. '9'
       | '-' => true
       | _ => false,
       text,
     );

let valid_version_identifiers = text =>
  String.length(text) > 0
  && text
  |> String.split_on_char('.')
  |> List.for_all(valid_version_identifier);

let valid_npm_version = version => {
  let (core_and_pre, build) = split_once('+', version);
  let (core, prerelease) = split_once('-', core_and_pre);
  let core_valid =
    switch (String.split_on_char('.', core)) {
    | [major, minor, patch] =>
      List.for_all(all_digits, [major, minor, patch])
    | _ => false
    };

  core_valid
  && Option.fold(~none=true, ~some=valid_version_identifiers, prerelease)
  && Option.fold(~none=true, ~some=valid_version_identifiers, build);
};

let parse_version_text = output => {
  let version = Util.trim(output);
  if (valid_npm_version(version)) {
    Ok(version);
  } else {
    Error("npm returned invalid package version: " ++ output);
  };
};

let find_callable = () =>
  switch (Util.getenv_nonempty("SYMPHONY_LAUNCHER_PATH")) {
  | Some(path) => Ok(path)
  | None =>
    switch (command_success("command -v symphony")) {
    | Ok(path) => Ok(path)
    | Error(error) => Error(error)
    }
  };

let parse_latest_version = output =>
  try(
    switch (Yojson.Basic.from_string(output)) {
    | `String(version) => parse_version_text(version)
    | _ => Error("npm returned malformed version metadata: " ++ output)
    }
  ) {
  | Yojson.Json_error(_) =>
    let trimmed = Util.trim(output);
    if (trimmed != "" && !String.contains(trimmed, '\n')) {
      parse_version_text(trimmed);
    } else {
      Error("npm returned malformed version metadata: " ++ output);
    };
  };

let package_spec = version => package_name ++ "@" ++ version;

let manual_repair = (~target_version, ~install_prefix) =>
  Printf.sprintf(
    "Manual repair: run npm install -g %s --prefix %s, then run symphony --version.",
    Util.shell_quote(package_spec(target_version)),
    Util.shell_quote(install_prefix),
  );

let confirm_update =
    (~current_version, ~latest_version, ~install_prefix, ~install_command) => {
  Printf.printf("current version: %s\n", current_version);
  Printf.printf("latest version: %s\n", latest_version);
  Printf.printf("package: %s\n", package_name);
  Printf.printf("Install Prefix: %s\n", install_prefix);
  Printf.printf("command: %s\n", install_command);
  Printf.printf("Proceed with update? [y/N] %!");
  switch (read_line() |> String.lowercase_ascii |> Util.trim) {
  | "y"
  | "yes" => true
  | _ => false
  };
};

let run =
    (
      ~runner=shell,
      ~find_callable=find_callable,
      ~is_tty=() => Unix.isatty(Unix.stdin),
      ~confirm=confirm_update,
      ~current_version,
      ~yes,
      (),
    ) =>
  switch (find_callable()) {
  | Error(error) =>
    Printf.eprintf("phase=install-shape outcome=failed reason=%s\n%!", error);
    1;
  | Ok(callable) =>
    switch (detect_install_shape(~launcher_path=callable)) {
    | Source_checkout(root) =>
      Printf.eprintf(
        "phase=install-shape outcome=failed reason=source checkout unsupported path=%s\nSource checkouts must be updated through the normal development workflow.\n%!",
        root,
      );
      1;
    | Unsupported(reason) =>
      Printf.eprintf(
        "phase=install-shape outcome=failed reason=%s\n%!",
        reason,
      );
      1;
    | Npm_package({ launcher_path, install_prefix, _ }) =>
      let discovery =
        runner(Printf.sprintf("npm view %s version --json", package_name));
      if (discovery.code != 0) {
        Printf.eprintf(
          "phase=discovery outcome=failed\n%s\n%!",
          discovery.output,
        );
        1;
      } else {
        switch (parse_latest_version(discovery.output)) {
        | Error(error) =>
          Printf.eprintf(
            "phase=discovery outcome=failed reason=%s\n%!",
            error,
          );
          1;
        | Ok(latest_version) =>
          if (latest_version == current_version) {
            Printf.printf(
              "symphony is already current (%s).\n%!",
              current_version,
            );
            0;
          } else {
            let install_command =
              Printf.sprintf(
                "npm install -g %s --prefix %s",
                Util.shell_quote(package_spec(latest_version)),
                Util.shell_quote(install_prefix),
              );

            if (!yes && !is_tty()) {
              Printf.eprintf(
                "phase=confirmation outcome=failed reason=non-interactive update requires --yes\n%!",
              );
              1;
            } else if (!yes
                       && !
                            confirm(
                              ~current_version,
                              ~latest_version,
                              ~install_prefix,
                              ~install_command,
                            )) {
              Printf.eprintf(
                "phase=confirmation outcome=failed reason=update declined\n%!",
              );
              1;
            } else {
              let install = runner(install_command);
              if (install.code != 0) {
                Printf.eprintf(
                  "phase=install outcome=failed Install Prefix=%s\n%s\n%s\n%!",
                  install_prefix,
                  install.output,
                  manual_repair(
                    ~target_version=latest_version,
                    ~install_prefix,
                  ),
                );
                1;
              } else {
                let resolved = runner("command -v symphony");
                let validation =
                  runner(
                    Printf.sprintf(
                      "%s --version",
                      Util.shell_quote(launcher_path),
                    ),
                  );

                let resolved_launcher =
                  if (resolved.code == 0) {
                    realpath_opt(Util.trim(resolved.output));
                  } else {
                    None;
                  };

                if (resolved_launcher == Some(launcher_path)
                    && validation.code == 0
                    && Util.trim(validation.output) == latest_version) {
                  Printf.printf(
                    "symphony updated to %s.\n%!",
                    latest_version,
                  );
                  0;
                } else {
                  Printf.eprintf(
                    "phase=validation outcome=failed expected=%s observed=%s resolved=%s Install Prefix=%s\n%s\n%!",
                    latest_version,
                    Util.trim(validation.output),
                    Util.trim(resolved.output),
                    install_prefix,
                    manual_repair(
                      ~target_version=latest_version,
                      ~install_prefix,
                    ),
                  );
                  1;
                };
              };
            };
          }
        };
      };
    }
  };
