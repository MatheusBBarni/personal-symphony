const supportedPackagePlatforms = [
  { platform: "linux", arch: "x64", extension: "" },
  { platform: "darwin", arch: "x64", extension: "" },
  { platform: "darwin", arch: "arm64", extension: "" },
  { platform: "win32", arch: "x64", extension: ".exe" }
];

function binaryName(platform, arch) {
  const target = supportedPackagePlatforms.find(
    (candidate) => candidate.platform === platform && candidate.arch === arch
  );

  if (!target) {
    throw new Error(`unsupported package platform: ${platform}-${arch}`);
  }

  return `symphony-${platform}-${arch}${target.extension}`;
}

function currentPackagePlatform() {
  return { platform: process.platform, arch: process.arch };
}

module.exports = {
  binaryName,
  currentPackagePlatform,
  supportedPackagePlatforms
};
