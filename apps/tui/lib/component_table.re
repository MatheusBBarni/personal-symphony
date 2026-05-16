let repeat = (s, n) =>
  if (n <= 0) {
    "";
  } else {
    String.concat("", List.init(n, _ => s));
  };

let fit = (width, text) =>
  if (width <= 0) {
    "";
  } else {
    let text_width = Utf.string_width(text);
    if (text_width <= width) {
      text ++ String.make(width - text_width, ' ');
    } else {
      let limit = max(0, width - 1);
      let used = ref(0);
      let out = Stdlib.Buffer.create(width);
      Uutf.String.fold_utf_8(
        ((), _, value) =>
          switch (value) {
          | `Uchar(u) =>
            let cell_width = Utf.uchar_width(u);
            if (used^ + cell_width <= limit) {
              Stdlib.Buffer.add_string(out, Utf.uchar_to_utf8(u));
              used := used^ + cell_width;
            };
          | `Malformed(_) =>
            if (used^ + 1 <= limit) {
              Stdlib.Buffer.add_char(out, '?');
              incr(used);
            }
          },
        (),
        text,
      );
      let clipped = Stdlib.Buffer.contents(out) ++ "…";
      clipped ++ String.make(max(0, width - Utf.string_width(clipped)), ' ');
    };
  };

let make =
    (
      ~id=?,
      ~style=Style.default,
      ~header_tone=Component_design.Accent,
      ~design=?,
      columns,
      rows,
    ) => {
  let design = Component_design.resolve_design(design);
  let widths = List.map(snd, columns);
  let line = cells =>
    List.map2((width, cell) => fit(width, cell), widths, cells)
    |> String.concat("  ");

  let header_style =
    Style.(
      make(
        ~fg=Component_design.color_of_tone(~design, header_tone),
        ~attrs=[Attr.Bold],
        (),
      )
    );
  let row_style =
    Style.(make(~fg=Component_design.default_fg_of(design), ()));
  let header = Node.text(~style=header_style, line(List.map(fst, columns)));
  let divider =
    Node.text(
      ~style=
        Style.(
          make(~fg=Component_design.muted_fg_of(design), ~attrs=[Attr.Dim], ())
        ),
      line(List.map(((_, width)) => repeat("─", width), columns)),
    );

  let body = rows |> List.map(cells => Node.text(~style=row_style, line(cells)));
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...style,
        flex_direction: Column,
      },
    [header, divider, ...body],
  );
};
