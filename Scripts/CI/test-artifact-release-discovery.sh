#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="build/hq-v32-prebuilt-native"
mkdir -p "$OUT"
xcrun swiftc -parse-as-library \
  Source/Otzaria/DataProfiles/OtzariaDataProfile.swift \
  Source/Otzaria/DataProfiles/OtzariaDataProfileRegistry.swift \
  Source/Otzaria/Bootstrap/OtzariaDatabaseDownloadModels.swift \
  Source/Otzaria/Search/OtzariaSearchMode.swift \
  Source/Otzaria/Search/OtzariaSearchModels.swift \
  Source/Otzaria/Search/OtzariaIndexFileLogger.swift \
  Source/Otzaria/Search/Distribution/OtzariaSearchArtifactManifest.swift \
  Source/Otzaria/Search/Distribution/OtzariaSearchArtifactPolicy.swift \
  Source/Otzaria/Search/Distribution/OtzariaSearchArtifactReleaseClient.swift \
  Tests/HQ/search/ArtifactReleaseDiscoveryTests.swift \
  -o "$OUT/release-discovery-tests" 2>&1 | tee "$OUT/release-discovery-compile.log"
"$OUT/release-discovery-tests" \
  docs/hq-integration/full-v32-native-20261119/otzaria-search-manifest.json \
  2>&1 | tee "$OUT/release-discovery-tests.log"
