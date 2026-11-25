#!/usr/bin/env bash
set -euo pipefail

# The shared owner's Mac already has its approved Xcode selected. Validate it;
# never change the machine-wide selection underneath another admitted build.
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "::error::The existing Apple arm64 runner is required." >&2
  exit 1
fi
version="$(xcodebuild -version)"
IFS= read -r first_line <<< "$version"
if [[ "$first_line" != "Xcode 27" && "$first_line" != "Xcode 27."* ]]; then
  echo "::error::The selected compiler must be Xcode 27; no global toolchain change was made." >&2
  printf '%s\n' "$version" >&2
  exit 1
fi
printf '%s\n' "$version"
xcodebuild -showsdks
