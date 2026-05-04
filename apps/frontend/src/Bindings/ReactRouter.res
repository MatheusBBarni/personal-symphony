type location = {
  pathname: string,
}

module HashRouter = {
  @module("react-router") @react.component
  external make: (~children: React.element, unit) => React.element = "HashRouter"
}

module Routes = {
  @module("react-router") @react.component
  external make: (~children: React.element, unit) => React.element = "Routes"
}

module Route = {
  @module("react-router") @react.component
  external make: (
    ~path: string=?,
    ~element: React.element,
    unit,
  ) => React.element = "Route"
}

module Navigate = {
  @module("react-router") @react.component
  external make: (~to: string, ~replace: bool=?, unit) => React.element = "Navigate"
}

@module("react-router") external useLocation: unit => location = "useLocation"
