#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
APP="build/HideBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/HideBar "$APP/Contents/MacOS/HideBar"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>HideBar</string>
  <key>CFBundleDisplayName</key><string>HideBar</string>
  <key>CFBundleIdentifier</key><string>com.local.hidebar</string>
  <key>CFBundleExecutable</key><string>HideBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" 2>/dev/null
echo "Built $APP"
