import assert from "node:assert/strict";
import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { make as Dashboard } from "../src/Pages/Dashboard.res.js";
import { createLiveStateConnection } from "../src/LiveState.res.js";
import { trackerKindOrDefault } from "../src/RuntimeState.res.js";
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

const disconnectLiveState = createLiveStateConnection({
  WebSocketCtor: MockWebSocket,
  locationObj: { protocol: "http:", host: "127.0.0.1:8080", search: "" },
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
    tracker_kind: "compozy_tasks",
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
    intake_evaluations: [
      {
        issue_identifier: "#1",
        eligible: true,
        state: "ready",
        reason: "Tracker state matches configured Symphony-ready Status.",
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
        sandbox_enabled: true,
        sandbox_provider: "docker",
        sandbox_reuse_outcome: "reused",
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
    compozy_progress: {
      run_id: "compozy:compozy-tasks-run-integration",
      slug: "compozy-tasks-run-integration",
      current_step: "task_02.md",
      completed: 1,
      failed: 0,
      skipped: 0,
      total: 8,
      lifecycle_state: "pr_handoff",
      dispatch_state: "Done",
      stage_agent: "engineer",
      pr_readiness: "handoff_failed",
      reason: "Batch Pull Request handoff failed.",
      handoff_status: "handoff_failed",
    },
  }),
});
assert.equal(snapshots.length, 1);
assert.equal(snapshots[0].counts.running, 1);
assert.equal(trackerKindOrDefault(snapshots[0].tracker_kind), "compozy_tasks");
assert.equal(snapshots[0][`codex_${"totals"}`], undefined);
assert.equal(snapshots[0].usage_totals.total_tokens, 42);
assert.equal(snapshots[0].running[0].context_status.state, "succeeded");
assert.equal(snapshots[0].running[0].harness_name, "engineer");
assert.equal(snapshots[0].running[0].harness_kind, "claude");
assert.equal(snapshots[0].intake_evaluations[0].state, "ready");
assert.equal(snapshots[0].running[0].sandbox_enabled, true);
assert.equal(snapshots[0].running[0].sandbox_provider, "docker");
assert.equal(snapshots[0].running[0].sandbox_reuse_outcome, "reused");
assert.equal(snapshots[0].retrying[0].context_status.state, "timed_out");
assert.equal(snapshots[0].compozy_progress.current_step, "task_02.md");
assert.equal(snapshots[0].compozy_progress.completed, 1);
assert.equal(snapshots[0].compozy_progress.failed, 0);
assert.equal(snapshots[0].compozy_progress.skipped, 0);
assert.equal(snapshots[0].compozy_progress.total, 8);
assert.equal(snapshots[0].compozy_progress.lifecycle_state, "pr_handoff");
assert.equal(snapshots[0].compozy_progress.dispatch_state, "Done");
assert.equal(snapshots[0].compozy_progress.stage_agent, "engineer");
assert.equal(snapshots[0].compozy_progress.pr_readiness, "handoff_failed");
assert.equal(snapshots[0].compozy_progress.reason, "Batch Pull Request handoff failed.");
assert.equal(snapshots[0].compozy_progress.handoff_status, "handoff_failed");

const dashboardSnapshot = snapshotFromState(snapshots[0]);
assert.equal(dashboardSnapshot.trackerKind, "compozy_tasks");
assert.equal(dashboardSnapshot.tokens, "42");
assert.equal(dashboardSnapshot.issues[0].harnessIdentity, "engineer (claude)");
assert.equal(dashboardSnapshot.issues[0].intakeState, "Ready for intake");
assert.equal(dashboardSnapshot.issues[0].intakeReason, "Tracker state matches configured Symphony-ready Status.");
assert.equal(dashboardSnapshot.issues[0].sandbox, "docker reused");
assert.equal(dashboardSnapshot.compozyProgress.runId, "compozy:compozy-tasks-run-integration");
assert.equal(dashboardSnapshot.compozyProgress.currentStep, "task_02.md");
assert.equal(dashboardSnapshot.compozyProgress.completed, "1");
assert.equal(dashboardSnapshot.compozyProgress.failed, "0");
assert.equal(dashboardSnapshot.compozyProgress.skipped, "0");
assert.equal(dashboardSnapshot.compozyProgress.total, "8");
assert.equal(dashboardSnapshot.compozyProgress.lifecycleState, "pr_handoff");
assert.equal(dashboardSnapshot.compozyProgress.dispatchState, "Done");
assert.equal(dashboardSnapshot.compozyProgress.stageAgent, "engineer");
assert.equal(dashboardSnapshot.compozyProgress.prReadiness, "handoff_failed");
assert.equal(dashboardSnapshot.compozyProgress.reason, "Batch Pull Request handoff failed.");
assert.equal(dashboardSnapshot.compozyProgress.handoffStatus, "handoff_failed");

const lifecycleMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: dashboardSnapshot, error: undefined }),
);
assert.match(lifecycleMarkup, /Compozy PRD Run progress/);
assert.match(lifecycleMarkup, /Compozy PRD Run lifecycle/);
assert.match(lifecycleMarkup, /Compozy Task Step progress/);
assert.match(lifecycleMarkup, /Lifecycle/);
assert.match(lifecycleMarkup, /pr_handoff/);
assert.match(lifecycleMarkup, /Dispatch state/);
assert.match(lifecycleMarkup, /Done/);
assert.match(lifecycleMarkup, /Stage agent/);
assert.match(lifecycleMarkup, /engineer/);
assert.match(lifecycleMarkup, /Sandbox/);
assert.match(lifecycleMarkup, /docker reused/);
assert.match(lifecycleMarkup, /PR readiness/);
assert.match(lifecycleMarkup, /handoff_failed/);
assert.match(lifecycleMarkup, /Handoff status/);
assert.match(lifecycleMarkup, /handoff_failed/);
assert.match(lifecycleMarkup, /Reason/);
assert.match(lifecycleMarkup, /Batch Pull Request handoff failed\./);
assert.match(lifecycleMarkup, /Intake/);
assert.match(lifecycleMarkup, /Ready for intake/);
assert.match(lifecycleMarkup, /Tracker state matches configured Symphony-ready Status\./);
assert.match(lifecycleMarkup, /Current step/);
assert.match(lifecycleMarkup, /task_02\.md/);
assert.match(lifecycleMarkup, /Completed/);
assert.match(lifecycleMarkup, /Failed/);
assert.match(lifecycleMarkup, /Skipped/);
assert.match(lifecycleMarkup, /Total/);

const reviewDashboardSnapshot = snapshotFromState({
  tracker_kind: "compozy_tasks",
  counts: { running: 1, retrying: 0 },
  usage_totals: { total_tokens: 18 },
  generated_at: "2026-05-04T00:02:00Z",
  status_order: ["In review"],
  issues: [],
  running: [],
  retrying: [],
  issue_errors: [],
  compozy_progress: {
    run_id: "compozy:review-run",
    slug: "review-run",
    current_step: "task_04.md",
    completed: 3,
    failed: 0,
    skipped: 0,
    total: 6,
    lifecycle_state: "in_review",
    dispatch_state: "In review",
    stage_agent: "reviewer",
    pr_readiness: "not_ready",
    reason: "Reviewer found failing verification.",
  },
});

assert.equal(reviewDashboardSnapshot.compozyProgress.currentStep, "task_04.md");
assert.equal(reviewDashboardSnapshot.compozyProgress.completed, "3");
assert.equal(reviewDashboardSnapshot.compozyProgress.failed, "0");
assert.equal(reviewDashboardSnapshot.compozyProgress.skipped, "0");
assert.equal(reviewDashboardSnapshot.compozyProgress.total, "6");
assert.equal(reviewDashboardSnapshot.compozyProgress.lifecycleState, "in_review");
assert.equal(reviewDashboardSnapshot.compozyProgress.dispatchState, "In review");
assert.equal(reviewDashboardSnapshot.compozyProgress.stageAgent, "reviewer");
assert.equal(reviewDashboardSnapshot.compozyProgress.prReadiness, "not_ready");
assert.equal(reviewDashboardSnapshot.compozyProgress.reason, "Reviewer found failing verification.");
assert.equal(reviewDashboardSnapshot.compozyProgress.handoffStatus, "");

const reviewMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: reviewDashboardSnapshot, error: undefined }),
);
assert.match(reviewMarkup, /Lifecycle/);
assert.match(reviewMarkup, /in_review/);
assert.match(reviewMarkup, /Dispatch state/);
assert.match(reviewMarkup, /In review/);
assert.match(reviewMarkup, /Stage agent/);
assert.match(reviewMarkup, /reviewer/);
assert.match(reviewMarkup, /PR readiness/);
assert.match(reviewMarkup, /not_ready/);
assert.match(reviewMarkup, /Reason/);
assert.match(reviewMarkup, /Reviewer found failing verification\./);
assert.match(reviewMarkup, /Current step/);
assert.match(reviewMarkup, /task_04\.md/);
assert.doesNotMatch(reviewMarkup, /Handoff status/);

const blockedDashboardSnapshot = snapshotFromState({
  tracker_kind: "compozy_tasks",
  counts: { running: 0, retrying: 0 },
  usage_totals: { total_tokens: 21 },
  generated_at: "2026-05-04T00:02:30Z",
  status_order: ["Human attention"],
  issues: [],
  running: [],
  retrying: [],
  issue_errors: [],
  compozy_progress: {
    run_id: "compozy:blocked-run",
    slug: "blocked-run",
    current_step: "task_03.md",
    completed: 2,
    failed: 1,
    skipped: 0,
    total: 5,
    lifecycle_state: "blocked",
    dispatch_state: "Human attention",
    stage_agent: "engineer",
    pr_readiness: "not_ready",
    reason: "Protected path attention required.",
  },
});

assert.equal(blockedDashboardSnapshot.compozyProgress.currentStep, "task_03.md");
assert.equal(blockedDashboardSnapshot.compozyProgress.completed, "2");
assert.equal(blockedDashboardSnapshot.compozyProgress.failed, "1");
assert.equal(blockedDashboardSnapshot.compozyProgress.skipped, "0");
assert.equal(blockedDashboardSnapshot.compozyProgress.total, "5");
assert.equal(blockedDashboardSnapshot.compozyProgress.lifecycleState, "blocked");
assert.equal(blockedDashboardSnapshot.compozyProgress.dispatchState, "Human attention");
assert.equal(blockedDashboardSnapshot.compozyProgress.stageAgent, "engineer");
assert.equal(blockedDashboardSnapshot.compozyProgress.prReadiness, "not_ready");
assert.equal(blockedDashboardSnapshot.compozyProgress.reason, "Protected path attention required.");
assert.equal(blockedDashboardSnapshot.compozyProgress.handoffStatus, "");

const blockedMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: blockedDashboardSnapshot, error: undefined }),
);
assert.match(blockedMarkup, /Lifecycle/);
assert.match(blockedMarkup, /blocked/);
assert.match(blockedMarkup, /Dispatch state/);
assert.match(blockedMarkup, /Human attention/);
assert.match(blockedMarkup, /Stage agent/);
assert.match(blockedMarkup, /engineer/);
assert.match(blockedMarkup, /PR readiness/);
assert.match(blockedMarkup, /not_ready/);
assert.match(blockedMarkup, /Reason/);
assert.match(blockedMarkup, /Protected path attention required\./);
assert.match(blockedMarkup, /Current step/);
assert.match(blockedMarkup, /task_03\.md/);
assert.match(blockedMarkup, /Completed/);
assert.match(blockedMarkup, /Failed/);
assert.match(blockedMarkup, /Skipped/);
assert.match(blockedMarkup, /Total/);
assert.doesNotMatch(blockedMarkup, /Handoff status/);

const compozyDashboardSnapshot = snapshotFromState({
  tracker_kind: "compozy_tasks",
  counts: { running: 1, retrying: 0 },
  usage_totals: { total_tokens: 11 },
  generated_at: "2026-05-04T00:03:00Z",
  status_order: ["In Progress"],
  issues: [
    {
      issue_id: "compozy:compozy-tasks-run-integration",
      issue_identifier: "compozy:compozy-tasks-run-integration",
      title: "Compozy Tasks Run Integration",
      state: "In Progress",
      description: "Run task files as one PRD run.",
    },
  ],
  intake_evaluations: [
    {
      issue_identifier: "compozy:compozy-tasks-run-integration",
      eligible: false,
      state: "parse_blocked",
      reason: "Ready-status parse failed for _tasks.md.",
    },
  ],
  running: [],
  retrying: [],
  issue_errors: [],
  compozy_progress: {
    run_id: "compozy:compozy-tasks-run-integration",
    slug: "compozy-tasks-run-integration",
    current_step: "task_02.md",
    completed: 1,
    failed: 0,
    skipped: 1,
    total: 8,
  },
});

