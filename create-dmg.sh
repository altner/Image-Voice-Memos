#!/bin/bash
set -euo pipefail

APP_NAME="Image-Voice-Memos"
SCHEME="Image-Voice-Memos"
BUILD_DIR="build"
VERSION="0.1.1"
DMG_NAME="${APP_NAME}-v${VERSION}"

# 1. Ensure xcodeproj exists
if [ ! -d "$APP_NAME.xcodeproj" ]; then
  echo "Generating Xcode project..."
  xcodegen generate
fi

# 2. Build Release
xcodebuild -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

# 3. Verify .app exists
if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: $APP_PATH not found"
  exit 1
fi

# 4. Create DMG staging directory
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 5. Create DMG
rm -f "$BUILD_DIR/$DMG_NAME.dmg"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$BUILD_DIR/$DMG_NAME.dmg"

# 6. Cleanup staging
rm -rf "$STAGING"

echo ""
echo "DMG created: $BUILD_DIR/$DMG_NAME.dmg"
echo ""
echo "Installation instructions for users:"
echo "  1. Open DMG, drag app to Applications"
echo "  2. Open Terminal and run:"
echo "     xattr -rd com.apple.quarantine /Applications/$APP_NAME.app"
echo "     Note: Give Terminal Full Disk Access in System Settings > Privacy & Security if needed."
echo "  3. Launch the app and grant Microphone + Speech Recognition permissions when prompted"
