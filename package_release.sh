#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Rast.xcodeproj"
SCHEME="Rast"
APP_NAME="Rast"
CONFIGURATION="${CONFIGURATION:-Release}"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
fi

BUILD_ROOT="$ROOT_DIR/build"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
DMG_STAGING_PATH="$BUILD_ROOT/DMG"
DIST_PATH="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
ZIP_PATH="$DIST_PATH/${APP_NAME}_v${VERSION}.zip"
DMG_PATH="$DIST_PATH/${APP_NAME}_v${VERSION}.dmg"

echo "Cleaning previous release artifacts..."
rm -rf "$BUILD_ROOT" "$DIST_PATH"
mkdir -p "$DMG_STAGING_PATH" "$DIST_PATH"

echo "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build \
  -quiet

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but app bundle was not found at $APP_PATH"
  exit 1
fi

echo "Creating ZIP archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Preparing DMG contents..."
cp -R "$APP_PATH" "$DMG_STAGING_PATH/"
ln -s /Applications "$DMG_STAGING_PATH/Applications"

echo "Creating DMG archive..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH" \
  > /dev/null

echo "Release artifacts created:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
