# Workflow Memory

Keep only durable, cross-task context here. Do not duplicate facts that are obvious from the repository, PRD documents, or git history.

## Current State

## Shared Decisions

## Shared Learnings
- Ordered Queue raw-to-canonical resolution is centralized in `Ordered_queue.resolve`; the resolved queue wrapper exposes `resolved_entries`, each with `queue_identifier` and `canonical_identifier`.
- `Ordered_queue.resolve` owns readiness-friendly queue style diagnostics, including non-Compozy bare-slug mismatch remediation and mixed bare/canonical Compozy style rejection before duplicate detection.
- Orchestrator stores the resolved queue internally for canonical matching/order/admission, while Runtime State and `ordered_queue.json` continue to store the operator-facing queue identifiers.

## Open Risks

## Handoffs
