# Stage Skill Load

Stage Agents can require reusable Codex skills, but expanding skill bodies into every prompt would duplicate Codex skill resolution and make the Runtime Contract brittle. Runtime Settings therefore configure Stage Skill Load with ordered `skills` identifiers on each stage; Symphony renders those identifiers as prompt skill references, validates all configured skills from the Workspace Repository and Codex Home before dispatch, and treats missing, malformed, or duplicate skill identifiers as Readiness Gaps rather than task retry failures.
