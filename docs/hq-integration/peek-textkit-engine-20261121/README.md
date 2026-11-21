# Peek Reader viewport: preserve the active TextKit engine

## Evidence and failure boundary

[Focused Native run 44940208007](https://github.com/davidpovarsky/Maktabah/actions/runs/44940208007) failed the existing Peek case before its actual Reader gesture: the original raw metrics reported content height 622 and viewport height 802, with zero insets (overflow -180). The actual offset was 506. The preserved screenshot and both original accessibility hierarchies show the real, large-font, multi-paragraph reading unit continuing far below the viewport. Before opening the sheet, the original hierarchy already reported a one-page scrollbar despite that long rendered content; the exact raw 622 value was captured only by the later viewport request. This is not evidence that Peek blocked the background gesture, because the prerequisite stopped the test before that gesture.

`DIAGNOSIS.json` binds the original artifact IDs, archive SHA256 values, exact attachment UUIDs, and byte hashes of the retained attachments. These files are copied from the parent's verified artifact extraction without re-rendering or alteration. `peek.png`, `before-sheet-hierarchy.txt`, `peek-hierarchy.txt`, `peek-actual-views.json`, and `viewport-before-gesture.json` preserve the narrow failure evidence.

## Concrete source defect and repair

At source base `633ea6e1d6153a27841b6cb899fa73be8a869ef8`, `iOSCustomIbarotTextView.captureViewportAnchor()` and `restorePendingViewportAnchor()` accessed the lazy `layoutManager` getter unconditionally. Capture is called from the real width-change path and from DEBUG viewport metadata; the downstream observer calls that metadata method. The Reader uses the normal UIKit initializer, with no explicit TextKit 1 storage/manager/container construction.

[Apple's WWDC22 TextKit session](https://developer.apple.com/videos/play/wwdc2022/10090/) explains that querying `layoutManager` on a TextKit 2 UITextView triggers a one-way compatibility fallback and can lose UI state. The patch checks `textLayoutManager` first, uses the public UITextInput position/caret geometry for TextKit 2, and returns before the legacy getter. The complete TextKit 1 capture and restore fallbacks remain byte-identical.

The new path retains the existing source/display mapping and the offset relative to the Reader viewport. It converts points and caret rectangles through `textInputView`, which [UITextInput documents as its geometry coordinate system](https://developer.apple.com/documentation/uikit/uitextinput). Restore uses the existing `NSTextLayoutManager.ensureLayout(for: NSRange)` extension from `Source/Core/TextProcessing/TextStorage.swift`, then applies the original offset clamp and native content-offset setter. The extension is internal in the same module, outside platform exclusion guards, already included in the application's source build phases and already used repeatedly in this same iOS wrapper. No new target membership is required.

Apple's current symbol metadata lists [UITextView.textLayoutManager](https://developer.apple.com/documentation/uikit/uitextview/textlayoutmanager.md) since iOS/iPadOS 16 and [caretRect(for:)](https://developer.apple.com/documentation/uikit/uitextinput/caretrect(for:).md) since 3.2. The project's iOS deployment target is 27. Apple requires caret geometry even for noneditable text. UIKit SDK typechecking remains part of the pending real Apple build.

The failed artifact did not record the runtime engine. The source/API defect is established; the next Native execution must establish whether correcting it also resolves the observed content-size mismatch. This commit does not claim that the failed acceptance case now passes.

## Preserved controls and bounded revalidation

The real fixture, font48, raw overflow greater than80, real press/drag, movement greater than20, original Reader identity, owner, and source/offset assertions are preserved. There is no content-size write, replacement text view, forced TextKit 1 initialization, layout-delay workaround, or synthetic scroll result.

The observer records `textLayoutManager != nil` immediately before and immediately after metadata capture. The test decoder keeps these as optional values; missing data does not default to false or true. Equality to true requires an actual positive witness. The existing Peek and existing narrow/wide tests assert the engine witness on their relevant actual snapshots while retaining all their original assertions.

The two exact cases to execute on the existing iPad11 / `11-reader` route are:

- `NativeStudySheetPadTests/testSystemStudySheetPeekAllowsOriginalReaderScrollBehindIt`
- `NativeStudySheetPadTests/testSystemStudySheetSameIPadNarrowAndWideRetainsOwnerAndAnchor`

The width case previously passed in run44811999303 attempt1, workflow head `a1d11a78152f9d6826c90646fcd72cf7711f12ff`, application source `353888ed645c135da9cb229713d17a4594d1edb6`, as retained in `docs/hq-integration/native-study-sheet-repair-20261120/CAPTURE_FINDINGS.json`. That was an individual pass in a failed run (two passed of eleven executed), not whole-run acceptance. It is reselected because the width/anchor implementation has now changed. The initial patch requires all seven previous focused selectors plus this one existing case; the production visibility follow-up below adds the ninth existing case. The full Native116 and Release114 catalogs are unchanged.

## Validation credit

`source-review.json` records the byte-identical legacy fallbacks and preserved original assertions. `syntax-validation.json` records Swift6.3.3 frontend syntax parsing of all four changed files (exit0, no output) and `git diff --check` (exit0). This Windows check does not typecheck UIKit or execute Native tests. Native compilation, engine persistence, raw scrollability, the real gesture, and the width/anchor assertions are explicitly pending the parent-controlled Apple route.

## Follow-up: preserve the engine in the production visibility witness

The final reachable-code sweep found another actual fallback site in ReaderNativeTextVisibility.isVisible inside MaktabahNativeSceneProjection.swift. The real Reader wrapper installs this callback; MaktabahNativeSceneSession.observe calls it on native Reader visibility even without a command submission. The same proof gates current-reader route snapshots, public presentation, note selection, and nonblank note-editor visibility. Leaving this site unchanged could switch the engine before the Peek observer recorded its first witness.

The follow-up now checks the active TextKit engine before the legacy getter. On TextKit2, a focused source still validates the original source range and exact display mapping, then reads the native rectangle of its first composed character. A nonfocused observation selects a composed-character candidate using the native closest-position API. That candidate alone proves nothing: the implementation requires a real nonempty UITextRange and its actual firstRect. It then applies the unchanged finite rectangle, viewport, window, and every clipping-ancestor check. UTF16 positions at the end of the document are bounded to the last composed sequence. The old glyph code is retained in the TextKit1 branch, with only indentation and the rect assignment declaration moved to the enclosing scope.

[Apple firstRect(for:) documentation](https://developer.apple.com/documentation/uikit/uitextinput/firstrect(for:).md) describes a text-range rectangle, unlike a caret-only position. It is available since iOS/iPadOS3.2. Both input points and returned rectangles use the documented textInputView coordinate conversion. No model-only acceptance or unconditional visibility result is added.

The reachable-layout-manager-audit.json report records the full tracked Swift/Objective-C/header search, including the exact remaining Source getter sites and any other tracked matches. The visibility-source-review.json report records unchanged shared geometry checks, preserved legacy statements, successful Swift syntax parsing, and pending Apple typecheck/runtime status. Existing Scripts/CI/typecheck-faithful-ui-tests.py already extracts and checks this marked helper against real UIKit; the normal application build also compiles it.

The bounded focused route should retain all prior seven selectors, add the original width/anchor case listed above, and add the existing NativeRoutingAcceptanceTests/testPublicV2CurrentReaderShowsTwoCanonicalSourceLines on iPad11. That ninth case verifies two independent nonzero focus locators, actual original TextKit selection, and distinct canonical receipts. The normal Reader mounts exercise the automatic witness; the added existing routing case directly exercises changing focused source evidence. Existing wrong-book, hidden-reader/no-ACK, and note-editor cases remain unchanged in the original full catalogs. No Native result is credited by this source repair.
