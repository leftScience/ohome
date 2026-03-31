#!/usr/bin/env bash
set -euo pipefail

OUTPUT_PATH="${1:?missing output path}"

VERSION="${VERSION:-}"
CHANNEL="${CHANNEL:-stable}"
BUILD_TIME="${BUILD_TIME:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
RELEASE_NOTES="${RELEASE_NOTES:-Release ${VERSION}}"
MIN_RUNTIME_VERSION="${MIN_RUNTIME_VERSION:-}"
RECOMMENDED_RUNTIME_VERSION="${RECOMMENDED_RUNTIME_VERSION:-}"
LINUX_AMD64_URL="${LINUX_AMD64_URL:-}"
LINUX_AMD64_URLS="${LINUX_AMD64_URLS:-}"
LINUX_AMD64_SHA256="${LINUX_AMD64_SHA256:-}"
LINUX_AMD64_FORMAT="${LINUX_AMD64_FORMAT:-tar.gz}"
LINUX_ARM64_URL="${LINUX_ARM64_URL:-}"
LINUX_ARM64_URLS="${LINUX_ARM64_URLS:-}"
LINUX_ARM64_SHA256="${LINUX_ARM64_SHA256:-}"
LINUX_ARM64_FORMAT="${LINUX_ARM64_FORMAT:-tar.gz}"
WINDOWS_AMD64_URL="${WINDOWS_AMD64_URL:-}"
WINDOWS_AMD64_URLS="${WINDOWS_AMD64_URLS:-}"
WINDOWS_AMD64_SHA256="${WINDOWS_AMD64_SHA256:-}"
WINDOWS_AMD64_FORMAT="${WINDOWS_AMD64_FORMAT:-zip}"
DARWIN_AMD64_URL="${DARWIN_AMD64_URL:-}"
DARWIN_AMD64_URLS="${DARWIN_AMD64_URLS:-}"
DARWIN_AMD64_SHA256="${DARWIN_AMD64_SHA256:-}"
DARWIN_AMD64_FORMAT="${DARWIN_AMD64_FORMAT:-tar.gz}"
DARWIN_ARM64_URL="${DARWIN_ARM64_URL:-}"
DARWIN_ARM64_URLS="${DARWIN_ARM64_URLS:-}"
DARWIN_ARM64_SHA256="${DARWIN_ARM64_SHA256:-}"
DARWIN_ARM64_FORMAT="${DARWIN_ARM64_FORMAT:-tar.gz}"

if [[ -z "$VERSION" ]]; then
  echo "VERSION is required" >&2
  exit 1
fi

if { [[ -z "$LINUX_AMD64_URL" && -z "$LINUX_AMD64_URLS" ]] || [[ -z "$LINUX_AMD64_SHA256" ]]; }; then
  echo "LINUX_AMD64_URL or LINUX_AMD64_URLS, and LINUX_AMD64_SHA256 are required" >&2
  exit 1
fi

if { [[ -z "$LINUX_ARM64_URL" && -z "$LINUX_ARM64_URLS" ]] || [[ -z "$LINUX_ARM64_SHA256" ]]; }; then
  echo "LINUX_ARM64_URL or LINUX_ARM64_URLS, and LINUX_ARM64_SHA256 are required" >&2
  exit 1
fi

if { [[ -z "$WINDOWS_AMD64_URL" && -z "$WINDOWS_AMD64_URLS" ]] || [[ -z "$WINDOWS_AMD64_SHA256" ]]; }; then
  echo "WINDOWS_AMD64_URL or WINDOWS_AMD64_URLS, and WINDOWS_AMD64_SHA256 are required" >&2
  exit 1
fi

if { [[ -z "$DARWIN_AMD64_URL" && -z "$DARWIN_AMD64_URLS" ]] || [[ -z "$DARWIN_AMD64_SHA256" ]]; }; then
  echo "DARWIN_AMD64_URL or DARWIN_AMD64_URLS, and DARWIN_AMD64_SHA256 are required" >&2
  exit 1
fi

if { [[ -z "$DARWIN_ARM64_URL" && -z "$DARWIN_ARM64_URLS" ]] || [[ -z "$DARWIN_ARM64_SHA256" ]]; }; then
  echo "DARWIN_ARM64_URL or DARWIN_ARM64_URLS, and DARWIN_ARM64_SHA256 are required" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

export OUTPUT_PATH VERSION CHANNEL BUILD_TIME RELEASE_NOTES MIN_RUNTIME_VERSION RECOMMENDED_RUNTIME_VERSION
export LINUX_AMD64_URL LINUX_AMD64_URLS LINUX_AMD64_SHA256 LINUX_AMD64_FORMAT
export LINUX_ARM64_URL LINUX_ARM64_URLS LINUX_ARM64_SHA256 LINUX_ARM64_FORMAT
export WINDOWS_AMD64_URL WINDOWS_AMD64_URLS WINDOWS_AMD64_SHA256 WINDOWS_AMD64_FORMAT
export DARWIN_AMD64_URL DARWIN_AMD64_URLS DARWIN_AMD64_SHA256 DARWIN_AMD64_FORMAT
export DARWIN_ARM64_URL DARWIN_ARM64_URLS DARWIN_ARM64_SHA256 DARWIN_ARM64_FORMAT

python3 - <<'PY'
import json
import os


def split_urls(raw: str) -> list[str]:
    result: list[str] = []
    for part in raw.split(","):
        candidate = part.strip()
        if candidate and candidate not in result:
            result.append(candidate)
    return result


def build_artifact(prefix: str) -> dict:
    primary = os.environ[f"{prefix}_URL"].strip()
    urls = split_urls(os.environ.get(f"{prefix}_URLS", ""))
    merged: list[str] = []
    for candidate in [primary, *urls]:
        if candidate and candidate not in merged:
            merged.append(candidate)
    artifact = {
        "url": merged[0],
        "sha256": os.environ[f"{prefix}_SHA256"].strip(),
        "format": os.environ[f"{prefix}_FORMAT"].strip(),
    }
    if len(merged) > 1:
        artifact["urls"] = merged
    return artifact


payload = {
    "channel": os.environ["CHANNEL"],
    "version": os.environ["VERSION"],
    "releaseNotes": os.environ["RELEASE_NOTES"],
    "publishedAt": os.environ["BUILD_TIME"],
    "minRuntimeVersion": os.environ["MIN_RUNTIME_VERSION"],
    "recommendedRuntimeVersion": os.environ["RECOMMENDED_RUNTIME_VERSION"],
    "artifacts": {
        "linux-amd64": build_artifact("LINUX_AMD64"),
        "linux-arm64": build_artifact("LINUX_ARM64"),
        "windows-amd64": build_artifact("WINDOWS_AMD64"),
        "darwin-amd64": build_artifact("DARWIN_AMD64"),
        "darwin-arm64": build_artifact("DARWIN_ARM64"),
    },
}

with open(os.environ["OUTPUT_PATH"], "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
