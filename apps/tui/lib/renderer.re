  type config = {
    exit_on_ctrl_c: bool,
    target_fps: int,
    screen_mode: Terminal.screen_mode,
  };

  type t = {
    mutable root: Node.t,
    mutable width: int,
    mutable height: int,
    config,
    mutable previous: option(Surface.t),
    mutable focused_id: option(string),
    keymap: Keymap.t,
    mutable destroyed: bool,
  };

  let default_config = {
    exit_on_ctrl_c: true,
    target_fps: 30,
    screen_mode: Terminal.Alternate_screen,
  };

  let create = (~width=?, ~height=?, ~config=default_config, root) => {
    let (width, height) =
      switch (width, height) {
      | (Some(w), Some(h)) => (w, h)
      | _ => Terminal.size()
      };

    let focused_id = Node.focus_first(root);
    {
      root,
      width,
      height,
      config,
      previous: None,
      focused_id,
      keymap: Keymap.create(),
      destroyed: false,
    };
  };

  let set_root = (t, root) => {
    t.root = root;
    t.focused_id = Node.focus_first(root);
    t.previous = None;
  };

  let viewport = t => Viewport.make(~width=t.width, ~height=t.height);
  let size = t => Viewport.size(viewport(t));

  let resize = (t, ~width, ~height) => {
    let width = max(1, width);
    let height = max(1, height);
    if (t.width != width || t.height != height) {
      t.width = width;
      t.height = height;
      t.previous = None;
    };
  };

  let resize_to_viewport = (t, viewport) =>
    resize(
      t,
      ~width=viewport.Viewport.width,
      ~height=viewport.Viewport.height,
    );
  let resize_to_terminal = (~env=?, ~fallback_to_tty=?, t) =>
    resize_to_viewport(t, Terminal.viewport(~env?, ~fallback_to_tty?, ()));

  let focus = (t, id) =>
    if (Node.set_focus(t.root, id)) {
      t.focused_id = Some(id);
    };
  let focus_next = t => t.focused_id = Node.focus_next(t.root, t.focused_id);
  let request_render = t =>
    Render.render(t.root, ~width=t.width, ~height=t.height);
  let render_to_string = (~ansi=false, t) => {
    let surface = request_render(t);
    if (ansi) {
      Surface.to_ansi(surface);
    } else {
      Surface.to_plain(surface);
    };
  };

  let render = t => {
    let next = request_render(t);
    let output =
      switch (t.previous) {
      | None => "\027[H" ++ Surface.to_ansi(next)
      | Some(previous) => Surface.diff_to_ansi(previous, next)
      };

    output_string(stdout, output);
    flush(stdout);
    t.previous = Some(next);
  };

  let dispatch_key = (t, key) =>
    if (t.config.exit_on_ctrl_c && key.Key.ctrl && key.name == "c") {
      t.destroyed = true;
      true;
    } else if (key.name == "tab") {
      focus_next(t);
      true;
    } else {
      switch (Option.bind(t.focused_id, id => Node.find_by_id(id, t.root))) {
      | Some(node) when Node.handle_key(node, key) => true
      | _ =>
        switch (Keymap.dispatch(t.keymap, key)) {
        | Keymap.Handled(_)
        | Pending => true
        | Unhandled => false
        }
      };
    };

  let destroy = t => t.destroyed = true;

  let run = t => {
    let fd = Unix.descr_of_in_channel(stdin);
    let frame_delay =
      if (t.config.target_fps <= 0) {
        0.033;
      } else {
        1. /. float(t.config.target_fps);
      };
    Fun.protect(
      ~finally=
        () =>
          if (t.config.screen_mode == Terminal.Alternate_screen) {
            Terminal.leave_alternate();
          },
      () => {
        if (t.config.screen_mode == Terminal.Alternate_screen) {
          Terminal.enter_alternate();
        };
        Terminal.with_raw(
          fd,
          () => {
            render(t);
            while (!t.destroyed) {
              switch (Key.read(fd)) {
              | Some(key) => ignore(dispatch_key(t, key))
              | None => ()
              };
              render(t);
              Unix.sleepf(frame_delay);
            };
          },
        );
      },
    );
  };
