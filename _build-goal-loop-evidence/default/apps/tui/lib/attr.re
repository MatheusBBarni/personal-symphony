  type t =
    | Bold
    | Dim
    | Italic
    | Underline
    | Blink
    | Inverse
    | Hidden
    | Strike;

  let code =
    fun
    | Bold => "1"
    | Dim => "2"
    | Italic => "3"
    | Underline => "4"
    | Blink => "5"
    | Inverse => "7"
    | Hidden => "8"
    | Strike => "9";

  let mem = (attr, attrs) => List.exists((==)(attr), attrs);
  let add = (attr, attrs) =>
    if (mem(attr, attrs)) {
      attrs;
    } else {
      [attr, ...attrs];
    };
