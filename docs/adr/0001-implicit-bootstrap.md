# Use implicit bootstrap for first CLI run

Personal Symphony will bootstrap a Workspace Repository when the user runs the default `symphony` command and required runtime files are missing, while also exposing `symphony init` for explicit setup. This favors a successful first run over an explicit-only flow, and records that file creation from the default command is intentional rather than accidental.
