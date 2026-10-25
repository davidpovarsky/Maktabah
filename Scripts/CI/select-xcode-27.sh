#!/usr/bin/env bash
set -euo pipefail

XCODE_PATH="$(find /Applications -maxdepth 1 -type d -name 'Xcode_27*.app' ! -name '*beta*' | sort -V | tail -n 1 || true)"
if [ -z "$XCODE_PATH" ]; then
  XCODE_PATH="$(find /Applications -maxdepth 1 -type d -name 'Xcode_27*.app' | sort -V | tail -n 1 || true)"
fi
if [ -n "$XCODE_PATH" ]; then
  echo "Selected Xcode: $XCODE_PATH"
  sudo xcode-select -s "$XCODE_PATH/Contents/Developer"
fi
xcodebuild -version
xcodebuild -showsdks
