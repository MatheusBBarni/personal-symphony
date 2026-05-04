module Button = {
  @module("@heroui/react/button") @react.component
  external make: (
    ~className: string=?,
    ~variant: string=?,
    ~size: string=?,
    @as("type") ~type_: string=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "Button"
}

module Card = {
  @module("@heroui/react/card") @react.component
  external make: (
    ~className: string=?,
    ~variant: string=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "Card"
}

module CardHeader = {
  @module("@heroui/react/card") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "CardHeader"
}

module CardContent = {
  @module("@heroui/react/card") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "CardContent"
}

module Chip = {
  @module("@heroui/react/chip") @react.component
  external make: (
    ~className: string=?,
    ~color: string=?,
    ~size: string=?,
    ~variant: string=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "Chip"
}

module Switch = {
  @module("@heroui/react/switch") @react.component
  external make: (
    ~className: string=?,
    ~isSelected: bool=?,
    ~onChange: bool => unit=?,
    ~children: React.element=?,
    unit,
  ) => React.element = "Switch"
}
