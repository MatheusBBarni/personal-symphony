module Text = {
  let make = (~id=?, ~style=Style.default, ~value, ()) =>
    Components.text(~id?, ~style, value);
  let createElement =
      (~id=?, ~style=Style.default, ~value, ~children as _children=[], ()) =>
    make(~id?, ~style, ~value, ());
};

module RichText = {
  let make = (~id=?, ~style=Style.default, ~spans, ()) =>
    Components.rich_text(~id?, ~style, spans);
  let createElement =
      (~id=?, ~style=Style.default, ~spans, ~children as _children=[], ()) =>
    make(~id?, ~style, ~spans, ());
};

module VerticalRule = {
  let make = (~id=?, ~style=Style.default, ~char=?, ()) =>
    Components.vertical_rule(~id?, ~style, ~char?, ());
  let createElement =
      (~id=?, ~style=Style.default, ~char=?, ~children as _children=[], ()) =>
    make(~id?, ~style, ~char?, ());
};

module Box = {
  let make = (~id=?, ~style=Style.default, ~children, ()) =>
    Components.box(~id?, ~style, children);
  let createElement = make;
};

module Spacer = {
  let make = (~id=?, ~style=Style.default, ()) =>
    Components.spacer(~id?, ~style, ());
  let createElement =
      (~id=?, ~style=Style.default, ~children as _children=[], ()) =>
    make(~id?, ~style, ());
};

module Input = {
  let make =
      (
        ~id=?,
        ~style=Style.default,
        ~value="",
        ~placeholder="",
        ~max_length=1000,
        ~on_input=?,
        ~on_enter=?,
        (),
      ) =>
    Components.input(
      ~id?,
      ~style,
      ~value,
      ~placeholder,
      ~max_length,
      ~on_input?,
      ~on_enter?,
      (),
    );
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~value="",
        ~placeholder="",
        ~max_length=1000,
        ~on_input=?,
        ~on_enter=?,
        ~children as _children=[],
        (),
      ) =>
    make(
      ~id?,
      ~style,
      ~value,
      ~placeholder,
      ~max_length,
      ~on_input?,
      ~on_enter?,
      (),
    );
};

module Option = {
  let make = (~value=?, ~description="", ~name, ()) =>
    Components.option(~value?, ~description, name);
  let createElement =
      (~value=?, ~description="", ~name, ~children as _children=[], ()) =>
    make(~value?, ~description, ~name, ());
};

module Select = {
  let make =
      (
        ~id=?,
        ~style=Style.default,
        ~selected=0,
        ~wrap=false,
        ~show_description=true,
        ~fast_scroll_step=5,
        ~on_change=?,
        ~on_select=?,
        ~options,
        (),
      ) =>
    Components.select(
      ~id?,
      ~style,
      ~selected,
      ~wrap,
      ~show_description,
      ~fast_scroll_step,
      ~on_change?,
      ~on_select?,
      options,
    );
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~selected=0,
        ~wrap=false,
        ~show_description=true,
        ~fast_scroll_step=5,
        ~on_change=?,
        ~on_select=?,
        ~options,
        ~children as _children=[],
        (),
      ) =>
    make(
      ~id?,
      ~style,
      ~selected,
      ~wrap,
      ~show_description,
      ~fast_scroll_step,
      ~on_change?,
      ~on_select?,
      ~options,
      (),
    );
};

module ScrollBox = {
  let make =
      (
        ~id=?,
        ~style=Style.default,
        ~scroll_x=0,
        ~scroll_y=0,
        ~sticky_bottom=false,
        ~children,
        (),
      ) =>
    Components.scroll_box(
      ~id?,
      ~style,
      ~scroll_x,
      ~scroll_y,
      ~sticky_bottom,
      children,
    );
  let createElement = make;
};

module ProgressBar = {
  let make = (~id=?, ~style=Style.default, ~label=?, ~fraction, ()) =>
    Components.progress_bar(~id?, ~style, ~label?, fraction);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~label=?,
        ~fraction,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~label?, ~fraction, ());
};

module Sparkline = {
  let make = (~id=?, ~style=Style.default, ~values, ()) =>
    Components.sparkline(~id?, ~style, values);
  let createElement =
      (~id=?, ~style=Style.default, ~values, ~children as _children=[], ()) =>
    make(~id?, ~style, ~values, ());
};

module Row = {
  let make = (~id=?, ~style=Style.default, ~gap=1, ~children, ()) =>
    Components.row(~id?, ~style, ~gap, children);
  let createElement = make;
};

