# Original Profile / Group system acceptance selectors

This is a test-source follow-up to Profile/Group product packet `2966054d46a2610b7a4fe53eb8ac1323710f25ae`, integrated by root at `dd4b28f42950689713a5980dbd3dae21eb414f26`. It changes no product Source file, public schema, native receipt format, original selector body or original timeout. Native execution and Apple SDK compilation are **NOT_RUN**.

## Exact selector scope

| Class | Selector | Intended original observation |
| --- | --- | --- |
| NativeRoutingAcceptanceTests | testSystemTabGroupIntentReusesOriginalSavedReaders | Select the original saved nonempty group from a genuinely selected empty group; original Reader source, tab and canonical receipt |
| NativeRoutingAcceptanceTests | testSystemTabGroupIntentShowsOriginalEmptyReader | Select an original empty group; actual existing iPad empty Reader view and no selected tab |
| NativeRoutingAcceptanceTests | testSystemStudyProfileIntentSelectsOriginalFirstGroup | Create a profile, visit its second group through original controls, leave it, then select the profile's original first ordered group through the system intent |
| NativeRoutingAcceptanceTests | testSystemTabGroupIntentRejectsActuallyDeletedCachedGroup | Prove cached entity success, actually delete its group through original controls, then require refusal and no state/receipt effect for the full five-second bound |
| NativeRoutingPhoneAcceptanceTests | testPhoneSystemTabGroupIntentReusesOriginalSavedReaders | Original phone Viewer Library to original saved Reader, preserving actual scene and process |
| NativeRoutingPhoneAcceptanceTests | testPhoneSystemTabGroupIntentShowsOriginalEmptyLibrary | Original close loop leads to the actual phone Library list within Viewer, with an empty selected group |
| NativeRoutingPhoneAcceptanceTests | testPhoneSystemStudyProfileIntentSelectsOriginalFirstGroup | Original compact overview/profile menus and nested editor setup, then system selection of the first group |
| NativeRoutingPhoneAcceptanceTests | testPhoneSystemTabGroupIntentReturnsFromBackgroundToOriginalReader | Same actual existing phone process/window is backgrounded before real system invocation and returns to the retained original Reader |

These are eight explicitly selected cases, not a claim that an inherited whole test class or a new full suite has passed. They use the original canonical miniTest10 real-UI fixture and sealed independent SQL oracle. The production v40 routes and the full Native116 / Release114+2 gates remain separately required.

## Delivery and independent oracle

All setup profile/group creation, first-group selection and deletion uses existing original controls: profile menu and editor, overview group-action menu, original confirmation dialogs and Done buttons. The helper requires a unique actual visible/hittable control; it does not tap coordinates or substitute a product callback. The original compact host keeps its overview presented when closing the last tab sets `showingTabsList` false; its original onChange only opens on true. That existing behavior is source-bound in the original UI read receipt.

The measured delivery uses an entity returned by Apple's actual out-of-process `IntentDefinitions` query, followed by `OpenStudyProfileIntent` or `OpenStudyTabGroupIntent`. It never invokes `perform()` directly, fabricates an identifier, calls a URL as fallback, activates the app after delivery or supplies a testing-only executor. Query matching must produce one entity in the real current window. Final selection is checked independently against the original persisted scene/profile/group/document UUIDs and original native surface.

The positive oracle requires one fresh strict `NativeNavigationReceipt` for `native.workspace.selection/currentTab`, its exact original scene, unchanged process, original saved profile/group/document source/location/search semantics, and visible original Reader/TextKit or the actual empty iPad/phone surface. A two-second observation checks the selected source, visible geometry and receipt set remain stable. Existing receipt parsing and source TextKit assertions are reused unchanged.

The deleted-group negative first executes the same cached entity successfully. Actual original deletion is then observed in persistence and fresh discovery. Its second system invocation must throw, create no receipt or state mutation, and produce no late effect throughout the original five-second command bound. The caught system error is retained; this is not a new assertion of a particular internal error code.

The focused saved-document comparison deliberately uses the existing semantic source/location/search projection. It does not claim full viewport, selection-range or expanded-TOC restoration; those remain the original Reader/Workspace suites' separate acceptance requirements. Neither a successful model projection nor a source control is a native pass.

## Preservation and validation

The complete prior `NativeRoutingAcceptanceTests.swift` is preserved as a byte prefix: 237451 bytes, SHA256 `5ad00a2b15b7029d56146dd2da8a738c895961c0e761583f2e892328cab66ae8`, including the prior Reader-tab helper. The follow-up appends 343 lines and adds one synchronized test-folder file. It does not require duplicate explicit PBX test membership; root retains project ownership.

Actual validation performed: exact prefix comparison; enumeration of the eight unique selectors; source inspection of real delivery/setup calls; Linux Swift6.4.3 frontend syntax parse of the full candidate and new selector file for `arm64-apple-ios27.0-simulator` (exit0). This parse does not import/typecheck the Apple SDK or execute XCTest/App Intents/UIKit. Raw parse argv/output, source hashes and receipt are preserved.

No original 56/46 product controls were rerun for this test-only packet. Original failures and native-pending status remain intact. Full iPad/iPhone, warm/cold, wrong-backend, stale profile, keyboard, VoiceOver, RTL, resize, multiwindow and physical device coverage is not inferred from these eight unrun selectors.
