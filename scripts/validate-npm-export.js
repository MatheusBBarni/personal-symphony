#!/usr/bin/env node

const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { binaryName, currentPackagePlatform, supportedPackagePlatforms } = require("./package-platforms");

const root = path.resolve(__dirname, "..");
const keepTarball = process.argv.includes("--keep-tarball");
const requireAllPlatforms = process.argv.includes("--require-all-platforms");

function run(command, args, options = {}) {
  const result = childProcess.spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: options.capture ? ["ignore", "pipe", "pipe"] : "inherit",
    ...options
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    const suffix = result.stderr ? `\n${result.stderr}` : "";
    throw new Error(`${command} ${args.join(" ")} failed with exit code ${result.status}${suffix}`);
  }

  return result;
}

function parsePackJson(stdout) {
  const start = stdout.indexOf("[");
  const end = stdout.lastIndexOf("]");

  if (start === -1 || end === -1 || end < start) {
    throw new Error(`npm pack did not return JSON output:\n${stdout}`);
  }

  const packages = JSON.parse(stdout.slice(start, end + 1));
  if (!Array.isArray(packages) || packages.length !== 1 || !packages[0].filename) {
    throw new Error(`npm pack returned unexpected metadata:\n${stdout}`);
  }

  return packages[0];
}

function requiredBinaryNames() {
  if (requireAllPlatforms) {
    return supportedPackagePlatforms.map((target) => binaryName(target.platform, target.arch));
  }

  const current = currentPackagePlatform();
  return [binaryName(current.platform, current.arch)];
}

function validatePackedBinaries(files) {
  const packedPaths = new Set(files.map((file) => file.path));
  const missing = requiredBinaryNames().filter((name) => !packedPaths.has(`vendor/${name}`));

  if (missing.length > 0) {
    throw new Error(`npm pack is missing required vendor binaries: ${missing.join(", ")}`);
  }
}

function main() {
  const prefix = fs.mkdtempSync(path.join(os.tmpdir(), "symphony-orchestrator-npm-"));
  let tarballPath = null;

  try {
    console.error("validate-npm-export: packing CLI Package");
    const packed = parsePackJson(run("npm", ["pack", "--json"], { capture: true }).stdout);
    tarballPath = path.join(root, packed.filename);
    validatePackedBinaries(packed.files || []);

    console.error(`validate-npm-export: installing ${packed.filename} into ${prefix}`);
    run("npm", ["install", "-g", "--prefix", prefix, tarballPath]);

    const command = path.join(prefix, process.platform === "win32" ? "symphony.cmd" : "bin/symphony");
    console.error("validate-npm-export: running installed symphony --help");
    run(command, ["--help"]);

    console.error("validate-npm-export: ok");
  } finally {
    fs.rmSync(prefix, { recursive: true, force: true });

    if (!keepTarball && tarballPath) {
      fs.rmSync(tarballPath, { force: true });
    }
  }
}

main();
