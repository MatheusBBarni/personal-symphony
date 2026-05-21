type theme_validation =
  | Theme_valid(string)
  | Theme_fallback({
      requested: option(string),
      fallback: string,
      reason: string,
    });

type port_validation =
  | Port_valid(int)
  | Port_invalid(string);

type port_update_result =
  | Port_updated(int)
  | Port_rejected(string)
  | Port_update_failed(string);

exception Settings_update_error(string);

let default_theme = "cursor-dark";

let supported_themes = ["cursor-dark", "dark", "light", "high-contrast", "no-color"];

let is_supported_theme = theme =>
  List.exists(candidate => candidate == theme, supported_themes);

let fallback_theme = (~requested, ~reason) =>
  Theme_fallback({requested, fallback: default_theme, reason});

let validate_theme = raw => {
  let theme = Util.trim(raw);
  if (is_supported_theme(theme)) {
    Theme_valid(theme);
  } else {
    fallback_theme(
      ~requested=theme == "" ? None : Some(theme),
      ~reason="Unsupported Terminal Console theme; using cursor-dark.",
    );
  };
};

let theme_of_validation = fun
| Theme_valid(theme) => theme
| Theme_fallback({fallback, _}) => fallback;

let state_dir = home =>
  Filename.concat(Filename.concat(home.Runtime_home.runtime_dir, "state"), "terminal-console");

let settings_path = home => Filename.concat(state_dir(home), "settings.json");

let decode_theme_json = json =>
  switch (json) {
  | `Assoc(fields) =>
    switch (List.assoc_opt("theme", fields)) {
    | Some(`String(theme)) => validate_theme(theme)
    | Some(_) =>
      fallback_theme(
        ~requested=None,
        ~reason="Terminal Console theme state must contain a string theme; using cursor-dark.",
      )
    | None => Theme_valid(default_theme)
    }
  | _ =>
    fallback_theme(
      ~requested=None,
      ~reason="Terminal Console theme state must be a JSON object; using cursor-dark.",
    )
  };

let load_theme = home => {
  let path = settings_path(home);
  if (!Sys.file_exists(path)) {
    Theme_valid(default_theme);
  } else {
    try(Yojson.Safe.from_file(path) |> decode_theme_json) {
    | Yojson.Json_error(msg) =>
      fallback_theme(
        ~requested=None,
        ~reason="Terminal Console theme state could not be parsed: " ++ msg,
      )
    | Sys_error(msg) =>
      fallback_theme(
        ~requested=None,
        ~reason="Terminal Console theme state could not be read: " ++ msg,
      )
    };
  };
};

let save_theme = (home, raw) =>
  switch (validate_theme(raw)) {
  | Theme_valid(theme) =>
    let path = settings_path(home);
    Util.mkdir_p(Filename.dirname(path));
    Util.write_file(
      path,
      Yojson.Safe.pretty_to_string(`Assoc([("theme", `String(theme))])),
    );
    Theme_valid(theme);
  | Theme_fallback(payload) => Theme_fallback(payload)
  };

let digits_only = text =>
  text !== ""
  && String.for_all(
       char =>
         switch (char) {
         | '0' .. '9' => true
         | _ => false
         },
       text,
     );

let validate_port = raw => {
  let value = Util.trim(raw);
  if (value == "") {
    Port_invalid("server.port must not be empty");
  } else if (!digits_only(value)) {
    Port_invalid("server.port must be numeric");
  } else {
    switch (int_of_string_opt(value)) {
    | Some(port) when port >= 1 && port <= 65535 => Port_valid(port)
    | Some(_)
    | None =>
      Port_invalid("server.port must be between 1 and 65535")
    };
  };
};

let rec upsert_assoc = (key, value, fields) =>
  switch (fields) {
  | [] => [(key, value)]
  | [(existing_key, _), ...rest] when existing_key == key => [(key, value), ...rest]
  | [field, ...rest] => [field, ...upsert_assoc(key, value, rest)]
  };

let update_server_port_json = (json, port) =>
  switch (json) {
  | `Assoc(fields) =>
    let server =
      switch (List.assoc_opt("server", fields)) {
      | None
      | Some(`Null) =>
        `Assoc([("port", `Int(port))])
      | Some(`Assoc(server_fields)) =>
        `Assoc(upsert_assoc("port", `Int(port), server_fields))
      | Some(_) =>
        raise(Settings_update_error("settings.json server field must be an object"))
      };
    `Assoc(upsert_assoc("server", server, fields));
  | _ => raise(Settings_update_error("settings.json root must be an object"))
  };

let save_server_port = (~settings_path, raw) =>
  switch (validate_port(raw)) {
  | Port_invalid(reason) => Port_rejected(reason)
  | Port_valid(port) =>
    try({
      let json = Yojson.Safe.from_file(settings_path);
      let updated = update_server_port_json(json, port);
      Util.write_file(settings_path, Yojson.Safe.pretty_to_string(updated));
      Port_updated(port);
    }) {
    | Yojson.Json_error(msg) => Port_update_failed("settings.json parse error: " ++ msg)
    | Sys_error(msg) => Port_update_failed(msg)
    | Settings_update_error(msg) => Port_update_failed(msg)
    }
  };

let save_dashboard_port = (home, raw) =>
  save_server_port(~settings_path=home.Runtime_home.settings_path, raw);
