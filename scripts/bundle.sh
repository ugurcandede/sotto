#!/bin/bash
set -euo pipefail

BINARY_PATH="${1:-.build/release/sotto}"
APP_NAME="sotto"
BUNDLE_ID="com.ugurcandede.sotto"
BUNDLE_DIR="${APP_NAME}.app"
PLIST_SRC="Resources/Info.plist"
ICON_SRC="Resources/AppIcon.icns"

echo "Creating ${BUNDLE_DIR}..."

rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/Contents/MacOS"
mkdir -p "${BUNDLE_DIR}/Contents/Resources"

cp "${BINARY_PATH}" "${BUNDLE_DIR}/Contents/MacOS/sotto"
cp "${PLIST_SRC}" "${BUNDLE_DIR}/Contents/Info.plist"

# Local builds are never releases; stamp them so the About row says so.
DEV_VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)"
DEV_VERSION="${DEV_VERSION#v}-dev"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString ${DEV_VERSION}" \
    -c "Set :CFBundleVersion ${DEV_VERSION}" \
    "${BUNDLE_DIR}/Contents/Info.plist"

if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature with a stable identifier keeps the Input Monitoring grant
# alive across rebuilds.
codesign --force --deep --sign - --identifier "${BUNDLE_ID}" "${BUNDLE_DIR}"

echo "Done: ${BUNDLE_DIR}"
echo "Run with: open ${BUNDLE_DIR}"
