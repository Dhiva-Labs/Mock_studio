# Mock Studio

*by dhiva labs*

A production-grade **mock server** you drive from a desktop app. Design HTTP
endpoints visually, hit **Start**, and any client — your apps, browsers,
emulators, phones on the same Wi-Fi, or webhook providers over a public tunnel —
gets realistic mock responses.

Built for two audiences at once: a complete beginner can build a working mock
API from templates in a minute, while an expert gets precise control over rules,
sequences, latency, faults, templating and proxying.

## Highlights

- **Visual endpoint editor** — method, path templates (`/users/:id`, `/files/*`,
  `/assets/**`), status, headers, and JSON/text/HTML/XML bodies.
- **Smart responses** — four strategies per endpoint:
  - *Single* — always the same.
  - *Conditional rules* — pick a response from the query, headers, path params,
    body JSON, or method (e.g. `password == "secret"` → 200, else 401).
  - *Sequence* — round-robin responses, ideal for testing retries.
  - *Random / weighted* — simulate a flaky service.
- **Dynamic templating** — inject request data and fakes into responses:
  `{{params.id}}`, `{{query.page}}`, `{{header.Authorization}}`, `{{body.email}}`,
  `{{uuid}}`, `{{now}}`, `{{randomInt(1,100)}}`, `{{faker.name}}`, `{{faker.email}}`…
- **Latency & fault injection** — fixed/jittered delays, drop-connection, empty
  body, malformed body, or an infinite hang for timeout testing.
- **Built-in tester** — send a live request and view the response inline, or copy
  the URL / a ready-made `curl` command / open it in the browser.
- **Live request log** — every request in real time with a full detail pane
  (headers, body, matched endpoint, timing), searchable and error-filterable.
- **Flows (concurrent load)** — chain several endpoints into a user journey
  (login → fetch → create…), capture values from one response for the next
  (`token = body.token` → `{{vars.token}}`), then run it with many virtual users
  at once: iterations or a fixed duration, ramp-up, think time, and *one by one*
  or *all at once* step modes. Live requests/sec, error rate, p50/p95/p99 per
  step and a throughput chart. Runs in a background isolate with fixed-memory
  latency histograms, and can target any base URL, not just the mock.
- **Share & expose** — localhost, LAN URLs (with a QR code for phones), and a
  one-click public tunnel via **cloudflared** (no account) or **ngrok**.
- **Proxy & record** — forward unmatched requests to a real API and convert the
  captured responses into mocks with one click.
- **Postman import** — turn a Postman collection into mock endpoints: every
  saved example becomes a response, several examples become conditional rules,
  and folders and auth requirements carry over. Import into a new or an
  existing project.
- **OpenAPI / Swagger import** — generate a full mock from a spec (JSON or YAML).
- **Hover help** — every field, button and badge explains itself with a short
  card and an example; turn it off in Settings once you know your way around.
- **Auth simulation**, **CORS**, **global headers/delay**, multiple projects on
  different ports simultaneously.
- **Git-friendly storage** — each project is a readable JSON file you can commit
  and share; export/import built in.

## Getting started

```bash
flutter pub get
flutter run -d linux      # or build: flutter build linux
```

On first launch a sample project ("My First Mock API") is created so you can
explore immediately. Toggle **Guide** on the left rail for extra hints, and
point at any field for an explanation. Teal (light/dark) and Graphite themes
are in **Settings**; phones get a bottom-navigation layout.

## Public tunnels

- **cloudflared** quick tunnels need no account. Install `cloudflared` and it
  appears in *Share & Expose → Public internet*.
- **ngrok** needs a one-time `ngrok config add-authtoken <token>`.

## Tech

Flutter (Material 3) · `shelf` HTTP server · Provider · file-based JSON storage.

## Tests

```bash
flutter test
flutter test integration_test/layout_sweep_test.dart -d linux   # every screen at phone, tablet and desktop sizes
flutter test integration_test/screenshots_test.dart -d linux    # regenerate screenshots/
```

Covers route matching, templating, response resolution, the flow runner
(chaining, parallel mode, stop, isolate), proxy/fault regressions, and live
end-to-end server integration tests.
