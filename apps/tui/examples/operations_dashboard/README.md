# Operations Dashboard Example

Source: [../operations_dashboard.ml](../operations_dashboard.ml)

Run from `apps/tui`:

```bash
opam exec -- dune exec examples/operations_dashboard.exe
```

## Purpose

`operations_dashboard` shows a dense, work-focused operations console. It is useful as a reference for dashboards that need metrics, service tables, event logs, runbook data, and a command footer.

## What It Demonstrates

- `Patterns.app_shell` for a full-page title, badges, content area, and command bar.
- `Components.split` for a fixed-width sidebar plus flexible main content.
- `Patterns.metric_card` for compact metrics with progress and sparkline data.
- `Components.table` for fixed-width tabular status rows.
- `Patterns.log_feed` for timestamped event streams.
- `Components.key_value` for dense metadata.
- Semantic tones such as `Success`, `Info`, `Warning`, and `Accent`.

## Layout Notes

The example renders at `132x38`, so it is intentionally wide. The sidebar uses a fixed width and the main grid uses `flex_grow` to fill the remaining space. This makes it a good reference for operator dashboards that prioritize scanning over decorative layout.

## When To Use It

Use this example when building a dashboard for services, jobs, queues, deployments, incidents, or other operational state.
