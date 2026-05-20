#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const docs = [
  "README.md",
  ".github/project-tracking.md",
];

const contextPath = path.join(root, "CONTEXT.md");
const context = fs.readFileSync(contextPath, "utf8");

const failures = [];

function fail(message) {
  failures.push(message);
}

function readDoc(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function extractJsonBlocks(markdown, relativePath) {
  const blocks = [];
  const fencePattern = /```json\n([\s\S]*?)```/g;
  let match;
  while ((match = fencePattern.exec(markdown)) !== null) {
    blocks.push({ relativePath, source: match[1], index: blocks.length + 1 });
  }
  return blocks;
}

function assertSecretFree(relativePath, text) {
  const forbidden = [
    { name: "GitHub token literal", pattern: /\b(?:github_pat_[A-Za-z0-9_]+|gh[pousr]_[A-Za-z0-9_]{20,})\b/ },
    { name: "Slack webhook URL", pattern: /https:\/\/hooks\.slack\.com\/services\// },
    { name: "Discord webhook URL", pattern: /https:\/\/(?:canary\.)?discord(?:app)?\.com\/api\/webhooks\// },
    { name: "local env token assignment", pattern: /^\s*(?:GITHUB_TOKEN|GH_TOKEN|NPM_TOKEN)\s*=\s*\S+/m },
  ];

  for (const { name, pattern } of forbidden) {
    if (pattern.test(text)) {
      fail(`${relativePath} contains forbidden ${name}`);
    }
  }
}

function parseJsonBlock(block) {
  try {
    return JSON.parse(block.source);
  } catch (error) {
    fail(`${block.relativePath} json block ${block.index} is invalid JSON: ${error.message}`);
    return null;
  }
}

function assertTrackerExamples(blocks) {
  const allowedKinds = new Set(["github", "minibeads", "compozy_tasks"]);
  const seenKinds = new Set();

  for (const block of blocks) {
    const parsed = parseJsonBlock(block);
    if (!parsed || typeof parsed !== "object" || !parsed.tracker) {
      continue;
    }

    const kind = parsed.tracker.kind;
    if (!allowedKinds.has(kind)) {
      fail(`${block.relativePath} json block ${block.index} must use a documented tracker.kind`);
      continue;
    }

    seenKinds.add(kind);

    if (kind === "minibeads") {
      if (parsed.tracker.command !== "mb") {
        fail(`${block.relativePath} json block ${block.index} must document tracker.command for minibeads`);
      }
      if (parsed.tracker.root !== ".beads") {
        fail(`${block.relativePath} json block ${block.index} must document tracker.root for minibeads`);
      }
    }

    if (kind === "compozy_tasks") {
      if (!parsed.tracker.compozy || parsed.tracker.compozy.root !== ".compozy/tasks") {
        fail(`${block.relativePath} json block ${block.index} must document tracker.compozy.root`);
      }
      if (parsed.tracker.compozy.maxTaskStepRetries !== 2) {
        fail(`${block.relativePath} json block ${block.index} must document tracker.compozy.maxTaskStepRetries`);
      }
    }
  }

  for (const requiredKind of allowedKinds) {
    if (!seenKinds.has(requiredKind)) {
      fail(`missing ${requiredKind} tracker settings example`);
    }
  }
}

function assertGlossaryTerms() {
  const terms = [
    "Issue Tracker",
    "GitHub Tracker",
    "Local Issue Tracker",
    "Local Issue File",
    "Compozy PRD Run",
    "Compozy Task Step",
    "Runtime Settings",
    "Readiness Gap",
    "Goal Loop",
    "Goal Loop State",
    "Goal Loop Evidence Command",
    "Goal Loop Stop Outcome",
  ];

  for (const term of terms) {
    if (!context.includes(`**${term}**:`)) {
      fail(`CONTEXT.md is missing glossary term ${term}`);
    }
  }

  const combinedDocs = docs.map(readDoc).join("\n");
  const normalizedDocs = combinedDocs.replace(/\s+/g, " ");
  for (const term of terms) {
    if (!normalizedDocs.includes(term)) {
      fail(`documentation does not use glossary term ${term}`);
    }
  }
}

function assertReadinessGuidance(readme) {
  const required = [
    "tracker.minibeads.command",
    "tracker.minibeads.store",
    "tracker.command",
    "tracker.root",
    "mb",
    "local issue store",
  ];

  for (const phrase of required) {
    if (!readme.includes(phrase)) {
      fail(`README.md is missing minibeads readiness guidance for ${phrase}`);
    }
  }
}

function assertCompozyGuidance(readme) {
  const required = [
    'tracker.kind = "compozy_tasks"',
    "GitHub remains the default Issue Tracker",
    ".compozy/tasks/<task_name>/",
    "Compozy PRD Run",
    "Compozy Task Steps",
    "tracker.compozy.root",
    "tracker.compozy.maxTaskStepRetries",
    "pending",
    "in_progress",
    "completed",
    "failed",
    "skipped",
    "Runtime State",
    "Terminal Console",
    "Web Dashboard",
    "Compozy tracking has four related status layers",
    "Compozy PR Readiness",
    "`lifecycle_state`",
    "`dispatch_state`",
    "`pr_readiness`",
    "`handoff_status`",
    "compozy:<task_name>",
    "Ordered Queue",
    "Manual Task Merge",
  ];

  for (const phrase of required) {
    if (!readme.includes(phrase)) {
      fail(`README.md is missing Compozy tracker guidance for ${phrase}`);
    }
  }
}

function extractOcamlMappingStrings(relativePath, functionName) {
  const source = readDoc(relativePath);
  const marker = `let ${functionName} = function`;
  const start = source.indexOf(marker);
  if (start === -1) {
    fail(`${relativePath} is missing ${functionName}`);
    return [];
  }

  const afterMarker = source.slice(start + marker.length);
  const end = afterMarker.search(/\n\nlet\s/);
  const body = end === -1 ? afterMarker : afterMarker.slice(0, end);
  const values = [...body.matchAll(/\|\s*[A-Za-z_][A-Za-z0-9_]*\s*->\s*"([^"]+)"/g)].map(
    (match) => match[1],
  );

  if (values.length === 0) {
    fail(`${relativePath} ${functionName} has no documented string mappings`);
  }

  return values;
}

function markdownTableRow(markdown, label) {
  return markdown.split(/\r?\n/).find((line) => line.startsWith(`| ${label} |`));
}

function markdownCells(row) {
  return row
    .split("|")
    .slice(1, -1)
    .map((cell) => cell.trim());
}

function assertCompozyLifecycleContractDocs(readme) {
  const lifecycleValues = extractOcamlMappingStrings(
    "apps/backend/lib/compozy_lifecycle.ml",
    "lifecycle_state_to_string",
  );
  const readinessValues = extractOcamlMappingStrings(
    "apps/backend/lib/compozy_lifecycle.ml",
    "pr_readiness_to_string",
  );

  for (const value of lifecycleValues) {
    if (!readme.includes(`| \`${value}\` |`)) {
      fail(`README.md does not document implemented lifecycle_state ${value}`);
    }
    if (!context.includes(`\`${value}\``)) {
      fail(`CONTEXT.md does not document implemented lifecycle_state ${value}`);
    }
  }

  for (const value of readinessValues) {
    if (!readme.includes(`| \`${value}\` |`)) {
      fail(`README.md does not document implemented pr_readiness ${value}`);
    }
    if (!context.includes(`\`${value}\``)) {
      fail(`CONTEXT.md does not document implemented pr_readiness ${value}`);
    }
  }

  const requiredFields = [
    "current_step",
    "completed",
    "failed",
    "skipped",
    "total",
    "lifecycle_state",
    "dispatch_state",
    "stage_agent",
    "pr_readiness",
    "handoff_status",
    "reason",
  ];
  for (const field of requiredFields) {
    if (!readme.includes(`\`${field}\``)) {
      fail(`README.md is missing Compozy Runtime State field ${field}`);
    }
  }

  const scenarios = [
    ["Review active", "`in_review`", "`not_ready` / none"],
    ["Retrying execution", "`in_execution`", "`not_ready` / none"],
    ["Blocked attention", "`blocked`", "`not_ready` / none"],
    ["Failed or skipped terminal", "`failed` or `skipped`", "`not_ready` / none"],
    ["Completed and batch-ready", "`completed`", "`ready` / none"],
    ["Completed with pull requests disabled", "`completed`", "`disabled` / none"],
    ["Handoff failure", "`pr_handoff`", "`handoff_failed` / `handoff_failed`"],
  ];

  for (const [label, lifecycle, readiness] of scenarios) {
    const row = markdownTableRow(readme, label);
    if (!row) {
      fail(`README.md is missing Compozy scenario ${label}`);
      continue;
    }

    const cells = markdownCells(row);
    if (cells[2] !== lifecycle) {
      fail(`README.md scenario ${label} documents lifecycle ${cells[2]}, expected ${lifecycle}`);
    }
    if (cells[4] !== readiness) {
      fail(`README.md scenario ${label} documents readiness ${cells[4]}, expected ${readiness}`);
    }
  }

  if (!readme.includes("Retry does not create a new lifecycle value")) {
    fail("README.md must explain retry remains in_execution with retry context");
  }
  if (!readme.includes("Symphony never opens one pull request per Compozy Task Step")) {
    fail("README.md must keep aggregate Batch Pull Request behavior explicit");
  }
  if (!readme.includes("failed handoff is a readiness outcome")) {
    fail("README.md must explain failed handoff as readiness, not successful review readiness");
  }
}

function assertTerminalConsoleGuidance(readme) {
  const requiredReadme = [
    "default read-first Terminal Console",
    "Run `symphony` from the Workspace Repository root",
    "Runtime State snapshots",
    "Readiness Gaps",
    "Ordered Queue progress",
    "Compozy PRD Run progress",
    "Agent Worktree details",
    "Task Branch context",
    "safe local aids",
    "Web Dashboard handoff command",
    "do not retry tasks, pause or resume dispatch, update tracker status",
    "symphony --web --port 8080",
    "Live Dashboard Connection as a Runtime State stream",
    "`symphony --once`",
  ];

  for (const phrase of requiredReadme) {
    if (!readme.includes(phrase)) {
      fail(`README.md is missing Terminal Console guidance for ${phrase}`);
    }
  }

  const requiredContext = [
    "Normal `symphony` runs open the read-first Terminal Console",
    "`symphony --web` opens the **Web Dashboard**",
    "`symphony --once` prints non-interactive terminal output",
    "The **Terminal Console** uses in-process **Runtime State** snapshots",
    "The **Live Dashboard Connection** remains the **Web Dashboard** Runtime State stream",
    "**Terminal Console** local aids must not retry tasks",
  ];

  for (const phrase of requiredContext) {
    if (!context.includes(phrase)) {
      fail(`CONTEXT.md is missing Terminal Console semantics for ${phrase}`);
    }
  }

  const adrPath = "docs/adr/0024-default-rich-terminal-console.md";
  const adr = readDoc(adrPath);
  const requiredAdr = [
    "Accepted",
    "Normal `symphony` runs open the read-first Terminal Console by default",
    "`symphony --web` keeps Web Dashboard mode separate",
    "The `symphony --once` command keeps",
    "non-interactive terminal output",
    "Runtime State snapshots",
    "must not retry tasks, pause or resume dispatch",
  ];

  for (const phrase of requiredAdr) {
    if (!adr.includes(phrase)) {
      fail(`${adrPath} is missing Terminal Console decision text for ${phrase}`);
    }
  }

  const userFacingText = `${readme}\n${adr}`;
  if (/\bTUI\b/.test(userFacingText)) {
    fail("Terminal Console docs must not introduce user-facing TUI product wording");
  }
}

function assertGoalLoopGuidance(readme, jsonBlocks) {
  const normalizedReadme = readme.replace(/\s+/g, " ");
  const includesReadme = (phrase) => normalizedReadme.includes(phrase.replace(/\s+/g, " "));
  const requiredReadme = [
    "Goal Loop is separate from Stage Goal Handoff",
    "Goal Loop is Runtime-owned Stage Agent behavior",
    "Goal met requires deterministic evidence",
    "Goal Usage, agent exit `0`, changed files, or model confidence alone",
    "`goalLoop`",
    "\"command\": [\"pnpm\", \"test\"]",
    "\"cwd\": \"agentWorktree\"",
    "\"timeoutMs\": 120000",
    "\"maxOutputBytes\": 8192",
    "\"maxTurns\": 4",
    "\"maxRuntimeMs\": 3600000",
    "\"maxTokens\": 200000",
    "secret-free evidence summary",
    "top-level `goal_loops[]`",
    "`latest_evidence`",
    "`stop_outcome`",
    "`stop_reason`",
    "`next_action`",
    "The Terminal Console and Web Dashboard read that same Runtime State projection",
    "Goal Loop does not own delivery authority",
    "Stage Commit, Stage Push, Task Branch Integration, merge, pull request creation, auto-merge, and tracker status transitions",
  ];

  for (const phrase of requiredReadme) {
    if (!includesReadme(phrase)) {
      fail(`README.md is missing Goal Loop guidance for ${phrase}`);
    }
  }

  const goalLoopExamples = jsonBlocks
    .filter((block) => block.relativePath === "README.md")
    .map((block) => parseJsonBlock(block))
    .filter((parsed) => parsed?.stageAgents?.stages?.some((stage) => stage.goalLoop));

  if (goalLoopExamples.length === 0) {
    fail("README.md is missing a parseable stageAgents.stages[].goalLoop settings example");
    return;
  }

  for (const example of goalLoopExamples) {
    for (const stage of example.stageAgents.stages.filter((stage) => stage.goalLoop)) {
      const loop = stage.goalLoop;
      if (loop.enabled !== true) {
        fail("README.md Goal Loop example must set goalLoop.enabled to true");
      }
      if (!Array.isArray(loop.evidence?.command) || loop.evidence.command.join(" ") !== "pnpm test") {
        fail("README.md Goal Loop example must use a secret-free argv evidence command");
      }
      if (loop.evidence?.cwd !== "agentWorktree") {
        fail("README.md Goal Loop example must document agentWorktree evidence cwd");
      }
      if (loop.evidence?.timeoutMs !== 120000) {
        fail("README.md Goal Loop example must document evidence timeoutMs");
      }
      if (loop.evidence?.maxOutputBytes !== 8192) {
        fail("README.md Goal Loop example must document evidence maxOutputBytes");
      }
      if (!loop.budget || loop.budget.maxTurns !== 4 || loop.budget.maxRuntimeMs !== 3600000 || loop.budget.maxTokens !== 200000) {
        fail("README.md Goal Loop example must document positive turn, runtime, and token budgets");
      }
    }
  }

  const requiredContext = [
    "**Goal Loop**:",
    "**Goal Loop State**:",
    "**Goal Loop Evidence Command**:",
    "**Goal Loop Stop Outcome**:",
    "Goal met requires successful deterministic evidence from the **Goal Loop Evidence Command**",
    "A **Goal Loop** must not change retry, completion, status transition, **Stage Commit**, **Stage Push**, Task Branch Integration, auto-merge, pull request, or delivery authority",
    "The **Terminal Console** and **Web Dashboard** read **Goal Loop State** from the same **Runtime State** projection",
  ];

  for (const phrase of requiredContext) {
    if (!context.includes(phrase)) {
      fail(`CONTEXT.md is missing Goal Loop semantics for ${phrase}`);
    }
  }
}

function assertGitHubScope(projectTracking) {
  const required = [
    'tracker.kind` is `"github"`',
    "GitHub Tracker",
    "For minibeads Local Issue Tracker setup",
    "For Compozy-backed Local Issue Tracker setup",
  ];

  for (const phrase of required) {
    if (!projectTracking.includes(phrase)) {
      fail(`.github/project-tracking.md is missing scoped GitHub Tracker wording: ${phrase}`);
    }
  }
}

function collectMarkdownFiles(relativeDir) {
  const absoluteDir = path.join(root, relativeDir);
  const entries = fs.readdirSync(absoluteDir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const childRelative = path.join(relativeDir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectMarkdownFiles(childRelative));
    } else if (entry.isFile() && entry.name.endsWith(".md")) {
      files.push(childRelative);
    }
  }

  return files;
}

function assertLegacyWorkflowReferencesAreScoped() {
  const filesToScan = [...docs];
  filesToScan.push(...collectMarkdownFiles("docs"));

  const allowedContext = /\blegacy\b|\bfixture\b|\bcompatibility\b|\bearlier root workflow\b|\bnot the active Runtime Contract\b/i;
  for (const relativePath of filesToScan) {
    const text = readDoc(relativePath);
    const lines = text.split(/\r?\n/);
    lines.forEach((line, index) => {
      const contextWindow = [
        lines[index - 2] || "",
        lines[index - 1] || "",
        line,
        lines[index + 1] || "",
        lines[index + 2] || "",
      ].join(" ");
      if (/WORKFLOW\.md|WORKFLOW\.example\.md/.test(line) && !allowedContext.test(contextWindow)) {
        fail(`${relativePath}:${index + 1} contains an unscoped legacy WORKFLOW reference`);
      }
    });
  }
}

function assertNoGeneratedResJsDiff() {
  const changedFrontendFiles = execFileSync("git", ["diff", "--name-only", "--", "apps/frontend/src"], {
    cwd: root,
    encoding: "utf8",
  })
    .split(/\r?\n/)
    .filter(Boolean);

  for (const changedFile of changedFrontendFiles) {
    if (changedFile.endsWith(".res.js")) {
      fail(`generated ReScript output changed in documentation-only task: ${changedFile}`);
    }
  }
}

const markdownByPath = new Map(docs.map((relativePath) => [relativePath, readDoc(relativePath)]));
const jsonBlocks = [];

for (const [relativePath, markdown] of markdownByPath.entries()) {
  assertSecretFree(relativePath, markdown);
  jsonBlocks.push(...extractJsonBlocks(markdown, relativePath));
}

assertTrackerExamples(jsonBlocks);
assertGlossaryTerms();
assertReadinessGuidance(markdownByPath.get("README.md"));
assertCompozyGuidance(markdownByPath.get("README.md"));
assertCompozyLifecycleContractDocs(markdownByPath.get("README.md"));
assertTerminalConsoleGuidance(markdownByPath.get("README.md"));
assertGoalLoopGuidance(markdownByPath.get("README.md"), jsonBlocks);
assertGitHubScope(markdownByPath.get(".github/project-tracking.md"));
assertLegacyWorkflowReferencesAreScoped();
assertNoGeneratedResJsDiff();

if (failures.length > 0) {
  console.error("Documentation validation failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Documentation validation passed: ${jsonBlocks.length} JSON examples checked across ${docs.length} docs.`);
