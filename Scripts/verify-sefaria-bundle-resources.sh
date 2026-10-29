#!/usr/bin/env bash
#
# Scripts/verify-sefaria-bundle-resources.sh
# Verifies that all 7 required Sefaria upstream JSON sources and main.jsbundle
# exist inside the target application bundle, are non-empty, and contain valid JSON.
# Generates a JSON manifest with SHA256 checksums and file sizes.
#
set -euo pipefail

APP_BUNDLE="${1:-}"
REQUIRE_BUNDLE="${2:-false}"

if [ -z "${APP_BUNDLE}" ]; then
  echo "Usage: $0 <path-to-Maktabah-iOS.app> [require-main-jsbundle: true/false]"
  exit 1
fi

if [ ! -d "${APP_BUNDLE}" ]; then
  echo "ERROR: Target application bundle does not exist: ${APP_BUNDLE}"
  exit 1
fi

echo "============================================================"
echo "Verifying Sefaria Bundle Resources in: ${APP_BUNDLE}"
echo "============================================================"

SOURCES_DIR="${APP_BUNDLE}/sources"
if [ ! -d "${SOURCES_DIR}" ]; then
  echo "FAIL: Missing '${SOURCES_DIR}' directory inside app bundle."
  exit 1
fi

REQUIRED_JSON_FILES=(
  "calendar.json"
  "hebrew_categories.json"
  "packages.json"
  "people.json"
  "search_toc.json"
  "toc.json"
  "topic_toc.json"
)

MANIFEST_TMP="$(mktemp 2>/dev/null || mktemp -t 'sefaria-manifest')"
echo "{" > "${MANIFEST_TMP}"
echo '  "verifiedAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "${MANIFEST_TMP}"
echo '  "appBundle": "'"${APP_BUNDLE}"'",' >> "${MANIFEST_TMP}"
echo '  "resources": {' >> "${MANIFEST_TMP}"

FIRST=true
FAILED=0

for filename in "${REQUIRED_JSON_FILES[@]}"; do
  filepath="${SOURCES_DIR}/${filename}"
  if [ ! -f "${filepath}" ]; then
    echo "FAIL: Missing required file '${filename}' at ${filepath}"
    FAILED=$((FAILED + 1))
    continue
  fi

  filesize=$(wc -c < "${filepath}" | tr -d ' ')
  if [ "${filesize}" -le 10 ]; then
    echo "FAIL: File '${filename}' is empty or too small (${filesize} bytes)"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Validate JSON syntax
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -m json.tool "${filepath}" >/dev/null 2>&1; then
      echo "FAIL: File '${filename}' contains invalid JSON syntax!"
      FAILED=$((FAILED + 1))
      continue
    fi
  fi

  sha256=$(shasum -a 256 "${filepath}" 2>/dev/null | awk '{print $1}' || sha256sum "${filepath}" 2>/dev/null | awk '{print $1}' || echo "checksum-unavailable")
  echo "OK: ${filename} (${filesize} bytes, sha256: ${sha256:0:16}...)"

  if [ "${FIRST}" = true ]; then
    FIRST=false
  else
    echo "," >> "${MANIFEST_TMP}"
  fi
  echo '    "sources/'"${filename}"'": { "size": '"${filesize}"', "sha256": "'"${sha256}"'" }' >> "${MANIFEST_TMP}"
done

# Check main.jsbundle
JSBUNDLE="${APP_BUNDLE}/main.jsbundle"
if [ -f "${JSBUNDLE}" ]; then
  js_size=$(wc -c < "${JSBUNDLE}" | tr -d ' ')
  js_sha=$(shasum -a 256 "${JSBUNDLE}" 2>/dev/null | awk '{print $1}' || sha256sum "${JSBUNDLE}" 2>/dev/null | awk '{print $1}' || echo "checksum-unavailable")
  echo "OK: main.jsbundle (${js_size} bytes, sha256: ${js_sha:0:16}...)"
  echo "," >> "${MANIFEST_TMP}"
  echo '    "main.jsbundle": { "size": '"${js_size}"', "sha256": "'"${js_sha}"'" }' >> "${MANIFEST_TMP}"
else
  if [ "${REQUIRE_BUNDLE}" = "true" ]; then
    echo "FAIL: main.jsbundle is required for this build but missing in ${APP_BUNDLE}"
    FAILED=$((FAILED + 1))
  else
    echo "WARN: main.jsbundle not found in ${APP_BUNDLE} (permissible in Debug dev mode if Metro is running)"
  fi
fi

echo "  }," >> "${MANIFEST_TMP}"
echo '  "failureCount": '"${FAILED}" >> "${MANIFEST_TMP}"
echo "}" >> "${MANIFEST_TMP}"

MANIFEST_OUT="${APP_BUNDLE}/sefaria-resource-manifest.json"
cp "${MANIFEST_TMP}" "${MANIFEST_OUT}"
rm -f "${MANIFEST_TMP}"

echo "Manifest saved to: ${MANIFEST_OUT}"

if [ "${FAILED}" -gt 0 ]; then
  echo "FAILED: ${FAILED} resource verification checks failed!"
  exit 1
fi

echo "SUCCESS: All required Sefaria resources verified inside app bundle."
exit 0
