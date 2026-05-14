  The weaker part is Components. It currently mixes three categories together:

  - real reusable primitives: panel, badge, tab_bar, table, key_value
  - semi-reusable app patterns: header, app_shell, composer, log_feed, metric_card
  - demo/OpenCode-specific pieces: wordmark, model_status, command_block, tip, hint_bar

  The main issue is that many components hard-code Theme.dark, default labels, colors, and product assumptions.
  For example model_status defaults to "DeepSeek V4 Pro" and "OpenCode Go" in lib/tui.ml:1703. That
  belongs in an example or preset, not the public general component layer.

  For symphony-orchestrator, the library is already useful for a first version: dashboards, panels, job tables,
  logs, status badges, progress bars, command footer, responsive viewport. But before calling it a general-
  purpose library, I’d split the API like this:

  Tui
    Core: Style, Color, Theme, Surface, Renderer, Terminal, Viewport, Keymap
    Components: Box, Text, Input, Select, Table, Panel, Badge, Tabs, Progress, Log
    Patterns: AppShell, Header, Footer, Composer, Modal, CommandPalette
    Examples: OpenCode, Dashboard, Symphony

  And I would move OpenCode-specific helpers out of Components into examples/ or a Presets.Open_code module.

  The next important improvement is theme injection. Instead of components calling Theme.dark internally, they
  should accept ?theme or a Design.t, so Symphony can have its own visual identity without rewriting
  components.

  So: usable for Symphony now, but not yet clean enough as a general library API. The next pass should be an
  API cleanup, not more visual polish.
