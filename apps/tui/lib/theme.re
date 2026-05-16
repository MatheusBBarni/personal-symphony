  type slot =
    | Fg_default
    | Fg_muted
    | Fg_emphasis
    | Bg_base
    | Bg_surface
    | Bg_overlay
    | Bg_selection
    | Accent_primary
    | Accent_secondary
    | Status_error
    | Status_warning
    | Status_success
    | Status_info;

  type t = slot => Color.t;

  type palette = {
    fg_default: Color.t,
    fg_muted: Color.t,
    fg_emphasis: Color.t,
    bg_base: Color.t,
    bg_surface: Color.t,
    bg_overlay: Color.t,
    bg_selection: Color.t,
    accent_primary: Color.t,
    accent_secondary: Color.t,
    status_error: Color.t,
    status_warning: Color.t,
    status_success: Color.t,
    status_info: Color.t,
  };

  let make =
      (
        ~fg_default,
        ~fg_muted,
        ~fg_emphasis,
        ~bg_base,
        ~bg_surface,
        ~bg_overlay,
        ~bg_selection,
        ~accent_primary,
        ~accent_secondary,
        ~status_error,
        ~status_warning,
        ~status_success,
        ~status_info,
        (),
      ) => {
    fg_default,
    fg_muted,
    fg_emphasis,
    bg_base,
    bg_surface,
    bg_overlay,
    bg_selection,
    accent_primary,
    accent_secondary,
    status_error,
    status_warning,
    status_success,
    status_info,
  };

  let of_palette = palette =>
    fun
    | Fg_default => palette.fg_default
    | Fg_muted => palette.fg_muted
    | Fg_emphasis => palette.fg_emphasis
    | Bg_base => palette.bg_base
    | Bg_surface => palette.bg_surface
    | Bg_overlay => palette.bg_overlay
    | Bg_selection => palette.bg_selection
    | Accent_primary => palette.accent_primary
    | Accent_secondary => palette.accent_secondary
    | Status_error => palette.status_error
    | Status_warning => palette.status_warning
    | Status_success => palette.status_success
    | Status_info => palette.status_info;

  let to_palette = theme =>
    make(
      ~fg_default=theme(Fg_default),
      ~fg_muted=theme(Fg_muted),
      ~fg_emphasis=theme(Fg_emphasis),
      ~bg_base=theme(Bg_base),
      ~bg_surface=theme(Bg_surface),
      ~bg_overlay=theme(Bg_overlay),
      ~bg_selection=theme(Bg_selection),
      ~accent_primary=theme(Accent_primary),
      ~accent_secondary=theme(Accent_secondary),
      ~status_error=theme(Status_error),
      ~status_warning=theme(Status_warning),
      ~status_success=theme(Status_success),
      ~status_info=theme(Status_info),
      (),
    );

  let dark_palette =
    make(
      ~fg_default=Color.rgb(192, 202, 245),
      ~fg_muted=Color.rgb(86, 95, 137),
      ~fg_emphasis=Color.rgb(224, 224, 224),
      ~bg_base=Color.rgb(26, 27, 38),
      ~bg_surface=Color.rgb(36, 40, 59),
      ~bg_overlay=Color.rgb(65, 72, 104),
      ~bg_selection=Color.rgb(54, 74, 130),
      ~accent_primary=Color.rgb(122, 162, 247),
      ~accent_secondary=Color.rgb(187, 154, 247),
      ~status_error=Color.rgb(247, 118, 142),
      ~status_warning=Color.rgb(224, 175, 104),
      ~status_success=Color.rgb(158, 206, 106),
      ~status_info=Color.rgb(125, 207, 255),
      (),
    );

  let light_palette =
    make(
      ~fg_default=Color.rgb(52, 59, 88),
      ~fg_muted=Color.rgb(110, 118, 147),
      ~fg_emphasis=Color.rgb(20, 23, 35),
      ~bg_base=Color.rgb(239, 241, 245),
      ~bg_surface=Color.rgb(230, 233, 239),
      ~bg_overlay=Color.rgb(204, 208, 218),
      ~bg_selection=Color.rgb(172, 188, 255),
      ~accent_primary=Color.rgb(30, 102, 245),
      ~accent_secondary=Color.rgb(136, 57, 239),
      ~status_error=Color.rgb(210, 15, 57),
      ~status_warning=Color.rgb(223, 142, 29),
      ~status_success=Color.rgb(64, 160, 43),
      ~status_info=Color.rgb(4, 165, 229),
      (),
    );

  let high_contrast_dark_palette =
    make(
      ~fg_default=Color.rgb(238, 238, 238),
      ~fg_muted=Color.rgb(176, 184, 196),
      ~fg_emphasis=Color.rgb(255, 255, 255),
      ~bg_base=Color.rgb(0, 0, 0),
      ~bg_surface=Color.rgb(18, 18, 18),
      ~bg_overlay=Color.rgb(38, 38, 38),
      ~bg_selection=Color.rgb(0, 95, 175),
      ~accent_primary=Color.rgb(0, 215, 255),
      ~accent_secondary=Color.rgb(255, 135, 255),
      ~status_error=Color.rgb(255, 95, 95),
      ~status_warning=Color.rgb(255, 215, 0),
      ~status_success=Color.rgb(135, 255, 95),
      ~status_info=Color.rgb(95, 175, 255),
      (),
    );

  let dark = of_palette(dark_palette);
  let light = of_palette(light_palette);
  let high_contrast_dark = of_palette(high_contrast_dark_palette);
  let no_color = _ => Color.Default;

  let with_slot = (slot, color, theme) => current =>
    if (current == slot) {
      color;
    } else {
      theme(current);
    };

  let map = (f, theme) => slot => f(slot, theme(slot));

  let named = name =>
    switch (String.lowercase_ascii(name)) {
    | "dark"
    | "tokyo-night" => Some(dark)
    | "light" => Some(light)
    | "high-contrast"
    | "high-contrast-dark" => Some(high_contrast_dark)
    | "none"
    | "no-color" => Some(no_color)
    | _ => None
    };
