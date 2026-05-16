let make =
    (
      ~id=?,
      ~tone=Component_design.Neutral,
      ~style=Style.default,
      ~design=?,
      label,
    ) => {
  let design = Component_design.resolve_design(design);
  let fg = Component_design.color_of_tone(~design, tone);
  let bg = Component_design.theme_color(design, Theme.Bg_selection);
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~height=Cells(1),
            ~padding=spacing_xy(~x=1, ~y=0),
            ~fg,
            ~bg,
            ~attrs=[Attr.Bold],
            (),
          ),

        margin: style.margin,
        width: style.width,
      },
    [Node.text(~style=Style.(make(~fg, ~bg, ~attrs=[Attr.Bold], ())), label)],
  );
};
