# Distribute the CLI through npm with a packaged binary

Personal Symphony will provide the `symphony` command through an npm package whose launcher executes a packaged platform-specific binary when available. Published CLI Package payloads include Linux x64, macOS x64, macOS arm64, and Windows x64 binaries under `vendor/`. This keeps `npm install -g ...` as the user-facing install path without requiring OCaml, dune, or opam in each Workspace Repository; local development may still fall back to the source build tooling.
