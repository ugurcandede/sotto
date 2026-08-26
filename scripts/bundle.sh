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

# TCC keys the Input Monitoring grant to the signing identity. The self-signed
# sotto-dev cert keeps it stable across rebuilds; ad-hoc (cdhash-keyed) loses
# the grant on every build. Fall back to ad-hoc where the cert is absent (CI).
SIGN_IDENTITY="sotto-dev"
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "\"${SIGN_IDENTITY}\""; then
    SIGN_IDENTITY="-"
fi
codesign --force --deep --sign "${SIGN_IDENTITY}" --identifier "${BUNDLE_ID}" "${BUNDLE_DIR}"

echo "Done: ${BUNDLE_DIR}"
echo "Run with: open ${BUNDLE_DIR}"