module Column = {
  let make = (~id=?, ~style=Style.default, ~gap=0, ~children, ()) =>
    Components.column(~id?, ~style, ~gap, children);
  let createElement = make;
};

module Panel = {
  let make =
      (
        ~id=?,
        ~tone=Components.Accent,
        ~title_align=Style.Title_left,
        ~bottom_title=?,
        ~style=Style.default,
        ~design=?,
        ~title,
        ~children,
        (),
      ) =>
    Components.panel(
      ~id?,
      ~tone,
      ~title_align,
      ~bottom_title?,
      ~style,
      ~design?,
      title,
      children,
    );
  let createElement = make;
};

module Badge = {
  let make =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~style=Style.default,
        ~design=?,
        ~label,
        (),
      ) =>
    Components.badge(~id?, ~tone, ~style, ~design?, label);
  let createElement =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~style, ~design?, ~label, ());
};

module TabBar = {
  let make = (~id=?, ~style=Style.default, ~design=?, ~tabs, ()) =>
    Components.tab_bar(~id?, ~style, ~design?, tabs);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~tabs,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~tabs, ());
};

module KeyValue = {
  let make =
      (~id=?, ~label_width=12, ~style=Style.default, ~design=?, ~pairs, ()) =>
    Components.key_value(~id?, ~label_width, ~style, ~design?, pairs);
  let createElement =
      (
        ~id=?,
        ~label_width=12,
        ~style=Style.default,
        ~design=?,
        ~pairs,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~label_width, ~style, ~design?, ~pairs, ());
};

module Table = {
  let make =
      (
        ~id=?,
        ~style=Style.default,
        ~header_tone=Components.Accent,
        ~design=?,
        ~columns,
        ~rows,
        (),
      ) =>
    Components.table(~id?, ~style, ~header_tone, ~design?, columns, rows);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~header_tone=Components.Accent,
        ~design=?,
        ~columns,
        ~rows,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~header_tone, ~design?, ~columns, ~rows, ());
};

module Split = {
  let make = (~id=?, ~style=Style.default, ~left_width=32, ~left, ~right, ()) =>
    Components.split(~id?, ~style, ~left_width, left, right);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~left_width=32,
        ~left,
        ~right,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~left_width, ~left, ~right, ());
};

module Divider = {
  let make =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~width=32,
        ~title=?,
        ~char=?,
        ~style=Style.default,
        ~design=?,
        (),
      ) =>
    Components.divider(
      ~id?,
      ~tone,
      ~width,
      ~title?,
      ~char?,
      ~style,
      ~design?,
      (),
    );
  let createElement =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~width=32,
        ~title=?,
        ~char=?,
        ~style=Style.default,
        ~design=?,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~width, ~title?, ~char?, ~style, ~design?, ());
};

module Callout = {
  let make =
      (
        ~id=?,
        ~tone=Components.Info,
        ~title=?,
        ~style=Style.default,
        ~design=?,
        ~children,
        (),
      ) =>
    Components.callout(~id?, ~tone, ~title?, ~style, ~design?, children);
  let createElement = make;
};

module EmptyState = {
  let make =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~detail=?,
        ~action=?,
        ~style=Style.default,
        ~design=?,
        ~title,
        (),
      ) =>
    Components.empty_state(
      ~id?,
      ~tone,
      ~detail?,
      ~action?,
      ~style,
      ~design?,
      title,
    );
  let createElement =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~detail=?,
        ~action=?,
        ~style=Style.default,
        ~design=?,
        ~title,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~detail?, ~action?, ~style, ~design?, ~title, ());
};

module Toolbar = {
  let make = (~id=?, ~style=Style.default, ~design=?, ~items, ()) =>
    Components.toolbar(~id?, ~style, ~design?, items);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~items,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~items, ());
};

module Meter = {
  let make =
      (
        ~id=?,
        ~tone=Components.Info,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~value=?,
        ~fraction,
        (),
      ) =>
    Components.meter(
      ~id?,
      ~tone,
      ~style,
      ~design?,
      ~label,
      ~value?,
      fraction,
    );
  let createElement =
      (
        ~id=?,
        ~tone=Components.Info,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~value=?,
        ~fraction,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~style, ~design?, ~label, ~value?, ~fraction, ());
};

module RulePanel = {
  let make =
      (
        ~id=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~design=?,
        ~children,
        (),
      ) =>
    Patterns.rule_panel(~id?, ~tone, ~style, ~design?, children);
  let createElement = make;
};

module Modal = {
  let make =
      (
        ~id=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~bottom_title=?,
        ~design=?,
        ~title,
        ~children,
        (),
      ) =>
    Patterns.modal(
      ~id?,
      ~tone,
      ~style,
      ~bottom_title?,
      ~design?,
      title,
      children,
    );
  let createElement = make;
};

