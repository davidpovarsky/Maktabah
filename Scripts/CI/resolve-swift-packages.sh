#!/usr/bin/env bash
# Retry transient downloads while retaining SwiftPM's exact pins and checksums.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
mkdir -p build/logs
LOGS="$(mktemp -d "$ROOT/build/logs/package-resolution.XXXXXX")"
if [ "$(uname -s)" = Darwin ]; then
  python3 Scripts/CI/prepare-swift-package-pins.py "$@"
fi
for attempt in 1 2 3; do
  if xcodebuild -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile "$@" > "$LOGS/attempt-$attempt.log" 2>&1; then
    cat "$LOGS/attempt-$attempt.log"
    if [ "$(uname -s)" = Darwin ]; then
      python3 Scripts/CI/prepare-swift-package-pins.py --verify "$@"
    fi
    exit 0
  else
    result=$?
  fi
  cat "$LOGS/attempt-$attempt.log"
  if [ "$attempt" = 3 ] || ! grep -Eiq 'badResponseStatusCode\((429|500|502|503|504)\)|timed out|timeout|Could not resolve host|Could not connect to server|network connection was lost' "$LOGS/attempt-$attempt.log"; then
    exit "$result"
  fi
  echo "Transient package download failure; retrying the same pinned graph ($attempt/3)."
  sleep "$((attempt * 5))"
done
