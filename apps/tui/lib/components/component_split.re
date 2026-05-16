let make = (~id=?, ~style=Style.default, ~left_width=32, left, right) =>
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...style,
        flex_direction: Row,
        gap: 1,
      },
    [
      Node.box(
        ~style=Style.(make(~width=Cells(left_width), ~height=Percent(1.), ())),
        left,
      ),
      Node.box(
        ~style=Style.(make(~flex_grow=1., ~height=Percent(1.), ())),
        right,
      ),
    ],
  );
