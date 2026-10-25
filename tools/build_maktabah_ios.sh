#!/usr/bin/env bash
set -euo pipefail

# tools/build_maktabah_ios.sh
# Exact reproducible Xcode build script for Maktabah-iOS scheme on macOS host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Maktabah iOS Build Script ==="
echo "Repository root: $REPO_ROOT"

# Check for macOS host
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: tools/build_maktabah_ios.sh must be run on macOS with Xcode installed." >&2
    echo "Current platform: $(uname -s) (Status: IOS_BUILD_BLOCKED_NO_APPLE_HOST)" >&2
    exit 1
fi

# Check for xcodebuild
if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "ERROR: 'xcodebuild' was not found in PATH. Please install Xcode and Xcode Command Line Tools." >&2
    exit 1
fi

echo "Xcode Version:"
xcodebuild -version

SCHEME="Maktabah-iOS"
PROJECT="Maktabah.xcodeproj"
DESTINATION="generic/platform=iOS Simulator"
DERIVED_DATA="build/DerivedData"

echo "Building project: $PROJECT"
echo "Scheme:           $SCHEME"
echo "Destination:      $DESTINATION"
echo "DerivedData:      $DERIVED_DATA"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

echo "=== Build completed successfully! ==="
