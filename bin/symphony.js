#!/usr/bin/env node

const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const packageRoot = path.resolve(__dirname, "..");
const platformKey = `${process.platform}-${process.arch}`;
const extension = process.platform === "win32" ? ".exe" : "";
const packagedCandidates = [
  path.join(packageRoot, "vendor", `symphony-${platformKey}${extension}`),
  path.join(__dirname, `symphony-${platformKey}${extension}`),
  path.join(packageRoot, "_build", "install", "default", "bin", `symphony${extension}`)
];

function executableCandidate() {
  return packagedCandidates.find((candidate) => fs.existsSync(candidate));
}

function run(command, args, options = {}) {
  const child = spawn(command, args, {
    stdio: "inherit",
    env: { ...process.env, SYMPHONY_LAUNCHER_PATH: process.argv[1], SYMPHONY_PACKAGE_ROOT: packageRoot },
    ...options
  });
  child.on("exit", (code, signal) => {
    if (signal) {
      process.kill(process.pid, signal);
    } else {
      process.exit(code ?? 1);
    }
  });
  child.on("error", (error) => {
    console.error(`symphony: ${error.message}`);
    process.exit(1);
  });
}

const binary = executableCandidate();

if (binary) {
  run(binary, process.argv.slice(2));
} else if (fs.existsSync(path.join(packageRoot, "dune-project"))) {
  run("opam", ["exec", "--", "dune", "exec", "--root", packageRoot, "symphony", "--", ...process.argv.slice(2)]);
} else {
  console.error(
    `symphony: no packaged binary for ${platformKey}; reinstall a package that includes vendor/symphony-${platformKey}${extension}`
  );
  process.exit(1);
}
