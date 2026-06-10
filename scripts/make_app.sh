#!/bin/bash
# 把 SwiftPM 产物打包成 CatOS.app(输出到 dist/)。
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/CatOS.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/CatOS "$APP/Contents/MacOS/CatOS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CatOS</string>
    <key>CFBundleIdentifier</key>
    <string>com.fov.catos</string>
    <key>CFBundleName</key>
    <string>CatOS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "打包完成: $APP"
