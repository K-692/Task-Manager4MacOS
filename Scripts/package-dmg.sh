#!/usr/bin/env bash
set -euo pipefail

./Scripts/build-app.sh

APP_NAME="Task Manager"
DMG_NAME="TaskManager-1.0.0.dmg"
DIST_DIR="dist"
DMG_STAGING="${DIST_DIR}/dmg_staging"

echo "==> Preparing DMG staging area..."
rm -rf "${DMG_STAGING}" "${DIST_DIR}/${DMG_NAME}"
mkdir -p "${DMG_STAGING}"

cp -R "${DIST_DIR}/${APP_NAME}.app" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

echo "==> Creating compressed read-only DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DIST_DIR}/${DMG_NAME}"

rm -rf "${DMG_STAGING}"
echo "==> Successfully created ${DIST_DIR}/${DMG_NAME}!"
