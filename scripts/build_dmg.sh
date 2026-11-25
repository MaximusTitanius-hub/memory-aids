#!/usr/bin/env bash
# Builds "Memory Aids.app" and packs it into build/MemoryAids.dmg. Runs on macOS.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-1}"
APP="build/Memory Aids.app"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: runs on Apple-chip and Intel Macs.
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
cp "$BIN_DIR/MemoryAids" "$APP/Contents/MacOS/MemoryAids"

sed -e "s/VERSION_PLACEHOLDER/$VERSION/" -e "s/BUILD_PLACEHOLDER/$BUILD/" \
    packaging/Info.plist > "$APP/Contents/Info.plist"

# App icon
ICONSET=build/AppIcon.iconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size packaging/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double packaging/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature (no Apple Developer account needed). Users open it once with right-click > Open.
codesign --force --deep --sign - "$APP"

# Disk image with a shortcut to Applications for drag-and-drop install.
STAGE=build/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Memory Aids" -srcfolder "$STAGE" -ov -format UDZO build/MemoryAids.dmg

echo "Built build/MemoryAids.dmg"
