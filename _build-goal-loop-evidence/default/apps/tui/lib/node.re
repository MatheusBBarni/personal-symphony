  type input_state = {
    mutable value: string,
    placeholder: string,
    max_length: int,
    mutable cursor: int,
    on_input: option(string => unit),
    on_enter: option(string => unit),
  };

  type select_option = {
    name: string,
    description: string,
    value: option(string),
  };

  type select_state = {
    options: list(select_option),
    mutable selected: int,
    mutable scroll: int,
    wrap: bool,
    show_description: bool,
    fast_scroll_step: int,
    on_change: option((int, select_option) => unit),
    on_select: option((int, select_option) => unit),
  };

  type scroll_state = {
    mutable scroll_x: int,
    mutable scroll_y: int,
    sticky_bottom: bool,
  };
  type progress_state = {
    fraction: float,
    label: option(string),
  };

  type kind =
    | Text(list(Span.t))
    | Vertical_rule(string)
    | Box
    | Input(input_state)
    | Select(select_state)
    | Scroll_box(scroll_state)
    | Progress_bar(progress_state)
    | Sparkline(list(float))
    | Spacer;

  type t = {
    id: string,
    kind,
    style: Style.t,
    children: list(t),
    focusable: bool,
    mutable focused: bool,
  };

  let next_id = {
    let counter = ref(0);
    prefix => {
      incr(counter);
      Printf.sprintf("%s-%d", prefix, counter^);
    };
  };

  let make =
      (~id=?, ~style=Style.default, ~children=[], ~focusable=false, kind) => {
    id: Option.value(~default=next_id("node"), id),
    kind,
    style,
    children,
    focusable,
    focused: false,
  };

  let text = (~id=?, ~style=Style.default, content) =>
    make(~id?, ~style, Text([Span.make(~style, content)]));
  let rich_text = (~id=?, ~style=Style.default, spans) =>
    make(~id?, ~style, Text(spans));
  let vertical_rule = (~id=?, ~style=Style.default, ~char="│", ()) =>
    make(~id?, ~style, Vertical_rule(char));
  let box = (~id=?, ~style=Style.default, children) =>
    make(~id?, ~style, ~children, Box);
  let spacer = (~id=?, ~style=Style.default, ()) =>
    make(~id?, ~style, Spacer);

  let input =
      (
        ~id=?,
        ~style=Style.default,
        ~value="",
        ~placeholder="",
        ~max_length=1000,
        ~on_input=?,
        ~on_enter=?,
        (),
      ) => {
    let state = {
      value,
      placeholder,
      max_length,
      cursor: String.length(value),
      on_input,
      on_enter,
    };
    make(~id?, ~style, ~focusable=true, Input(state));
  };

  let option = (~value=?, ~description="", name) => {
    name,
    description,
    value,
  };

  let select =
      (
        ~id=?,
        ~style=Style.default,
        ~selected=0,
        ~wrap=false,
        ~show_description=true,
        ~fast_scroll_step=5,
        ~on_change=?,
        ~on_select=?,
        options,
      ) => {
    let state = {
      options,
      selected,
      scroll: 0,
      wrap,
      show_description,
      fast_scroll_step,
      on_change,
      on_select,
    };
    make(~id?, ~style, ~focusable=true, Select(state));
  };

  let scroll_box =
      (
        ~id=?,
        ~style=Style.default,
        ~scroll_x=0,
        ~scroll_y=0,
        ~sticky_bottom=false,
        children,
      ) =>
    make(
      ~id?,
      ~style,
      ~children,
      ~focusable=true,
      Scroll_box({
        scroll_x,
        scroll_y,
        sticky_bottom,
      }),
    );

  let progress_bar = (~id=?, ~style=Style.default, ~label=?, fraction) =>
    make(
      ~id?,
      ~style,
      Progress_bar({
        fraction: max(0., min(1., fraction)),
        label,
      }),
    );

  let sparkline = (~id=?, ~style=Style.default, values) =>
    make(~id?, ~style, Sparkline(values));

  let plain_text =
    fun
    | Text(spans) =>
      spans |> List.map(span => span.Span.text) |> String.concat("")
    | Vertical_rule(char) => char
    | _ => "";

  let rec find_by_id = (id, node) =>
    if (node.id == id) {
      Some(node);
    } else {
      node.children |> List.find_map(find_by_id(id));
    };

  let rec focusables = node => {
    let own =
      if (node.focusable) {
        [node];
      } else {
        [];
      };
    own @ List.concat_map(focusables, node.children);
  };

  let set_focus = (root, id) => {
    let all = focusables(root);
    List.iter(node => node.focused = node.id == id, all);
    List.exists(node => node.id == id, all);
  };

  let focus_first = root =>
    switch (focusables(root)) {
    | [] => None
    | [node, ..._] =>
      ignore(set_focus(root, node.id));
      Some(node.id);
    };

  let focus_next = (root, current) => {
    let all = focusables(root);
    switch (all) {
    | [] => None
    | _ =>
      let index =
        switch (current) {
        | None => (-1)
        | Some(id) =>
          switch (List.find_index(node => node.id == id, all)) {
          | Some(i) => i
          | None => (-1)
          }
        };

      let next = List.nth(all, (index + 1) mod List.length(all));
      ignore(set_focus(root, next.id));
      Some(next.id);
    };
  };

  let selected_option = state => List.nth_opt(state.options, state.selected);

  let clamp_select = state => {
    let count = List.length(state.options);
    if (count == 0) {
      state.selected = 0;
    } else {
      state.selected = max(0, min(count - 1, state.selected));
    };
  };

  let move_select = (state, delta) => {
    let count = List.length(state.options);
    if (count > 0) {
      let next = state.selected + delta;
      state.selected = (
        if (state.wrap) {
          (next mod count + count) mod count;
        } else {
          max(0, min(count - 1, next));
        }
      );
      switch (state.on_change, selected_option(state)) {
      | (Some(f), Some(option)) => f(state.selected, option)
      | _ => ()
      };
    };
  };

  let insert_at = (s, index, text) =>
    String.sub(s, 0, index)
    ++ text
    ++ String.sub(s, index, String.length(s) - index);

  let remove_before = (s, index) =>
    if (index <= 0) {
      s;
    } else {
      String.sub(s, 0, index - 1)
      ++ String.sub(s, index, String.length(s) - index);
    };

  let remove_at = (s, index) =>
    if (index < 0 || index >= String.length(s)) {
      s;
    } else {
      String.sub(s, 0, index)
      ++ String.sub(s, index + 1, String.length(s) - index - 1);
    };

  let handle_key = (node, key: Key.event) =>
    switch (node.kind) {
    | Input(state) =>
      switch (key.name) {
      | "left" =>
        state.cursor = max(0, state.cursor - 1);
        true;
      | "right" =>
        state.cursor = min(String.length(state.value), state.cursor + 1);
        true;
      | "home" =>
        state.cursor = 0;
        true;
      | "end" =>
        state.cursor = String.length(state.value);
        true;
      | "backspace" =>
        state.value = remove_before(state.value, state.cursor);
        state.cursor = max(0, state.cursor - 1);
        Option.iter(f => f(state.value), state.on_input);
        true;
      | "delete" =>
        state.value = remove_at(state.value, state.cursor);
        Option.iter(f => f(state.value), state.on_input);
        true;
      | "return" =>
        Option.iter(f => f(state.value), state.on_enter);
        true;
      | name when !key.ctrl && !key.alt && String.length(name) == 1 =>
        if (String.length(state.value) < state.max_length) {
          state.value = insert_at(state.value, state.cursor, name);
          state.cursor = state.cursor + 1;
          Option.iter(f => f(state.value), state.on_input);
        };
        true;
      | _ => false
      }
    | Select(state) =>
      clamp_select(state);
      switch (key.name) {
      | "up"
      | "k" =>
        move_select(state, -1);
        true;
      | "down"
      | "j" =>
        move_select(state, 1);
        true;
      | "pageup" =>
        move_select(state, - state.fast_scroll_step);
        true;
      | "pagedown" =>
        move_select(state, state.fast_scroll_step);
        true;
      | "return" =>
        switch (state.on_select, selected_option(state)) {
        | (Some(f), Some(option)) => f(state.selected, option)
        | _ => ()
        };
        true;
      | _ => false
      };
    | Scroll_box(state) =>
      switch (key.name) {
      | "up"
      | "k" =>
        state.scroll_y = max(0, state.scroll_y - 1);
        true;
      | "down"
      | "j" =>
        state.scroll_y = state.scroll_y + 1;
        true;
      | "left"
      | "h" =>
        state.scroll_x = max(0, state.scroll_x - 1);
        true;
      | "right"
      | "l" =>
        state.scroll_x = state.scroll_x + 1;
        true;
      | _ => false
      }
    | _ => false
    };
