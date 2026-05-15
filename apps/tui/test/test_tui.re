open Tui;

let contains_sub = (haystack, needle) => {
  let haystack_len = String.length(haystack);
  let needle_len = String.length(needle);
  let rec loop = index =>
    index
    + needle_len <= haystack_len
    && (String.sub(haystack, index, needle_len) == needle || loop(index + 1));

  needle_len == 0 || loop(0);
};

let plain_snapshot = () => {
  let root =
    box(
      ~style=
        Style.(
          make(
            ~border=Single,
            ~title="Hi",
            ~padding=spacing_all(1),
            ~width=Cells(12),
            ~height=Cells(5),
            (),
          )
        ),
      [text("OCaml")],
    );

  let renderer = Renderer.create(~width=12, ~height=5, root);
  Alcotest.(check(string))(
    "box snapshot",
    "┌─ Hi ─────┐\n│          │\n│ OCaml    │\n│          │\n└──────────┘",
    Renderer.render_to_string(renderer),
  );
};

let flex_row_layout = () => {
  let left =
    box(
      ~style=Style.(make(~flex_grow=1., ~bg=Color.ansi(1), ())),
      [text("L")],
    );
  let right = box(~style=Style.(make(~width=Cells(5), ())), [text("R")]);
  let root =
    box(
      ~style=
        Style.(
          make(~flex_direction=Row, ~width=Cells(10), ~height=Cells(1), ())
        ),
      [left, right],
    );
  let renderer = Renderer.create(~width=10, ~height=1, root);
  Alcotest.(check(string))(
    "row text placement",
    "L    R    ",
    Renderer.render_to_string(renderer),
  );
};

let input_editing = () => {
  let field = input(~id="field", ~value="ab", ());
  let renderer = Renderer.create(~width=8, ~height=1, field);
  Renderer.dispatch_key(renderer, Key.of_sequence("c")) |> ignore;
  Renderer.dispatch_key(renderer, Key.of_sequence("")) |> ignore;
  switch (Node.find_by_id("field", renderer.Renderer.root)) {
  | Some({ kind: Input(state), _ }) =>
    Alcotest.(check(string))("value", "ab", state.value)
  | _ => Alcotest.fail("input not found")
  };
};

let select_navigation = () => {
  let menu =
    select(
      ~id="menu",
      ~wrap=true,
      [option("One"), option("Two"), option("Three")],
    );

  let renderer = Renderer.create(~width=20, ~height=3, menu);
  Renderer.dispatch_key(renderer, Key.of_sequence("k")) |> ignore;
  switch (Node.find_by_id("menu", renderer.Renderer.root)) {
  | Some({ kind: Select(state), _ }) =>
    Alcotest.(check(int))("wrapped selection", 2, state.selected)
  | _ => Alcotest.fail("select not found")
  };
};

let scrollbox_keyboard_routing = () => {
  let scroller =
    scroll_box(
      ~id="scroll",
      ~style=Style.(make(~width=Cells(8), ~height=Cells(2), ())),
      [text("A"), text("B"), text("C")],
    );

  let renderer = Renderer.create(~width=8, ~height=2, scroller);
  Renderer.dispatch_key(renderer, Key.of_sequence("\027[B")) |> ignore;
  switch (Node.find_by_id("scroll", renderer.Renderer.root)) {
  | Some({ kind: Scroll_box(state), _ }) =>
    Alcotest.(check(int))("scroll y", 1, state.scroll_y);
    Alcotest.(check(string))(
      "scrolled snapshot",
      "B       \nC       ",
      Renderer.render_to_string(renderer),
    );
  | _ => Alcotest.fail("scrollbox not found")
  };
};

let key_parses_arrows = () => {
  let key = Key.of_sequence("\027[A");
  Alcotest.(check(string))("name", "up", key.name);
  Alcotest.(check(bool))("ctrl", false, key.ctrl);
};

let keymap_sequence = () => {
  let keymap = Keymap.create();
  let fired = ref(false);
  Keymap.register(keymap, ~key="dd", ~name="delete-line", ~run=() =>
    fired := true
  );
  Alcotest.(check(bool))(
    "pending",
    true,
    Keymap.dispatch(keymap, Key.of_sequence("d")) == Keymap.Pending,
  );
  Alcotest.(check(bool))(
    "handled",
    true,
    switch (Keymap.dispatch(keymap, Key.of_sequence("d"))) {
    | Keymap.Handled("delete-line") => true
    | _ => false
    },
  );
  Alcotest.(check(bool))("ran command", true, fired^);
};

