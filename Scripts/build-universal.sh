#!/usr/bin/env bash
set -euo pipefail

# Build Universal Binary (Apple Silicon + Intel) and assemble Universal .app bundle
APP_NAME="Task Manager"
BUNDLE_ID="com.k692.TaskManager"
DIST_DIR="dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building arm64 and x86_64 universal slices..."

swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0

# Locate compiled binaries dynamically
ARM64_BIN=$(find .build -path "*/arm64-apple-macosx*/release/TaskManager" -type f | head -n 1)
X86_BIN=$(find .build -path "*/x86_64-apple-macosx*/release/TaskManager" -type f | head -n 1)

if [ -z "${ARM64_BIN}" ] || [ -z "${X86_BIN}" ]; then
    echo "Error: Could not locate arm64 or x86_64 binaries in .build!"
    exit 1
fi

echo "==> Found arm64 slice at: ${ARM64_BIN}"
echo "==> Found x86_64 slice at: ${X86_BIN}"

mkdir -p "${DIST_DIR}/universal"
lipo -create "${ARM64_BIN}" "${X86_BIN}" -output "${DIST_DIR}/universal/TaskManager"

echo "==> Universal binary created at ${DIST_DIR}/universal/TaskManager:"
lipo -info "${DIST_DIR}/universal/TaskManager"

echo "==> Assembling Universal .app bundle at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy universal binary
cp "${DIST_DIR}/universal/TaskManager" "${MACOS_DIR}/TaskManager"
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
    rm -rf "${ICONSET}"
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

echo "==> Universal Application bundle built successfully at ${APP_DIR}!"
file "${MACOS_DIR}/TaskManager"
lipo -info "${MACOS_DIR}/TaskManager"

