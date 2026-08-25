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

if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${BUNDLE_DIR}/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature with a stable identifier keeps the Input Monitoring grant
# alive across rebuilds.
codesign --force --deep --sign - --identifier "${BUNDLE_ID}" "${BUNDLE_DIR}"

echo "Done: ${BUNDLE_DIR}"
echo "Run with: open ${BUNDLE_DIR}"
