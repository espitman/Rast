#!/bin/zsh
set -euo pipefail

APP_NAME="Rast"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}_v${VERSION}.dmg"
APP_PATH="/Applications/${APP_NAME}.app"
BACKGROUND_IMAGE="Resources/installer_background.png"

echo "Checking if app exists at $APP_PATH..."
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Please build the app first."
    exit 1
fi

echo "Cleaning up old DMG files..."
rm -f "$DMG_NAME"

echo "Creating DMG..."
create-dmg \
  --volname "${APP_NAME} Installer" \
  --background "$BACKGROUND_IMAGE" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 150 210 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 450 210 \
  "$DMG_NAME" \
  "$APP_PATH"

echo "------------------------------------------------"
echo "DMG Created: $DMG_NAME"
echo "------------------------------------------------"
