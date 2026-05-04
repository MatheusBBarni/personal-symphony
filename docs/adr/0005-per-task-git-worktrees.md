# Use per-task Git worktrees and task branches

Personal Symphony will run each dispatched task in an Agent Worktree under `.symphony/workspaces/`, backed by a Task Branch created from the Loop-Start Branch. This isolates concurrent task changes and makes integration explicit: completed Task Branches may fast-forward merge back into the Loop-Start Branch only when it is not a configured Protected Trunk Branch such as `main` or `master`; merge failures move the task to the paused `Human attention` status instead of retrying agent work automatically.
