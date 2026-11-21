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

The width case previously passed in run44811999303 attempt1, workflow head `a1d11a78152f9d6826c90646fcd72cf7711f12ff`, application source `353888ed645c135da9cb229713d17a4594d1edb6`, as retained in `docs/hq-integration/native-study-sheet-repair-20261120/CAPTURE_FINDINGS.json`. That was an individual pass in a failed run (two passed of eleven executed), not whole-run acceptance. It is reselected because the width/anchor implementation has now changed. Root retains all seven previous focused selectors individually and adds this one existing case, for eight unique cases. The full Native116 and Release114 catalogs are unchanged.

## Validation credit

`source-review.json` records the byte-identical legacy fallbacks and preserved original assertions. `syntax-validation.json` records Swift6.3.3 frontend syntax parsing of all four changed files (exit0, no output) and `git diff --check` (exit0). This Windows check does not typecheck UIKit or execute Native tests. Native compilation, engine persistence, raw scrollability, the real gesture, and the width/anchor assertions are explicitly pending the parent-controlled Apple route.
