#!/usr/bin/env bash
set -euo pipefail

# Build and package Task Manager for macOS as a native .app bundle
echo "==> Building Task Manager in release mode..."
swift build -c release

APP_NAME="Task Manager"
BUNDLE_ID="com.k692.TaskManager"
BUILD_DIR=".build/release"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Creating .app bundle structure at ${APP_DIR}..."
rm -rf "${DIST_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy compiled executable
cp "${BUILD_DIR}/TaskManager" "${MACOS_DIR}/TaskManager"
chmod +x "${MACOS_DIR}/TaskManager"

# Copy SPM Resource Bundle if present into Resources directory
BUNDLE_PATH=$(find .build -name "TaskManager_TaskManagerApp.bundle" -type d | head -n 1)
if [ -n "${BUNDLE_PATH}" ] && [ -d "${BUNDLE_PATH}" ]; then
    echo "==> Copying SwiftPM resource bundle from ${BUNDLE_PATH}..."
    cp -R "${BUNDLE_PATH}" "${RESOURCES_DIR}/"
fi

# Copy icon.png directly into Resources as well
if [ -f "icon/icon.png" ]; then
    cp "icon/icon.png" "${RESOURCES_DIR}/icon.png"
fi

# Generate native macOS AppIcon.icns from icon/icon.png
if [ -f "icon/icon.png" ]; then
    echo "==> Generating AppIcon.icns from icon/icon.png..."
    ICONSET="dist/AppIcon.iconset"
    mkdir -p "${ICONSET}"
    sips -z 16 16     icon/icon.png --out "${ICONSET}/icon_16x16.png" > /dev/null 2>&1
    sips -z 32 32     icon/icon.png --out "${ICONSET}/icon_16x16@2x.png" > /dev/null 2>&1
    sips -z 32 32     icon/icon.png --out "${ICONSET}/icon_32x32.png" > /dev/null 2>&1
    sips -z 64 64     icon/icon.png --out "${ICONSET}/icon_32x32@2x.png" > /dev/null 2>&1
    sips -z 128 128   icon/icon.png --out "${ICONSET}/icon_128x128.png" > /dev/null 2>&1
    sips -z 256 256   icon/icon.png --out "${ICONSET}/icon_128x128@2x.png" > /dev/null 2>&1
    sips -z 256 256   icon/icon.png --out "${ICONSET}/icon_256x256.png" > /dev/null 2>&1
    sips -z 512 512   icon/icon.png --out "${ICONSET}/icon_256x256@2x.png" > /dev/null 2>&1
    sips -z 512 512   icon/icon.png --out "${ICONSET}/icon_512x512.png" > /dev/null 2>&1
    sips -z 1024 1024 icon/icon.png --out "${ICONSET}/icon_512x512@2x.png" > /dev/null 2>&1
    iconutil -c icns "${ICONSET}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "${ICONSET}"
fi

# Create Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TaskManager</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Krishnendu Pal. MIT License.</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>${BUNDLE_ID}</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>taskmanager</string>
            </array>
        </dict>
    </array>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Ad-hoc sign the bundle
echo "==> Signing application bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Successfully assembled ${APP_DIR} with AppIcon.icns!"