module Header = {
  let make = (~id=?, ~subtitle=?, ~badges=[], ~design=?, ~title, ()) =>
    Patterns.header(~id?, ~subtitle?, ~badges, ~design?, title);
  let createElement =
      (
        ~id=?,
        ~subtitle=?,
        ~badges=[],
        ~design=?,
        ~title,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~subtitle?, ~badges, ~design?, ~title, ());
};

module MetricCard = {
  let make =
      (
        ~id=?,
        ~tone=Components.Info,
        ~detail=?,
        ~progress=?,
        ~sparkline=?,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~value,
        (),
      ) =>
    Patterns.metric_card(
      ~id?,
      ~tone,
      ~detail?,
      ~progress?,
      ~sparkline?,
      ~style,
      ~design?,
      ~label,
      ~value,
      (),
    );
  let createElement =
      (
        ~id=?,
        ~tone=Components.Info,
        ~detail=?,
        ~progress=?,
        ~sparkline=?,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~value,
        ~children as _children=[],
        (),
      ) =>
    make(
      ~id?,
      ~tone,
      ~detail?,
      ~progress?,
      ~sparkline?,
      ~style,
      ~design?,
      ~label,
      ~value,
      (),
    );
};

module LogFeed = {
  let make = (~id=?, ~style=Style.default, ~design=?, ~entries, ()) =>
    Patterns.log_feed(~id?, ~style, ~design?, entries);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~entries,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~entries, ());
};

module SectionTitle = {
  let make =
      (
        ~id=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~design=?,
        ~title,
        (),
      ) =>
    Patterns.section_title(~id?, ~tone, ~style, ~design?, title);
  let createElement =
      (
        ~id=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~design=?,
        ~title,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~style, ~design?, ~title, ());
};

module NavItem = {
  let make =
      (
        ~id=?,
        ~active=false,
        ~meta=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~design=?,
        ~label,
        (),
      ) =>
    Patterns.nav_item(~id?, ~active, ~meta?, ~tone, ~style, ~design?, label);
  let createElement =
      (
        ~id=?,
        ~active=false,
        ~meta=?,
        ~tone=Components.Accent,
        ~style=Style.default,
        ~design=?,
        ~label,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~active, ~meta?, ~tone, ~style, ~design?, ~label, ());
};

module Message = {
  let make =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~time=?,
        ~style=Style.default,
        ~design=?,
        ~author,
        ~body,
        (),
      ) =>
    Patterns.message(~id?, ~tone, ~time?, ~style, ~design?, ~author, body);
  let createElement =
      (
        ~id=?,
        ~tone=Components.Neutral,
        ~time=?,
        ~style=Style.default,
        ~design=?,
        ~author,
        ~body,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~tone, ~time?, ~style, ~design?, ~author, ~body, ());
};

module Timeline = {
  let make = (~id=?, ~style=Style.default, ~design=?, ~entries, ()) =>
    Patterns.timeline(~id?, ~style, ~design?, entries);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~entries,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~entries, ());
};

module Composer = {
  let make =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~prompt=">",
        ~placeholder="Type a message",
        (),
      ) =>
    Patterns.composer(~id?, ~style, ~design?, ~prompt, ~placeholder, ());
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~prompt=">",
        ~placeholder="Type a message",
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~prompt, ~placeholder, ());
};

module CommandBar = {
  let make = (~id=?, ~style=Style.default, ~design=?, ~items, ()) =>
    Patterns.command_bar(~id?, ~style, ~design?, items);
  let createElement =
      (
        ~id=?,
        ~style=Style.default,
        ~design=?,
        ~items,
        ~children as _children=[],
        (),
      ) =>
    make(~id?, ~style, ~design?, ~items, ());
};

module Footer = {
  let make = (~design=?, ~shortcuts, ()) =>
    Patterns.footer(~design?, shortcuts);
  let createElement = (~design=?, ~shortcuts, ~children as _children=[], ()) =>
    make(~design?, ~shortcuts, ());
};

module AppShell = {
  let make =
      (
        ~id=?,
        ~title="App",
        ~subtitle=?,
        ~badges=[],
        ~footer_items=[("q", "uit"), ("?", "help"), ("Tab", "focus")],
        ~design=?,
        ~children,
        (),
      ) =>
    Patterns.app_shell(
      ~id?,
      ~title,
      ~subtitle?,
      ~badges,
      ~footer_items,
      ~design?,
      children,
    );
  let createElement = make;
};
