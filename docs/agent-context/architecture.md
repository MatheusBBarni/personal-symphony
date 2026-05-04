# Architecture Notes

Personal Symphony is the Product Repository. Users run the `symphony` CLI inside a separate Workspace Repository.

Runtime ownership:
- Bootstrap creates a Runtime Home at `.symphony/` in the Workspace Repository.
- Runtime Contract files are `.symphony/settings.json`, `.symphony/prompt.md`, and `.symphony/agents/*`.
- Runtime State, Local Environment, and Agent Workspaces are ignored Runtime Home contents.

Dispatch model:
- GitHub Issues are work items and GitHub Projects `Status` is the dispatch board.
- Each dispatched task gets a Task Branch and an Agent Worktree under `.symphony/workspaces/`.
- The Loop-Start Worktree must be clean before a new Agent Worktree is created.
- Auto-merge is fast-forward only and skipped for Protected Trunk Branches.

Packaging:
- npm exposes `symphony` through `bin/symphony.js`.
- Published packages should include `vendor/symphony-linux-x64`, `vendor/symphony-darwin-x64`,
  `vendor/symphony-darwin-arm64`, and `vendor/symphony-win32-x64.exe`.
- Product Repository development falls back to `opam exec -- dune exec symphony --`.