let surface_ansi_respects_no_color = () => {
  let level =
    Color.detect_level(
      ~env=
        fun
        | "NO_COLOR" => Some("1")
        | _ => None,
      (),
    );
  let surface = Surface.create(~width=2, ~height=1, ());
  Surface.set(
    surface,
    ~x=0,
    ~y=0,
    ~style=Style.(make(~fg=Color.ansi(1), ())),
    "x",
  );
  Alcotest.(check(string))(
    "plain when no color",
    "x ",
    Surface.to_ansi(~level, surface),
  );
};

let utf_width_helpers_handle_unicode = () => {
  Alcotest.(check(int))("ascii width", 5, Utf.string_width("hello"));
  Alcotest.(check(int))("wide width", 2, Utf.string_width("界"));
  Alcotest.(check(int))("combining mark width", 1, Utf.string_width("é"));
  Alcotest.(check(string))(
    "utf8 encoding 2-byte",
    "é",
    Utf.uchar_to_utf8(Uchar.of_int(0x00E9)),
  );
  Alcotest.(check(string))(
    "utf8 encoding 3-byte",
    "界",
    Utf.uchar_to_utf8(Uchar.of_int(0x754C)),
  );
  Alcotest.(check(string))(
    "utf8 encoding 4-byte",
    "😀",
    Utf.uchar_to_utf8(Uchar.of_int(0x1F600)),
  );
};

let table_component_fits_unicode = () => {
  let root = Components.table([("COL", 3)], [["abcdef"]]);
  let renderer = Renderer.create(~width=10, ~height=3, root);
  Alcotest.(check(string))(
    "table snapshot",
    "COL       \n───       \nab…       ",
    Renderer.render_to_string(renderer),
  );
};

let dashboard_components_render = () => {
  let root =
    Patterns.app_shell(
      ~title="Ops",
      ~badges=[(Components.Success, "live")],
      [
        Components.row([
          Patterns.metric_card(
            ~label="CPU",
            ~value="67%",
            ~progress=0.67,
            (),
          ),
          Components.panel(
            "Events",
            [
              Patterns.log_feed([
                ("12:00", "INFO", "started"),
                ("12:01", "OK", "ready"),
              ]),
            ],
          ),
        ]),
      ],
    );

  let output =
    Renderer.render_to_string(Renderer.create(~width=64, ~height=12, root));
  Alcotest.(check(bool))(
    "contains title",
    true,
    String.contains(output, 'O'),
  );
  Alcotest.(check(bool))(
    "contains metric",
    true,
    String.contains(output, 'C'),
  );
};

let vertical_rule_fills_height = () => {
  let root = vertical_rule(~style=Style.(make(~height=Cells(3), ())), ());
  let output =
    Renderer.render_to_string(Renderer.create(~width=2, ~height=3, root));
  Alcotest.(check(string))("rule", "│ \n│ \n│ ", output);
};

let opencode_helpers_render = () => {
  let root =
    box([
      Presets.Open_code.wordmark("opencode"),
      Patterns.rule_panel([
        Presets.Open_code.model_status(),
        Presets.Open_code.hint_bar([
          ("tab", "agents"),
          ("ctrl+p", "commands"),
        ]),
      ]),
    ]);

  let output =
    Renderer.render_to_string(Renderer.create(~width=80, ~height=10, root));
  Alcotest.(check(bool))("has rule", true, contains_sub(output, "│"));
  Alcotest.(check(bool))(
    "has model status",
    true,
    String.contains(output, 'B'),
  );
};

let modal_component_renders_overlay = () => {
  let root =
    box(
      ~style=Style.(make(~width=Cells(40), ~height=Cells(12), ())),
      [
        text("background"),
        Patterns.modal(
          ~id="help-modal",
          ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
          "Commands",
          [text("q quit"), text("? close")],
        ),
      ],
    );

  let renderer = Renderer.create(~width=40, ~height=12, root);
  let output = Renderer.render_to_string(renderer);
  Alcotest.(check(bool))(
    "modal node exists",
    true,
    Option.is_some(Node.find_by_id("help-modal", renderer.root)),
  );
  Alcotest.(check(bool))(
    "contains title",
    true,
    contains_sub(output, "Commands"),
  );
  Alcotest.(check(bool))(
    "contains body",
    true,
    contains_sub(output, "q quit"),
  );
};

