---
tracker:
  kind: github
  owner: your-org
  repo: your-repo
  project_number: 1
  api_key: $GITHUB_TOKEN
  active_states: [Todo, In Progress]
  terminal_states: [Done, Closed, Cancelled]
  project_status_field: Status
polling:
  interval_ms: 30000
workspace:
  root: ./.symphony-workspaces
agent:
  max_concurrent_agents: 2
  max_turns: 10
  max_retry_backoff_ms: 300000
codex:
  command: codex app-server
  model: gpt-5.5
  reasoning_effort: medium
server:
  port: 8080
---

You are working on GitHub issue {{ issue.identifier }}: {{ issue.title }}.

Repository issue URL: {{ issue.url }}
Current project status: {{ issue.state }}
Attempt: {{ attempt }}

Use the repository workflow, make focused changes, validate them, and hand off through the GitHub
issue and project status expected by the team.
