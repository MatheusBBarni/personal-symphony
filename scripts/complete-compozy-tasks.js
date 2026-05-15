#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const activeTasksRoot = path.join(root, ".compozy", "tasks");
const completedTasksRoot = path.join(root, ".compozy", "completed_tasks");

function fail(message) {
  console.error(`complete-compozy-tasks: ${message}`);
  process.exit(1);
}

function parseSlugs(argv) {
  const slugs = argv
    .flatMap((value) => value.split(","))
    .map((value) => value.trim())
    .filter(Boolean);

  if (slugs.length === 0) {
    fail("expected at least one task slug, e.g. `pnpm compozy:complete -- my-task,another-task`");
  }

  const uniqueSlugs = [...new Set(slugs)];

  for (const slug of uniqueSlugs) {
    if (slug === "." || slug === ".." || slug.includes("/") || slug.includes("\\")) {
      fail(`invalid task slug: ${slug}`);
    }
  }

  return uniqueSlugs;
}

function resolveTaskPath(baseDir, slug) {
  const candidate = path.join(baseDir, slug);
  const relative = path.relative(baseDir, candidate);

  if (relative.startsWith("..") || path.isAbsolute(relative)) {
    fail(`task slug resolves outside ${path.relative(root, baseDir)}: ${slug}`);
  }

  return candidate;
}

function ensureDirectoryExists(directoryPath, label) {
  if (!fs.existsSync(directoryPath)) {
    fail(`missing ${label} at ${path.relative(root, directoryPath)}`);
  }

  if (!fs.statSync(directoryPath).isDirectory()) {
    fail(`${path.relative(root, directoryPath)} is not a directory`);
  }
}

function main() {
  const slugs = parseSlugs(process.argv.slice(2));

  ensureDirectoryExists(activeTasksRoot, "active Compozy task root");
  fs.mkdirSync(completedTasksRoot, { recursive: true });
  ensureDirectoryExists(completedTasksRoot, "completed Compozy task root");

  const moves = slugs.map((slug) => {
    const source = resolveTaskPath(activeTasksRoot, slug);
    const target = resolveTaskPath(completedTasksRoot, slug);

    if (!fs.existsSync(source)) {
      fail(`Compozy PRD Run not found: ${path.relative(root, source)}`);
    }

    if (!fs.statSync(source).isDirectory()) {
      fail(`expected a directory for ${path.relative(root, source)}`);
    }

    if (fs.existsSync(target)) {
      fail(`destination already exists: ${path.relative(root, target)}`);
    }

    return { slug, source, target };
  });

  for (const { source, target } of moves) {
    fs.renameSync(source, target);
    console.error(
      `complete-compozy-tasks: moved ${path.relative(root, source)} -> ${path.relative(root, target)}`
    );
  }
}

main();
