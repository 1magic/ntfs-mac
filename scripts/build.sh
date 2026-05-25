#!/bin/bash
set -e

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="NTFSMac"
APP_NAME="NTFS Mac"
SCHEME="NTFSMac"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}.dmg"
DMG_VOLUME_NAME="${APP_NAME}"

echo "================================================"
echo "  Building ${APP_NAME}"
echo "================================================"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 1: Archive
echo ""
echo "▶ Step 1/3: Archiving..."
xcodebuild archive \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -archivePath "${ARCHIVE_PATH}" \
    -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_ALLOWED=NO \
    | tail -1

echo "✓ Archive complete"

# Step 2: Export .app from archive
echo ""
echo "▶ Step 2/3: Exporting app..."
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    # Fallback: try building directly
    echo "  Archive export not found, building directly..."
    xcodebuild build \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_ALLOWED=NO \
        | tail -1

    APP_PATH=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "✗ Error: Could not find ${APP_NAME}.app"
    exit 1
fi

mkdir -p "${EXPORT_PATH}"
cp -R "${APP_PATH}" "${EXPORT_PATH}/"
echo "✓ App exported to: ${EXPORT_PATH}/${APP_NAME}.app"

# Step 3: Create DMG
echo ""
echo "▶ Step 3/3: Creating DMG..."

DMG_TEMP="${BUILD_DIR}/tmp.dmg"
DMG_SIZE=50 # MB

# Create temporary DMG
hdiutil create \
    -srcfolder "${EXPORT_PATH}" \
    -volname "${DMG_VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "${DMG_TEMP}" \
    -quiet

# Mount it
MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

# Create Applications symlink
ln -sf /Applications "${MOUNT_POINT}/Applications"

# Set DMG window properties
echo '
   tell application "Finder"
     tell disk "'"${DMG_VOLUME_NAME}"'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 900, 400}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 80
           set position of item "'"${APP_NAME}.app"'" of container window to {130, 150}
           set position of item "Applications" of container window to {370, 150}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript || true

# Unmount
hdiutil detach "${MOUNT_POINT}" -quiet -force || true
sleep 1

# Convert to compressed DMG
hdiutil convert "${DMG_TEMP}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" -quiet
rm -f "${DMG_TEMP}"

echo "✓ DMG created: ${DMG_PATH}"

echo ""
echo "================================================"
echo "  Build complete!"
echo "  DMG: ${DMG_PATH}"
echo "  App: ${EXPORT_PATH}/${APP_NAME}.app"
echo "================================================"
