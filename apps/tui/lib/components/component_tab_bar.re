let make = (~id=?, ~style=Style.default, ~design=?, tabs) => {
  let design = Component_design.resolve_design(design);
  let tab = ((label, active)) => {
    let fg =
      if (active) {
        Component_design.emphasis_fg_of(design);
      } else {
        Component_design.muted_fg_of(design);
      };
    let attrs =
      if (active) {
        [Attr.Bold, Attr.Underline];
      } else {
        [Attr.Dim];
      };
    Node.text(~style=Style.(make(~fg, ~attrs, ())), label);
  };

  Node.box(
    ~id?,
    ~style=
      Style.{
        ...make(~height=Cells(1), ~flex_direction=Row, ~gap=2, ()),

        width: style.width,
        margin: style.margin,
      },
    List.map(tab, tabs),
  );
};
