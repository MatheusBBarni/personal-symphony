#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: sh scripts/release-archive.sh <version> [git-ref]" >&2
  exit 2
fi

version="$1"
git_ref="${2:-tui-v$version}"
repo_root="$(git rev-parse --show-toplevel)"
out_dir="$repo_root/apps/tui/dist"
archive="$out_dir/symphony-orchestrator-tui-$version.tar.gz"

mkdir -p "$out_dir"
git archive \
  --format=tar.gz \
  --prefix="symphony-orchestrator-tui-$version/" \
  --output="$archive" \
  "$git_ref:apps/tui"

echo "$archive"
