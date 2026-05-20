# Built-In Agent Looper — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Codify Goal Loop domain language and runtime ADR | pending | medium | — |
| 02 | Add Goal Loop domain model and transition rules | pending | medium | task_01 |
| 03 | Add stage-scoped Goal Loop configuration and readiness validation | pending | high | task_02 |
| 04 | Persist canonical Goal Loop state under Runtime Home | pending | medium | task_02 |
| 05 | Expose Goal Loop state through Runtime State JSON | pending | medium | task_04 |
| 06 | Add evidence command runner and diagnostics | pending | high | task_03, task_04 |
| 07 | Wire Goal Loop lifecycle into orchestration dispatch and activity | pending | high | task_03, task_04, task_05 |
| 08 | Gate completion on evidence with retry and Human Attention routing | pending | critical | task_06, task_07 |
| 09 | Render Goal Loop state in Terminal Console | pending | medium | task_05, task_08 |
| 10 | Render Goal Loop state in Web Dashboard | pending | medium | task_05, task_08 |
| 11 | Update operator docs, examples, and final validation coverage | pending | medium | task_03, task_08, task_09, task_10 |
