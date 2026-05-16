let make =
    (
      ~id=?,
      ~tone=Component_design.Info,
      ~title=?,
      ~style=Style.default,
      ~design=?,
      children,
    ) => {
  let design = Component_design.resolve_design(design);
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...
          make(
            ~border=Single,
            ~title?,
            ~border_fg=Component_design.color_of_tone(~design, tone),
            ~padding=spacing_xy(~x=1, ~y=0),
            ~fg=Component_design.default_fg_of(design),
            (),
          ),

        width: style.width,
        height: style.height,
        min_width: style.min_width,
        min_height: style.min_height,
        flex_grow: style.flex_grow,
        margin: style.margin,
        bg: style.bg,
      },
    children,
  );
};
