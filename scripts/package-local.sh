#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/fiGate.xcodeproj"
SCHEME="fiGate"
CONFIGURATION="${CONFIGURATION:-Release}"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="fiGate.app"
RELEASE_LABEL="${RELEASE_LABEL:-Beta-0.1}"
APP_DESTINATION="$DIST_DIR/$APP_NAME"
ZIP_DESTINATION="$DIST_DIR/fiGate-${RELEASE_LABEL}.zip"
DMG_DESTINATION="$DIST_DIR/fiGate-${RELEASE_LABEL}.dmg"
DMG_VOLUME_NAME="fiGate ${RELEASE_LABEL}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "fiGate.xcodeproj was not found at $PROJECT_PATH"
  echo "Run ./scripts/generate-xcodeproj.sh first."
  exit 1
fi

echo "Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  build > /tmp/figate-package-build.log

BUILT_PRODUCTS_DIR="$(
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings |
    awk '/BUILT_PRODUCTS_DIR = / {print substr($0, index($0, "= ") + 2); exit}'
)"

if [[ -z "$BUILT_PRODUCTS_DIR" ]]; then
  echo "Unable to determine BUILT_PRODUCTS_DIR."
  exit 1
fi

SOURCE_APP_PATH="$BUILT_PRODUCTS_DIR/$APP_NAME"

if [[ ! -d "$SOURCE_APP_PATH" ]]; then
  echo "Built app was not found at $SOURCE_APP_PATH"
  exit 1
fi

echo "Preparing $DIST_DIR..."
mkdir -p "$DIST_DIR"
rm -rf "$APP_DESTINATION" "$ZIP_DESTINATION" "$DMG_DESTINATION"

echo "Copying app bundle..."
/usr/bin/ditto "$SOURCE_APP_PATH" "$APP_DESTINATION"

echo "Creating zip archive..."
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DESTINATION" "$ZIP_DESTINATION"

echo "Creating dmg archive..."
/usr/bin/hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$APP_DESTINATION" \
  -format UDZO \
  -ov \
  "$DMG_DESTINATION" >/tmp/figate-package-dmg.log

signature_line="$(
  codesign -dv --verbose=4 "$APP_DESTINATION" 2>&1 |
    awk -F= '/^Signature=/ {print $2; exit}'
)"
team_line="$(
  codesign -dv --verbose=4 "$APP_DESTINATION" 2>&1 |
    awk -F= '/^TeamIdentifier=/ {print $2; exit}'
)"

echo
echo "Package complete."
echo "App bundle: $APP_DESTINATION"
echo "Zip archive: $ZIP_DESTINATION"
echo "DMG archive: $DMG_DESTINATION"
echo "Signature: ${signature_line:-unknown}"
echo "TeamIdentifier: ${team_line:-unknown}"
