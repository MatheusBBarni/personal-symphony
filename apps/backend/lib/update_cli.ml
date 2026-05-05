type command_result = { code : int; output : string }

type install_shape =
  | Npm_package of { launcher_path : string; package_root : string; install_prefix : string }
  | Source_checkout of string
  | Unsupported of string

let package_name = "symphony-orchestrator"

let rec find_ancestor_with name path =
  let candidate = Filename.concat path name in
  if Sys.file_exists candidate then Some path
  else
    let parent = Filename.dirname path in
    if parent = path then None else find_ancestor_with name parent

let realpath_opt path =
  try Some (Unix.realpath path) with Unix.Unix_error _ -> None

let is_source_checkout_path path =
  let start = if Sys.file_exists path && Sys.is_directory path then path else Filename.dirname path in
  match find_ancestor_with "dune-project" start with Some root -> Some root | None -> None

let read_package_name package_root =
  let package_json = Filename.concat package_root "package.json" in
  if not (Sys.file_exists package_json) then None
  else
    try
      match Yojson.Basic.from_file package_json with
      | `Assoc fields -> (
          match List.assoc_opt "name" fields with Some (`String name) -> Some name | _ -> None)
      | _ -> None
    with _ -> None

let infer_prefix_from_launcher launcher_path =
  let parent = Filename.dirname launcher_path in
  if Filename.basename parent = "bin" then Some (Filename.dirname parent) else None

let infer_prefix_from_package_root package_root =
  let node_modules = Filename.dirname package_root in
  if Filename.basename node_modules <> "node_modules" then None
  else
    let lib_dir = Filename.dirname node_modules in
    if Filename.basename lib_dir = "lib" then Some (Filename.dirname lib_dir) else None

let is_symlink path =
  try (Unix.lstat path).st_kind = Unix.S_LNK with Unix.Unix_error _ -> false

let infer_prefix ~raw_launcher_path ~resolved_launcher_path ~package_root =
  if is_symlink raw_launcher_path then
    match realpath_opt raw_launcher_path with
    | Some raw_real when raw_real = resolved_launcher_path ->
      infer_prefix_from_launcher raw_launcher_path
    | _ -> infer_prefix_from_package_root package_root
  else infer_prefix_from_package_root package_root

let detect_install_shape ~launcher_path =
  let raw_launcher_path = launcher_path in
  let resolved_launcher_path =
    match realpath_opt launcher_path with Some real -> real | None -> launcher_path
  in
  match is_source_checkout_path resolved_launcher_path with
  | Some root -> Source_checkout root
  | None ->
      let package_root = Filename.dirname (Filename.dirname resolved_launcher_path) in
      if read_package_name package_root = Some package_name then
        let install_prefix = infer_prefix ~raw_launcher_path ~resolved_launcher_path ~package_root in
        match install_prefix with
        | Some install_prefix -> Npm_package { launcher_path = resolved_launcher_path; package_root; install_prefix }
        | None -> Unsupported ("could not identify the Install Prefix that owns " ^ resolved_launcher_path)
      else Unsupported ("current symphony command is not an npm-installed " ^ package_name ^ " CLI Package")

let shell command =
  let ic = Unix.open_process_in (command ^ " 2>&1") in
  let output =
    let buffer = Buffer.create 256 in
    (try
       while true do
         Buffer.add_string buffer (input_line ic);
         Buffer.add_char buffer '\n'
       done
     with End_of_file -> ());
    Buffer.contents buffer |> Util.trim
  in
  let code =
    match Unix.close_process_in ic with
    | Unix.WEXITED code -> code
    | Unix.WSIGNALED signal -> 128 + signal
    | Unix.WSTOPPED signal -> 128 + signal
  in
  { code; output }

let command_success command =
  let result = shell command in
  if result.code = 0 then Ok result.output else Error result.output

let find_callable () =
  match Util.getenv_nonempty "SYMPHONY_LAUNCHER_PATH" with
  | Some path -> Ok path
  | None -> (
      match command_success "command -v symphony" with Ok path -> Ok path | Error error -> Error error)

