# Maktabah Zayit Search Port

Version 0.2.0

This package adds a completely separate, local Zayit-compatible search engine for Maktabah. It does not modify or reuse the existing Otzaria/Tantivy search pipeline.

## Phase 1 architecture

- The iPad never builds an index.
- A prebuilt index is generated outside the app from `seforim.db`.
- The user selects a folder in Files containing `lexical.db` and `zayit-search-index/`.
- Maktabah may reuse its already-selected `seforim.db`; otherwise the same folder may contain it.
- No large database or index is included in Git or the IPA.

## This package now includes

- A real Rust command-line index builder: `zayit-index-builder`.
- A read-only Rust runtime engine and C ABI for iOS.
- Hebrew normalization, quoted-phrase parsing, lexical expansion, fuzzy/4-gram branches, filters, base-book boosting, snippets and highlighting.
- Swift folder selection with persistent security-scoped access.
- Swift repository, bridge, view model and independent search view.
- XCFramework build script.
- Windows/macOS/Linux scripts for building the prebuilt index.
- A GitHub Actions workflow example.
- Complete Codex integration instructions that keep changes to existing Maktabah files minimal.

## Build the prebuilt index first

Windows:

```powershell
.\Scripts\build-prebuilt-index.ps1 `
  -SeforimDb "C:\Users\DAVID\Downloads\seforim.db" `
  -OutputDirectory "C:\Users\DAVID\Downloads\ZayitSearchData\zayit-search-index"
```

Then place `lexical.db` next to the generated directory:

```text
ZayitSearchData/
├── lexical.db
├── zayit-search-index/
└── seforim.db   # optional if Maktabah reuses its existing selected DB
```

## Repository location

Extract the contents to:

```text
Vendor/ZayitSearchPort/
```

Then give Codex the file:

```text
Vendor/ZayitSearchPort/CODEX-INTEGRATION-INSTRUCTIONS.md
```
