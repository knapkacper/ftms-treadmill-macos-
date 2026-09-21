#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="$HOME/Applications/Bieznia.app"
BIN=".build/release/Bieznia"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Bieznia"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Bieznia</string>
  <key>CFBundleDisplayName</key><string>Bieżnia</string>
  <key>CFBundleIdentifier</key><string>local.bieznia.app</string>
  <key>CFBundleExecutable</key><string>Bieznia</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Odczyt danych treningu z bieżni po Bluetooth LE</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "gotowe: $APP"
echo "uruchom: open \"$APP\""
