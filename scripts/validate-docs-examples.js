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
  ];

  for (const term of terms) {
    if (!context.includes(`**${term}**:`)) {
      fail(`CONTEXT.md is missing glossary term ${term}`);
    }
  }

  const combinedDocs = docs.map(readDoc).join("\n");
  for (const term of terms) {
    if (!combinedDocs.includes(term)) {
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

function assertCompozyQueueShortcutGuidance(readme) {
  const required = [
    "Bare Compozy PRD Run slugs are accepted by `--queue` only when Runtime Settings select",
    'tracker.kind = "compozy_tasks"',
    "symphony --queue compozy-tasks-run-integration,queue-flag-compozy-tasks",
    "Canonical Compozy selectors remain valid for a Compozy-backed Ordered Queue",
    "Manual Task Merge flows still require the canonical",
    "`compozy:<task_name>` selector form",
    "blocking Readiness Gap after Runtime Settings load",
    "resumes the queue stored for `example-feature`",
  ];

  for (const phrase of required) {
    if (!readme.includes(phrase)) {
      fail(`README.md is missing Compozy queue shortcut guidance for ${phrase}`);
    }
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
assertCompozyQueueShortcutGuidance(markdownByPath.get("README.md"));
assertTerminalConsoleGuidance(markdownByPath.get("README.md"));
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
