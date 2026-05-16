  type t = {
    width: int,
    height: int,
  };
  type breakpoint =
    | Tiny
    | Compact
    | Regular
    | Wide;
  type orientation =
    | Portrait
    | Landscape
    | Square;

  let make = (~width, ~height) => {
    width: max(1, width),
    height: max(1, height),
  };
  let size = t => (t.width, t.height);
  let area = t => t.width * t.height;
  let fits = (~min_width=1, ~min_height=1, t) =>
    t.width >= min_width && t.height >= min_height;

  let orientation = t =>
    if (t.width == t.height) {
      Square;
    } else if (t.width > t.height) {
      Landscape;
    } else {
      Portrait;
    };

  let breakpoint = t =>
    if (t.width < 60 || t.height < 18) {
      Tiny;
    } else if (t.width < 80 || t.height < 24) {
      Compact;
    } else if (t.width >= 120 && t.height >= 30) {
      Wide;
    } else {
      Regular;
    };

  let breakpoint_name =
    fun
    | Tiny => "tiny"
    | Compact => "compact"
    | Regular => "regular"
    | Wide => "wide";
  let is_tiny = t => breakpoint(t) == Tiny;
  let is_compact = t => breakpoint(t) == Compact;
  let is_regular = t => breakpoint(t) == Regular;
  let is_wide = t => breakpoint(t) == Wide;

  let choose = (t, ~tiny, ~compact, ~regular, ~wide) =>
    switch (breakpoint(t)) {
    | Tiny => tiny
    | Compact => compact
    | Regular => regular
    | Wide => wide
    };
