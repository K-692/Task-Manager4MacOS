#!/usr/bin/env bash
set -euo pipefail

# Build Universal Application bundle
./Scripts/build-universal.sh

APP_NAME="Task Manager"
DMG_NAME="TaskManager-1.0.0-Universal.dmg"
DIST_DIR="dist"
RELEASES_DIR="releases"
DMG_STAGING="${DIST_DIR}/dmg_staging"

echo "==> Preparing Universal DMG staging area..."
rm -rf "${DMG_STAGING}" "${DIST_DIR}/${DMG_NAME}"
mkdir -p "${DMG_STAGING}"
mkdir -p "${RELEASES_DIR}"

cp -R "${DIST_DIR}/${APP_NAME}.app" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

# Set volume icon if AppIcon.icns is present
if [ -f "${DIST_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" ]; then
    cp "${DIST_DIR}/${APP_NAME}.app/Contents/Resources/AppIcon.icns" "${DMG_STAGING}/.VolumeIcon.icns" || true
fi

echo "==> Creating compressed read-only Universal DMG (${DMG_NAME})..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"

# Copy to repository releases folder
cp "${DIST_DIR}/${DMG_NAME}" "${RELEASES_DIR}/${DMG_NAME}"

rm -rf "${DMG_STAGING}"
echo "==> Successfully created Universal DMG at:"
echo "    - ${DIST_DIR}/${DMG_NAME}"
echo "    - ${RELEASES_DIR}/${DMG_NAME}"
ls -lh "${RELEASES_DIR}/${DMG_NAME}"

