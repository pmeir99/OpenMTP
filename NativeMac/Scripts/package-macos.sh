#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "The native MTP runtime currently supports Apple Silicon (arm64) only." >&2
  exit 1
fi

APP_VERSION="${APP_VERSION:-$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' package.json | head -n 1)}"
APP_PATH="$ROOT/dist/mac/OpenMTP.app"
DMG_PATH="$ROOT/dist/OpenMTPNative-macOS.dmg"
ICONSET_PATH="$ROOT/dist/OpenMTP.iconset"
STAGING_PATH="$ROOT/dist/OpenMTP-dmg"

swift build --package-path NativeMac -c release --product OpenMTPNative

mkdir -p "$ROOT/dist"
swift "$ROOT/NativeMac/Scripts/GenerateAppIcon.swift" \
  "$ROOT/NativeMac/Resources/OpenMTP-Icon-Glass-Background.svg" \
  "$ICONSET_PATH"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICONSET_PATH/icon_1024x1024.png" \
    --out "$ICONSET_PATH/icon_${size}x${size}.png" >/dev/null
  if [[ "$size" -lt 512 ]]; then
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$ICONSET_PATH/icon_1024x1024.png" \
      --out "$ICONSET_PATH/icon_${size}x${size}@2x.png" >/dev/null
  fi
done
cp "$ICONSET_PATH/icon_1024x1024.png" "$ICONSET_PATH/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_PATH" -o "$ROOT/dist/AppIcon.icns"

rm -rf "$APP_PATH" "$STAGING_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources/bin" "$STAGING_PATH"
cp "$ROOT/NativeMac/.build/release/OpenMTPNative" "$APP_PATH/Contents/MacOS/OpenMTP"
cp "$ROOT/build/mac/bin/arm64/kalam-seg5.dylib" "$APP_PATH/Contents/Resources/bin/"
cp "$ROOT/build/mac/bin/arm64/libusb-seg5.dylib" "$APP_PATH/Contents/Resources/bin/"
cp "$ROOT/dist/AppIcon.icns" "$APP_PATH/Contents/Resources/"
chmod +x "$APP_PATH/Contents/MacOS/OpenMTP"

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>OpenMTP</string>
  <key>CFBundleIdentifier</key><string>io.ganeshrvel.openmtp</string>
  <key>CFBundleName</key><string>OpenMTP</string>
  <key>CFBundleDisplayName</key><string>OpenMTP</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>$APP_VERSION</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSRemovableVolumesUsageDescription</key><string>OpenMTP needs access to connected Android devices to transfer files.</string>
</dict></plist>
PLIST

plutil -lint "$APP_PATH/Contents/Info.plist"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
cp -R "$APP_PATH" "$STAGING_PATH/"
ln -s /Applications "$STAGING_PATH/Applications"
hdiutil create -volname OpenMTP -srcfolder "$STAGING_PATH" -format UDZO -ov "$DMG_PATH"
hdiutil imageinfo "$DMG_PATH"
test -s "$DMG_PATH"
