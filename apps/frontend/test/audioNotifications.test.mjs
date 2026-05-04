import assert from "node:assert/strict";
import { audioNotificationForTransition } from "../src/AudioNotifications.res.js";

const state = overrides => ({
  counts: { running: 0, retrying: 0 },
  issue_errors: [],
  retrying: [],
  last_error: null,
  ...overrides,
});

assert.equal(audioNotificationForTransition(undefined, state({ counts: { running: 0, retrying: 0 } })), undefined);

assert.equal(
  audioNotificationForTransition(
    state({ counts: { running: 1, retrying: 0 } }),
    state({ counts: { running: 0, retrying: 0 } }),
  ),
  "idle",
);

assert.equal(
  audioNotificationForTransition(
    state({ counts: { running: 0, retrying: 1 } }),
    state({ counts: { running: 0, retrying: 0 } }),
  ),
  "idle",
);

assert.equal(
  audioNotificationForTransition(
    state({ issue_errors: [] }),
    state({ issue_errors: [{ issue_id: "6", issue_identifier: "#6", error: "blocked" }] }),
  ),
  "attention",
);

assert.equal(
  audioNotificationForTransition(
    state({ issue_errors: [{ issue_id: "6", issue_identifier: "#6", error: "blocked" }] }),
    state({ issue_errors: [{ issue_id: "6", issue_identifier: "#6", error: "still blocked" }] }),
  ),
  undefined,
);

assert.equal(
  audioNotificationForTransition(
    state({ counts: { running: 1, retrying: 0 }, issue_errors: [] }),
    state({
      counts: { running: 0, retrying: 0 },
      issue_errors: [{ issue_id: "6", issue_identifier: "#6", error: "blocked" }],
    }),
  ),
  "attention",
);

assert.equal(
  audioNotificationForTransition(
    state({ retrying: [] }),
    state({ retrying: [{ issue_id: "6", issue_identifier: "#6", error: "try again" }] }),
  ),
  undefined,
);

assert.equal(
  audioNotificationForTransition(state({ last_error: null }), state({ last_error: "backend warning" })),
  undefined,
);
