# Changelog

All notable changes to Mock Studio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.0.0