let viewport_helpers = () => {
  let tiny = Viewport.make(~width=40, ~height=12);
  let compact = Viewport.make(~width=72, ~height=22);
  let regular = Viewport.make(~width=96, ~height=24);
  let wide = Viewport.make(~width=132, ~height=38);
  Alcotest.(check(int))(
    "width clamped",
    1,
    Viewport.make(~width=0, ~height=0).width,
  );
  Alcotest.(check(int))("area", 132 * 38, Viewport.area(wide));
  Alcotest.(check(bool))(
    "fits",
    true,
    Viewport.fits(~min_width=80, ~min_height=24, wide),
  );
  Alcotest.(check(bool))(
    "tiny",
    true,
    Viewport.breakpoint(tiny) == Viewport.Tiny,
  );
  Alcotest.(check(bool))(
    "compact",
    true,
    Viewport.breakpoint(compact) == Viewport.Compact,
  );
  Alcotest.(check(bool))(
    "regular",
    true,
    Viewport.breakpoint(regular) == Viewport.Regular,
  );
  Alcotest.(check(bool))(
    "wide",
    true,
    Viewport.breakpoint(wide) == Viewport.Wide,
  );
  Alcotest.(check(string))(
    "choose",
    "wide",
    Viewport.choose(
      wide,
      ~tiny="tiny",
      ~compact="compact",
      ~regular="regular",
      ~wide="wide",
    ),
  );
};

let terminal_viewport_uses_env = () => {
  let env =
    fun
    | "COLUMNS" => Some("120")
    | "LINES" => Some("40")
    | _ => None;
  let viewport = Terminal.viewport(~env, ~fallback_to_tty=false, ());
  Alcotest.(check(int))("columns", 120, viewport.width);
  Alcotest.(check(int))("rows", 40, viewport.height);
  Alcotest.(check(pair(int, int)))(
    "size",
    (120, 40),
    Terminal.size(~env, ~fallback_to_tty=false, ()),
  );
  Alcotest.(check(int))(
    "columns helper",
    120,
    Terminal.columns(~env, ~fallback_to_tty=false, ()),
  );
  Alcotest.(check(int))(
    "rows helper",
    40,
    Terminal.rows(~env, ~fallback_to_tty=false, ()),
  );
  let invalid_env =
    fun
    | "COLUMNS" => Some("0")
    | "LINES" => Some("wat")
    | _ => None;
  Alcotest.(check(pair(int, int)))(
    "fallback size",
    (80, 24),
    Terminal.size(~env=invalid_env, ~fallback_to_tty=false, ()),
  );
};

let renderer_viewport_and_resize = () => {
  let renderer = Renderer.create(~width=10, ~height=5, text("x"));
  Alcotest.(check(pair(int, int)))(
    "initial renderer size",
    (10, 5),
    Renderer.size(renderer),
  );
  Renderer.resize(renderer, ~width=30, ~height=9);
  Alcotest.(check(pair(int, int)))(
    "resized renderer",
    (30, 9),
    Renderer.size(renderer),
  );
  Renderer.resize_to_viewport(renderer, Viewport.make(~width=20, ~height=7));
  Alcotest.(check(pair(int, int)))(
    "viewport resize",
    (20, 7),
    Renderer.size(renderer),
  );
  Renderer.resize(renderer, ~width=0, ~height=0);
  Alcotest.(check(pair(int, int)))(
    "resize clamps",
    (1, 1),
    Renderer.size(renderer),
  );
};

let component_design_injects_theme = () => {
  let theme =
    fun
    | Theme.Fg_default => Color.ansi(1)
    | Theme.Fg_muted => Color.ansi(2)
    | Theme.Fg_emphasis => Color.ansi(3)
    | Theme.Bg_base => Color.ansi(4)
    | Theme.Bg_surface => Color.ansi(5)
    | Theme.Bg_overlay => Color.ansi(6)
    | Theme.Bg_selection => Color.ansi(7)
    | Theme.Accent_primary => Color.ansi(8)
    | Theme.Accent_secondary => Color.ansi(9)
    | Theme.Status_error => Color.ansi(10)
    | Theme.Status_warning => Color.ansi(11)
    | Theme.Status_success => Color.ansi(12)
    | Theme.Status_info => Color.ansi(13);

  let design = Components.make_design(~theme, ());
  let root =
    Components.badge(~id="badge", ~tone=Components.Success, ~design, "ok");
  switch (Node.find_by_id("badge", root)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "uses custom success color",
      true,
      node.style.fg == Some(Color.ansi(12)),
    )
  | None => Alcotest.fail("badge not found")
  };
  let light_design = Components.make_design(~theme=Theme.light, ());
  let light =
    Components.badge(
      ~id="light-badge",
      ~tone=Components.Success,
      ~design=light_design,
      "ok",
    );
  switch (Node.find_by_id("light-badge", light)) {
  | Some(node) =>
    Alcotest.(check(bool))(
      "uses light success color",
      true,
      node.style.fg == Some(Theme.light(Theme.Status_success)),
    )
  | None => Alcotest.fail("light badge not found")
  };
};

