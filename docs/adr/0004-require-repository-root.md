# Require commands to run from the workspace repository root

Personal Symphony commands will require the current working directory to be the root of a Workspace Repository instead of searching upward for a Git repository. This prevents accidental bootstrap in the wrong repository or from an ambiguous nested path, at the cost of requiring users to `cd` to the repository root before running `symphony`.
