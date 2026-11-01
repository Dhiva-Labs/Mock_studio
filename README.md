# Mock Studio

[![ARM64 builds](https://github.com/Dhiva-Labs/Mock_studio/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/Dhiva-Labs/Mock_studio/actions/workflows/desktop.yml)
![Linux x64 | arm64](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-informational?logo=linux&logoColor=white)
![Windows x64 | arm64](https://img.shields.io/badge/Windows-x64%20%7C%20arm64-informational?logo=windows&logoColor=white)
![Linux: deb | rpm | Arch | AppImage | Flatpak | Snap](https://img.shields.io/badge/Linux-deb%20%7C%20rpm%20%7C%20Arch%20%7C%20AppImage%20%7C%20Flatpak%20%7C%20Snap-informational?logo=linux&logoColor=white)

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

## Install

Download from the [releases page](https://github.com/Dhiva-Labs/Mock_studio/releases):

| Platform | File |
|---|---|
| Linux x64 (Debian, Ubuntu) | `mockstudio_<version>_amd64.deb` |
| Linux arm64 (Debian, Ubuntu) | `mockstudio_<version>_arm64.deb` |
| Linux (Fedora, RHEL, openSUSE) | `mockstudio-<version>-1.x86_64.rpm`, `mockstudio-<version>-1.aarch64.rpm` |
| Linux (Arch, Manjaro, EndeavourOS) | `mockstudio-<version>-1-x86_64.pkg.tar.zst`, `mockstudio-<version>-1-aarch64.pkg.tar.zst` |
| Linux (any distribution) | `MockStudio-<version>-x86_64.AppImage`, `MockStudio-<version>-aarch64.AppImage` |
| Linux (Flatpak) | `mockstudio-<version>-x86_64.flatpak`, `mockstudio-<version>-aarch64.flatpak` |
| Linux x64 (other distributions) | `MockStudio-<version>-linux-x64.tar.gz` |
| Linux arm64 (other distributions) | `MockStudio-<version>-linux-arm64.tar.gz` |
| Windows x64 | `MockStudio-<version>-windows-x64.zip` |
| Windows arm64 | `MockStudio-<version>-windows-arm64.zip` |

```sh
sudo apt install ./mockstudio_<version>_arm64.deb       # or _amd64.deb
sha256sum -c mockstudio_<version>_arm64.deb.sha256      # optional check
tar -xzf MockStudio-<version>-linux-arm64.tar.gz && ./MockStudio-<version>-linux-arm64/mock_studio
```

The tarball needs GTK 3 (`libgtk-3-0`). On Windows, unzip and run
`mock_studio.exe`. Snap: `sudo snap install mockstudio` (amd64 and arm64).

### Fedora, RHEL, openSUSE, Arch, AppImage and Flatpak

These are attached to releases from 1.2.1 on, for x86_64 and aarch64. They
hold the same build as the .deb (the CI repackages it and then installs and
starts every package on Fedora, openSUSE Tumbleweed and Arch Linux). The
build machine is Ubuntu 24.04, so the .rpm, Arch package and AppImage need
glibc 2.34 or newer and a current GTK 3: Fedora 40+, RHEL/Rocky/Alma 10,
openSUSE Tumbleweed and Leap 16, current Arch.

```sh
sudo dnf install ./mockstudio-<version>-1.x86_64.rpm                          # Fedora, RHEL
sudo zypper install --allow-unsigned-rpm ./mockstudio-<version>-1.x86_64.rpm  # openSUSE
sudo pacman -U ./mockstudio-<version>-1-x86_64.pkg.tar.zst                    # Arch
chmod +x MockStudio-<version>-x86_64.AppImage && ./MockStudio-<version>-x86_64.AppImage
flatpak install --user ./mockstudio-<version>-x86_64.flatpak                 # then: flatpak run com.dhivalabs.mock_studio
```

- The .rpm and Arch packages are not signed, hence zypper's
  `--allow-unsigned-rpm`. They pull in `xdg-user-dirs` (the projects folder)
  and `which` (the tunnel tools' lookup); install `cloudflared` yourself for
  public tunnels, as with the .deb.
- Arch: an AUR recipe for `mockstudio-bin` (PKGBUILD and .SRCINFO) is
  attached to each release as `mockstudio-bin-<version>-aur.tar.gz`.
- The AppImage uses the system's GTK 3 and `xdg-user-dir`, as the tarball
  does.
- The Flatpak needs the Flathub remote for the GNOME runtime it uses
  (`flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`).
  It includes cloudflared, so public tunnels work out of the box; ngrok is not
  included. It saves projects in the same `Documents/MockStudio` folder. See
  [packaging/flatpak/README.md](packaging/flatpak/README.md).

Every push to `main` builds, tests and packages Mock Studio for Linux and
Windows on x64 and arm64 (the **Desktop builds** workflow). Its run page has
the Microsoft Store packages (`.msix`) and the snaps for both architectures as
artifacts. The Linux and Windows packages above are attached to a release when
it is published; a file that was attached by hand is left as it is.

## Getting started

```bash
flutter pub get
flutter run -d linux      # or build: flutter build linux
```

On Windows, `flutter build windows --release`, then `dart run msix:create --store`
for the Microsoft Store package (.msix); on an ARM64 machine add
`--architecture arm64` (`pwsh tool\package_windows.ps1` does this for you and also
writes the zip). On Linux, `tool/build_deb.sh` and `tool/build_tarball.sh` package
the bundle of the machine's architecture, x64 or arm64. Projects are saved in
`Documents\MockStudio\projects`. The first time a server starts, Windows
Firewall asks whether to allow Mock Studio on your networks; allow private
networks if phones or teammates on your LAN should reach it.

On first launch a sample project ("My First Mock API") is created so you can
explore immediately. Toggle **Guide** on the left rail for extra hints, and
point at any field for an explanation. Teal (light/dark) and Graphite themes
are in **Settings**; phones get a bottom-navigation layout.

## Public tunnels

- **cloudflared** quick tunnels need no account. Install `cloudflared` and it
  appears in *Share & Expose → Public internet*. On Windows:
  `winget install --id Cloudflare.cloudflared`, then restart Mock Studio.
  The Flatpak has its own copy; the snap cannot start it (see the snap's
  description).
- **ngrok** needs a one-time `ngrok config add-authtoken <token>`. The
  Flatpak cannot start ngrok from the host: run `ngrok http <port>` in a
  terminal instead, since the server listens on the host's network.

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

## Privacy

No accounts, analytics or telemetry; the network traffic is the mock server you
start and the requests you send. See [PRIVACY.md](PRIVACY.md).

## Sponsors

Dhiva Labs is an independent, self-funded lab. [Sponsorships](https://github.com/sponsors/Dhiva-Labs) help bring this project and the rest of Dhiva Labs to every platform, iPhone and Mac included.

[![Sponsor Dhiva Labs](https://img.shields.io/badge/Sponsor-Dhiva%20Labs-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Dhiva-Labs)

Monthly sponsors at $10 and up are listed here:

<!-- sponsors -->
*Be the first: [sponsor Dhiva Labs](https://github.com/sponsors/Dhiva-Labs).*
<!-- sponsors -->
