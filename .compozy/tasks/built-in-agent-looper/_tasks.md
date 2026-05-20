# Built-In Agent Looper — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Codify Goal Loop domain language and runtime ADR | completed | medium | — |
| 02 | Add Goal Loop domain model and transition rules | completed | medium | task_01 |
| 03 | Add stage-scoped Goal Loop configuration and readiness validation | completed | high | task_02 |
| 04 | Persist canonical Goal Loop state under Runtime Home | completed | medium | task_02 |
| 05 | Expose Goal Loop state through Runtime State JSON | completed | medium | task_04 |
| 06 | Add evidence command runner and diagnostics | completed | high | task_03, task_04 |
| 07 | Wire Goal Loop lifecycle into orchestration dispatch and activity | completed | high | task_03, task_04, task_05 |
| 08 | Gate completion on evidence with retry and Human Attention routing | completed | critical | task_06, task_07 |
| 09 | Render Goal Loop state in Terminal Console | completed | medium | task_05, task_08 |
| 10 | Render Goal Loop state in Web Dashboard | completed | medium | task_05, task_08 |
| 11 | Update operator docs, examples, and final validation coverage | completed | medium | task_03, task_08, task_09, task_10 |
