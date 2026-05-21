let uchar_to_utf8 = u => {
  let n = Uchar.to_int(u);
  if (n <= 0x7F) {
    String.make(1, Char.chr(n));
  } else if (n <= 0x7FF) {
    String.init(
      2,
      fun
      | 0 => Char.chr(0xC0 lor n lsr 6)
      | _ => Char.chr(0x80 lor (n land 0x3F)),
    );
  } else if (n <= 0xFFFF) {
    String.init(
      3,
      fun
      | 0 => Char.chr(0xE0 lor n lsr 12)
      | 1 => Char.chr(0x80 lor (n lsr 6 land 0x3F))
      | _ => Char.chr(0x80 lor (n land 0x3F)),
    );
  } else {
    String.init(
      4,
      fun
      | 0 => Char.chr(0xF0 lor n lsr 18)
      | 1 => Char.chr(0x80 lor (n lsr 12 land 0x3F))
      | 2 => Char.chr(0x80 lor (n lsr 6 land 0x3F))
      | _ => Char.chr(0x80 lor (n land 0x3F)),
    );
  };
};

let is_combining = n =>
  n >= 0x0300
  && n <= 0x036F
  || n >= 0x1AB0
  && n <= 0x1AFF
  || n >= 0x1DC0
  && n <= 0x1DFF
  || n >= 0x20D0
  && n <= 0x20FF
  || n >= 0xFE20
  && n <= 0xFE2F;

let is_wide = n =>
  n >= 0x1100
  && n <= 0x115F
  || n == 0x2329
  || n == 0x232A
  || n >= 0x2E80
  && n <= 0xA4CF
  || n >= 0xAC00
  && n <= 0xD7A3
  || n >= 0xF900
  && n <= 0xFAFF
  || n >= 0xFE10
  && n <= 0xFE19
  || n >= 0xFE30
  && n <= 0xFE6F
  || n >= 0xFF00
  && n <= 0xFF60
  || n >= 0xFFE0
  && n <= 0xFFE6
  || n >= 0x1F300
  && n <= 0x1FAFF;

let uchar_width = u => {
  let n = Uchar.to_int(u);
  if (n == 0 || n < 32 || n >= 0x7F && n < 0xA0 || is_combining(n)) {
    0;
  } else if (is_wide(n)) {
    2;
  } else {
    1;
  };
};

let string_width = s =>
  Uutf.String.fold_utf_8(
    (acc, _, value) =>
      switch (value) {
      | `Uchar(u) => acc + uchar_width(u)
      | `Malformed(_) => acc + 1
      },
    0,
    s,
  );

let lines = s => String.split_on_char('\n', s);

let longest_line_width = s =>
  lines(s)
  |> List.fold_left((acc, line) => max(acc, string_width(line)), 0);

let line_count = s => max(1, List.length(lines(s)));
