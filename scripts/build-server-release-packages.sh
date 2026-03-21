#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
END_DIR="$ROOT_DIR/end"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/server-release}"
BUILD_DIR="$DIST_DIR/build"

sha256_file() {
  local file="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi

  sha256sum "$file" | awk '{print $1}'
}

build_package() {
  local goos="$1"
  local goarch="$2"
  local binary_name="$3"
  local archive_name="$4"

  local package_dir="$BUILD_DIR/${goos}_${goarch}"

  rm -rf "$package_dir"
  mkdir -p "$package_dir/conf" "$package_dir/sql"

  (
    cd "$END_DIR"
    GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 go build -trimpath -o "$package_dir/$binary_name" .
  )

  cp "$END_DIR/conf/config.yaml" "$package_dir/conf/config.yaml"
  cp "$END_DIR/sql/init_data.sql" "$package_dir/sql/init_data.sql"
  cp "$END_DIR/release/README.txt" "$package_dir/README.txt"

  if [[ "$goos" == "windows" ]]; then
    cp "$END_DIR/release/start.bat" "$package_dir/start.bat"
  else
    cp "$END_DIR/release/start.command" "$package_dir/start.command"
    chmod +x "$package_dir/$binary_name" "$package_dir/start.command"
  fi

  rm -f "$DIST_DIR/$archive_name"
  (
    cd "$package_dir"
    zip -qr "$DIST_DIR/$archive_name" .
  )
}

rm -rf "$DIST_DIR"
mkdir -p "$BUILD_DIR"

build_package windows amd64 ohome.exe ohome-server_windows_amd64.zip
build_package darwin amd64 ohome ohome-server_darwin_amd64.zip
build_package darwin arm64 ohome ohome-server_darwin_arm64.zip

checksum_file="$DIST_DIR/checksums.txt"
: > "$checksum_file"
for archive in \
  "$DIST_DIR/ohome-server_windows_amd64.zip" \
  "$DIST_DIR/ohome-server_darwin_amd64.zip" \
  "$DIST_DIR/ohome-server_darwin_arm64.zip"; do
  printf "%s  %s\n" "$(sha256_file "$archive")" "$(basename "$archive")" >> "$checksum_file"
done
