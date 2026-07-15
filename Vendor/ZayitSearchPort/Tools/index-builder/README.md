# Prebuilt Zayit-compatible index builder

This package now includes a real command-line index builder:

```text
Rust/src/bin/zayit_index_builder.rs
```

It reads `seforim.db` in read-only mode and writes a separate Tantivy index directory suitable for the iPad runtime. It does not require `lexical.db` during index construction; `lexical.db` is opened read-only at search time for query expansion.

## Windows

```powershell
Set-Location "C:\path\to\Maktabah\Vendor\ZayitSearchPort"
.\Scripts\build-prebuilt-index.ps1 `
  -SeforimDb "C:\Users\DAVID\Downloads\seforim.db" `
  -OutputDirectory "C:\Users\DAVID\Downloads\ZayitSearchData\zayit-search-index"
```

## macOS / Linux / GitHub Actions

```bash
bash Scripts/build-prebuilt-index.sh \
  /path/to/seforim.db \
  /path/to/ZayitSearchData/zayit-search-index
```

## Final folder imported on iPad

```text
ZayitSearchData/
├── lexical.db
├── zayit-search-index/
│   ├── meta.json
│   ├── *.store / *.term / other Tantivy segment files
│   └── zayit-index-metadata.json
└── seforim.db   # optional when Maktabah already has access to the same DB
```

The index must be generated from the exact `seforim.db` used by the app. Rebuild it when the source DB changes.
