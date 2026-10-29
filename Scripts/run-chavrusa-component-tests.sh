#!/usr/bin/env bash
#
# Scripts/run-chavrusa-component-tests.sh
# Compiles and runs all 30 suites of ChavrusaText portable component,
# backend isolation, and Sefaria-Mobile embedded contracts.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OUT_BIN="${1:-${RUNNER_TEMP:-/tmp}/chavrusa_component_tests}"

echo "=== Compiling ChavrusaText Portable Component & Sefaria-Embedded Tests ==="

swiftc -parse-as-library \
  "${REPO_ROOT}/Source/ChavrusaText/ReaderRendering/ReaderPullNavigationStateMachine.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/ReaderRendering/ReaderSelectionRangeMapper.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Annotations/BackendAnnotationBridge.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/ReaderSessionRestoreCoordinator.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/SerializedSessionWriter.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/BackendNavigationAdapter.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/BackendSessionIntegrityRepair.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/TargetBackendBookResolver.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Testing/ReaderRenderedHighlightInspector.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Localization/ChavrusaTextLocalizationResolver.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Localization/TalmudHebrewAddressFormatter.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/ReaderDestinationResolver.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/ReaderBackendPagingCoordinator.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Search/ReaderSearchContextCoordinator.swift" \
  "${REPO_ROOT}/Source/ChavrusaText/Navigation/TOCReadingLocationTracker.swift" \
  "${REPO_ROOT}/Source/Sefaria/Domain/SefariaModels.swift" \
  "${REPO_ROOT}/Source/Sefaria/Offline/SefariaExportModels.swift" \
  "${REPO_ROOT}/Source/Sefaria/Offline/SefariaOfflinePaths.swift" \
  "${REPO_ROOT}/Source/Otzaria/Search/OtzariaSearchMode.swift" \
  "${REPO_ROOT}/Source/Otzaria/Search/OtzariaSearchModels.swift" \
  "${REPO_ROOT}/Source/LibraryBackend/LibraryBackendProtocols.swift" \
  "${REPO_ROOT}/Source/LibraryBackend/LibraryBackendModels.swift" \
  "${REPO_ROOT}/Source/LibraryBackend/LibraryPresentationPolicy+Display.swift" \
  "${REPO_ROOT}/Source/LibraryBackend/BackendCoordinator.swift" \
  "${REPO_ROOT}/Source/LibraryBackend/LegacyIdentityRegistry.swift" \
  "${REPO_ROOT}/Source/SefariaEmbedded/Bridge/SefariaRPCModels.swift" \
  "${REPO_ROOT}/Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift" \
  "${REPO_ROOT}/Source/SefariaEmbedded/Runtime/SefariaExpoLifecycleAdapter.swift" \
  "${REPO_ROOT}/Source/SefariaEmbedded/Runtime/SefariaRuntimeManager.swift" \
  "${REPO_ROOT}/tools/test_chavrusa_text_components.swift" \
  -o "${OUT_BIN}"

echo "=== Compilation Succeeded. Running Test Suite ==="
if [[ "${OUT_BIN}" != /* && "${OUT_BIN}" != .* && "${OUT_BIN}" != [a-zA-Z]:* ]]; then
  "./${OUT_BIN}"
else
  "${OUT_BIN}"
fi
