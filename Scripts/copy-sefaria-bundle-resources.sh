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

# Optional JS bundle copy if built
JSBUNDLE_SRC="${REPO_ROOT}/build/jsbundle/main.jsbundle"
if [ -f "${JSBUNDLE_SRC}" ]; then
  echo "==> Copying pre-built main.jsbundle to ${DEST_DIR}/..."
  cp "${JSBUNDLE_SRC}" "${DEST_DIR}/main.jsbundle"
  if [ -d "${REPO_ROOT}/build/jsbundle/assets" ]; then
    echo "==> Copying Metro assets to ${DEST_DIR}/..."
    cp -R "${REPO_ROOT}/build/jsbundle/assets" "${DEST_DIR}/"
  fi
else
  echo "NOTE: main.jsbundle not found at ${JSBUNDLE_SRC}."
  echo "      For Release builds, bundle must be generated via 'npx react-native bundle'."
  echo "      For Debug builds, metro server can serve virtual entrypoint."
fi

echo "==> Sefaria bundle resources staged successfully."
