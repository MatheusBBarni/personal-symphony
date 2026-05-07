# Generate Agent Context Snapshot in the Symphony launch harness

Personal Symphony needs bounded launch context for agents, but global Codex lifecycle hooks would make Workspace Repository behavior depend on user-level Codex configuration outside the Runtime Contract. Symphony will generate Agent Context Snapshot content in its own launch harness, scoped to the active Workspace Repository, and will not install or mutate global Codex hooks.

Runtime Settings own operator-configurable context behavior, Agent Prompt composition owns prompt injection, Runtime State may expose live generation status, and ignored Runtime Diagnostics may store bounded secret-free metadata. Agent Context Snapshot supplements the Agent Prompt and coexists with Stage Goal Handoff; it does not replace either. Context Command stdout may supplement the Agent Context Snapshot, while stderr and command failures remain diagnostic by default.

Retry launches may add Previous Attempt Output to the Agent Context Snapshot. Symphony carries only the immediately previous failed launch's attempt number and bounded stdout/stderr tails into the next prompt. Missing output files render as unavailable, truncation is deterministic and explicitly marked, and first launches omit Previous Attempt Output entirely.

This keeps Bootstrap idempotent, preserves existing Runtime Contract defaults unless an operator explicitly approves a change, and prevents bounded context work from becoming transcript replay or hidden global hook behavior.