let app_shell_default_is_neutral = () => {
  let output =
    Renderer.render_to_string(
      Renderer.create(~width=32, ~height=6, Patterns.app_shell([])),
    );
  Alcotest.(check(bool))(
    "default app title",
    true,
    contains_sub(output, "App"),
  );
  Alcotest.(check(bool))(
    "no product title",
    false,
    contains_sub(output, "Symphony TUI"),
  );
};

let opencode_preset_has_moved_helper = () => {
  let root = Presets.Open_code.model_status();
  let output =
    Renderer.render_to_string(Renderer.create(~width=80, ~height=1, root));
  Alcotest.(check(bool))(
    "preset renders default model",
    true,
    contains_sub(output, "DeepSeek V4 Pro"),
  );
};

let component_compat_aliases_render = () => {
  let root =
    box([
      Components.header(~subtitle="keeps old call sites working", "Compat"),
      Components.modal(
        ~id="compat-modal",
        ~style=Style.(make(~width=Cells(24), ~height=Cells(7), ())),
        "Help",
        [text("q quit")],
      ),
      Components.model_status(),
    ]);

  let renderer = Renderer.create(~width=48, ~height=12, root);
  let output = Renderer.render_to_string(renderer);
  Alcotest.(check(bool))(
    "modal alias node exists",
    true,
    Option.is_some(Node.find_by_id("compat-modal", renderer.root)),
  );
  Alcotest.(check(bool))(
    "header alias renders",
    true,
    contains_sub(output, "Compat"),
  );
  Alcotest.(check(bool))(
    "preset alias renders",
    true,
    contains_sub(output, "DeepSeek V4 Pro"),
  );
};

let () =
  Alcotest.run(
    "tui",
    [
      (
        "render",
        [
          Alcotest.test_case("plain snapshot", `Quick, plain_snapshot),
          Alcotest.test_case("flex row", `Quick, flex_row_layout),
        ],
      ),
      (
        "widgets",
        [
          Alcotest.test_case("input editing", `Quick, input_editing),
          Alcotest.test_case("select navigation", `Quick, select_navigation),
          Alcotest.test_case(
            "scrollbox routing",
            `Quick,
            scrollbox_keyboard_routing,
          ),
        ],
      ),
      (
        "keys",
        [
          Alcotest.test_case("sequence", `Quick, keymap_sequence),
          Alcotest.test_case("arrow parser", `Quick, key_parses_arrows),
        ],
      ),
      (
        "ansi",
        [
          Alcotest.test_case(
            "no color",
            `Quick,
            surface_ansi_respects_no_color,
          ),
        ],
      ),
      (
        "utf",
        [
          Alcotest.test_case(
            "unicode width helpers",
            `Quick,
            utf_width_helpers_handle_unicode,
          ),
        ],
      ),
      (
        "components",
        [
          Alcotest.test_case(
            "table unicode fit",
            `Quick,
            table_component_fits_unicode,
          ),
          Alcotest.test_case(
            "dashboard render",
            `Quick,
            dashboard_components_render,
          ),
          Alcotest.test_case(
            "vertical rule",
            `Quick,
            vertical_rule_fills_height,
          ),
          Alcotest.test_case(
            "opencode helpers",
            `Quick,
            opencode_helpers_render,
          ),
          Alcotest.test_case(
            "modal overlay",
            `Quick,
            modal_component_renders_overlay,
          ),
          Alcotest.test_case(
            "design injection",
            `Quick,
            component_design_injects_theme,
          ),
          Alcotest.test_case(
            "neutral app shell default",
            `Quick,
            app_shell_default_is_neutral,
          ),
          Alcotest.test_case(
            "opencode preset helper",
            `Quick,
            opencode_preset_has_moved_helper,
          ),
          Alcotest.test_case(
            "compat aliases",
            `Quick,
            component_compat_aliases_render,
          ),
        ],
      ),
      (
        "viewport",
        [
          Alcotest.test_case("helpers", `Quick, viewport_helpers),
          Alcotest.test_case(
            "terminal env",
            `Quick,
            terminal_viewport_uses_env,
          ),
          Alcotest.test_case(
            "renderer resize",
            `Quick,
            renderer_viewport_and_resize,
          ),
        ],
      ),
    ],
  );
