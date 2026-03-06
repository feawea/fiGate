#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/fiGate.xcodeproj"
SCHEME="fiGate"
CONFIGURATION="${CONFIGURATION:-Release}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
APP_NAME="fiGate.app"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME"

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
  build > /tmp/figate-install-build.log

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

echo "Stopping any running fiGate processes..."
pkill -x fiGate >/dev/null 2>&1 || true

echo "Installing to $INSTALL_PATH..."
rm -rf "$INSTALL_PATH"
/usr/bin/ditto "$SOURCE_APP_PATH" "$INSTALL_PATH"

signature_line="$(
  codesign -dv --verbose=4 "$INSTALL_PATH" 2>&1 |
    awk -F= '/^Signature=/ {print $2; exit}'
)"
team_line="$(
  codesign -dv --verbose=4 "$INSTALL_PATH" 2>&1 |
    awk -F= '/^TeamIdentifier=/ {print $2; exit}'
)"

echo
echo "Local install complete."
echo "Installed app: $INSTALL_PATH"
echo "Signature: ${signature_line:-unknown}"
echo "TeamIdentifier: ${team_line:-unknown}"
echo
echo "Recommended next steps:"

if [[ "${signature_line:-}" == "adhoc" ]]; then
  echo "WARNING: fiGate.app is still ad hoc signed."
  echo "System Settings may reject it with:"
  echo "  Failed to create archivableRepresentation for URL: file:///Applications/fiGate.app/"
  echo "Fix this first in Xcode:"
  echo "1. Xcode > Settings > Accounts > Manage Certificates"
  echo "2. Create or refresh a valid Apple Development certificate"
  echo "3. Select a Development Team for the fiGate target"
  echo "4. Re-run ./scripts/install-local.sh"
else
  echo "1. Open $INSTALL_PATH once."
  echo "2. Open Full Disk Access and enable:"
  echo "   - $INSTALL_PATH"
  echo "3. Allow Automation access to Messages when prompted."
  echo "4. Launch fiGate from /Applications instead of Xcode for stable permission testing."
fi
