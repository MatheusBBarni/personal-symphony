# Keep the Runtime Contract inside `.symphony/`

Personal Symphony will create the Workspace Repository Runtime Contract inside `.symphony/` instead
of requiring a root `WORKFLOW.md`. This keeps the OpenAI Symphony principle of a repository-owned
workflow contract while grouping Personal Symphony files under a single Runtime Home; `WORKFLOW.md`
can remain as a legacy/import format or developer fixture, but new CLI bootstrap flows should create
the `.symphony/` Runtime Contract.
