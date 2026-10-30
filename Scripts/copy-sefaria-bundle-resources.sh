#!/usr/bin/env bash
#
# Scripts/copy-sefaria-bundle-resources.sh
# Copies original Sefaria-Mobile JSON sources and pre-built Metro JS bundle
# into the target iOS application bundle.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEST_DIR="${1:-${TARGET_BUILD_DIR:-}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}}"

if [ -z "${DEST_DIR}" ]; then
  echo "Usage: $0 <path-to-built-app-or-resources-dir>"
  echo "Or run within an Xcode Run Script build phase."
  exit 1
fi

echo "==> Preparing Sefaria bundle resources in: ${DEST_DIR}"

SOURCES_SRC="${REPO_ROOT}/Vendor/SefariaMobile/Upstream/ios/sources"
SOURCES_DEST="${DEST_DIR}/sources"

if [ -d "${SOURCES_SRC}" ]; then
  echo "==> Copying Sefaria JSON sources to ${SOURCES_DEST}..."
  mkdir -p "${SOURCES_DEST}"
  cp "${SOURCES_SRC}/"*.json "${SOURCES_DEST}/"
  echo "==> Copied $(ls -1 "${SOURCES_DEST}"/*.json | wc -l | tr -d ' ') JSON sources."
else
  echo "ERROR: Sefaria upstream sources not found at: ${SOURCES_SRC}"
  echo "Ensure 'git submodule update --init --recursive' has been run."
  exit 1
fi

# Sefaria main.jsbundle copy and verification
JSBUNDLE_SRC="${REPO_ROOT}/build/jsbundle/main.jsbundle"
REQUIRE_BUNDLE="${FAIL_ON_MISSING_BUNDLE:-1}"

if [ -f "${JSBUNDLE_SRC}" ] && [ -s "${JSBUNDLE_SRC}" ]; then
  BUNDLE_SIZE=$(wc -c < "${JSBUNDLE_SRC}" | tr -d ' ')
  if [ "${BUNDLE_SIZE}" -lt 1000 ]; then
    echo "ERROR: main.jsbundle at ${JSBUNDLE_SRC} is suspiciously small (${BUNDLE_SIZE} bytes)."
    exit 1
  fi
  echo "==> Copying pre-built main.jsbundle (${BUNDLE_SIZE} bytes) to ${DEST_DIR}/..."
  cp "${JSBUNDLE_SRC}" "${DEST_DIR}/main.jsbundle"
  if [ -d "${REPO_ROOT}/build/jsbundle/assets" ]; then
    echo "==> Copying Metro assets to ${DEST_DIR}/..."
    cp -R "${REPO_ROOT}/build/jsbundle/assets" "${DEST_DIR}/"
  fi
else
  if [ "${REQUIRE_BUNDLE}" = "1" ] || [ "${CONFIGURATION:-Debug}" = "Release" ]; then
    echo "ERROR: main.jsbundle is required for Sefaria-Embedded but missing or empty at: ${JSBUNDLE_SRC}"
    echo "      Run 'npx react-native bundle' from Vendor/SefariaMobile/Upstream to build the production bundle."
    exit 1
  else
    echo "NOTE: main.jsbundle not found at ${JSBUNDLE_SRC}."
    echo "      Running in dev mode without bundled JS."
  fi
fi

echo "==> Sefaria bundle resources staged successfully."
