# Compozy Tasks Run Integration — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Add Compozy tracker Runtime Settings | completed | medium | — |
| 02 | Add Compozy task file parser and frontmatter updater | completed | medium | task_01 |
| 03 | Map Compozy PRD runs to Symphony issues | completed | medium | task_02 |
| 04 | Build Compozy task-step prompt context | completed | medium | task_03 |
| 05 | Add Compozy progress to Runtime State | completed | medium | task_03 |
| 06 | Wire Compozy readiness and run selection in CLI startup | completed | high | task_01, task_03, task_05 |
| 07 | Add sequential task-step orchestration in one worktree | completed | critical | task_04, task_06 |
| 08 | Add Compozy task-step retry and skip behavior | completed | high | task_07 |
| 09 | Add Compozy progress to terminal and dashboard surfaces | completed | medium | task_05, task_08 |
| 10 | Support Compozy identifiers in queue and manual merge flows | completed | high | task_03, task_07 |
| 11 | Update tracker documentation and examples | completed | medium | task_01, task_06, task_09, task_10 |
