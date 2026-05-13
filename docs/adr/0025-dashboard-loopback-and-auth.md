# Dashboard loopback binding and non-loopback auth

Accepted 2026-05-13.

Personal Symphony exposes Runtime State through the Web Dashboard HTTP endpoint and Live Dashboard Connection. Runtime State may include issue descriptions, comments, task metadata, local Workspace Repository paths, diagnostic paths, errors, and rate-limit summaries. Those surfaces are intended for the local operator, not unauthenticated shared-network readers.

Symphony will bind the dashboard server to `127.0.0.1` by default. Runtime Settings may explicitly set `server.host` to another IPv4 bind address, including `0.0.0.0`, when an operator wants LAN, Tailscale, or container access. Non-loopback hosts require a generated local dashboard auth token for Runtime State HTTP endpoints and the Live Dashboard Connection. Static dashboard assets remain readable so the browser can load the app, but state access fails without the token.

The token is generated for the current server process and printed as a `symphony_auth` URL query parameter when Web Dashboard mode starts on a non-loopback host. The browser forwards that token to the websocket endpoint because browser WebSocket clients cannot set arbitrary auth headers. HTTP diagnostics may also use the same query token or an auth header.

This keeps existing loopback workflows simple while making shared-network exposure an explicit operator choice. Bootstrap remains idempotent and existing Runtime Contract files are not overwritten.
