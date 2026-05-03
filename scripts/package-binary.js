#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = path.join(root, "_build", "default", "apps", "backend", "bin", "main.exe");
const extension = process.platform === "win32" ? ".exe" : "";
const targetDir = path.join(root, "vendor");
const target = path.join(targetDir, `symphony-${process.platform}-${process.arch}${extension}`);

if (!fs.existsSync(source)) {
  console.error(`package-binary: missing built executable at ${source}`);
  process.exit(1);
}

fs.mkdirSync(targetDir, { recursive: true });
fs.copyFileSync(source, target);
fs.chmodSync(target, 0o755);
console.error(`package-binary: wrote ${path.relative(root, target)}`);
