# Separate full-v40 original Reader/Inspector observations

## State at this handoff

The original two full-v32 XCTest selectors remain available with their complete original runtime assertions. Two separately named full-v40 selectors now exercise those same original UI operations against independently pinned v40 data. No application `Source/` implementation or original source-observation hook is changed by this adapter.

This is **source and admission readiness**, not native UI or performance acceptance. Actual integrated UI execution remains the integration owner's next step. The source/test tree and execution-byte pins in the new v40 inputs are deliberately `UNFINALIZED` until that owner freezes the final integrated checkout and produces its qualified app/UI-test build. The existing v32 manifest must likewise be rebound by that owner before its unchanged two cases run on the new integrated source.

## Exact selectors and source identity

| Corpus | XCTest selector |
| --- | --- |
| Original v32 | `FaithfulProductionReleaseTests/testTwentyOriginalFullV32ReaderOpensAndForcedRelaunch` |
| Original v32 | `FaithfulProductionReleaseTests/testOriginalFullV32InspectorRelationshipScalesAndReturn` |
| Separate v40 | `FaithfulProductionReleaseTests/testTwentyOriginalFullV40ReaderOpensAndForcedRelaunch` |
| Separate v40 | `FaithfulProductionReleaseTests/testOriginalFullV40InspectorRelationshipScalesAndReturn` |

The v32 source remains release `409213893`, tag `v32-20261010190601`, 7,876 books / 7,080,797 lines, database SHA256 `2f4dcd72e8bdb1fc5c0516ae9705e57759c017ec2981b49c35115625c3d3f765`. Its fresh simulator creation, original app installer invocation, immutable source/count checks, and owned simulator shutdown/deletion remain the default path.

