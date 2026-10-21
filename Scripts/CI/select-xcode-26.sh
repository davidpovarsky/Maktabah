#!/usr/bin/env bash
set -euo pipefail

XCODE_PATH="$(find /Applications -maxdepth 1 -type d \( -name 'Xcode_27*.app' -o -name 'Xcode_26*.app' -o -name 'Xcode*.app' \) | sort -V | tail -n 1 || true)"
if [ -z "$XCODE_PATH" ]; then
  echo "::error::No Xcode installation was found on this runner"
  exit 1
fi
echo "Selected Xcode: $XCODE_PATH"
sudo xcode-select -s "$XCODE_PATH/Contents/Developer"
xcodebuild -version
xcodebuild -showsdks
