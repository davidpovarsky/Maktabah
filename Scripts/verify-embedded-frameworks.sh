#!/bin/bash

set -euo pipefail

APP_PATH="${1:-}"

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "usage: $0 /path/to/Application.app" >&2
  exit 64
fi

if ! command -v otool >/dev/null 2>&1; then
  echo "error: otool is required to inspect Mach-O dependencies." >&2
  exit 69
fi

if [[ -f "${APP_PATH}/Info.plist" ]]; then
  INFO_PLIST="${APP_PATH}/Info.plist"
  FRAMEWORKS_DIR="${APP_PATH}/Frameworks"
  EXECUTABLE_DIR="${APP_PATH}"
elif [[ -f "${APP_PATH}/Contents/Info.plist" ]]; then
  INFO_PLIST="${APP_PATH}/Contents/Info.plist"
  FRAMEWORKS_DIR="${APP_PATH}/Contents/Frameworks"
  EXECUTABLE_DIR="${APP_PATH}/Contents/MacOS"
else
  echo "error: no application Info.plist was found in ${APP_PATH}." >&2
  exit 65
fi

APP_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${INFO_PLIST}" 2>/dev/null || true)"
if [[ -z "${APP_EXECUTABLE}" || ! -f "${EXECUTABLE_DIR}/${APP_EXECUTABLE}" ]]; then
  echo "error: the main executable declared by ${INFO_PLIST} was not found." >&2
  exit 66
fi

binaries=("${EXECUTABLE_DIR}/${APP_EXECUTABLE}")

if [[ -d "${FRAMEWORKS_DIR}" ]]; then
  while IFS= read -r -d '' framework; do
    framework_plist="${framework}/Info.plist"
    framework_executable=""
    if [[ -f "${framework_plist}" ]]; then
      framework_executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${framework_plist}" 2>/dev/null || true)"
    fi
    if [[ -z "${framework_executable}" ]]; then
      framework_executable="$(basename "${framework}" .framework)"
    fi

    framework_binary="${framework}/${framework_executable}"
    if [[ ! -f "${framework_binary}" ]]; then
      echo "error: framework executable is missing: ${framework_binary}" >&2
      exit 67
    fi
    binaries+=("${framework_binary}")
  done < <(find "${FRAMEWORKS_DIR}" -type d -name '*.framework' -print0)
fi

missing_count=0
for binary in "${binaries[@]}"; do
  echo "Inspecting ${binary}"
  otool_output="$(otool -L "${binary}")"
  printf '%s\n' "${otool_output}"
  while IFS= read -r dependency; do
    [[ -z "${dependency}" ]] && continue
    case "${dependency}" in
      @rpath/*.framework/*)
        relative_path="${dependency#@rpath/}"
        embedded_path="${FRAMEWORKS_DIR}/${relative_path}"
        if [[ ! -f "${embedded_path}" ]]; then
          echo "error: ${binary} requires missing dependency ${dependency}" >&2
          echo "error: expected embedded binary at ${embedded_path}" >&2
          missing_count=$((missing_count + 1))
        fi
        ;;
    esac
  done < <(printf '%s\n' "${otool_output}" | awk 'NR > 1 { print $1 }')
done

if [[ "${missing_count}" -ne 0 ]]; then
  echo "error: found ${missing_count} missing embedded framework dependency/dependencies." >&2
  exit 1
fi

echo "Verified ${#binaries[@]} Mach-O binary/binaries: every @rpath framework dependency is embedded."
