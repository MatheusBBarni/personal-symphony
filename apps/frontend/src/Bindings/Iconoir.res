module Play = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "Play"
}

module Refresh = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "Refresh"
}

module CoinsSwap = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "CoinsSwap"
}

module KanbanBoard = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "KanbanBoard"
}

module Settings = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "Settings"
}

module CheckCircle = {
  @module("iconoir-react/regular") @react.component
  external make: (~className: string=?, @as("aria-hidden") ~ariaHidden: bool=?, unit) => React.element =
    "CheckCircle"
}
