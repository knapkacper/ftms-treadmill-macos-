#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="$HOME/Applications/FTMSTreadmill.app"
BIN=".build/release/FTMSTreadmill"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FTMSTreadmill"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>FTMSTreadmill</string>
  <key>CFBundleDisplayName</key><string>FTMS Treadmill</string>
  <key>CFBundleIdentifier</key><string>local.ftms-treadmill.app</string>
  <key>CFBundleExecutable</key><string>FTMSTreadmill</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>Reads live workout data from a Bluetooth LE treadmill</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "built: $APP"
echo "run:   open \"$APP\""
