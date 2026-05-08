# minibeads Local Issue Tracker — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Add tracker kind config and minibeads settings | completed | medium | — |
| 02 | Introduce shared Issue Tracker boundary and GitHub adapter | completed | high | task_01 |
| 03 | Add minibeads CLI readiness and diagnostics | completed | medium | task_01, task_02 |
| 04 | Implement minibeads issue fetch, lookup, blockers, and status updates | completed | high | task_03 |
| 05 | Refactor orchestrator to use the selected Issue Tracker | completed | high | task_02, task_04 |
| 06 | Support selected-tracker identifiers in Ordered Queue | completed | medium | task_02, task_04 |
| 07 | Support selected-tracker identifiers in Manual Task Merge | completed | high | task_02, task_04, task_06 |
| 08 | Add tracker kind Runtime State and tracker-neutral dashboard wording | completed | medium | task_01, task_05 |
| 09 | Preserve pull request handoff for minibeads tracker runs | completed | medium | task_01, task_05 |
| 10 | Update tracker documentation and glossary alignment | completed | medium | task_01, task_03, task_08 |
