# Actual intermediate Apple SDK result — run 44765034019

The original SDK/workspace job completed successfully on **`86e817f6c9b9f3d8726832280c6ee9916bfcf7ad`**, with application and UI-test trees equal to reviewed **`e603d8182a1c10c4b37b14c92b5f0bc3829edea8`**. This is source-specific Apple compiler and component evidence. **It executed zero Native UI tests and did not build the full application.**

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44765034019

## Identity and execution

| Field | Verified value |
| --- | --- |
| Workflow | `.github/workflows/otzaria-ui-sdk-intermediate.yml` |
| Trigger/ref | Push; `codex/otzaria-ui-sdk-intermediate-20261120` |
| Run/attempt | `44765034019` / `1` |
| Job | `136387248090`, completed/success |
| Actual job interval | `2026-11-20T15:40:30Z` to `2026-11-20T15:47:06Z` |
| GitHub run updated time | `2026-11-20T15:47:07Z`; distinct from execution completion |
| Compiler | Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9`) |
| Xcode | 27.2, build `27B52` |
| UI SDK/target | iPhoneSimulator27.2; `arm64-apple-ios27.0-simulator` |
| Artifact | `14646210906`, `faithful-ui-sdk-check`, 231,140 bytes |
| Artifact SHA256 | `1f8dcea4aea110eb40a206c9fba5748e448ea27cb07b63354a075240323a0792` |

The original source selector found an installed SDK/runtime pair; it did not install a toolchain or change global `xcode-select`. The selected runtime's availability is environment evidence, not a claim that a Simulator UI test ran.

The full original artifact is retained. All 48 ZIP members passed CRC verification, were unique safe regular-file entries, and matched the already extracted bytes. The archive size/digest, source, repository IDs, branch and run are checked against the retained GitHub API metadata. The only application-comparison changes from e603 are the two additional CI files and their documentation; the four product/test Git trees are unchanged.

## Actual compiler and declaration scope

The original driver ran Swift 6 code generation (`-c -whole-module-optimization`, `DEBUG`) on **11 complete original UI test source files**: MaktabahUITestBase, FaithfulReaderUIAcceptanceTests, Build8401SevenDefectsAcceptanceTests, PullNavigationAcceptanceTests, SefariaEmbeddedAcceptanceTests, NativeRoutingAcceptanceTests, GlobalSearchNativeAcceptanceTests, R27NativeInteractionAcceptanceTests, Sidebar11201AcceptanceTests, HanlinConsumerAcceptanceTests and BookHistoryScopeAcceptanceTests.

The original compiler-backed declaration checker also matched **116 distinct selected Native declarations**, exactly equal to the catalog's current execution-group selection, and its 8 original regression controls passed. Declaration matching is separate from SDK code generation and UI execution. This run did not code-generate all 18 UI source files as one target and did not execute those 116 cases.

Original standalone SDK compilations passed for the native sidebar search/title components, ReaderSidebarSplitConfiguration, toolbar sources, actual Reader TextKit visibility component and the NativeRoutingHost package/dependencies. The project membership gate passed. The original aggregate explicitly retains:

- `appComposedSidebar: REQUIRES_FULL_APP_BUILD`.
- `appComposedGlobalSearchField: REQUIRES_FULL_APP_BUILD`.

The complete app-owned compositions, actual presentation/layout, live scene acknowledgements, provider execution, physical devices, HID and Release behavior remain outside this result.

## Executed component evidence

| Original check | Actual result | Scope and limit |
| --- | --- | --- |
| Workspace executable | 89 reported assertions passed | Original persistence, migration, rollback, scene and semantic-location checks. The original executable emits one aggregate summary, not 89 individual XCTest leaves. |
| SQLite wrapper | 25/25 named cases passed | Actual original wrapper, disposable SQLite 3.54.0 databases and contention/cancellation. Real-corpus read count, decompressor, UI and physical execution are zero. |
| Annotation exchange ledger | 28/28 named cases passed | Real SQLite, production CryptoKit SHA256 and original sync-pending store component. Source bytes and original CloudKit queue bytes remained unchanged. |
| Annotation crash/reopen | 2/2 passed | Separate before/after commit process exits of 73, verified reopen exit 0, actual WAL with synchronous=2. |
| Hebrew ranges | 15/15 passed | Complete original String extension, real Swift/Foundation and independent literal source-span oracles. No UIKit/TextKit rendering claim. |
| BookPageCache | 26/26 passed | Original cache/model/capacity/lifetime behavior. This is not device RSS or UI performance acceptance. |
| Inspector owner | 17/17 passed | Exact binding with real Swift6/MainActor and explicit model/backend DTO doubles. No Core permission/database/actual panel proof. |
| Legacy Hanlin navigation | 8/8 XCTest cases passed | Complete original SDK dispatcher/contracts; explicit host/navigation effect boundary. |
| Hanlin conversation store | 11/11 XCTest cases passed | Complete app store with real Foundation files and scoped lease/CAS/failure checks; no provider, scene or physical protection proof. |
| Hanlin API 1.2 host | 48/48 XCTest cases passed | Frozen SDK contracts, original dispatcher, actual Core/adapter, explicit backend/authority/native-receipt doubles. |

Every named component result was compared with its raw case lines/JSON or XCTest leaves. No duplicate leaf was counted. The extra Swift Testing “0 tests” trailers do not erase the actual XCTest results. Counts in this table are intentionally not combined into a Native test total.

The Hanlin source-preparation record binds the original `e00498e33f106cc43be0476ffa2e09329c8ca300` source, 424 checked Git blobs and the three original package layouts. It is not provider execution.

The annotation result explicitly states `original_annotation_repository_runtime_executed: false`; CloudKit, Anytype, transport, physical-device and Native execution are zero and live capability remains disabled. This packet therefore grants no acceptance to the later Maktabah local-body or new Anytype ownership work.

## Warnings and limits

The UI compiler report contains **2,844 `warning:` occurrences**, corresponding to 1,422 source-location warning headers with repeated caret diagnostics. They remain unfiltered in the original log. The combined log has **2,848** total occurrences: the remaining four belong to the appended NativeRoutingHost SwiftPM output (three manifest-command notices and the deprecated native build-system notice). No source-location compiler error was found in those retained sections. Successful compilation is not a warning-free claim.

Before/after guards at `15:40:58.598242Z` and `15:46:55.731243Z` reported identical input observations. This review recomputed all bytes, SHA256 and Git blobs for the 24 inputs independently fetched by Root, matched them to both guards and matched the 11 UI compiler hashes. Full evidence and commands are retained; nothing was rebuilt or rerun during this review.

This is the exact 86e817/e603 SDK closure. It grants **no cold-Core798/194 acceptance, no new Anytype local-body acceptance, no complete app build, no Native116 execution, no physical performance and no Release114 acceptance**. Future source changes require their own matching evidence.

## Retained packet

The packet includes the exact artifact, original GitHub receipts, complete raw job-log input, Root's 24 fetched source inputs, archive/member inventory, source-binding replay, raw-leaf projection and this independent verification script. The ephemeral signed artifact download URL is omitted from durable documentation; the original artifact and API-authenticated size/digest are retained.

An initial local evidence-parser attempt treated the BookPageCache log as pure JSON and failed on its original `PASS:` prefix. That verifier and error are retained as a review-tool failure, not an SDK failure. The corrected parser requires all 26 exact `PASS:` lines and the matching JSON payload. The final evidence replay passed without any Swift or test execution.

To replay this packet after checkout, run `python3 docs/hq-integration/sdk-intermediate-result-20261120/VERIFY_PACKET.py`. It verifies every retained payload and replays the source, archive and result checks in a temporary directory. It makes no network call and does not execute Swift or tests.
