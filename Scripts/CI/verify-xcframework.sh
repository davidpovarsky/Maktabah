#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 /path/to/framework.xcframework expected-header.h" >&2
  exit 64
fi

FRAMEWORK="$1"
HEADER="$2"
test -d "$FRAMEWORK"
test -f "$FRAMEWORK/Info.plist"
plutil -lint "$FRAMEWORK/Info.plist" >/dev/null

LIBRARIES="$(find "$FRAMEWORK" -type f -name '*.a' | sort)"
test "$(printf '%s\n' "$LIBRARIES" | sed '/^$/d' | wc -l | tr -d ' ')" -eq 2
simulator_found=0
device_found=0
for library in $LIBRARIES; do
  info="$(lipo -info "$library")"
  echo "$info"
  grep -q 'arm64' <<<"$info"
  if grep -q 'x86_64' <<<"$info"; then
    simulator_found=1
  else
    device_found=1
  fi
done
test "$simulator_found" -eq 1
test "$device_found" -eq 1
test "$(find "$FRAMEWORK" -type f -path '*/Headers/*' -name "$HEADER" | wc -l | tr -d ' ')" -eq 2
