# Ready-for-Symphony Intake — Task List

## Tasks

| # | Title | Status | Complexity | Dependencies |
|---|-------|--------|------------|--------------|
| 01 | Add ready-status Runtime Settings and tracker admission contract | completed | medium | — |
| 02 | Implement GitHub exact-match ready-status admission | pending | medium | task_01 |
| 03 | Parse Compozy _tasks.md ready status and gate PRD-run admission | completed | high | task_01 |
| 04 | Allow idle startup and enforce ready-status dispatch semantics | completed | high | task_01, task_02, task_03 |
| 05 | Expose intake eligibility in Runtime State and dashboard | completed | high | task_04 |
| 06 | Update docs and ADR-aligned runtime semantics | pending | medium | task_04, task_05 |
