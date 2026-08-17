#!/usr/bin/env bash
set -euo pipefail

XCODE_PATH="$(find /Applications -maxdepth 1 -type d -name 'Xcode_26*.app' | sort -V | tail -n 1 || true)"
if [ -z "$XCODE_PATH" ]; then
  echo "::error::Xcode 26 was not found on this runner"
  exit 1
fi
sudo xcode-select -s "$XCODE_PATH/Contents/Developer"
xcodebuild -version
xcodebuild -showsdks
