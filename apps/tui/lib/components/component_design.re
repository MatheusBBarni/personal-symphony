type tone =
  | Neutral
  | Accent
  | Info
  | Success
  | Warning
  | Error;

type design = {
  theme: Theme.t,
  tone_color: tone => Color.t,
};

let default_tone_color = theme =>
  fun
  | Neutral => theme(Theme.Fg_muted)
  | Accent => theme(Theme.Accent_primary)
  | Info => theme(Theme.Status_info)
  | Success => theme(Theme.Status_success)
  | Warning => theme(Theme.Status_warning)
  | Error => theme(Theme.Status_error);

let make_design = (~theme=Theme.dark, ~tone_color=?, ()) => {
  let tone_color =
    switch (tone_color) {
    | Some(tone_color) => tone_color
    | None => default_tone_color(theme)
    };

  {
    theme,
    tone_color,
  };
};

let default_design = make_design();
let resolve_design =
  fun
  | None => default_design
  | Some(design) => design;

let with_theme = (~theme, design) => {
  theme,
  tone_color: design.tone_color,
};

let with_tone_color = (~tone_color, design) => {
  ...design,
  tone_color,
};

let theme_color = (design, slot) => design.theme(slot);
let color_of_tone = (~design=?, tone) =>
  resolve_design(design).tone_color(tone);
let surface_of = design => theme_color(design, Theme.Bg_surface);
let overlay_of = design => theme_color(design, Theme.Bg_overlay);
let default_fg_of = design => theme_color(design, Theme.Fg_default);
let muted_fg_of = design => theme_color(design, Theme.Fg_muted);
let emphasis_fg_of = design => theme_color(design, Theme.Fg_emphasis);

let style = (~design=?, ~fg=Theme.Fg_default, ~bg=?, ~attrs=[], ()) => {
  let design = resolve_design(design);
  let base = Style.make(~fg=theme_color(design, fg), ~attrs, ());
  switch (bg) {
  | None => base
  | Some(slot) => Style.with_bg(theme_color(design, slot), base)
  };
};

let tone_style = (~design=?, ~tone=Accent, ~attrs=[], ()) => {
  let design = resolve_design(design);
  Style.make(~fg=color_of_tone(~design, tone), ~attrs, ());
};

let surface_style = (~design=?, ~attrs=[], ()) => {
  let design = resolve_design(design);
  Style.make(
    ~fg=default_fg_of(design),
    ~bg=surface_of(design),
    ~attrs,
    (),
  );
};

let surface = surface_of(default_design);
let overlay = overlay_of(default_design);
let default_fg = default_fg_of(default_design);
let muted_fg = muted_fg_of(default_design);
let emphasis_fg = emphasis_fg_of(default_design);
