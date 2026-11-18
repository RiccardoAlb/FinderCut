#!/bin/bash
# Builds FinderCut.app (universal-free, native arch) into ./build
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/FinderCut.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/release/FinderCut "$APP/Contents/MacOS/"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>FinderCut</string>
<key>CFBundleIdentifier</key><string>org.findercut.app</string>
<key>CFBundleExecutable</key><string>FinderCut</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSUIElement</key><true/>
<key>NSAppleEventsUsageDescription</key><string>FinderCut needs to ask Finder which folder you pasted into, to show moved files again.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP"
