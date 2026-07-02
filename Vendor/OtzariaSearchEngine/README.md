# OtzariaSearchEngine native iOS wrapper

This folder builds the real Otzaria Rust/Tantivy engine for native Swift/iOS.

It does **not** use SQLite FTS. SQLite/seforim.db is only the source for indexing. Search runs against Tantivy.

## Build on Mac

```bash
cd Vendor/OtzariaSearchEngine
chmod +x build_xcframework.sh
./build_xcframework.sh
```

Output:

```text
OtzariaSearchEngine.xcframework
```

Add that XCFramework to the `Maktabah-iOS` target.

## Structure

```text
include/otzaria_search_engine.h        C ABI used by Swift
module.modulemap                       optional clang module map
ios_bridge/                            Rust staticlib wrapper
upstream/otzaria_search_engine/        cloned by build script
```

The wrapper depends on the upstream Otzaria Rust crate and calls `SearchEngine::search_exact`, `search_advanced`, `search_fuzzy`, `add_documents_batch`, `commit`, `clear`, and `optimize`.
