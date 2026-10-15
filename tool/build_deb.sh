#!/usr/bin/env bash
# Build the Debian package for Mock Studio.
# Usage: tool/build_deb.sh [version]   (defaults to the version in pubspec.yaml)
#
# The architecture (amd64 or arm64) is the one of the machine running the
# script, because it packages the bundle that `flutter build linux` made there.
set -euo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(grep '^version:' "$PROJ/pubspec.yaml" | sed 's/version: *//; s/+.*//')}"
DEB_ARCH="$(dpkg --print-architecture)"
case "$DEB_ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *)
    echo "error: unsupported architecture '$DEB_ARCH' (amd64 or arm64)" >&2
    exit 1
    ;;
esac
PKG="mockstudio_${VERSION}_${DEB_ARCH}"
ROOT="$PROJ/dist/deb/$PKG"
BUNDLE="$PROJ/build/linux/$FLUTTER_ARCH/release/bundle"

[ -d "$BUNDLE" ] || { echo "Release bundle missing - run: flutter build linux --release"; exit 1; }

rm -rf "$ROOT"
mkdir -p "$ROOT/DEBIAN" \
         "$ROOT/usr/lib/mockstudio" \
         "$ROOT/usr/bin" \
         "$ROOT/usr/share/applications" \
         "$ROOT/usr/share/icons/hicolor/256x256/apps" \
         "$ROOT/usr/share/icons/hicolor/512x512/apps"

cp -r "$BUNDLE/." "$ROOT/usr/lib/mockstudio/"
ln -s ../lib/mockstudio/mock_studio "$ROOT/usr/bin/mockstudio"

cp "$PROJ/assets/icon_256.png" "$ROOT/usr/share/icons/hicolor/256x256/apps/mockstudio.png"
cp "$PROJ/assets/icon_512.png" "$ROOT/usr/share/icons/hicolor/512x512/apps/mockstudio.png"

cat > "$ROOT/usr/share/applications/mockstudio.desktop" <<'EOF'
[Desktop Entry]
Name=Mock Studio
Comment=Production mock server - design endpoints, expose them on LAN or a public tunnel
Exec=mockstudio
Icon=mockstudio
Terminal=false
Type=Application
Categories=Development;Network;
Keywords=mock;server;API;REST;HTTP;endpoint;stub;testing;
EOF

SIZE=$(du -sk "$ROOT/usr" | cut -f1)
cat > "$ROOT/DEBIAN/control" <<EOF
Package: mockstudio
Version: $VERSION
Section: devel
Priority: optional
Architecture: ${DEB_ARCH}
Installed-Size: $SIZE
Depends: libgtk-3-0, libglib2.0-0
Maintainer: Dhivakar <dhivakar1010@gmail.com>
Description: Mock Studio - production mock server by dhiva labs
 Design HTTP endpoints visually, start a real server, and share it on
 your LAN or over a public tunnel. Conditional rules, response
 sequences, templating, fault injection, proxy recording and
 OpenAPI import - friendly enough for non-developers.
EOF

mkdir -p "$PROJ/dist"
dpkg-deb --build --root-owner-group "$ROOT" "$PROJ/dist/$PKG.deb"
(cd "$PROJ/dist" && sha256sum "$PKG.deb" > "$PKG.deb.sha256")
echo "Built $PROJ/dist/$PKG.deb"
