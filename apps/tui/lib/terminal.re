  type screen_mode =
    | Alternate_screen
    | Main_screen;

  let output = seq => {
    output_string(stdout, seq);
    flush(stdout);
  };

  let enter_alternate = () => output("\027[?1049h\027[?25l");
  let leave_alternate = () => output("\027[?25h\027[?1049l\027[0m");

  let positive_int_env = (env, name) =>
    switch (Option.bind(env(name), int_of_string_opt)) {
    | Some(n) when n > 0 => Some(n)
    | _ => None
    };

  let parse_stty_size = line =>
    switch (
      String.split_on_char(' ', String.trim(line)) |> List.filter((!=)(""))
    ) {
    | [rows, columns] =>
      switch (int_of_string_opt(columns), int_of_string_opt(rows)) {
      | (Some(width), Some(height)) when width > 0 && height > 0 =>
        Some((width, height))
      | _ => None
      }
    | _ => None
    };

  let query_tty_size = () => {
    let channel = Unix.open_process_in("stty size < /dev/tty 2>/dev/null");
    Fun.protect(
      ~finally=() => ignore(Unix.close_process_in(channel)),
      () =>
        switch (input_line(channel)) {
        | line => parse_stty_size(line)
        | exception End_of_file => None
        },
    );
  };

  let viewport = (~env=Sys.getenv_opt, ~fallback_to_tty=true, ()) =>
    switch (
      positive_int_env(env, "COLUMNS"),
      positive_int_env(env, "LINES"),
    ) {
    | (Some(width), Some(height)) => Viewport.make(~width, ~height)
    | _ =>
      switch (
        if (fallback_to_tty) {
          query_tty_size();
        } else {
          None;
        }
      ) {
      | Some((width, height)) => Viewport.make(~width, ~height)
      | None => Viewport.make(~width=80, ~height=24)
      }
    };

  let size = (~env=?, ~fallback_to_tty=?, ()) =>
    Viewport.size(viewport(~env?, ~fallback_to_tty?, ()));
  let columns = (~env=?, ~fallback_to_tty=?, ()) =>
    viewport(~env?, ~fallback_to_tty?, ()).width;
  let rows = (~env=?, ~fallback_to_tty=?, ()) =>
    viewport(~env?, ~fallback_to_tty?, ()).height;
  let is_interactive = (~fd=Unix.stdout, ()) =>
    try(Unix.isatty(fd)) {
    | Unix.Unix_error(_) => false
    };
  let color_level = (~env=Sys.getenv_opt, ()) =>
    Color.detect_level(~env, ());
  let supports_color = (~env=?, ()) =>
    color_level(~env?, ()) != Color.No_color;

  let with_raw = (fd, f) => {
    let original = Unix.tcgetattr(fd);
    let raw = {
      ...original,
      Unix.c_icanon: false,
      c_echo: false,
      c_vmin: 1,
      c_vtime: 0,
    };
    Fun.protect(
      ~finally=() => Unix.tcsetattr(fd, Unix.TCSANOW, original),
      () => {
        Unix.tcsetattr(fd, Unix.TCSANOW, raw);
        f();
      },
    );
  };
