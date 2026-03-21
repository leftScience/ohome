#!/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
export OHOME_BASE_DIR="$APP_DIR"
cd "$APP_DIR"

exec "$APP_DIR/ohome"
