#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:?missing output path}"

VERSION="${VERSION:-}"
DOCKER_IMAGE="${DOCKER_IMAGE:-}"
DOCKER_TAG="${DOCKER_TAG:-$VERSION}"
CHANNEL="${CHANNEL:-stable}"
BUILD_TIME="${BUILD_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

if [[ -z "$VERSION" ]]; then
  echo "VERSION is required" >&2
  exit 1
fi

if [[ -z "$DOCKER_IMAGE" ]]; then
  echo "DOCKER_IMAGE is required" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

cat > "$OUTPUT_PATH" <<EOF
{
  "channel": "${CHANNEL}",
  "version": "${VERSION}",
  "releaseNotes": "GitHub Release ${VERSION}",
  "publishedAt": "${BUILD_TIME}",
  "docker": {
    "image": "${DOCKER_IMAGE}",
    "tag": "${DOCKER_TAG}"
  }
}
EOF
