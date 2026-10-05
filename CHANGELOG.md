# Changelog

All notable changes to Mock Studio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-06

### Added

- **Flows** tab — multi-step, concurrent traffic scenarios. Steps run one by
  one (with response value extraction into `{{vars.*}}`) or all at once, by N
  virtual users for a number of iterations or a duration, with ramp-up and
  think time. Live throughput, error rate and p50/p95/p99 per step. The load
  generator runs in a background isolate.

### Changed

- Request-log bodies are capped at 64 KB each, and log updates are batched
  (~8/s) instead of rebuilding the whole UI on every request.
- Route templates, rule regexes and template parsing are cached on the hot path;
  token-free bodies skip templating entirely.
- Proxy reuses a pooled HTTP client.
- Project saves are atomic (temp file + rename) and serialised per file.

### Fixed

- Proxy passthrough broke gzip-encoded upstreams (stale `content-encoding`) and
  corrupted binary/non-ASCII bodies.
- "Connection reset" fault swallowed shelf's `HijackException`, causing a
  server error after the socket was hijacked.
- Binary (non-UTF-8) request bodies crashed the handler with a 500.
- Importing a project file kept the original id, so the copy and original
  shared servers/logs and deleting one removed both from the list.
- Stopping any project's server tore down a tunnel serving another project;
  a failed ngrok start left the process running.

## [1.0.0] - 2026-07-22

First public release of **Mock Studio by dhiva labs** — a production-grade mock
server you drive from a desktop app.

### Added

- **Projects** — create, open, save, import and export mock projects; each
  project is a readable JSON file you can commit to git.
- **Endpoint designer** — visual editor for method, path (with `:params` and
  `*` wildcards), status, headers and body (JSON / Text / HTML / XML / Empty)
  with live JSON validation and formatting.
- **Response strategies** — single response, conditional rules (by query,
  header, path param, body JSON or method), round-robin sequences, and
  weighted-random selection.
- **Templating** — `{{now}}`, `{{uuid}}`, path params, query, headers and body
  values rendered into responses.
- **Latency & faults** — per-response and global delays with jitter, plus fault
  injection for resilience testing.
- **Real HTTP server** — `shelf`-based server bound on the LAN, permissive CORS,
  auth gating, and proxy passthrough with response recording.
- **Live request log** — every request with method, path, status, matched
  endpoint, latency and timestamp; searchable and filterable.
- **Share & Expose** — localhost + LAN URLs with a QR code for phones, and
  public tunnels via cloudflared or ngrok.
- **OpenAPI / Swagger import** and Postman-style project import.
- **HTTP methods** — GET, POST, PUT, PATCH, DELETE, OPTIONS, and HEAD (HEAD
  falls back to the matching GET route with an empty body, per HTTP semantics).
- **One UI-inspired** desktop interface with light/dark themes and a beginner
  Guide mode.

[1.1.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.1.0
[1.0.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.0.0
