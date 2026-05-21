  module Open_code = {
    let glyph =
      fun
      | 'o' => ["████", "█  █", "█  █", "█  █", "████"]
      | 'p' => ["███ ", "█  █", "███ ", "█   ", "█   "]
      | 'e' => ["████", "█   ", "███ ", "█   ", "████"]
      | 'n' => ["█  █", "██ █", "█ ██", "█  █", "█  █"]
      | 'c' => ["████", "█   ", "█   ", "█   ", "████"]
      | 'd' => ["███ ", "█  █", "█  █", "█  █", "███ "]
      | 'a' => [" ██ ", "█  █", "████", "█  █", "█  █"]
      | 'g' => ["████", "█   ", "█ ██", "█  █", "████"]
      | 't' => ["████", " ██ ", " ██ ", " ██ ", " ██ "]
      | 'w' => ["█  █", "█  █", "█  █", "████", "█  █"]
      | 'r' => ["███ ", "█  █", "███ ", "█ █ ", "█  █"]
      | 'k' => ["█  █", "█ █ ", "██  ", "█ █ ", "█  █"]
      | 's' => ["████", "█   ", "████", "   █", "████"]
      | 'i' => ["███", " █ ", " █ ", " █ ", "███"]
      | ' ' => ["  ", "  ", "  ", "  ", "  "]
      | _ => ["██", "██", "██", "██", "██"];

    let wordmark = (~id=?, ~style=Style.default, ~design=?, label) => {
      let design = Components_core.resolve_design(design);
      let rows = Array.make(5, "");
      label
      |> String.lowercase_ascii
      |> String.iter(ch =>
           glyph(ch)
           |> List.iteri((i, part) => rows[i] = rows[i] ++ part ++ " ")
         );
      Components_core.box(
        ~id?,
        ~style=
          Style.{
            ...style,
            flex_direction: Column,
          },
        Array.to_list(rows)
        |> List.map(line =>
             Components_core.text(
               ~style=
                 Style.(
                   make(
                     ~fg=Components_core.emphasis_fg_of(design),
                     ~attrs=[Attr.Bold],
                     (),
                   )
                 ),
               line,
             )
           ),
      );
    };

    let model_status =
        (
          ~id=?,
          ~style=Style.default,
          ~design=?,
          ~mode="Build",
          ~model="DeepSeek V4 Pro",
          ~provider="OpenCode Go",
          ~effort="high",
          (),
        ) => {
      let design = Components_core.resolve_design(design);
      Components_core.rich_text(
        ~id?,
        ~style,
        [
          Span.make(
            ~style=
              Style.(
                make(
                  ~fg=
                    Components_core.theme_color(
                      design,
                      Theme.Accent_secondary,
                    ),
                  ~attrs=[Attr.Bold],
                  (),
                )
              ),
            mode,
          ),
          Span.make(
            ~style=Style.(make(~fg=Components_core.muted_fg_of(design), ())),
            " · ",
          ),
          Span.make(
            ~style=
              Style.(
                make(
                  ~fg=Components_core.default_fg_of(design),
                  ~attrs=[Attr.Bold],
                  (),
                )
              ),
            model,
          ),
          Span.make(
            ~style=Style.(make(~fg=Components_core.muted_fg_of(design), ())),
            " " ++ provider ++ " · ",
          ),
          Span.make(
            ~style=
              Style.(
                make(
                  ~fg=
                    Components_core.theme_color(design, Theme.Status_warning),
                  ~attrs=[Attr.Bold],
                  (),
                )
              ),
            effort,
          ),
        ],
      );
    };

    let command_block =
        (
          ~id=?,
          ~tone=Components_core.Accent,
          ~style=Style.default,
          ~design=?,
          command,
        ) => {
      let design_value = Components_core.resolve_design(design);
      Patterns.rule_panel(
        ~id?,
        ~tone,
        ~design?,
        ~style=
          Style.{
            ...style,
            height:
              switch (style.height) {
              | Auto => Cells(4)
              | h => h
              },
          },
        [
          Components_core.text(
            ~style=
              Style.(
                make(~fg=Components_core.default_fg_of(design_value), ())
              ),
            command,
          ),
        ],
      );
    };

    let hint_bar = (~id=?, ~style=Style.default, ~design=?, items) => {
      let design = Components_core.resolve_design(design);
      let spans =
        items
        |> List.concat_map(((key, label)) =>
             [
               Span.make(
                 ~style=
                   Style.(
                     make(
                       ~fg=Components_core.default_fg_of(design),
                       ~attrs=[Attr.Bold],
                       (),
                     )
                   ),
                 key,
               ),
               Span.make(
                 ~style=
                   Style.(make(~fg=Components_core.muted_fg_of(design), ())),
                 " " ++ label ++ "   ",
               ),
             ]
           );

      Components_core.rich_text(~id?, ~style, spans);
    };

    let tip = (~id=?, ~style=Style.default, ~design=?, message) => {
      let design = Components_core.resolve_design(design);
      Components_core.rich_text(
        ~id?,
        ~style,
        [
          Span.make(
            ~style=
              Style.(
                make(
                  ~fg=
                    Components_core.theme_color(design, Theme.Status_warning),
                  ~attrs=[Attr.Bold],
                  (),
                )
              ),
            "● Tip ",
          ),
          Span.make(
            ~style=Style.(make(~fg=Components_core.muted_fg_of(design), ())),
            message,
          ),
        ],
      );
    };
  };
