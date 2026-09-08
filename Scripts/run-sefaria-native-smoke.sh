#!/usr/bin/env bash
set -euo pipefail

output="${TMPDIR:-/tmp}/sefaria-native-smoke"
xcrun swiftc \
  Source/LibraryBackend/LibraryBackendModels.swift \
  Source/Sefaria/Domain/SefariaModels.swift \
  Source/Sefaria/Network/SefariaNetworkConfiguration.swift \
  Source/Sefaria/Network/SefariaHTTPClient.swift \
  Source/Sefaria/Network/SefariaDTOs.swift \
  Source/Sefaria/Offline/SefariaExportModels.swift \
  Vendor/SefariaNativeSmoke/SefariaNativeSmoke.swift \
  -o "$output"
"$output" --run-network-smoke
