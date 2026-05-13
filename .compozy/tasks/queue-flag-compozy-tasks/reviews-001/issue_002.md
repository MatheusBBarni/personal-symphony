---
provider: manual
pr:
round: 1
round_created_at: 2026-05-13T20:12:51Z
status: pending
file: apps/backend/lib/ordered_queue.ml
line: 51
severity: medium
author: claude-code
provider_ref:
---

# Issue 002: Bare-slug parser rejects valid Compozy run names

## Review Comment

The new bare-slug path is narrower than the tracker normalization path. `Ordered_queue.parse` only accepts bare queue tokens made of `[a-z0-9._-]`, but `Issue_tracker.compozy_identifier` accepts any non-empty identifier that does not contain `/` or `:`. As a result, a run that can already be addressed canonically as `compozy:MyFeature` or `compozy:Feature_01` may still be impossible to queue as `--queue MyFeature` if the slug contains characters outside this lowercase-only subset.

The docs and spec describe bare input as the PRD-run directory name under `.compozy/tasks/<task_name>/`; they do not narrow `<task_name>` to lowercase slugs only. The parser and tracker should therefore agree on the accepted identifier space. The simplest fix is to make bare-token parsing delegate to the same structural rules as `Issue_tracker.compozy_identifier`, then keep tracker selection and canonicalization in the later resolution step.

## Triage

- Decision: `UNREVIEWED`
- Notes:
