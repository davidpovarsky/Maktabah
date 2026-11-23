# Repaired Reader and Profile native qualification

This lane selects exactly ten original XCTest methods on application and tests `1969b2065469b55e38e42cbb838a469ffa6a80f7`. It verifies eight repaired system-sheet cases plus the repaired ProfileColor and full 100-switch/cold-restore cases. There are zero changes to Source, Vendor, the Xcode project or original UI tests. The Library morph branch and its active run are independent.

## Exact selected cases

- `NativeStudySheetPadTests/testSystemStudySheetThreeDetentsPhysicallyRightRTL`
- `NativeStudySheetPadTests/testSystemStudySheetThreeDetentsPhysicallyRightLTR`
- `NativeStudySheetPadTests/testSystemStudySheetOriginalNotesSaveEditDeleteAndCancel`
- `NativeStudySheetPadTests/testSystemStudySheetOriginalEmbeddedSefariaOwnerAndAnchor`
- `NativeStudySheetPadTests/testSystemStudySheetParentCloseWhileOriginalNoteChildIsVisible`
- `NativeStudySheetPadTests/testSystemStudySheetTOCWhileOriginalNoteChildIsVisible`
- `NativeStudySheetPadTests/testSystemStudySheetReopenDuringActualDismissalRejectsStaleAndReplayedInput`
- `NativeStudySheetPadTests/testSystemStudySheetInteractiveDismissThenSameIPadResizeDoesNotReopen`
- `StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace`
- `StudyGroupStressNativeAcceptanceTests/testOneHundredConsecutiveOriginalGroupSwitchesPreserveDocumentsAndColdRestore`

The already passed Peek, same-iPad narrow/wide, original TOC and palette cases are excluded. The original 100-transition loop, real UI input, live hittability checks, complete membership/profile/locator comparisons, application metrics, cold restoration, all assertion lines and original 600-second per-case limit remain unchanged.

## Source and execution

The new additive wrapper reuses the original runtime27 execution-group validation, XCTest declaration validator, SDK selector, actual Apple UI-test compile route, hq-stage2 full app/UI-runner build, run-faithful-ipad-matrix runner, xcresult zero-skip collection, post-UI original source/privacy/package audit and disposable Simulator cleanup. The wrapper is derived from the reviewed Library native wrapper at `cba554ded79144d48642b12dba926a30a8eac451`; the Library product guard is not applicable to this unchanged canonical source. The complete Source/Vendor/project/UI-test trees and all tracked script/workflow/test/tool bytes are instead bound before and after execution.

The original build-input document changes only its application source SHA and Source tree. Existing Vendor/project/engine/native artifact/package pins remain exact. One native 11-inch group executes the ten methods. None of these selectors belongs to the original hardware-Escape set; they use their unchanged XCTest gestures/typing and existing scoped native lifecycle observation. No separate IDB installation or artificial input acknowledgement is required. The original group-switch observation is not replaced with synthetic measurements.

The new push workflow performs one original app build and one selected native execution. It retains original failure evidence and captures, verifies compiled image stability, and accepts only ten actual passes, zero failures/skips/missing leaves, the exact selected group and successful cleanup. It does not run old portable suites or historical Host48 again.

## Existing evidence and why this run is needed

The source-reviewed system-sheet repair packet is `docs/hq-integration/native-study-sheet-repair-20261120/`, with actual historical run 44811999303 on application 353888ed645c135da9cb229713d17a4594d1edb6. Eight selected cases still lack a later retained actual pass after the carrier/reciprocal-owner/weak-dismissal-observer/input corrections. The passing Peek and width cases have later evidence in run 44952423858 and are excluded.

ProfileColor and 100-switch last executed failures belong to run 44723902453 at application 87b783ac3f0257e8461762e0ea9dfa5248dd06e8, preserved in `native98-raw-supplement-20261120`. The current-value Picker target correction 0a493e0a362e88405fabe7a08ff60fb51820496f and accepted snapshot reduction b82fe8843803bdd6fbecc6bf0262bdcdfb9e2e28 have source reviews, but no later retained native acceptance. Those source controls do not count as current UI or performance success.

## Current acceptance boundary

This is preparation until the exact published workflow produces its actual result. Source-only admission and declaration checks are separate from Apple compilation and native outcomes. Full Native116, Release114, iPad13, physical-device, full production corpus, performance thresholds and distribution remain separate. No repaired case is relabeled from an older failed run.
