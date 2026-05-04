#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { binaryName, currentPackagePlatform, supportedPackagePlatforms } = require("./package-platforms");

const root = path.resolve(__dirname, "..");
const source = path.join(root, "_build", "default", "apps", "backend", "bin", "main.exe");
const targetPlatform = process.env.SYMPHONY_PACKAGE_PLATFORM || currentPackagePlatform().platform;
const targetArch = process.env.SYMPHONY_PACKAGE_ARCH || currentPackagePlatform().arch;
const targetDir = path.join(root, "vendor");
let target;

try {
  target = path.join(targetDir, binaryName(targetPlatform, targetArch));
} catch (error) {
  console.error(`package-binary: ${error.message}`);
  process.exit(1);
}

if (!fs.existsSync(source)) {
  console.error(`package-binary: missing built executable at ${source}`);
  process.exit(1);
}

fs.mkdirSync(targetDir, { recursive: true });
fs.copyFileSync(source, target);
for (const platform of supportedPackagePlatforms) {
  const candidate = path.join(targetDir, binaryName(platform.platform, platform.arch));
  if (fs.existsSync(candidate) && platform.extension !== ".exe") {
    fs.chmodSync(candidate, 0o755);
  }
}
console.error(`package-binary: wrote ${path.relative(root, target)}`);
