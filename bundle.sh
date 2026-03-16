#!/bin/bash
# Bundle KiroSwitcher as a macOS .app

APP_NAME="KiroSwitcher"
APP_DIR="${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp ".build/release/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>KiroSwitcher</string>
    <key>CFBundleDisplayName</key>
    <string>Kiro Switcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.kiro.switcher</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>KiroSwitcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>KiroSwitcher needs accessibility access to manage Kiro windows.</string>
</dict>
</plist>
EOF

echo "✅ ${APP_DIR} created successfully!"
echo "📍 Location: $(pwd)/${APP_DIR}"
echo ""
echo "To run: open ${APP_DIR}"
echo "⚠️  First run will ask for Accessibility permission in System Settings."
