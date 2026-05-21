  type t = {
    text: string,
    style: Style.t,
  };
  let make = (~style=Style.default, text) => {
    text,
    style,
  };
  let plain = text => make(text);
