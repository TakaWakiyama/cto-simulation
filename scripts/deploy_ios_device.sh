#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE_LINE="$(xcrun devicectl list devices 2>/dev/null | awk '/connected/ {print; exit}')"
DEVICE_ID="$(echo "${DEVICE_LINE}" | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' || true)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "No connected iOS device found."
  echo "Connect iPhone by USB and trust this computer."
  exit 1
fi

echo "Using device: ${DEVICE_ID}"
echo "Building iOS release..."
flutter build ios --release

APP_PATH="${ROOT_DIR}/build/ios/iphoneos/Runner.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Build output not found: ${APP_PATH}"
  exit 1
fi

echo "Installing app to iPhone..."
xcrun devicectl device install app --device "${DEVICE_ID}" "${APP_PATH}"

echo "Done."