The v40 source is release `455390662`, tag `v40-20261123094345`, manifest asset `782942035`, `seforim-schema7.db.zst.manifest.json`. Its combined archive is 2,129,902,636 bytes with SHA256 `39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587`. Its complete database is 4,355,063,808 bytes, SHA256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`, with 8,259 books / 7,925,185 lines / 7,001,824 links.

The integration owner's fresh read-only source-identity receipt is `docs/hq-integration/wave2-20261127/v40-source-identity/RESULT.json`, SHA256 `e7b68681b47f881f13bd33b3af8ba457c591b2b5b2c18cd418ba073837b80f3b`. It rehashed the full actual Oracle database and independently queried the following v40 identities:

| Workload | v40 identity |
| --- | --- |
| Berakhot first/middle/last | Book 103, all 2,875 actual SQL rows |
| Tehillim first/middle/last | Book 28, all 2,678 actual SQL rows |
| Derashot HaRan first/middle/last | Book 3152, all 528 actual SQL rows; preserve the exact database title bytes |
| Retained measured chapter | Book 8042, unit `toc:1948815`, 52,332 rows, actual source indices 0–52,331, focus 26,166 |

The three book numbers happen to persist across the two corpora. Their v40 identity comes from that independent v40 query and full database hash; no v32 catalog or UI receipt is transferred. The retained chapter's prior measured 8,307,947 UTF16 source length is still an assertion for the **actual Swift catalog to revalidate**, not a result of the SQL identity recipe. This is not a new global-largest claim.

## Runtime admission and ownership

`reader-full-v40-ui-observation.py` accepts only an explicit simulator UUID plus the original successful `library-v40-focused-native.py` `RESULT.json`. That result must report `ORIGINAL_INTEGRATED_V40_NATIVE_PASS` and `SHUTDOWN_RETAINED_FOR_ADDITIONAL_ACCEPTANCE` for the same UUID and SDK-matched original iPad type. It requires the original native install report, exact multipart-manifest bytes, actual installed corpus, safe-cleanup receipt, and retained artifact index. All those receipts are hashed, checked against the original index, and checked again after observation.

The prior installer's checkout, app/SDK image closure and source receipt are kept under `original_installation` with an explicit historical scope. They are not treated as installation acceptance of the current observation build. The driver requires a qualified **current same-checkout** build containing the app and UI test bundle, installs that current app into the explicitly retained simulator, and compares the actual installed app/SDK images to the current qualified build. After XCTest it also compares the actual installed runner and nested test-bundle images to that build.

App data-container relocation after installing a new app/test build is allowed only within that same UUID's actual app data container, at the original relative database path. The original path, actual current path and reason are retained. The complete database hash/size, independent SQL counts and exact installation-manifest bytes must remain unchanged. The post-UI check resolves the current container again. The external simulator is shut down and retained for the integration owner; it is never deleted or replaced by this observation driver. No extra library download or data clone is performed.

The existing opt-in source/Inspector IPC field names retain `FULL_V32` / `full-v32`. These are a wire format, not evidence of installed corpus identity. Separate selected test names, catalog database hash, admitted installation, top-level `corpus_profile`, output directory, trace/XCResult names and attachment labels identify the v40 run. The app's original UI and observation producers stay unchanged.

## Original assertions and measurement limits

The Reader body still performs ten actual target identities in process-cold and warm modes (20 opens), observes distinct process IDs, compares exact bounded source UTF8 and UTF16 anchors against the independent full-unit catalog, exercises the original overview action, and checks ten forced relaunches for the same actual document/group and original source/pixel anchor.

The Inspector body still explores nine complete original chapters, retains actual empty and oversized outcomes, independently checks visible source/relationship metadata against immutable SQL and original cache receipts, expands/collapses a real source row, scrolls the original panel, and preserves the original Reader identity/source/pixel anchor on return. Natural workloads of at least 100 / 500 / 2,000 are recorded honestly; they do not satisfy a missing **exact** workload of those sizes by truncation.

The original trace and app-PID CPU/RSS measurement host remains in use. Exact first pixel, continuous longest MainActor slice, frame/hitch coverage, SQL wait, continuous peak RSS/physical footprint, exact Inspector sizes, every Inspector row body, physical iPad, selection/annotations and other regression cases are not inferred from these observations. The existing result explicitly retains missing or unqualified metrics. Final status remains `ORIGINAL_UI_OBSERVATIONS_COMPLETE_METRICS_REVIEW_REQUIRED`, never full performance acceptance merely because the two UI cases passed.

## Verification retained here

`admission-controls.json` records 33 passing source/admission controls and zero native UI cases. It compares the **entire** original v32 Reader/Inspector runtime bodies against base `29a731e273f9a757c743c49e182fece0e8047d46` after only explicit profile/artifact substitutions, not just a count of assertions. Original v32 installer admission, actual fresh-install statements, old catalog bytes and shutdown/delete AST are also compared. Negative controls reject wrong corpus/hash/counts, v32 selection, unfinalized targets, incorrect native report identity and another simulator/path escape. Synthetic native-report fixtures are explicitly controls, not native evidence.

The first Oracle control run retained `admission-controls-sparse-catalog-missing.json`: 32 pass / 1 fail because the existing v32 catalog was not materialized in the sparse worktree. Materializing that unchanged tracked directory resolved it; the complete rerun passed 33 / 33. No assertion was weakened.

`apple-source-controls/RESULT.json` retains actual Scaleway Mac commands, paths, hashes, toolchain and exits at 2026-11-26 23:29 UTC:

- Xcode 27.0 (`27A266a`), Apple Swift 6.4 (`swiftlang-6.4.0.34.1`), iPhoneSimulator 27.0 SDK.
- Full changed Faithful UI source syntax parse: exit 0. This is not an XCTest typecheck or UI execution.
- Whole original SQLite/Zstd/ReadingUnitService plus the new v40 independent catalog: actual native compile/link exit 0. Linkage includes the actual system SQLite and Homebrew Zstd; the compile did not open the full database.
- Catalog binary SHA256 `9a5833a53e1c25187b8bb3c4efad25263f5faa67b7fc5d9a7e6d2335ac9602e3`.
- Candidate Faithful source SHA256 `ce0f81985627c57f959d9554bb56768316fe2bebe8e5977d84a4901755beab8b` before integration of disjoint worker changes.
- Catalog source SHA256 `2478e8c6d04723c2764f0fb3acc6b50e9e92e3dbb62d5627162ae2275f921e9b`.

Mac retained stage: `/Users/m1/builds/otzaria-wave2-reader-controls-20261127/full-v40-observation-admission`. The source-hash inventory binds this component compile to its exact files. It does not claim to be a build of the final combined app.

## Integration-owner invocation

After retaining the actual installation and freezing each profile's source trees/input hashes against the final combined qualified build:

```sh
EXPECTED_CHECKOUT_SHA=<actual-current-qualified-checkout> \
FAITHFUL_RUNTIME27_IDENTIFIER=<actual-qualified-runtime-id> \
python3 Scripts/CI/reader-full-v40-ui-observation.py execute \
  --owned-simulator <original-retained-installation-uuid> \
  --installation-result <original-installation-output>/RESULT.json
```

The existing v32 driver remains a separate fresh-install run:

```sh
EXPECTED_CHECKOUT_SHA=<actual-current-qualified-checkout> \
FAITHFUL_RUNTIME27_IDENTIFIER=<actual-qualified-runtime-id> \
python3 Scripts/CI/reader-full-v32-ui-observation.py execute
```

Coordinate storage and simulator ownership before these invocations. Re-running the v40 execution cannot overwrite retained observation evidence; a preceding source-only admission report is the sole allowed pre-existing output.
