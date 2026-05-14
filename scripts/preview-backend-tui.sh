#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v opam >/dev/null 2>&1; then
  echo "opam is required to run the backend TUI preview." >&2
  exit 127
fi

if [ -t 1 ]; then
  echo "Launching backend TUI preview with mock Runtime State."
  echo "Controls: q/Esc quit, Tab or Left/Right switch tabs, j/k or Up/Down move rows, / search, ? help."
fi

opam exec -- dune exec apps/backend/bin/terminal_console_preview.exe -- "$@"
