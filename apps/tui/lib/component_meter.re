let make =
    (
      ~id=?,
      ~tone=Component_design.Info,
      ~style=Style.default,
      ~design=?,
      ~label,
      ~value=?,
      fraction,
    ) => {
  let design = Component_design.resolve_design(design);
  let accent = Component_design.color_of_tone(~design, tone);
  let value =
    switch (value) {
    | Some(value) => value
    | None => Printf.sprintf("%3.0f%%", max(0., min(1., fraction)) *. 100.)
    };

  Node.box(
    ~id?,
    ~style=
      Style.{
        ...
          make(~flex_direction=Column, ~gap=1, ~height=Cells(3), ()),

        width: style.width,
        margin: style.margin,
        flex_grow: style.flex_grow,
      },
    [
      Node.rich_text([
        Span.make(
          ~style=
            Style.(
              make(
                ~fg=Component_design.muted_fg_of(design),
                ~attrs=[Attr.Dim],
                (),
              )
            ),
          label ++ " ",
        ),
        Span.make(
          ~style=Style.(make(~fg=accent, ~attrs=[Attr.Bold], ())),
          value,
        ),
      ]),
      Node.progress_bar(
        ~style=Style.(make(~height=Cells(1), ~fg=accent, ())),
        fraction,
      ),
    ],
  );
};
