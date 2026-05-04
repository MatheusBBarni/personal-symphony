type locationObj = {
  protocol: string,
  host: string,
}

type messageEvent = {
  data: string,
}

type socket
type webSocketCtor

%%raw(`
function makeSocket(WebSocketCtor, url) {
  return new WebSocketCtor(url);
}
`)

type connectionOptions<'snapshot> = {
  @as("WebSocketCtor")
  webSocketCtor: webSocketCtor,
  locationObj: locationObj,
  setTimeoutFn: (unit => unit, int) => int,
  onSnapshot: 'snapshot => unit,
  onConnectionError: string => unit,
}

@val external makeSocket: (webSocketCtor, string) => socket = "makeSocket"
@set external setOnOpen: (socket, unit => unit) => unit = "onopen"
@set external setOnMessage: (socket, messageEvent => unit) => unit = "onmessage"
@set external setOnError: (socket, unit => unit) => unit = "onerror"
@set external setOnClose: (socket, unit => unit) => unit = "onclose"
@get external readyState: socket => int = "readyState"
@send external close: socket => unit = "close"
@val external webSocket: webSocketCtor = "WebSocket"
@val @scope("window") external location: locationObj = "location"
@val @scope("window") external setTimeout: (unit => unit, int) => int = "setTimeout"
@scope("JSON") @val external parseJson: string => 'snapshot = "parse"

let liveStateUrl = locationObj => {
  let protocol = if locationObj.protocol == "https:" {
    "wss:"
  } else {
    "ws:"
  }
  protocol ++ "//" ++ locationObj.host ++ "/api/v1/state/live"
}

let createLiveStateConnection = options => {
  let reconnectDelay = ref(250)
  let closed = ref(false)
  let socket = ref(None)

  let rec connect = () => {
    if !closed.contents {
      let nextSocket = makeSocket(options.webSocketCtor, liveStateUrl(options.locationObj))
      socket := Some(nextSocket)

      setOnOpen(nextSocket, () => reconnectDelay := 250)
      setOnMessage(nextSocket, event => {
        let snapshot = parseJson(event.data)
        options.onSnapshot(snapshot)
      })
      setOnError(nextSocket, () =>
        options.onConnectionError("Live dashboard connection failed. Reconnecting...")
      )
      setOnClose(nextSocket, () => {
        if !closed.contents {
          options.onConnectionError("Live dashboard disconnected. Reconnecting...")
          let delay = reconnectDelay.contents
          let nextDelay = reconnectDelay.contents * 2
          reconnectDelay := if nextDelay > 2000 {
            2000
          } else {
            nextDelay
          }
          ignore(options.setTimeoutFn(connect, delay))
        }
      })
    }
  }

  connect()

  () => {
    closed := true
    switch socket.contents {
    | Some(currentSocket) =>
      if readyState(currentSocket) < 2 {
        close(currentSocket)
      }
    | None => ()
    }
  }
}

let connectLiveState = (onSnapshot, onConnectionError) =>
  createLiveStateConnection({
    webSocketCtor: webSocket,
    locationObj: location,
    setTimeoutFn: setTimeout,
    onSnapshot,
    onConnectionError,
  })
