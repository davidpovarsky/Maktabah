# Package contents

## Runtime engine

- `Rust/src/engine.rs` — read-only search runtime.
- `Rust/src/query_builder.rs` — Zayit-compatible parsing and lexical alternatives.
- `Rust/src/magic_dictionary_index.rs` — read-only `lexical.db` access.
- `Rust/src/snippet_builder.rs` — custom snippets/highlights.
- `Rust/src/ffi.rs` — isolated C ABI.

## Prebuilt index pipeline

- `Rust/src/bin/zayit_index_builder.rs` — real builder from `seforim.db`.
- `Scripts/build-prebuilt-index.ps1` — Windows entry point.
- `Scripts/build-prebuilt-index.sh` — macOS/Linux/GitHub Actions entry point.
- `CI/build-prebuilt-index.workflow.example.yml` — workflow template.

## iOS integration

- `Swift/ZayitSearchFolderAccess.swift` — persistent security-scoped folder access.
- `Swift/ZayitSearchDataValidator.swift` — validates all required files and metadata.
- `Swift/ZayitSearchEngineBridge.swift` — C ABI bridge.
- `Swift/ZayitSearchRepository.swift` — isolated actor.
- `Swift/ZayitSearchViewModel.swift` and `ZayitSearchView.swift` — independent tab implementation.

## Build/integration

- `Scripts/build-ios-xcframework.sh` — device and simulator XCFramework.
- `CODEX-INTEGRATION-INSTRUCTIONS.md` — exact minimal-touch integration plan.
- `Upstream/UPSTREAM_MANIFEST.json` — source-to-port tracking.
