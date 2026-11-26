# Actual full-v40 source oracle for search preview and Reader mode acceptance

`FullV40ObservationCatalog.swift` accepts an optional `previewTargets` array. With that field absent, the existing ten Reader/Inspector targets and `catalog.json` contract remain unchanged. With it present, the program writes **only** a separate `preview-targets.json` and complete `.source.utf8` files. The output is a source oracle, not a claim that search or UI executed.

The selected `bookID` / `focusLineIndex` must come from a retained real result from the original installed search provider. Do not invent a hit for the requested query. The native test must compare its actual selected hit tuple to the corresponding output before applying the preview/source assertions. Reader mode tests can use the same exact target in all three original modes.

The execution controller must independently admit the actual complete database hash, size, counts and ownership before invoking this program, just as the Reader v40 driver does. The Swift input's `databaseSHA256` is the controller's admitted identity, not a substitute for hashing the actual database.

## Input

Start with the existing catalog input:

- `databaseURI`: actual immutable, read-only full-v40 database URI.
- `databaseSHA256`: `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`.
- `v40Targets`: the exact `catalog_targets` object in `reader-full-v40-ui-observation.inputs.json`.

Add these fields, using real observed values:

```json
{
  "previewTargets": [
    {"bookID": "ACTUAL_RESULT_BOOK_ID_AS_INTEGER", "focusLineIndex": "ACTUAL_RESULT_LINE_INDEX_AS_INTEGER", "mode": "line"},
    {"bookID": "ACTUAL_RESULT_BOOK_ID_AS_INTEGER", "focusLineIndex": "ACTUAL_RESULT_LINE_INDEX_AS_INTEGER", "mode": "paragraph"},
    {"bookID": "ACTUAL_RESULT_BOOK_ID_AS_INTEGER", "focusLineIndex": "ACTUAL_RESULT_LINE_INDEX_AS_INTEGER", "mode": "chapter"}
  ],
  "sourceService": {
    "path": "ACTUAL_COMPILED_PATH/Source/Otzaria/Reading/OtzariaReadingUnitService.swift",
    "sha256": "ACTUAL_SHA256_FROM_RETAINED_CATALOG_COMPILE_INPUTS",
    "compileInputsPath": "ACTUAL_CATALOG_OUTPUT/compile-inputs.json"
  }
}
```

This example is intentionally non-runnable until actual result identities and current source paths/hashes are supplied. There may be 1–9 unique `(bookID, focusLineIndex, mode)` requests. Only the original `line`, `paragraph` and `chapter` modes are accepted.

The existing `prepare_catalog` compilation receipt has `command` and `source_sha256` fields. The oracle rehashes the actual service source file and requires both the same hash under `Source/Otzaria/Reading/OtzariaReadingUnitService.swift` and that exact file path in the retained compiler command. Preserve the binary/compile log and exact source closure with the output. A receipt copied from a different build is not sufficient.

## Output

Top-level `preview-targets.json` fields are:

| Field | Meaning |
| --- | --- |
| `schema` | `1` |
| `status` | `ORIGINAL_SOURCE_PREVIEW_CATALOG_ONLY_NOT_SEARCH_OR_UI` |
| `corpusProfile` | `full-v40` |
| `databaseSHA256` | Independently admitted full database identity |
| `sourceServiceSHA256` | Rehashed original service file, bound to retained compile inputs |
| `catalogCompileInputsSHA256` | Exact compile-input receipt digest |
| `targets` | One complete original reading unit per actual requested tuple/mode |
| `uiExecuted` / `searchProviderExecuted` | `0` / `false`; source generation never supplies those acceptance results |

Each target retains the existing complete-unit identity fields: book ID and actual canonical title, requested focus index, mode, unit ID, TOC ID, start/end source indices, row count, section/focus locators, UTF8 byte count, UTF16 length, full source SHA256 and source file, all-anchor identity hash, and exact focused-anchor range/hash. It additionally contains:

- `sourceUTF8`: the entire original `unit.plainText`, without truncation or normalization.
- `anchors`: every source row in order, each with actual `lineID`, `bookID`, `lineIndex`, nullable `heRef`, UTF16 `rangeLocation` / `rangeLength`, exact `text`, and `textSHA256`.

The oracle calls the unchanged production `OtzariaReadingUnitService.descriptor` and `readingUnit` with the requested mode, and rejects a fallback mode. It checks every original anchor against immutable SQL `id` / `lineIndex` / `heRef`, exact UTF16 boundaries, exact UTF8 source slices and the final complete-source boundary. SQLite/Zstd decoding comes from the actual original service and its existing compatibility code, not a rewritten decoder.

## Verification at handoff

Actual Apple Swift compilation of the whole unchanged service/SQLite/Zstd closure with this optional path passed (exit 0). Exact source SHA256 is `1ecd1336ef0f353d14bfdf857a71f3ee9c37d56fe3a47dd541ca86959fa2a86c`; native binary SHA256 is `34dce24d689df3c52875492df996b30762d9b8d231da395a80c1ce16925f1bb2`. The Mac retains `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/full-v40-preview-catalog`. `apple-preview-source-controls/RESULT.json` and `compile.log` preserve the command and result.

No selected search hit, full database generation, original preview UI, mode transition, focus, selection or performance acceptance is claimed by that compilation. The integration owner must generate this receipt from the real installed provider hit and the final qualified source before the corresponding native cases execute.
