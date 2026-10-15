# Changelog

All notable changes to Mock Studio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-10-16

### Added

- Linux arm64 and Windows arm64 builds, next to the x64 ones. CI builds,
  tests and starts each package on a native runner of its architecture, and
  a published release carries `mockstudio_<version>_arm64.deb` (with its
  `.sha256`), `MockStudio-<version>-linux-arm64.tar.gz` and
  `MockStudio-<version>-windows-arm64.zip`. The snap and the Microsoft Store
  package build for arm64 too.
- Windows x64 zip (`MockStudio-<version>-windows-x64.zip`), Linux tarballs for
  x64 and arm64, and Microsoft Store packaging for Windows (`msix_config` in
  `pubspec.yaml`).
- A privacy policy (`PRIVACY.md`): Mock Studio reports nothing to Dhiva Labs,
  and the network use it makes is the use you start.

### Changed

- The Windows executable is labelled Mock Studio / Dhiva Labs in its version
  info, so Windows settings live under `%APPDATA%\Dhiva Labs\Mock Studio`.
- Locked `jni` to 1.0.3, which compiles on Linux arm64.

### Fixed

- Windows: public tunnels were always reported as not installed, because the
  check ran `which`, which Windows does not have. It now uses `where`, and the
  hint gives Windows install instructions and says to restart Mock Studio.
- The test bar's Open in browser used `xdg-open` on every platform, so on
  Windows and macOS it only copied the URL. It now opens the default browser
  (`rundll32 url.dll,FileProtocolHandler` on Windows, `open` on macOS).
- Share & Expose showed the "This computer" card twice.
- On Linux arm64 the cloudflared install hint pointed at the amd64 download;
  it now names the arm64 one.

## [1.2.0] - 2026-10-10

### Added

- **Postman import** — turn a Postman collection (v2.1, v2.0, v1, single
  requests or folders; files or pasted JSON) into mock endpoints. Each saved
  example becomes a response; several examples become conditional rules
  (query-parameter rules where the example's request differs, otherwise the
  `x-mock-response-name` header, like Postman's own mock servers). Auth
  requirements, folders and `{{variables}}` carry over; a preview lists
  anything that needs attention. Import into a new or an existing project.
- **Folders** in the endpoint list, with Move to folder, Rename and Ungroup.
- **Hover help** on every field, button, badge and section: a card with a
  title, a plain explanation and an example. Can be turned off in Settings.
- **Phone layout** — bottom navigation, list-then-editor endpoints, full-screen
  request details and stacked forms on small screens.
- Teal light and dark themes (following the system by default) and a
  Graphite and orange theme, shared with ApiWorkbench.

### Changed

- Redesigned interface: icon rail navigation, resizable side panel,
  breadcrumbs and a clickable server status pill in the header.
- New braces-and-server logo on every platform.
- Method colours follow the ApiWorkbench / Postman convention (GET green,
  POST amber, PUT blue).

### Fixed

- Duplicating a project kept the original's id, so the copy shared its
  server, logs and file and could overwrite the original.
- The conditions row and Live request tags overflowed in narrow layouts.

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

[1.2.1]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.2.1
[1.2.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.2.0
[1.1.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.1.0
[1.0.0]: https://github.com/Dhiva-Labs/Mock_studio/releases/tag/v1.0.0
