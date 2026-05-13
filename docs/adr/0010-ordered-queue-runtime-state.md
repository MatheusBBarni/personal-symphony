# Ordered Queue Runtime State

Ordered Queue mode is launched from a CLI-provided issue sequence, but Symphony records the original order and per-entry progress in Runtime State. This makes the Terminal Console and Web Dashboard share one queue truth, lets operators see pending, running, retrying, completed, and skipped entries, and allows restarting with the same Ordered Queue to resume progress instead of reconstructing it from tracker state alone.

The persisted Runtime State projection for the active Ordered Queue lives under the Runtime Home state directory. The ordered issue sequence is the resume key: restarting with the same sequence resumes per-entry progress, while restarting with a different sequence starts a fresh Ordered Queue after readiness validation.

For Compozy-backed queues, `--queue` may receive bare Compozy PRD Run slugs when Runtime Settings select `tracker.kind = "compozy_tasks"`. Runtime State preserves the operator-facing queue identifiers rather than rewriting them to canonical selectors. For Compozy bare-slug queues, this means `example-feature` and `compozy:example-feature` are different resume keys even though they resolve to the same tracker issue identity. Readiness validates bare Compozy slugs after Runtime Settings load, so using them under a non-Compozy Issue Tracker surfaces as a Readiness Gap instead of a parse-time error.

An Ordered Queue entry is completed only when the issue has no active next stage. If a stage agent moves an issue from one active Project status to another, such as Backlog to Todo, Symphony returns that queue entry to pending so the same issue can continue through the next stage before the queue advances.
