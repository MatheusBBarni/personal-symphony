function liveStateUrl(locationObj) {
  const protocol = locationObj.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${locationObj.host}/api/v1/state/live`;
}

export function createLiveStateConnection({
  WebSocketCtor,
  locationObj,
  setTimeoutFn,
  onSnapshot,
  onConnectionError,
}) {
  let reconnectDelay = 250;
  let closed = false;
  let socket = null;

  const connect = () => {
    if (closed) return;
    socket = new WebSocketCtor(liveStateUrl(locationObj));

    socket.onopen = () => {
      reconnectDelay = 250;
    };

    socket.onmessage = event => {
      const snapshot = JSON.parse(event.data);
      onSnapshot(snapshot);
    };

    socket.onerror = () => {
      onConnectionError("Live dashboard connection failed. Reconnecting...");
    };

    socket.onclose = () => {
      if (closed) return;
      onConnectionError("Live dashboard disconnected. Reconnecting...");
      const delay = reconnectDelay;
      reconnectDelay = Math.min(reconnectDelay * 2, 2000);
      setTimeoutFn(connect, delay);
    };
  };

  connect();

  return () => {
    closed = true;
    if (socket && socket.readyState < 2) {
      socket.close();
    }
  };
}

export function connectLiveState(onSnapshot, onConnectionError) {
  return createLiveStateConnection({
    WebSocketCtor: WebSocket,
    locationObj: window.location,
    setTimeoutFn: window.setTimeout.bind(window),
    onSnapshot,
    onConnectionError,
  });
}
