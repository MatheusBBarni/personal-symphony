  type stroke = {
    name: string,
    ctrl: bool,
    shift: bool,
    alt: bool,
  };
  type command = {
    name: string,
    description: option(string),
    run: unit => unit,
  };
  type binding = {
    keys: list(stroke),
    command,
  };
  type dispatch_result =
    | Handled(string)
    | Pending
    | Unhandled;
  type t = {
    mutable bindings: list(binding),
    mutable pending: list(stroke),
  };

  let create = () => {
    bindings: [],
    pending: [],
  };
  let stroke = (~ctrl=false, ~shift=false, ~alt=false, name) => {
    name,
    ctrl,
    shift,
    alt,
  };
  let of_event = (event: Key.event) => {
    name: event.name,
    ctrl: event.ctrl,
    shift: event.shift,
    alt: event.alt,
  };

  let normalize_name =
    fun
    | "enter" => "return"
    | "esc" => "escape"
    | " " => "space"
    | s => String.lowercase_ascii(s);

  let parse_token = token => {
    let parts = String.split_on_char('+', String.lowercase_ascii(token));
    let ctrl = List.mem("ctrl", parts) || List.mem("control", parts);
    let shift = List.mem("shift", parts);
    let alt = List.mem("alt", parts) || List.mem("meta", parts);
    let key =
      parts
      |> List.filter(p =>
           !List.mem(p, ["ctrl", "control", "shift", "alt", "meta"])
         )
      |> (
        fun
        | [k] => normalize_name(k)
        | [] => normalize_name(token)
        | ks => normalize_name(String.concat("+", ks))
      );

    stroke(~ctrl, ~shift, ~alt, key);
  };

  let parse_sequence = s => {
    let s = String.trim(s);
    if (String.contains(s, ' ')) {
      s
      |> String.split_on_char(' ')
      |> List.filter((!=)(""))
      |> List.map(parse_token);
    } else if (String.contains(s, '+') || String.length(s) <= 1) {
      [parse_token(s)];
    } else {
      let known = [
        "escape",
        "return",
        "enter",
        "tab",
        "backspace",
        "up",
        "down",
        "left",
        "right",
        "pageup",
        "pagedown",
        "home",
        "end",
      ];

      if (List.mem(String.lowercase_ascii(s), known)) {
        [parse_token(s)];
      } else {
        List.init(String.length(s), i => stroke(String.make(1, s.[i])));
      };
    };
  };

  let register = (~description=?, t, ~key, ~name, ~run) => {
    let command = {
      name,
      description,
      run,
    };
    t.bindings = [
      {
        keys: parse_sequence(key),
        command,
      },
      ...t.bindings,
    ];
  };

  let is_prefix = (prefix, keys) => {
    let rec loop = (a, b) =>
      switch (a, b) {
      | ([], _) => true
      | ([x, ...xs], [y, ...ys]) when x == y => loop(xs, ys)
      | _ => false
      };

    loop(prefix, keys);
  };

  let dispatch = (t, event) => {
    let next = t.pending @ [of_event(event)];
    let exact = List.find_opt(binding => binding.keys == next, t.bindings);
    switch (exact) {
    | Some(binding) =>
      t.pending = [];
      binding.command.run();
      Handled(binding.command.name);
    | None =>
      if (List.exists(binding => is_prefix(next, binding.keys), t.bindings)) {
        t.pending = next;
        Pending;
      } else {
        t.pending = [];
        Unhandled;
      }
    };
  };

  let active_keys = t =>
    t.bindings
    |> List.filter_map(binding =>
         if (is_prefix(t.pending, binding.keys)) {
           List.nth_opt(binding.keys, List.length(t.pending));
         } else {
           None;
         }
       );
