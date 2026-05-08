import assert from "node:assert/strict";
import { createLiveStateConnection } from "../src/LiveState.res.js";
import { snapshotFromState } from "../src/RuntimeStateSnapshot.res.js";

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
    usage_totals: { total_tokens: 42 },
    generated_at: "2026-05-04T00:00:00Z",
    issues: [
      {
        issue_id: "I1",
        issue_identifier: "#1",
        title: "Provider neutral Runtime State",
        state: "In Progress",
        description: "Dashboard card fixture",
      },
    ],
    running: [
      {
        issue_id: "I1",
        issue_identifier: "#1",
        title: "Provider neutral Runtime State",
        state: "In Progress",
        description: "Dashboard card fixture",
        harness_name: "engineer",
        harness_kind: "claude",
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
assert.equal(snapshots[0][`codex_${"totals"}`], undefined);
assert.equal(snapshots[0].usage_totals.total_tokens, 42);
assert.equal(snapshots[0].running[0].context_status.state, "succeeded");
assert.equal(snapshots[0].running[0].harness_name, "engineer");
assert.equal(snapshots[0].running[0].harness_kind, "claude");
assert.equal(snapshots[0].retrying[0].context_status.state, "timed_out");

const dashboardSnapshot = snapshotFromState(snapshots[0]);
assert.equal(dashboardSnapshot.tokens, "42");
assert.equal(dashboardSnapshot.issues[0].harnessIdentity, "engineer (claude)");

const richDashboardSnapshot = snapshotFromState({
  workspace_repository_name: "workspace-repo",
  counts: { running: 3, retrying: 2 },
  usage_totals: { total_tokens: 99 },
  generated_at: "2026-05-04T00:02:00Z",
  last_error: "global runtime issue",
  readiness_gaps: [{ requirement: "claude", remediation: "Install Claude CLI" }],
  startup_reconciliation: [
    {
      issue_identifier: null,
      task_branch: null,
      category: "scan",
      message: "Startup check completed",
    },
    {
      issue_identifier: "#9",
      task_branch: "task/9",
      category: "attention",
      message: "Branch needs review",
    },
  ],
  status_order: ["Backlog", "In Progress"],
  ordered_queue: {
    entries: [
      {
        issue_identifier: "#4",
        title: null,
        state: "skipped",
        skip_reason: "not dispatchable",
      },
    ],
  },
  issues: [
    {
      issue_id: "I-run",
      issue_identifier: "#10",
      title: "Running issue",
      state: "In Progress",
      url: "https://example.test/issues/10",
      description: null,
    },
    {
      issue_id: "I-name",
      issue_identifier: "#11",
      title: "Harness name only",
      state: "In Progress",
      description:
        "This description is intentionally long. ".repeat(8) +
        "It should be shortened for dashboard cards.",
    },
    {
      issue_id: "I-kind",
      issue_identifier: "#12",
      title: "Harness kind only",
      state: "In Progress",
      description: "Provider kind only",
    },
    {
      issue_id: "I-blocked",
      issue_identifier: "#13",
      title: "Blocked issue",
      state: "Human Attention",
      description: "Blocked by readiness",
    },
    {
      issue_id: "I-retry",
      issue_identifier: "#14",
      title: "Retrying issue",
      state: "Retrying",
      description: "Retrying with context diagnostics",
    },
    {
      issue_id: "I-empty-retry",
      issue_identifier: "#15",
      title: "Retrying without error message",
      state: "Retrying",
      description: "Retrying without a message",
    },
  ],
  running: [
    {
      issue_id: "I-run",
      harness_name: "planner",
      harness_kind: "codex",
      goal_usage: { status: "running", time_used_seconds: 1.5, tokens_used: 7 },
      context_status: { state: "in_progress", summary: null, diagnostics_path: null },
    },
    { issue_id: "I-name", harness_name: "reviewer", harness_kind: null },
    { issue_id: "I-kind", harness_name: null, harness_kind: "pi" },
  ],
  retrying: [
    {
      issue_id: "I-retry",
      issue_identifier: "#14",
      error: "will retry",
      goal_usage: { status: null, time_used_seconds: 3, tokens_used: null },
      context_status: {
        state: "timed_out",
        summary: "Context Command timed out",
        diagnostics_path: null,
      },
    },
    {
      issue_id: "I-empty-retry",
      issue_identifier: "#15",
      error: null,
      goal_usage: null,
      context_status: null,
    },
  ],
  issue_errors: [
    {
      issue_id: "I-blocked",
      issue_identifier: "#13",
      error: "human action required",
      goal_usage: { status: "blocked", time_used_seconds: null, tokens_used: 8 },
    },
  ],
});

assert.equal(richDashboardSnapshot.workspaceRepositoryName, "workspace-repo");
assert.equal(richDashboardSnapshot.running, "3");
assert.equal(richDashboardSnapshot.retrying, "2");
assert.equal(richDashboardSnapshot.tokens, "99");
assert.match(richDashboardSnapshot.readinessGaps, /claude: Install Claude CLI/);
assert.match(richDashboardSnapshot.startupReconciliation, /startup scan/);
assert.match(richDashboardSnapshot.startupReconciliation, /#9 task\/9 attention/);
assert.equal(richDashboardSnapshot.lastError, "global runtime issue");
assert.equal(richDashboardSnapshot.orderedQueue[0].title, "");
assert.equal(richDashboardSnapshot.orderedQueue[0].skipReason, "not dispatchable");
assert.equal(richDashboardSnapshot.issues[0].description, "No description provided.");
assert.equal(richDashboardSnapshot.issues[0].goalUsage, "status running | time 1.5s | tokens 7");
assert.equal(richDashboardSnapshot.issues[0].contextStatus, "in progress");
assert.equal(richDashboardSnapshot.issues[0].harnessIdentity, "planner (codex)");
assert.equal(richDashboardSnapshot.issues[1].harnessIdentity, "reviewer");
assert.match(richDashboardSnapshot.issues[1].description, /\.\.\.$/);
assert.equal(richDashboardSnapshot.issues[2].harnessIdentity, "pi");
assert.equal(richDashboardSnapshot.issues[3].error, "human action required");
assert.equal(richDashboardSnapshot.issues[3].goalUsage, "status blocked | tokens 8");
assert.equal(richDashboardSnapshot.issues[4].error, "will retry");
assert.equal(richDashboardSnapshot.issues[4].goalUsage, "time 3s");
assert.equal(richDashboardSnapshot.issues[4].contextStatus, "timed out: Context Command timed out");
assert.equal(richDashboardSnapshot.issues[5].error, "");

sockets[0].onmessage({
  data: JSON.stringify({
    counts: { running: 1, retrying: 0 },
    usage_totals: { total_tokens: 13 },
    generated_at: "2026-05-04T00:01:00Z",
    running: [{ issue_id: "I3", issue_identifier: "#3" }],
  }),
});
assert.equal(snapshots.length, 2);
assert.equal(snapshots[1].running[0].context_status, undefined);
assert.equal(snapshots[1].running[0].harness_name, undefined);

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
