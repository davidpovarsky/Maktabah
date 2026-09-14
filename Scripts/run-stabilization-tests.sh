#!/usr/bin/env bash
set -euo pipefail

output="${TMPDIR:-/tmp}/stabilization-tests"
swiftc \
  Source/LibraryBackend/LibraryBackendModels.swift \
  Source/LibraryBackend/LibraryBackendProtocols.swift \
  Source/Sefaria/Domain/SefariaModels.swift \
  Source/Sefaria/Network/SefariaDTOs.swift \
  Vendor/StabilizationTests/StabilizationTests.swift \
  -o "$output"
"$output"