let parse_latest_version output =
  try
    match Yojson.Basic.from_string output with
    | `String version when Util.trim version <> "" -> Ok (Util.trim version)
    | _ -> Error ("npm returned malformed version metadata: " ^ output)
  with Yojson.Json_error _ -> (
    let trimmed = Util.trim output in
    if trimmed <> "" && not (String.contains trimmed '\n') then Ok trimmed
    else Error ("npm returned malformed version metadata: " ^ output))

let manual_repair ~target_version ~install_prefix =
  Printf.sprintf "Manual repair: run npm install -g %s@%s --prefix %s, then run symphony --version."
    package_name target_version (Util.shell_quote install_prefix)

let confirm_update ~current_version ~latest_version ~install_prefix ~install_command =
  Printf.printf "current version: %s\n" current_version;
  Printf.printf "latest version: %s\n" latest_version;
  Printf.printf "package: %s\n" package_name;
  Printf.printf "Install Prefix: %s\n" install_prefix;
  Printf.printf "command: %s\n" install_command;
  Printf.printf "Proceed with update? [y/N] %!";
  match read_line () |> String.lowercase_ascii |> Util.trim with "y" | "yes" -> true | _ -> false

let run ?(runner = shell) ?(find_callable = find_callable) ?(is_tty = fun () -> Unix.isatty Unix.stdin)
    ?(confirm = confirm_update) ~current_version ~yes () =
  match find_callable () with
  | Error error ->
      Printf.eprintf "phase=install-shape outcome=failed reason=%s\n%!" error;
      1
  | Ok callable -> (
      match detect_install_shape ~launcher_path:callable with
      | Source_checkout root ->
          Printf.eprintf
            "phase=install-shape outcome=failed reason=source checkout unsupported path=%s\n\
             Source checkouts must be updated through the normal development workflow.\n%!"
            root;
          1
      | Unsupported reason ->
          Printf.eprintf "phase=install-shape outcome=failed reason=%s\n%!" reason;
          1
      | Npm_package { launcher_path; install_prefix; _ } ->
          let discovery = runner (Printf.sprintf "npm view %s version --json" package_name) in
          if discovery.code <> 0 then (
            Printf.eprintf "phase=discovery outcome=failed\n%s\n%!" discovery.output;
            1)
          else
            match parse_latest_version discovery.output with
            | Error error ->
                Printf.eprintf "phase=discovery outcome=failed reason=%s\n%!" error;
                1
            | Ok latest_version ->
                if latest_version = current_version then (
                  Printf.printf "symphony is already current (%s).\n%!" current_version;
                  0)
                else
                  let install_command =
                    Printf.sprintf "npm install -g %s@%s --prefix %s" package_name latest_version
                      (Util.shell_quote install_prefix)
                  in
                  if (not yes) && not (is_tty ()) then (
                    Printf.eprintf "phase=confirmation outcome=failed reason=non-interactive update requires --yes\n%!";
                    1)
                  else if (not yes) && not (confirm ~current_version ~latest_version ~install_prefix ~install_command)
                  then (
                    Printf.eprintf "phase=confirmation outcome=failed reason=update declined\n%!";
                    1)
                  else
                    let install = runner install_command in
                    if install.code <> 0 then (
                      Printf.eprintf "phase=install outcome=failed Install Prefix=%s\n%s\n%s\n%!" install_prefix
                        install.output (manual_repair ~target_version:latest_version ~install_prefix);
                      1)
                    else
                      let resolved = runner "command -v symphony" in
                      let validation =
                        runner (Printf.sprintf "%s --version" (Util.shell_quote launcher_path))
                      in
                      let resolved_launcher =
                        if resolved.code = 0 then realpath_opt (Util.trim resolved.output) else None
                      in
                      if
                        resolved_launcher = Some launcher_path
                        && validation.code = 0
                        && Util.trim validation.output = latest_version
                      then (
                        Printf.printf "symphony updated to %s.\n%!" latest_version;
                        0)
                      else (
                        Printf.eprintf
                          "phase=validation outcome=failed expected=%s observed=%s resolved=%s Install Prefix=%s\n%s\n%!"
                          latest_version (Util.trim validation.output) (Util.trim resolved.output) install_prefix
                          (manual_repair ~target_version:latest_version ~install_prefix);
                        1))
