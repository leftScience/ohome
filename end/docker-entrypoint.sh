#!/bin/sh
set -eu

APP_DIR="/app"
CONF_DIR="$APP_DIR/conf"
CONFIG_PATH="$CONF_DIR/config.yaml"
DEFAULT_CONFIG_PATH="$APP_DIR/defaults/config.yaml"

mkdir -p "$CONF_DIR" "$APP_DIR/data" "$APP_DIR/log"

if [ -d "$CONFIG_PATH" ]; then
  echo "error: $CONFIG_PATH is a directory. Mount the host config directory to /app/conf instead of mounting a missing file to /app/conf/config.yaml." >&2
  exit 1
fi

if [ ! -f "$CONFIG_PATH" ]; then
  cp "$DEFAULT_CONFIG_PATH" "$CONFIG_PATH"
fi

exec "$APP_DIR/server"
