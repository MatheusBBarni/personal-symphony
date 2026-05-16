let make =
    (
      ~id=?,
      ~tone=Component_design.Neutral,
      ~width=32,
      ~title=?,
      ~char="─",
      ~style=Style.default,
      ~design=?,
      (),
    ) => {
  let design = Component_design.resolve_design(design);
  let line =
    switch (title) {
    | None => Component_table.repeat(char, width)
    | Some(title) =>
      let title = " " ++ title ++ " ";
      let rest = max(0, width - Utf.string_width(title));
      Component_table.fit(
        width,
        Component_table.repeat(char, rest / 2)
        ++ title
        ++ Component_table.repeat(char, rest - rest / 2),
      );
    };

  Node.text(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~fg=Component_design.color_of_tone(~design, tone),
            ~attrs=[Attr.Dim],
            (),
          ),

        margin: style.margin,
        width: style.width,
      },
    line,
  );
};
