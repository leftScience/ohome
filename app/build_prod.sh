#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PUBSPEC_FILE="pubspec.yaml"
APP_ENV="prod"
OUTPUT_DIR="build/app/outputs/flutter-apk"
APK_FILENAME="app-release.apk"
DRY_RUN=""
REQUESTED_BUILD_NUMBER=""
BUILD_METADATA_FILE="${BUILD_METADATA_FILE:-}"
RELEASE_TAG="${RELEASE_TAG:-}"
CI_BUILD_NUMBER="${CI_BUILD_NUMBER:-}"

# ── Parse arguments ──────────────────────────────────────────────
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  REQUESTED_BUILD_NUMBER="${2:-}"
else
  REQUESTED_BUILD_NUMBER="${1:-}"
fi

# ── Helper ───────────────────────────────────────────────────────
is_number() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

TAG_BUILD_NAME=""
TAG_BUILD_NUMBER=""

parse_release_tag() {
  local normalized_tag="$1"

  if [[ "$normalized_tag" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)(-rc([0-9]+))?$ ]]; then
    TAG_BUILD_NAME="${BASH_REMATCH[1]}"
    TAG_BUILD_NUMBER="${BASH_REMATCH[3]:-}"
    return 0
  fi

  TAG_BUILD_NAME=""
  TAG_BUILD_NUMBER=""
  return 1
}

# ── Read version from pubspec.yaml ───────────────────────────────
if [[ ! -f "$PUBSPEC_FILE" ]]; then
  echo "[ERROR] \"$PUBSPEC_FILE\" not found."
  exit 1
fi

VERSION_LINE=$(grep -m1 '^version:' "$PUBSPEC_FILE" | cut -d':' -f2 | tr -d ' \r')

if [[ -z "$VERSION_LINE" ]]; then
  echo "[ERROR] version was not found in \"$PUBSPEC_FILE\"."
  exit 1
fi

BUILD_NAME="${VERSION_LINE%%+*}"
PUBSPEC_BUILD_NUMBER="${VERSION_LINE#*+}"

if [[ -z "$BUILD_NAME" ]]; then
  echo "[ERROR] build name could not be parsed from \"$VERSION_LINE\"."
  exit 1
fi

# If there was no '+' in the version string, default to 1
if [[ "$PUBSPEC_BUILD_NUMBER" == "$VERSION_LINE" ]]; then
  PUBSPEC_BUILD_NUMBER=1
fi

TAG_VERSION_SOURCE=""
if [[ -n "$RELEASE_TAG" ]]; then
  NORMALIZED_TAG="${RELEASE_TAG#refs/tags/}"
  if parse_release_tag "$NORMALIZED_TAG"; then
    TAG_VERSION_SOURCE="release tag"
  fi
fi

if [[ -n "$TAG_BUILD_NAME" ]]; then
  BUILD_NAME="$TAG_BUILD_NAME"
  BUILD_NAME_SOURCE="$TAG_VERSION_SOURCE"
else
  BUILD_NAME_SOURCE="pubspec version"
fi

# ── Determine build number ───────────────────────────────────────
if [[ -n "$REQUESTED_BUILD_NUMBER" ]]; then
  if ! is_number "$REQUESTED_BUILD_NUMBER"; then
    echo "[ERROR] Invalid build number \"$REQUESTED_BUILD_NUMBER\"."
    exit 1
  fi
  BUILD_NUMBER="$REQUESTED_BUILD_NUMBER"
  BUILD_NUMBER_SOURCE="argument"
elif [[ -n "$TAG_BUILD_NUMBER" ]]; then
  if ! is_number "$TAG_BUILD_NUMBER"; then
    echo "[ERROR] Invalid build number \"$TAG_BUILD_NUMBER\" parsed from release tag."
    exit 1
  fi
  BUILD_NUMBER="$TAG_BUILD_NUMBER"
  BUILD_NUMBER_SOURCE="release tag"
elif [[ -n "$CI_BUILD_NUMBER" ]]; then
  if ! is_number "$CI_BUILD_NUMBER"; then
    echo "[ERROR] Invalid CI build number \"$CI_BUILD_NUMBER\"."
    exit 1
  fi
  BUILD_NUMBER="$CI_BUILD_NUMBER"
  BUILD_NUMBER_SOURCE="ci run number"
else
  if ! is_number "$PUBSPEC_BUILD_NUMBER"; then
    echo "[ERROR] Invalid pubspec build number \"$PUBSPEC_BUILD_NUMBER\"."
    exit 1
  fi
  BUILD_NUMBER="$PUBSPEC_BUILD_NUMBER"
  BUILD_NUMBER_SOURCE="pubspec version"
fi

if [[ "$BUILD_NUMBER" -le 0 ]]; then
  echo "[ERROR] build number must be greater than 0."
  exit 1
fi

if [[ -n "$RELEASE_TAG" ]]; then
  if [[ -n "$TAG_VERSION_SOURCE" ]]; then
    :
  else
    EXPECTED_FORMATS=(
      "<version>"
      "v<version>"
      "<version>-rc<number>"
      "v<version>-rc<number>"
    )
    echo "[ERROR] Unsupported release tag \"$NORMALIZED_TAG\"."
    echo "[ERROR] Allowed formats: ${EXPECTED_FORMATS[*]}"
    exit 1
  fi
fi

APK_RELATIVE_PATH="$OUTPUT_DIR/$APK_FILENAME"

echo ""
echo "Build name   : $BUILD_NAME ($BUILD_NAME_SOURCE)"
echo "Build number : $BUILD_NUMBER ($BUILD_NUMBER_SOURCE)"
echo "Release tag  : ${RELEASE_TAG:-<none>}"
echo "APK file     : $APK_RELATIVE_PATH"
echo "Output dir   : $OUTPUT_DIR"
echo ""

write_metadata() {
  if [[ -z "$BUILD_METADATA_FILE" ]]; then
    return
  fi

  mkdir -p "$(dirname "$BUILD_METADATA_FILE")"
  cat > "$BUILD_METADATA_FILE" <<EOF
BUILD_NAME=$BUILD_NAME
BUILD_NUMBER=$BUILD_NUMBER
DISPLAY_VERSION=$BUILD_NAME+$BUILD_NUMBER
APK_RELATIVE_PATH=$APK_RELATIVE_PATH
APK_FILENAME=$APK_FILENAME
OUTPUT_DIR=$OUTPUT_DIR
EOF
}

# ── Dry run ──────────────────────────────────────────────────────
if [[ -n "$DRY_RUN" ]]; then
  write_metadata
  echo "[DRY RUN] flutter pub get"
  echo "[DRY RUN] flutter build apk --release --dart-define=APP_ENV=$APP_ENV --build-name=$BUILD_NAME --build-number=$BUILD_NUMBER"
  exit 0
fi

# ── Build ────────────────────────────────────────────────────────
flutter pub get
if [[ $? -ne 0 ]]; then
  echo "[ERROR] flutter pub get failed."
  exit 1
fi

flutter build apk --release \
  --dart-define=APP_ENV="$APP_ENV" \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER"
if [[ $? -ne 0 ]]; then
  echo "[ERROR] flutter build apk failed."
  exit 1
fi

write_metadata

echo ""
echo "Build finished successfully."
if [[ -n "$BUILD_METADATA_FILE" ]]; then
  echo "Build metadata: $BUILD_METADATA_FILE"
fi
