#!/usr/bin/env bash
set -euo pipefail

changed="$(git diff --cached --name-only || true)"

case "$changed" in
  *package.json*|*pnpm-lock.yaml*|*dune-project*|*.github/workflows/*|*.eslintrc*|*biome.json*|*prettier.config.*)
    echo "nv-context: dependency, build, CI, or lint config changed; review AGENTS.md and CLAUDE.md." >&2
    ;;
esac

find AGENTS.md CLAUDE.md -maxdepth 0 -mtime +14 -print 2>/dev/null |
  sed 's/^/nv-context: stale agent config older than 14 days: /' >&2

pattern='d[o] n[o]t|av[o]id|d[o]n'\''t'
if rg -n "$pattern" AGENTS.md CLAUDE.md apps/*/CLAUDE.md docs/CLAUDE.md 2>/dev/null; then
  echo "nv-context: soft negative instruction found; prefer MUST phrasing or NEVER for absolute prohibitions." >&2
fi

exit 0
