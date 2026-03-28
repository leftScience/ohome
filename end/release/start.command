#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export OHOME_BASE_DIR="$APP_DIR"
cd "$APP_DIR"

if [[ -x "$APP_DIR/ohome-updater" ]]; then
  nohup "$APP_DIR/ohome-updater" >/dev/null 2>&1 &
fi

exec "$APP_DIR/ohome-updater" run-current-server
