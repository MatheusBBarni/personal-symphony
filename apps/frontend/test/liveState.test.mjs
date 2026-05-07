import assert from "node:assert/strict";
import { createLiveStateConnection } from "../src/LiveState.res.js";

const sockets = [];
const timers = [];
const snapshots = [];
const errors = [];

class MockWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;

  constructor(url) {
    this.url = url;
    this.readyState = MockWebSocket.CONNECTING;
    sockets.push(this);
  }

  close() {
    this.readyState = MockWebSocket.CLOSED;
  }
}

globalThis.fetch = () => {
  throw new Error("fetch polling must not be used by live dashboard state");
};

createLiveStateConnection({
  WebSocketCtor: MockWebSocket,
  locationObj: { protocol: "http:", host: "127.0.0.1:8080" },
  setTimeoutFn: (fn, delay) => {
    timers.push({ fn, delay });
    return timers.length;
  },
  onSnapshot: snapshot => snapshots.push(snapshot),
  onConnectionError: message => errors.push(message),
});

assert.equal(sockets.length, 1);
assert.equal(sockets[0].url, "ws://127.0.0.1:8080/api/v1/state/live");

sockets[0].onmessage({
  data: JSON.stringify({
    counts: { running: 1, retrying: 1 },
    generated_at: "2026-05-04T00:00:00Z",
    running: [
      {
        issue_id: "I1",
        issue_identifier: "#1",
        context_status: {
          state: "succeeded",
          summary: "Agent Context Snapshot generated.",
          diagnostics_path: null,
        },
      },
    ],
    retrying: [
      {
        issue_id: "I2",
        issue_identifier: "#2",
        context_status: {
          state: "timed_out",
          summary: "Context Command timed out after 20ms; prompt contains bounded warning.",
          diagnostics_path: null,
        },
      },
    ],
  }),
});
assert.equal(snapshots.length, 1);
assert.equal(snapshots[0].counts.running, 1);
assert.equal(snapshots[0].running[0].context_status.state, "succeeded");
assert.equal(snapshots[0].retrying[0].context_status.state, "timed_out");

sockets[0].onmessage({
  data: JSON.stringify({
    counts: { running: 1, retrying: 0 },
    generated_at: "2026-05-04T00:01:00Z",
    running: [{ issue_id: "I3", issue_identifier: "#3" }],
  }),
});
assert.equal(snapshots.length, 2);
assert.equal(snapshots[1].running[0].context_status, undefined);

sockets[0].onclose();
assert.equal(errors.at(-1), "Live dashboard disconnected. Reconnecting...");
assert.equal(snapshots.at(-1).counts.running, 1);
assert.equal(timers.length, 1);
assert.equal(timers[0].delay, 250);

timers[0].fn();
assert.equal(sockets.length, 2);
assert.equal(sockets[1].url, "ws://127.0.0.1:8080/api/v1/state/live");

sockets[1].onerror();
assert.equal(errors.at(-1), "Live dashboard connection failed. Reconnecting...");
