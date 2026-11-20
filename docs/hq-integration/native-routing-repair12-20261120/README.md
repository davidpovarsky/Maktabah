# Native routing repairs from authenticated repair12 failures

## Status

Candidate changes address three concrete mechanisms found in original [Native run 44673191816](https://github.com/davidpovarsky/Maktabah/actions/runs/44673191816). That run remains **FAILED: 3 passed, 9 failed, 0 skipped, 0 not run**, checkout **6030087e27f75b26d9a9bb144ba9ba71eaddadc5**, application/tests **461de9aaee620d4275a1676ce8e1c230eb8e27ad**.

Candidate base is integration **0ade6b47708c47cc26932105eb6de7743539b3bc**, app source **c61213d9fcc8b80a8606ba00a1562215312ca2ed**. **Candidate Apple typecheck and Native execution are NOT_RUN.** System Inspector's generic errors remain unresolved. The historical failures are not a successful test of this patch.

Only two app integration files, one native helper identifier, and the existing portable note-owner fixture/driver change. Root owns manifests, integration, freezes and dispatch. Original case counts, timeouts, oracles, engines, SDK source/pins and user data remain unchanged.

## 1. Return to the original iPad tab

Both actual Pad newTab cases reached the original Reader, requested exact locator/highlight, a new receipt, persisted +1 document count, distinct UUID and preserved original document/group/profile. They failed waiting for the strip identifier, before the bounded swipe loop.

The active original ReaderTabItemView assigns **reader-document-tabs**. Independent native AX reports that ScrollView at (340,92,136,32.5), with exact old/new UUID buttons; the old UUID is partly left of its narrow viewport. The previous **reader-document-tab-strip** identifier belongs to another renderer that is not mounted on this route.

The helper now uses the actual original strip. Its UUID lookup, maximum eight real gestures, direction logic, existence/hittability, actual tap, exact locator/receipt and persisted count assertions are unchanged. Source inverse proof confirms this one string is the entire XCTest diff.

Affected original selectors:

- NativeRoutingAcceptanceTests/testPublicV2NewTabOpensOtherBookAndPreservesOriginalReader
- NativeRoutingAcceptanceTests/testPublicV2NewTabSameBookCreatesDistinctOriginalReaderTab
- NativeRoutingAcceptanceTests/testCoreCommentaryOpensVerifiedSourceLinkAndPreservesBaseOnPad

The phone path still uses original overview cells.

## 2. Idle note registration cancelled a different route

The RequiresVisible Inspector test failed **before** its Inspector refusal gate, while opening the original Search root:

- 06:30:38.682Z: Search appeared, contained and visible, request pending.
- 06:30:38.683Z: visible observation matched the route.
- 06:30:38.958Z: presentation_binding_changed.
- 06:30:39.301Z: native_effect_uncertain.

Both failed and current baseline sources call detachNoteEditor from the original Reader workspace's onDisappear. The original method revoked the scene presentation unconditionally after matching UUID, including an idle registration with no note request, draft or editor. A valid root transition therefore caused Reader disappearance to cancel that transition itself.

The new method snapshots the original owner's note state before clearing it. Revocation remains required for **any** retained note binding, current draft or active presentation, including dismissal after the draft binding becomes nil. Idle registration removal does not cancel a different surface's request. Matching UUID and nativeStateChanged/directory.invalidate(lease) remain; scene unmount still revokes fully. Note completion still requires the same live owner and bound draft.

### Actual portable validation

The existing source extraction driver compiles the complete original owner, text callback, dismissal callback, workspace setter and now the detach method. UIKit, SwiftUI Binding, Reader, Annotation, scene revision and presentation revocation are explicit boundary doubles.

| Same fixture against | Actual result |
| --- | --- |
| Original app c61213d9 | 20/21 passed; only idle_reader_detach_preserves_pending_other_surface failed |
| Candidate methods | 21/21 passed, 0 failures, 0 warnings |

All **15 original controls** remain unchanged after newline normalization. Six new controls cover idle detachment, retained binding, manual draft before first text callback, closing presentation, stale UUID and duplicate detachment. Actual Windows Swift6.3.3 with Swift6 strict concurrency; both compiled. Job job_de8f834b9f4f completed at 2026-11-20T07:51:06.525686Z, 7.46s total.

This does not prove SwiftUI scheduling, UIKit presentation, TextKit, Core or Native acceptance. The subsequent two FloatingPanel modifier additions do not alter the extracted workspace setter; SOURCE_PRESERVATION.json verifies every compiled fragment against final candidate bytes.

Independent source review by Asana-audit found no weakened owner/receipt guard: live/closing notes still revoke, idle removal still invalidates the directory, stale UUID is ignored and note completion cannot acknowledge a detached owner. The reviewer did not rerun tests or claim Native success.

## 3. Floating Inspector content exceeded its viewport

The first Inspector request received a real receipt at 06:29:20.416Z. Content later changed to contained=false. On the repeated request, the original panel was mounted/foreground but extended outside the window, reached its unchanged five-second deadline and displayed an actual failure alert. That alert then covered the panel and correctly failed panel.isHittable.

AX reports original panel (328,643,498,954) in an 834×1210 window: only567 of954 vertical points are visible. Its screenshot independently shows the half-height floating panel and resulting alert. The unchanged surface witness correctly rejects its **98% full-bounds containment** gate.

Locked FloatingPanel **3.2.4**, revision **3db567a19ff81d2d3ce00399021ee87a4fccf7e0**, defaults to static content height. Its exact public SwiftUI source provides **floatingPanelContentMode(.fitToBounds)** to resize content to the current panel bounds. Original fetched source, Git blob SHA, URL and content SHA256 are preserved in FLOATING_PANEL_API.json:

[Locked public API](https://github.com/scenee/FloatingPanel/blob/3db567a19ff81d2d3ce00399021ee87a4fccf7e0/Sources/SwiftUI/View%2BfloatingPanelConfiguration.swift)

Only this modifier was added at the two existing composition sites, floatingWorkspace and SharedSidebarFloatingPanel. Panel states, anchors, detents, layout, original content, Reader/ViewModel, animations, marker and strict visibility tests remain. The compact SwiftUI sheet and dependency lockfile remain unchanged. This changes actual content layout rather than permitting clipped content through the witness.

Three candidate files passed Swift syntax parsing with no diagnostics: SceneSession, iOSReaderWorkspaceView and NativeRoutingAcceptanceTests. **Syntax parsing does not prove Apple API typechecking or actual layout.**

## 4. System Inspector remains open

Pad and Phone System Inspector cases threw generic OtzariaUIRouting.UIRouteError NSError code1 after initial real Reader checks, before an Inspector route/await-mount event. The old raw logs expose no internal string code or exact metadata stage. No crash or foreground root cause is inferred.

Current source already includes39ba01a0 and bounded NativeIntentFailure stage/code logging. It separates Reader-window metadata; general Inspector entities still use live discovery. This patch does not claim the System Inspector failures are fixed and does not weaken discovery, admission, foreground or receipt rules based on a generic NSError.

Keep both cases open:

- NativeRoutingAcceptanceTests/testSystemAppIntentShowsOriginalReaderInspector
- NativeRoutingPhoneAcceptanceTests/testPhoneSystemAppIntentShowsOriginalReaderInspector

## Required actual Native regression

Retain the three original Pad tab-return cases, Public Inspector Pad/Phone, System Inspector Pad/Phone, and testPublicV2InspectorRequiresVisibleOriginalReader. Retain both original Core note-draft Pad/Phone cases to verify active-note cancellation; this patch does not claim to fix their separately unresolved native witness behavior. Original Phone NewTab/Commentary, Search navigation/focus, and floating/compact Inspector controls remain regressions.

Root preserves the full original selection and controls any focused dispatch. No failure is selected away; no synthetic receipt, model-only mutation, reduced assertion or longer timeout is introduced.

## Evidence

RESULT.json records source-bound outcomes. SOURCE_PRESERVATION.json proves localized diffs, unchanged witness/observer/SDK lock and Faithful/R27 sources. RAW_EVIDENCE_MANIFEST.json lists raw copied bytes and hashes.

The small original evidence ZIP was independently verified as **63,017,123B**, SHA256 **5ff46397642ad94f64c351bbc2dfd5dd97f902602994e8b5354996ac4e00d958**. Its original path is retained; it was not downloaded or copied again.

Captures artifact14609343962 is **435,989,487B**. Only selected authenticated HTTP206 entries were fetched by the original collector and checked against central-directory CRCs plus individual SHA256. **The complete captures archive was not downloaded or hash-verified.** RANGE_EVIDENCE.json explicitly preserves that limit. Relevant original AX/screenshots/receipt/workspace records and logs are included here.

Raw Windows hashes and canonical Git LF hashes are separately labelled. Gzip preserves raw historical logs, JSON and generated source units exactly; source newline conversion does not rewrite them.

## Ownership

| Path | Ownership and edit |
| --- | --- |
| Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSceneSession.swift | Downstream integration; only detach ownership guard |
| Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift | Existing fork-owned Reader composition; two public SDK modifiers, assigned by Root |
| Maktabah-iOSUITests/NativeRoutingAcceptanceTests.swift | Downstream authentic Native acceptance; one control identifier |
| Tests/HQ/navigation/NativeNoteEditorOwnerFixtures.swift | Downstream fixture; original15 retained plus6 |
| tools/hq-native-note-editor-ownership.py | Downstream extraction driver; exact detachment plus21-control gate |
| This docs directory | Source-bound original failure/API/validation evidence |

No SDK implementation, package pin, annotation persistence, engine, DB, user index, workflow, frozen branch or manifest was modified.
