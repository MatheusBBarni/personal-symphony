# Ordered Queue Runtime State

Ordered Queue mode is launched from a CLI-provided issue sequence, but Symphony records the original order and per-entry progress in Runtime State. This makes the Terminal Console and Web Dashboard share one queue truth, lets operators see pending, running, retrying, completed, and skipped entries, and allows restarting with the same Ordered Queue to resume progress instead of reconstructing it from GitHub Project state alone.
