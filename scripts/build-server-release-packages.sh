#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
END_DIR="$ROOT_DIR/end"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/server-release}"
BUILD_DIR="$DIST_DIR/build"

VERSION="${VERSION:-${GITHUB_REF_NAME:-}}"
VERSION="${VERSION#refs/tags/}"
VERSION="${VERSION#v}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
  VERSION="${VERSION#v}"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="0.0.1"
fi

COMMIT="${COMMIT:-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo dev)}"
BUILD_TIME="${BUILD_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
CHANNEL="${CHANNEL:-stable}"
RELEASE_BASE_URL="${RELEASE_BASE_URL:-https://github.com/leftScience/ohome/releases/latest/download}"

sha256_file() {
  local file="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi

  sha256sum "$file" | awk '{print $1}'
}

archive_dir() {
  local source_dir="$1"
  local archive_path="$2"

  if command -v zip >/dev/null 2>&1; then
    (
      cd "$source_dir"
      zip -qr "$archive_path" .
    )
    return
  fi

  python - "$source_dir" "$archive_path" <<'PY'
import os
import sys
import zipfile

source_dir = sys.argv[1]
archive_path = sys.argv[2]

with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for root, _, files in os.walk(source_dir):
        for name in files:
            path = os.path.join(root, name)
            arcname = os.path.relpath(path, source_dir)
            zf.write(path, arcname)
PY
}

ldflags() {
  cat <<EOF
-X 'ohome/buildinfo.Version=${VERSION}' -X 'ohome/buildinfo.Commit=${COMMIT}' -X 'ohome/buildinfo.BuildTime=${BUILD_TIME}' -X 'ohome/buildinfo.Channel=${CHANNEL}'
EOF
}

build_package() {
  local goos="$1"
  local goarch="$2"
  local server_binary_name="$3"
  local updater_binary_name="$4"
  local archive_name="$5"

  local package_dir="$BUILD_DIR/${goos}_${goarch}"
  local version_dir="$package_dir/versions/$VERSION"

  rm -rf "$package_dir"
  mkdir -p "$package_dir/conf" "$package_dir/sql" "$package_dir/data" "$package_dir/log" "$version_dir"

  (
    cd "$END_DIR"
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build -trimpath -ldflags="$(ldflags)" -o "$version_dir/$server_binary_name" .
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build -trimpath -ldflags="$(ldflags)" -o "$package_dir/$updater_binary_name" ./cmd/updater
  )

  cp "$END_DIR/conf/config.yaml" "$package_dir/conf/config.yaml"
  cp "$END_DIR/sql/init_data.sql" "$package_dir/sql/init_data.sql"
  cp "$END_DIR/release/README.txt" "$package_dir/README.txt"
  printf "%s\n" "$VERSION" > "$package_dir/current.txt"

  if [[ "$goos" == "windows" ]]; then
    cp "$END_DIR/release/start.bat" "$package_dir/start.bat"
  else
    cp "$END_DIR/release/start.command" "$package_dir/start.command"
    chmod +x "$version_dir/$server_binary_name" "$package_dir/$updater_binary_name" "$package_dir/start.command"
  fi

  rm -f "$DIST_DIR/$archive_name"
  archive_dir "$package_dir" "$DIST_DIR/$archive_name"
}

generate_manifest() {
  local windows_sha="$1"
  local darwin_amd64_sha="$2"
  local darwin_arm64_sha="$3"

  cat > "$DIST_DIR/server-manifest.json" <<EOF
{
  "channel": "${CHANNEL}",
  "version": "${VERSION}",
  "releaseNotes": "GitHub Release ${VERSION}",
  "publishedAt": "${BUILD_TIME}",
  "docker": {
    "image": "hanlinwang0606/ohome",
    "tag": "${VERSION}"
  },
  "portable": {
    "windows_amd64": {
      "url": "${RELEASE_BASE_URL}/ohome-server_windows_amd64.zip",
      "sha256": "${windows_sha}"
    },
    "darwin_amd64": {
      "url": "${RELEASE_BASE_URL}/ohome-server_darwin_amd64.zip",
      "sha256": "${darwin_amd64_sha}"
    },
    "darwin_arm64": {
      "url": "${RELEASE_BASE_URL}/ohome-server_darwin_arm64.zip",
      "sha256": "${darwin_arm64_sha}"
    }
  }
}
EOF
}

rm -rf "$DIST_DIR"
mkdir -p "$BUILD_DIR"

build_package windows amd64 ohome.exe ohome-updater.exe ohome-server_windows_amd64.zip
build_package darwin amd64 ohome ohome-updater ohome-server_darwin_amd64.zip
build_package darwin arm64 ohome ohome-updater ohome-server_darwin_arm64.zip

windows_archive="$DIST_DIR/ohome-server_windows_amd64.zip"
darwin_amd64_archive="$DIST_DIR/ohome-server_darwin_amd64.zip"
darwin_arm64_archive="$DIST_DIR/ohome-server_darwin_arm64.zip"

windows_sha="$(sha256_file "$windows_archive")"
darwin_amd64_sha="$(sha256_file "$darwin_amd64_archive")"
darwin_arm64_sha="$(sha256_file "$darwin_arm64_archive")"

generate_manifest "$windows_sha" "$darwin_amd64_sha" "$darwin_arm64_sha"

checksum_file="$DIST_DIR/checksums.txt"
: > "$checksum_file"
for archive in \
  "$windows_archive" \
  "$darwin_amd64_archive" \
  "$darwin_arm64_archive" \
  "$DIST_DIR/server-manifest.json"; do
  printf "%s  %s\n" "$(sha256_file "$archive")" "$(basename "$archive")" >> "$checksum_file"
done
