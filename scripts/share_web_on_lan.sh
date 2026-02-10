#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8080}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building Flutter web (release)..."
flutter build web --release

DEFAULT_IFACE="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
HOST_IP=""
if [[ -n "${DEFAULT_IFACE}" ]]; then
  HOST_IP="$(ipconfig getifaddr "${DEFAULT_IFACE}" 2>/dev/null || true)"
fi
if [[ -z "${HOST_IP}" ]]; then
  HOST_IP="127.0.0.1"
fi

echo ""
echo "LAN URL: http://${HOST_IP}:${PORT}"
echo "Open this from a phone on the same network."
echo "Press Ctrl+C to stop."
echo ""

exec python3 -m http.server "${PORT}" --bind 0.0.0.0 --directory build/web
