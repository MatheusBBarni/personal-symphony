#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

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
  const allowedKinds = new Set(["github", "minibeads"]);
  const seenKinds = new Set();

  for (const block of blocks) {
    const parsed = parseJsonBlock(block);
    if (!parsed || typeof parsed !== "object" || !parsed.tracker) {
      continue;
    }

    const kind = parsed.tracker.kind;
    if (!allowedKinds.has(kind)) {
      fail(`${block.relativePath} json block ${block.index} must use tracker.kind "github" or "minibeads"`);
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

function assertGitHubScope(projectTracking) {
  const required = [
    'tracker.kind` is `"github"`',
    "GitHub Tracker",
    "For minibeads Local Issue Tracker setup",
  ];

  for (const phrase of required) {
    if (!projectTracking.includes(phrase)) {
      fail(`.github/project-tracking.md is missing scoped GitHub Tracker wording: ${phrase}`);
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
assertGitHubScope(markdownByPath.get(".github/project-tracking.md"));

if (failures.length > 0) {
  console.error("Documentation validation failed:");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Documentation validation passed: ${jsonBlocks.length} JSON examples checked across ${docs.length} docs.`);
