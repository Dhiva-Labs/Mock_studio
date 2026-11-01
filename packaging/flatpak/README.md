# Flatpak

`com.dhivalabs.mock_studio.yml` builds the Flatpak from the installed tree of
the .deb, so it ships the same binary as every other Linux package, plus
Cloudflare's own `cloudflared` for public tunnels.

## How CI builds it

The `distros` job in `.github/workflows/desktop.yml` unpacks the .deb, cleans
the tree (`packaging/linux-distros/pack.sh`, which drops the Debian-only files
and `libdartjni.so`, see `distro.conf`) and passes it on. The `flatpak` job
unpacks it into `packaging/flatpak/tree/` and runs flatpak-builder in the
`ghcr.io/flathub-infra/flatpak-github-actions:gnome-51` image, on x86_64 and
aarch64. It then installs the bundle, checks every ELF file with ldd against
the GNOME 51 runtime, runs the bundled cloudflared the way the app finds it
(`which`, then `cloudflared`), and starts the app under Xvfb until its window
is up (`x11_window.py`; the image has no xdotool) and the sample project is
saved in `Documents/MockStudio/projects`.

The bundle, `mockstudio-<version>-<arch>.flatpak`, refers to Flathub for its
runtime:

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./mockstudio-<version>-x86_64.flatpak
flatpak run com.dhivalabs.mock_studio
```

## Sandbox

- `--share=network`: the mock server listens on the host's network, so
  localhost, LAN and QR-code sharing work as in the other packages; proxy
  passthrough and cloudflared reach the internet.
- `--filesystem=xdg-documents/MockStudio:create`: projects are saved as JSON
  in `Documents/MockStudio/projects`, the same folder as everywhere else.
  Import and export go through the file chooser portal.
- cloudflared: a sandboxed app cannot run the host's tools, so the Flatpak
  carries Cloudflare's release binary (Apache-2.0), pinned by version and
  sha256 in the manifest. Bump it when Cloudflare releases (old versions stop
  being supported after about a year): new `url`s and `sha256`s for both
  architectures and the LICENSE.
- ngrok is proprietary and needs an account, so it is not bundled, and the
  app cannot start the host's ngrok. Run `ngrok http <port>` in a terminal
  instead; the server is reachable on the host's ports.

## Releases

Add a `<release>` line to `com.dhivalabs.mock_studio.metainfo.xml` with each
version bump; the CI fails when the version in `pubspec.yaml` is missing
there.

## Flathub

A Flathub submission would differ in two ways: the `tree` directory source
becomes an `archive` source (the release's `mockstudio_<version>_amd64.deb` /
`_arm64.deb`, with `only-arches` and a sha256 each, unpacked with `ar` and
`tar` in the build commands, and `libdartjni.so` removed), and the manifest
goes to a new `flathub/com.dhivalabs.mock_studio` repository through
Flathub's review (an `x-checker-data` entry can keep cloudflared current).
Nothing is published from this repository.
