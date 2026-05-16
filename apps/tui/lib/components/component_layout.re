let row = (~id=?, ~style=Style.default, ~gap=1, children) =>
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...style,
        flex_direction: Row,
        gap,
      },
    children,
  );

let column = (~id=?, ~style=Style.default, ~gap=0, children) =>
  Node.box(
    ~id?,
    ~style=
      Style.{
        ...style,
        flex_direction: Column,
        gap,
      },
    children,
  );
