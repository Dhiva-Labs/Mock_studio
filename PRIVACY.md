# Privacy Policy: Mock Studio

Last updated: 11 October 2026

Mock Studio is a mock API server made by Dhiva Labs. This policy covers the
app on every platform it ships on (Windows, including the Microsoft Store
build, Linux, macOS and Android).

## Summary

Mock Studio has no accounts, analytics, telemetry, advertising or crash
reporting, and nothing is sent to Dhiva Labs. Its network activity is the
mock server you start and the requests you ask it to make.

## Data stored on your device

- **Projects**: your mock projects (endpoints, responses, rules, flows and
  project settings) are saved as readable JSON files in
  `Documents/MockStudio/projects`. If your Documents folder is synced by a
  cloud service (for example OneDrive), that service syncs these files like
  any other document.
- **App settings** (theme, hover help, guide mode) are kept by the system's
  preferences store in the app's private data folder.
- **Request logs** of calls to your mock server are kept in memory while the
  app runs and are not saved, unless you save them as endpoints.

Imports (Postman, OpenAPI, Mock Studio files) and exports read and write only
the files you choose.

## Network use

- **The mock server.** While a project's server is running, it listens on the
  port you set on all of this computer's network interfaces, so apps on this
  computer and devices on your local network can call it and receive your
  mock responses. Stop the server to close it.
- **Requests you send.** The endpoint test bar and Flows send HTTP requests to
  your mock server, or to the target URL you enter.
- **Proxy passthrough.** If you turn it on, requests that match no endpoint
  are forwarded to the real API address you set, and, if you choose, its
  responses are recorded so you can save them as endpoints.
- **Public tunnels.** If you start a tunnel, Mock Studio runs the
  `cloudflared` or `ngrok` program installed on your computer, which makes
  your mock server reachable from the internet through Cloudflare's or
  ngrok's service. Those services' own privacy policies apply to that
  traffic. Stop the tunnel or the server to close it.

The app makes no other connections: no update checks, no usage reporting.

## Children

Mock Studio does not collect personal information from anyone, including
children.

## Changes

If this policy changes, the new version will be published in this file in the
app's public repository: <https://github.com/Dhiva-Labs/Mock_studio>.

## Contact

Questions about this policy: reachout@dhivalabs.com
