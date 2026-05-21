  type t =
    | Default
    | Ansi(int)
    | Indexed(int)
    | RGB(int, int, int);

  type level =
    | No_color
    | Ansi16
    | Ansi256
    | Truecolor;

  let clamp = (lo, hi, v) => max(lo, min(hi, v));
  let rgb = (r, g, b) =>
    [@implicit_arity]
    RGB(clamp(0, 255, r), clamp(0, 255, g), clamp(0, 255, b));
  let ansi = n => Ansi(clamp(0, 15, n));
  let indexed = n => Indexed(clamp(0, 255, n));

  let detect_level = (~env=Sys.getenv_opt, ()) =>
    switch (env("NO_COLOR")) {
    | Some(_) => No_color
    | None =>
      switch (env("COLORTERM")) {
      | Some("truecolor" | "24bit") => Truecolor
      | _ =>
        switch (env("TERM")) {
        | Some(term)
            when
              String.contains(term, '2')
              && String.ends_with(~suffix="256color", term) =>
          Ansi256
        | _ => Ansi16
        }
      }
    };

  let fg_code =
    fun
    | Default => "39"
    | Ansi(n) when n < 8 => string_of_int(30 + n)
    | Ansi(n) => string_of_int(90 + (n - 8))
    | Indexed(n) => "38;5;" ++ string_of_int(n)
    | [@implicit_arity] RGB(r, g, b) =>
      Printf.sprintf(
        "38;2;%d;%d;%d",
        clamp(0, 255, r),
        clamp(0, 255, g),
        clamp(0, 255, b),
      );

  let bg_code =
    fun
    | Default => "49"
    | Ansi(n) when n < 8 => string_of_int(40 + n)
    | Ansi(n) => string_of_int(100 + (n - 8))
    | Indexed(n) => "48;5;" ++ string_of_int(n)
    | [@implicit_arity] RGB(r, g, b) =>
      Printf.sprintf(
        "48;2;%d;%d;%d",
        clamp(0, 255, r),
        clamp(0, 255, g),
        clamp(0, 255, b),
      );

  let degrade = level =>
    fun
    | Default => Default
    | Ansi(n) => Ansi(n)
    | Indexed(n) =>
      if (level == Ansi16) {
        Ansi(n mod 16);
      } else {
        Indexed(n);
      }
    | [@implicit_arity] RGB(r, g, b) =>
      switch (level) {
      | Truecolor => [@implicit_arity] RGB(r, g, b)
      | Ansi256 =>
        let bucket = v => int_of_float(Float.round(float(v) /. 255. *. 5.));
        Indexed(16 + 36 * bucket(r) + 6 * bucket(g) + bucket(b));
      | Ansi16 =>
        let bright =
          if (r + g + b > 382) {
            8;
          } else {
            0;
          };
        let base =
          if (r >= g && r >= b) {
            1;
          } else if (g >= r && g >= b) {
            2;
          } else if (b >= r && b >= g) {
            4;
          } else {
            7;
          };

        Ansi(bright + base);
      | No_color => Default
      };

  let equal = (==);
