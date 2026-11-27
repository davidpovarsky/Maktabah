# Original Sefaria Inspector mode regression: prepared native case

## Status and exact scope

The new native UI case is implemented and Apple SDK typechecked. **The Maktabah app UI has not been run for this case.** One real public Sefaria response was captured and converted using unchanged production DTO/model/presentation sources. Those are source and SDK receipts only.

The case is registered through the already registered file `Maktabah-iOSUITests/DeepLinkedCommentaryAcceptanceTests.swift`. The two legacy cases and the separate full-v40 Inspector semantic class remain byte-identical. No Source, SDK, workspace, or project-registration file changes in this checkpoint.

Selector:

`Maktabah-iOSUITests/SefariaInspectorModeAcceptanceTests/testSameTabInspectorHonorsSourceTranslationAndBothAcrossCloseAndReopen`

The case exercises the visible and hidden mode transitions covered by library commit `f000c095cea53945eba3859eb8a25c0f60906970`, including a single original reopen action. Wave3 separately owns the repository-identity mount follow-up in the host; that change must be delivered and qualified by its owner. This test does not turn either component receipt into UI acceptance.

## Actual source, rather than preview-edition substitution

The ordinary Reader and Inspector currently use the default canonical Sefaria request. Selected search-edition support belongs to the separate Search preview acceptance. The setup uses original Search controls to reach Psalms 35:17, then its original Open action loads the canonical default Psalms 35 unit. The selected preview edition is recorded as route evidence and is not used as the expected Reader/Inspector edition.

The exact public request was captured on 2026-11-27 at 04:13:28 UTC with HTTP 200:

`https://www.sefaria.org/api/v3/texts/Psalms%2035?version=source&version=translation&fill_in_missing_segments=1&return_format=text_only`

Its raw response is 29,198 bytes, SHA256 `c785026ced58b9af868ce50181463fd0bfafa7d96b7f9f3c1bb710aba5e0ae90`. Raw HTTP receipt, headers, original URL, final URL, status, byte count, digest and capture time are retained next to it.

The response identifies Psalms 35 / תהילים ל״ה and contains 28 segments in each of:

- Hebrew: **Miqra according to the Masorah**, source/primary, provider license **CC-BY-SA**.
- English: **THE JPS TANAKH: Gender-Sensitive Edition**, translation, provider license **CC-BY-NC**.

The original response retains the provider's complete version and attribution metadata. These source licenses and names describe that response, not a claim that the Kit displays a version title.

`InspectorModeSourceOracle.swift` decodes the response through unchanged `LibraryBackendModels.swift`, `SefariaModels.swift`, and the whole original `SefariaDTOs.swift` from integration revision `991526228533d6689c4ad9da8dbd3e9f82a7bea1`. It checks complete source/translation correspondence for all 28 segments, then derives the exact Source, Translation and Both bodies through the original presentation policy. The reader-model body hashes are additionally recorded as source observations, but are not asserted as full native UITextView acceptance by this case.

Generated oracle: `sefaria-inspector-default-mode-oracle.json`, 21,902 bytes, SHA256 `288876d0fcb903298bc0b4c9bcfe95047f4f520ea0ce9476fe008650baa3e224`. Its status explicitly says `ACTUAL_DEFAULT_SEFARIA_SOURCE_ORACLE_ONLY_NOT_UI` and `uiExecuted` is false.

## Native assertions to be executed

The case launches the ordinary production Sefaria backend in Hebrew. No bootstrap bypass, test workspace namespace, injected source database, synthetic row, private route, or mocked API is supplied.

It selects Source through the original View Options picker before opening Inspector. The original mode action clears prior search-hit segment focus. Consequently the expected Inspector selection is the complete current unit, not the earlier individual Search hit.

The eight required observations are initial Source, visible Translation, visible Both, visible Source, a matching Source close/reopen, and hidden-change/reopen for Translation, Both and Source. Visible transitions must update without toggling Inspector again. Hidden transitions must leave it closed until one original open action.

At every observation it requires one actual original selected-unit quote Text whose complete accessibility label has the exact 28-segment body byte length and SHA256 for that mode. It also asserts the original display reference: Hebrew in Source/Both and canonical English in Translation, under the Hebrew interface.

**Surface boundary:** the Kit visually caps that quote at two lines. This is a complete supplied accessibility value on a genuine displayed Text, not a claim that all 28 segments are simultaneously visible or separately expanded inside Inspector. The Kit's legacy configuration disables inline full-source navigation, so the test does not target its unavailable full-source button. The main original UITextView is required to be present and populated at the exact canonical default Reader locator; its complete rendered body is a separate Reader acceptance.

