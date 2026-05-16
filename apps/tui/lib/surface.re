  type cell = {
    text: string,
    style: Style.t,
  };
  type t = {
    width: int,
    height: int,
    cells: array(cell),
  };

  let blank = (~style=Style.default, ()) => {
    text: " ",
    style,
  };
  let create = (~style=Style.default, ~width, ~height, ()) => {
    width,
    height,
    cells: Array.make(width * height, blank(~style, ())),
  };
  let bounds = t =>
    Geometry.rect(~x=0, ~y=0, ~width=t.width, ~height=t.height);
  let index = (t, x, y) => y * t.width + x;
  let in_bounds = (t, x, y) =>
    x >= 0 && y >= 0 && x < t.width && y < t.height;

  let set = (~clip=?, t, ~x, ~y, ~style, text) => {
    let clip = Option.value(~default=bounds(t), clip);
    if (in_bounds(t, x, y) && Geometry.contains(clip, x, y)) {
      t.cells[index(t, x, y)] = {
        text,
        style,
      };
    };
  };

  let get = (t, ~x, ~y) =>
    if (in_bounds(t, x, y)) {
      Some(t.cells[index(t, x, y)]);
    } else {
      None;
    };

  let fill_rect = (~clip=?, t, rect, ~style) => {
    let clip =
      Option.value(~default=bounds(t), clip) |> Geometry.intersect(rect);
    for (y in clip.y to Geometry.bottom(clip) - 1) {
      for (x in clip.x to Geometry.right(clip) - 1) {
        set(t, ~x, ~y, ~style, " ");
      };
    };
  };

  let write = (~clip=?, t, ~x, ~y, ~style, text) => {
    let start_x = x;
    let cx = ref(x);
    let cy = ref(y);
    let put = (text, width) =>
      if (width > 0) {
        set(~clip?, t, ~x=cx^, ~y=cy^, ~style, text);
        if (width == 2) {
          set(~clip?, t, ~x=cx^ + 1, ~y=cy^, ~style, " ");
        };
        cx := cx^ + width;
      };

    Uutf.String.fold_utf_8(
      ((), _, value) =>
        switch (value) {
        | `Uchar(u) when Uchar.to_int(u) == 0x0A =>
          cx := start_x;
          incr(cy);
        | `Uchar(u) =>
          let width = Utf.uchar_width(u);
          put(Utf.uchar_to_utf8(u), width);
        | `Malformed(_) => put("?", 1)
        },
      (),
      text,
    );
    (cx^, cy^);
  };

  let to_plain = t => {
    let out = Stdlib.Buffer.create(t.width * t.height);
    for (y in 0 to t.height - 1) {
      for (x in 0 to t.width - 1) {
        Stdlib.Buffer.add_string(out, t.cells[index(t, x, y)].text);
      };
      if (y < t.height - 1) {
        Stdlib.Buffer.add_char(out, '\n');
      };
    };
    Stdlib.Buffer.contents(out);
  };

  let to_ansi = (~level=Color.detect_level(), t) =>
    if (level == Color.No_color) {
      to_plain(t);
    } else {
      let out = Stdlib.Buffer.create(t.width * t.height * 2);
      let current = ref(None);
      for (y in 0 to t.height - 1) {
        for (x in 0 to t.width - 1) {
          let cell = t.cells[index(t, x, y)];
          switch (current^) {
          | Some(style) when Style.paint_equal(style, cell.style) => ()
          | _ =>
            Stdlib.Buffer.add_string(out, Style.to_ansi(~level, cell.style));
            current := Some(cell.style);
          };
          Stdlib.Buffer.add_string(out, cell.text);
        };
        if (y < t.height - 1) {
          Stdlib.Buffer.add_char(out, '\n');
        };
      };
      Stdlib.Buffer.add_string(out, "\027[0m");
      Stdlib.Buffer.contents(out);
    };

  let diff_to_ansi = (~level=Color.detect_level(), before, after) => {
    let out = Stdlib.Buffer.create(256);
    for (y in 0 to min(before.height, after.height) - 1) {
      for (x in 0 to min(before.width, after.width) - 1) {
        let a = before.cells[index(before, x, y)];
        let b = after.cells[index(after, x, y)];
        if (a.text != b.text || !Style.paint_equal(a.style, b.style)) {
          Stdlib.Buffer.add_string(
            out,
            Printf.sprintf("\027[%d;%dH", y + 1, x + 1),
          );
          Stdlib.Buffer.add_string(out, Style.to_ansi(~level, b.style));
          Stdlib.Buffer.add_string(out, b.text);
        };
      };
    };
    Stdlib.Buffer.add_string(out, "\027[0m");
    Stdlib.Buffer.contents(out);
  };
