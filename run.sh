#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Rast.xcodeproj"
SCHEME="Rast"

echo "Building $SCHEME..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS" \
  build \
  -quiet

APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path "*/Build/Products/Debug/Rast.app" -print -quit)"

if [[ -z "${APP_PATH:-}" ]]; then
  echo "Build succeeded, but Rast.app was not found in DerivedData."
  exit 1
fi

echo "Launching app: $APP_PATH"
open "$APP_PATH"

echo "Opening Accessibility settings..."
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo "Done."
echo "Please enable Rast in Accessibility list, then quit and relaunch the app once."