**Version boundary:** this pinned Kit has no displayed version-title field. Exact default-response and body equality qualify the expected source editions. Internal `document.version` mapping remains component evidence; the UI test never invents a visible version assertion.

Same-tab identity is read from the ordinary `workspace-v1.json`, under a freshly observed original MCM application owner within the actual test Simulator. It resolves last active scene, group, scene override/group active tab, and session UUID. Every mode must keep the same owner, scene, group, session ID, book ID and persisted canonical backend locator, and match the original `reader-document-tab-<UUID>` control. No user-state file is written by the test harness.

## Runner environment and attachments

Supply all of:

- `SEFARIA_INSPECTOR_MODE_ORACLE`: absolute path to this directory's generated oracle.
- `SEFARIA_INSPECTOR_MODE_ORACLE_SHA256`: `288876d0fcb903298bc0b4c9bcfe95047f4f520ea0ce9476fe008650baa3e224`.
- `SEFARIA_INSPECTOR_CONTAINER_PARENT`: the owned Simulator's actual `data/Containers/Data/Application` directory.
- `SIMULATOR_UDID`: actual XCTest Simulator identity; must agree with the directory above.

The oracle must remain beside its sealed `psalms35-default-response.json` and `psalms35-default-response-receipt.json`. Do not rewrite the original source receipts for relocation. The test discovers the current application owner from actual MCM metadata and only reads its ordinary workspace.

Retained attachments are the source oracle, `sefaria-inspector-original-canonical-open`, and `sefaria-inspector-mode-<phase>` JSON/screens/hierarchies for each of the eight named observations. A MainActor-scoped defer captures the final screen and hierarchy on success or failure. Each phase records exact body digest/bytes, display reference, source response digest, ordinary tab/group/scene identity, current workspace digest, and source-only version scope.

## Actual Apple checks and retained attempts

Owned lane: `/Users/m1/builds/otzaria-wave2-library-controls-20261127/inspector-sefaria-mode-ui-attempt-1` through `-3`.

The source oracle compiled and ran on Mac Catalyst with Swift 6 strict concurrency and the MacOSX 27 SDK. This was a direct Foundation source conversion, not an iPhone runtime or application launch. Only the already owned module cache was reused.

The whole current UI file was typechecked against the original iPhoneSimulator 27 XCTest SDK, target `arm64-apple-ios27.0-simulator`, with the target's Swift 6/approachable-concurrency/member-import flags. The original test base and exact, byte-verified public shared UI helper are disclosed dependencies. All helper blocks were checked against their actual Git source; they were not rewritten for this check.

- Attempt 1 (04:26:06–04:26:10 UTC): source conversion exit 0; whole UI typecheck exit 0. One new screenshot teardown isolation warning was observed. RESULT SHA256 `09dbcf8bc4c5c9dd033001675285b59954099b6e577cfeb814f89673ca440030`.
- Attempt 2: compiler exit 0, but the local no-new-warning criterion failed because the alternate screenshot API was also actor isolated. This attempt is retained as `FAILED_SOURCE_ONLY`; it is not a UI failure or a passing warning gate. RESULT SHA256 `c17c7512359f44b9cc256524d03790ed314d38a543c53c7384187c48a83a1599`.
- Attempt 3, finished 04:32:12 UTC: final source typecheck exit 0, no new-class warnings, no errors. Final test source SHA256 `e7c993c6b9da1a05640b5791884c0202ad6b6377efa5c9e27bcfcf69da1ea5b7`; RESULT SHA256 `2cc2b0f86d436b4cc70707ea0f47cf9ee19f9520e9efd915da0e1a5367545bf6`. Existing base/legacy diagnostics remain retained without being reclassified as new-case warnings.

One Attempt-3 dispatch returned Sentinel `-32603`. A subsequent read-only check established that the attempt directory and result were both absent before the one successful retry. No unknown-outcome job was launched twice.

Exact commands, hashes, compiler output and previous test-source snapshots are retained. `NATIVE_EVIDENCE.json` records original and stored digests, including deterministic gzip archives of logs and source snapshots. No native app, Simulator UI, full corpus benchmark, or full application build was run for this checkpoint.

## Provenance and remaining acceptance

Affected test path is absent from exact upstream revision `4203de5fd77beb119e5826e039be1a61325f7be0`; its immediate pre-change SHA256 is `489a28190fa171bd5c5b3fdb47fadb48d3733d6f178315266eea5ea314848e7a`. The existing prefix is preserved byte-for-byte. The new class is additive in the already registered file.

The remaining gate is an actual original app run of the selector against the qualified combined build, owned Simulator, original pinned Kit, and source-qualified default response. It must produce the eight actual assertions and zero-skipped XCTest result; source conversion and SDK typechecking do not satisfy that gate.
