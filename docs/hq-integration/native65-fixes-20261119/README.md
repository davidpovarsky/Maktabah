# Native65 failure correction and full release evidence producer

This batch continues the existing three-phase integration from 987bc0ce. It is source reviewed and locally checked; Apple app compilation and real Native acceptance of this batch are pending.

## Actual prior Native evidence

Run 44383462276 checked out 2d31ba096bae1136f52a6dff97727d86d7dfc93e, application source 19b5cba46e664692bae6ddcdfca5eccacba8b3c6, on Xcode/SDK/runtime27.2. Original build-for-testing passed. Strict xcresult evidence:36PASS,18FAIL,0SKIP,11UNVERIFIED. The original phase1 subset is21PASS,3FAIL,3UNVERIFIED. None of these passes is reassigned to this changed source. All16 native test/resource hashes,14 helper hashes and871 ordinary app source blobs were independently checked against that Git commit. The sole generated privacy input is original CocoaPods aggregation with independently traced dependency reasons. Range-extracted entries have per-entry CRC verification; whole-archive integrity is separately recorded in the canonical evidence directory after the owned download finishes.

## Product corrections

- Original selected-segment blue background no longer overwrites search highlights or persistent annotation backgrounds/identity. Only uncolored attributed-string ranges receive the same original selection color.
- The recent-search section title uses the dynamic system label color, avoiding inherited section-header secondary styling implicated by the actual unfiltered contrast audit.
- System entity resolution may describe an existing mounted background window. Every execution still obtains fresh foreground eligibility and uses the original Core/scene/witness/receipt checks. Missing, stale, different-backend/window and duplicated live catalogs remain failures. Visible query-component entities still require the original actual foreground field.
- Original tab select/close buttons expose their actual tab UUID as accessibility identity, retaining layout/actions. Same-title tabs remain distinguishable.

The exact two original-reader hooks, upstream provenance, authorization boundaries and rollback are in REVIEW.json and ORIGINAL_READER.diff. The owner authorized all required phase work; no unseen exact-hunk review is claimed and no approval/signing policy is changed.

## Real test preconditions and source oracles

The previous generic31-character reader heuristic falsely rejected real source headings, including book1 line1 פרק א and book3891 line1 הקדמת המחבר. The affected Native cases now compare the entire rendered value to independently extracted, SHA-sealed SQLite text; only bidi controls and outer whitespace are normalized. Existing frames, genuine-title/error/pixel checks, exact locator, selection, original tab ownership and full Core receipts remain. Other generic reader assertions retain31characters.

The original text fixture retains all three old rows unchanged and adds only the canonical first-link bootstrap plus the exact first/tenth nonzero book3891 rows needed by existing tests. Database miniTest10-v6:15,470,592 bytes, SHA256 d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef. New text-resource SHA25651632762100689aa2da6a6d360a6434d4fa4caf5e57971f4ad8e327ab6e173dc. Original metadata resource18,879rows is unchanged. tools/hq-native-reader-text-oracle.py reads only a verified source copy and independently decodes original compressed SQL rows; no app diagnostics supply expected text.

The later-page search case now waits for its exact source locator and original renderer before asserting text/highlight. Sidebar selectors retain the full base64 path identifier with an exact predicate rather than XCTest's truncated identifier API. The empty-TOC test creates and selects a real empty study profile through original management controls, preserving all previous groups/tab IDs. It no longer assumes a fresh sidecar erases original persisted Reader tabs. An already existing unique UUID sidecar returns immediately, avoiding a nested XCTWaiter inside receipt observations.

The annotation-root case remains unresolved: original URL delivery was observed after the20-second visible-screen assertion had already failed. Its failure and latency bound are retained; a late receipt is not PASS.

## Verification boundaries

- Original selection behavior:1PASS5FAIL; corrected source:6PASS0FAIL using Foundation attributed-string tests. No UIKit runtime claimed.
- NativeIntentService:11actual portable XCTest methods PASS, including four new background identity/fresh execution tests. Native catalog state is an explicit fixture.
- Current local preflight: Python AST, YAML/unchanged read-only workflow permissions, actual app/SPM membership, Swift6.3.3 parser,70 selected native declarations including all27phase1 cases,23 independent release-gate tests and13 producer/consumer tests. Synthetic artifact tests never count as Native UI.
- Separately reviewed old app run44413677701 passed unsigned build on392b8a10/appc91db450 with six package pins. SDK run44423067214 passed code generation and20real macOS SQLite cases on987bc0ce with47 exact Git source hashes. Neither proves the new nine-pin app graph or these current fixes.

## Release evidence production

The existing strict runtime27 pipeline gains an explicit release mode. It builds original source inputs and then executes the exact existing full-release manifest:5configurations,94required UI executions plus2separate prototype oracle executions. The original production installer and Release build must prove the full corpus, exact SDK/runtime, app/test binaries, locale arguments/actual device orientation, independently verified xcresult counts and zero skipped tests. The producer validates artifacts with the existing release gate's shared pure verifier; the outer gate still requires the actual successful completed GitHub run/commit/age/digest. No synthetic GitHub success or distribution is created.

Large native xcresult/video/visual captures are preserved separately from the small release-evidence artifact. The scoped70-case matrix's whole-run budget is12600seconds, after the actual9000second cutoff left phone evidence unfinished. Existing product-assertion latency bounds are not relaxed.

## State

All23 original tasks and two parents retain their actual acceptance states. No new task is completed by these local checks. Native70, complete release matrix, actual full production journeys, physical device/VoiceOver/Stage Manager, compatible Books Updates provider and remaining Hanlin host composition/release requirements still need their recorded evidence. Main remains untouched and TestFlight is not ready.
