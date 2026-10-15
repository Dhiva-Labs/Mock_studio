#!/usr/bin/env bash
# Assemble and upload the Mock Studio PPA source package from the repo's
# canonical packaging metadata in linux/packaging/.
#
#   bash tool/make_ppa.sh                 # build bundle + stage + sign source pkg
#   bash tool/make_ppa.sh --skip-build    # reuse existing Flutter bundle
#   bash tool/make_ppa.sh --upload        # also dput to the PPA
#
# The version comes from pubspec.yaml (before '+'); a matching top entry must
# exist in linux/packaging/debian/changelog. Launchpad rejects re-uploads of an
# already-published version.
#
# The package holds the bundle built on this machine, so it targets this
# machine's architecture (amd64 or arm64): the staged debian/control gets the
# matching Architecture line. (A PPA only builds arm64 when it is enabled there.)
#
# Regression guard: debian/source/options overrides dpkg-source's default
# ignore list so the bundled *.so engine libraries ship in the source tarball.
# Without it the app installs but crashes with
#   "error while loading shared libraries: libflutter_linux_gtk.so".
set -euo pipefail

KEY=0D3EFC9C8CE20ADE3CE809AD3D8D857AAF4D50E6
PPA=ppa:dhiva-labs/apps
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$REPO/linux/packaging"
OUT="$REPO/dist/ppa"

BOLD=$'\e[1m'; GRN=$'\e[32m'; RED=$'\e[31m'; RST=$'\e[0m'
say(){ echo "${BOLD}${GRN}>>> $*${RST}"; }
die(){ echo "${BOLD}${RED}XXX $*${RST}" >&2; exit 1; }

DEB_ARCH="$(dpkg --print-architecture)"
case "$DEB_ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *) die "unsupported architecture '$DEB_ARCH' (amd64 or arm64)" ;;
esac
BUNDLE="$REPO/build/linux/$FLUTTER_ARCH/release/bundle"

SKIP_BUILD=0; UPLOAD=0
for a in "$@"; do case "$a" in
  --skip-build) SKIP_BUILD=1 ;;
  --upload) UPLOAD=1 ;;
  *) die "unknown flag: $a" ;;
esac; done

VER=$(grep -oP '^version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$REPO/pubspec.yaml") \
  || die "could not read version from pubspec.yaml"
say "Release version (pubspec.yaml): $VER"

CHVER=$(head -1 "$PKG/debian/changelog" | grep -oP '\(\K[^)]+') || true
[ "$CHVER" = "$VER" ] || die "debian/changelog top entry is '$CHVER', expected '$VER'"
[ -f "$PKG/debian/source/options" ] || die "debian/source/options missing — *.so files would be stripped"

if [ "$SKIP_BUILD" = 0 ]; then
  say "Building Flutter Linux release bundle..."
  (cd "$REPO" && flutter build linux --release) || die "flutter build failed"
fi
[ -f "$BUNDLE/lib/libflutter_linux_gtk.so" ] || die "bundle missing lib/libflutter_linux_gtk.so"

say "Assembling PPA source tree..."
SRC="$OUT/mockstudio-$VER"
rm -rf "$OUT"; mkdir -p \
  "$SRC/usr/lib/mockstudio" "$SRC/usr/bin" \
  "$SRC/usr/share/applications" \
  "$SRC/usr/share/icons/hicolor/512x512/apps" \
  "$SRC/usr/share/icons/hicolor/256x256/apps"
cp -a "$PKG/debian" "$SRC/debian"
sed -i "s/^Architecture: .*/Architecture: $DEB_ARCH/" "$SRC/debian/control"
cp -a "$BUNDLE/." "$SRC/usr/lib/mockstudio/"
cp "$PKG/mockstudio.desktop" "$SRC/usr/share/applications/"
cp "$PKG/icons/mockstudio-512.png" "$SRC/usr/share/icons/hicolor/512x512/apps/mockstudio.png"
cp "$PKG/icons/mockstudio-256.png" "$SRC/usr/share/icons/hicolor/256x256/apps/mockstudio.png"

for so in libflutter_linux_gtk.so libapp.so; do
  [ -f "$SRC/usr/lib/mockstudio/lib/$so" ] || die "staging missing $so"
done
say "Staged OK (both .so files present): $SRC"

say "Building signed source package (GPG passphrase expected)..."
(cd "$SRC" && debuild -S -sa -k"$KEY") || die "debuild failed"

TARBALL="$OUT/mockstudio_${VER}.tar.xz"
# grep -c reads the whole stream, so tar finishes cleanly (no SIGPIPE that
# `set -o pipefail` would otherwise misread as a verification failure).
SO_COUNT=$(tar tJf "$TARBALL" | grep -c 'libflutter_linux_gtk\.so$' || true)
[ "$SO_COUNT" -ge 1 ] \
  || die "SAFETY STOP: $TARBALL does not contain libflutter_linux_gtk.so — not uploading a broken package"
say "Source tarball verified (.so files included)."

if [ "$UPLOAD" = 1 ]; then
  say "Uploading to $PPA ..."
  (cd "$OUT" && dput "$PPA" "mockstudio_${VER}_source.changes") || die "dput failed"
  say "Upload done — watch for the Launchpad build email."
else
  say "Next: bash tool/make_ppa.sh --skip-build --upload"
fi
