# Ordered Queue Runtime State

Ordered Queue mode is launched from a CLI-provided issue sequence, but Symphony records the original order and per-entry progress in Runtime State. This makes the Terminal Console and Web Dashboard share one queue truth, lets operators see pending, running, retrying, completed, and skipped entries, and allows restarting with the same Ordered Queue to resume progress instead of reconstructing it from GitHub Project state alone.

The persisted Runtime State projection for the active Ordered Queue lives under the Runtime Home state directory. The ordered issue sequence is the resume key: restarting with the same sequence resumes per-entry progress, while restarting with a different sequence starts a fresh Ordered Queue after readiness validation.

An Ordered Queue entry is completed only when the issue has no active next stage. If a stage agent moves an issue from one active Project status to another, such as Backlog to Todo, Symphony returns that queue entry to pending so the same issue can continue through the next stage before the queue advances.

Amended 2026-05-14: Ordered Queue Runtime State stores operator-provided queue identifiers, not necessarily canonical tracker identifiers. This matters for the Compozy-backed `--queue` shortcut: a bare Compozy PRD Run slug such as `docs-refresh` is persisted and shown as `docs-refresh`, while readiness, lookup, and dispatch resolve it internally to the canonical `compozy:docs-refresh` identifier after Runtime Settings select `tracker.kind = "compozy_tasks"`.

The raw ordered queue identifier sequence remains the resume key. Restarting with the same bare Compozy slug sequence resumes the previous queue state when possible; restarting with equivalent canonical selectors such as `compozy:docs-refresh` starts a fresh Ordered Queue after readiness validation. If a bare Compozy slug is used while another Issue Tracker is selected, startup readiness reports the mismatch as a Readiness Gap before orchestration begins.
