# Original full-v40 Reader regression gates

Status: **source checks complete; native application execution pending**. This checkpoint adds two cases to the already registered `Build8401SevenDefectsAcceptanceTests.swift` and an optional source-oracle field. It does not report an application UI pass, a full-corpus performance result, or acceptance of another build.

## Exact selectors

| Selector, prefixed by `Maktabah-iOSUITests/` | Required original behavior |
| --- | --- |
| `FullV40ReaderModeAcceptanceTests/testOriginalUIKitSelectionPersistsExactUTF16AndRestoresAcrossThreeBackends` | Original full-v40 Search hit, native Select All and highlight action, exact UIKit/display/source/persisted UTF16 ranges, actual rendered highlight color, three-backend Reader roundtrip, retained original document and annotation |
| `FullV40ReaderModeAcceptanceTests/testOriginalParagraphAndChapterPullCancellationAndCanonicalTOCStaySynchronized` | Original paragraph and chapter preference controls, actual positive sub-threshold pull cancellation, threshold-crossing previous/next navigation to independently derived adjacent units, actual selected TOC node synchronized at each unit |

The original `testOriginalSearchOpensLineParagraphAndChapterAtExactSourceFocus` and every preceding legacy case remain byte-identical after removing the explicit additive schema and appended block. `source-preservation.json` records that comparison. The original full-v32 files and selectors are untouched.

## Source checks actually run

Actual Scaleway directory: `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/reader-native-typecheck-20261127T023105Z`.

| Check | Actual result |
| --- | --- |
| Parse whole registered test file | Exit 0 |
| Typecheck whole registered test file with actual XCTest/iPhoneSimulator27.0, Swift 6 strict concurrency | Exit 0 |
| Compile whole independent v40 source catalog with original Reader/SQLite/ZSTD sources and actual macOS27.0 SDK | Exit 0 |
| Application target build, catalog execution on v40, native UI run | **Not executed by these checks** |

Xcode was 27.0 (27A266a), Apple Swift 6.4. The test check uses the unchanged original `MaktabahUITestBase` and the exact original `OriginalSearchContextUI`/support declarations from search commit `780ede48ca90c65bcda1d8349b059dd2dd095ac3`; no UI helper body is stubbed. The twelve original catalog dependencies were SHA-checked against reader source `9e38d9ac087a6a301299045b8d3114e2c801d81f` and again against the retained Mac copies before compiling. Existing telemetry-only catalog boundaries are preserved.

The compiler emitted 153 actor-isolation warnings: 56 in the unchanged test base and 97 in the unchanged legacy portion of Build8401. No new gate or catalog diagnostic is hidden. Raw commands, stdout/stderr and hashes are retained under `apple-source-controls`. Raw compiler output and exact original helper fragments are retained without trimming source whitespace. Their whitespace is not a product-source gate.

## Evidence boundaries

- The optional DEBUG selection observer was separately delivered in `9e38d9ac087a6a301299045b8d3114e2c801d81f`. Its twelve real UIKit component controls do not substitute for these native cases.
- A fresh observation binds request UUID, actual process, original UITextView object, original diagnostics locator/render generation and the committed real workspace document. Bounded source samples remain bounded source samples; they do not prove the complete rendered body or first-pixel latency.
- The annotation assertion reads the actual existing `Annotations.sqlite` read-only, compares the genuine UI-created row and its active UTF16 columns with the original mapping, and requires actual renderer ranges and RGB color. It never inserts fixture rows or replaces user storage.
- Settings backend selection is performed through the original Settings picker. The remote and embedded canonical Genesis Readers must be visited, the same remote document must restore, and the original production document plus its highlight must survive the complete roundtrip. The remote source assertion is explicitly a bounded original sample, not an independent full Sefaria body oracle.
- Gesture samples come from the existing read-only probe while XCTest performs a held real drag. A no-op cannot satisfy positive overscroll; committed navigation must cross the original 80-point threshold and reach the exact independently derived adjacent unit. Cancellation in this checkpoint means a positive pull released below that threshold. **Above-threshold retreat in one continuous touch remains a separate unproved gate.** Two separate drags are not credited as that behavior.
- TOC entry identities/titles/anchors come from immutable schema-7 SQL. Original UI row IDs are read from the application's genuine forward and reverse `LegacyIdentityRegistry` preferences. A SQL `tocEntry.id` is never presented as a fabricated UI surrogate.
- The integration owner must run the exact selectors on the same qualified current app/test source, retained owned Simulator and complete production installation, export genuine xcresult attachments, require zero skips, and retain installation/source identity before and after. No source check in this directory supplies that acceptance.