assert.equal(compozyDashboardSnapshot.trackerKind, "compozy_tasks");
assert.equal(compozyDashboardSnapshot.compozyProgress.currentStep, "task_02.md");
assert.equal(compozyDashboardSnapshot.compozyProgress.completed, "1");
assert.equal(compozyDashboardSnapshot.compozyProgress.failed, "0");
assert.equal(compozyDashboardSnapshot.compozyProgress.skipped, "1");
assert.equal(compozyDashboardSnapshot.compozyProgress.total, "8");
assert.equal(compozyDashboardSnapshot.compozyProgress.lifecycleState, "");
assert.equal(compozyDashboardSnapshot.compozyProgress.dispatchState, "");
assert.equal(compozyDashboardSnapshot.compozyProgress.stageAgent, "");
assert.equal(compozyDashboardSnapshot.compozyProgress.prReadiness, "");
assert.equal(compozyDashboardSnapshot.compozyProgress.reason, "");
assert.equal(compozyDashboardSnapshot.compozyProgress.handoffStatus, "");
assert.equal(compozyDashboardSnapshot.issues[0].intakeState, "Parse blocked");
assert.equal(compozyDashboardSnapshot.issues[0].intakeReason, "Ready-status parse failed for _tasks.md.");

const compozyMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: compozyDashboardSnapshot, error: undefined }),
);
assert.match(compozyMarkup, /Compozy PRD Run progress/);
assert.match(compozyMarkup, /Compozy Task Step progress/);
assert.match(compozyMarkup, /task_02\.md/);
assert.match(compozyMarkup, /Current step/);
assert.match(compozyMarkup, /Completed/);
assert.match(compozyMarkup, /Failed/);
assert.match(compozyMarkup, /Skipped/);
assert.match(compozyMarkup, /Total/);
assert.match(compozyMarkup, /1 tracked PRD runs/);
assert.match(compozyMarkup, /work item states/);
assert.match(compozyMarkup, /Parse blocked/);
assert.match(compozyMarkup, /Ready-status parse failed for _tasks\.md\./);
assert.doesNotMatch(compozyMarkup, /Lifecycle/);
assert.doesNotMatch(compozyMarkup, /Compozy PRD Run lifecycle/);
assert.doesNotMatch(compozyMarkup, /Dispatch state/);
assert.doesNotMatch(compozyMarkup, /Stage agent/);
assert.doesNotMatch(compozyMarkup, /PR readiness/);
assert.doesNotMatch(compozyMarkup, /Handoff status/);
assert.doesNotMatch(compozyMarkup, /Reason/);

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
  intake_evaluations: [
    {
      issue_identifier: "#13",
      eligible: false,
      state: "queue_blocked",
      reason: "Ordered Queue entry is waiting for first-admission eligibility.",
    },
    {
      issue_identifier: "#15",
      eligible: true,
      state: "admitted",
      reason: "Work item was already admitted; lifecycle state now controls execution.",
    },
  ],
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
assert.equal(richDashboardSnapshot.issues[3].intakeState, "Queue blocked");
assert.equal(
  richDashboardSnapshot.issues[3].intakeReason,
  "Ordered Queue entry is waiting for first-admission eligibility.",
);
assert.equal(richDashboardSnapshot.issues[3].goalUsage, "status blocked | tokens 8");
assert.equal(richDashboardSnapshot.issues[4].error, "will retry");
assert.equal(richDashboardSnapshot.issues[4].goalUsage, "time 3s");
assert.equal(richDashboardSnapshot.issues[4].contextStatus, "timed out: Context Command timed out");
assert.equal(richDashboardSnapshot.issues[5].error, "");
assert.equal(richDashboardSnapshot.issues[5].intakeState, "Already admitted");

const richMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: richDashboardSnapshot, error: "live socket warning" }),
);
assert.match(richMarkup, /Live Dashboard Connection/);
assert.match(richMarkup, /live socket warning/);
assert.match(richMarkup, /Readiness Gaps/);
assert.match(richMarkup, /claude: Install Claude CLI/);
assert.match(richMarkup, /Startup Reconciliation/);
assert.match(richMarkup, /Startup check completed/);
assert.match(richMarkup, /Runtime State Error/);
assert.match(richMarkup, /global runtime issue/);
assert.match(richMarkup, /Ordered Queue/);
assert.match(richMarkup, /Pending work item details/);
assert.match(richMarkup, /not dispatchable/);
assert.match(richMarkup, /Goal Usage/);
assert.match(richMarkup, /status running \| time 1\.5s \| tokens 7/);
assert.match(richMarkup, /Context Status/);
assert.match(richMarkup, /timed out: Context Command timed out/);
assert.match(richMarkup, /Harness/);
assert.match(richMarkup, /planner \(codex\)/);
assert.match(richMarkup, /human action required/);
assert.match(richMarkup, /Queue blocked/);
assert.match(richMarkup, /Already admitted/);
assert.match(richMarkup, /6 tracked issues/);
assert.match(richMarkup, /Tracker github/);

const emptyTrackerSnapshot = snapshotFromState({
  tracker_kind: "github",
  counts: { running: 0, retrying: 0 },
  usage_totals: { total_tokens: 0 },
  generated_at: "2026-05-04T00:04:00Z",
  status_order: [],
  issues: [],
  running: [],
  retrying: [],
  issue_errors: [],
});

const emptyTrackerMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: emptyTrackerSnapshot, error: undefined }),
);
assert.match(emptyTrackerMarkup, /No tracked issues were returned by the latest snapshot\./);

const legacyIssueSnapshot = snapshotFromState({
  tracker_kind: "github",
  counts: { running: 0, retrying: 0 },
  usage_totals: { total_tokens: 0 },
  generated_at: "2026-05-04T00:04:30Z",
  status_order: ["Todo"],
  issues: [{ issue_id: "I-legacy", issue_identifier: "#99", title: "Legacy issue", state: "Todo" }],
  running: [],
  retrying: [],
  issue_errors: [],
});
assert.equal(legacyIssueSnapshot.issues[0].intakeState, "");
assert.equal(legacyIssueSnapshot.issues[0].intakeReason, "");

const loadingMarkup = renderToStaticMarkup(
  React.createElement(Dashboard, { snapshot: undefined, error: "backend unavailable" }),
);
assert.match(loadingMarkup, /Backend unavailable/);
assert.match(loadingMarkup, /Loading runtime state/);

sockets[0].onmessage({
  data: JSON.stringify({
    counts: { running: 1, retrying: 0 },
    usage_totals: { total_tokens: 13 },
    generated_at: "2026-05-04T00:01:00Z",
    running: [{ issue_id: "I3", issue_identifier: "#3" }],
  }),
});
assert.equal(snapshots.length, 2);
assert.equal(trackerKindOrDefault(snapshots[1].tracker_kind), "github");
assert.equal(snapshots[1].compozy_progress, undefined);
assert.equal(snapshotFromState(snapshots[1]).compozyProgress, undefined);
assert.equal(snapshots[1].running[0].context_status, undefined);
assert.equal(snapshots[1].running[0].harness_name, undefined);
assert.equal(snapshotFromState(snapshots[1]).issues.length, 0);
assert.equal(snapshots[1].running[0].sandbox_enabled, undefined);

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

disconnectLiveState();
assert.equal(sockets[1].readyState, MockWebSocket.CLOSED);
sockets[1].onclose();
assert.equal(timers.length, 1);

const authSocketIndex = sockets.length;
const disconnectAuthLiveState = createLiveStateConnection({
  WebSocketCtor: MockWebSocket,
  locationObj: { protocol: "http:", host: "127.0.0.1:8080", search: "?symphony_auth=local token&ignored=1" },
  setTimeoutFn: (fn, delay) => {
    timers.push({ fn, delay });
    return timers.length;
  },
  onSnapshot: snapshot => snapshots.push(snapshot),
  onConnectionError: message => errors.push(message),
});

assert.equal(sockets[authSocketIndex].url, "ws://127.0.0.1:8080/api/v1/state/live?symphony_auth=local%20token");
disconnectAuthLiveState();
