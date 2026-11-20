# Active iPad overview, original scroll reporting, and current Release UI controls

## Scope and result

Base: `ca314e7cc5d5cdde2bb15a54a79c92541296349f`.
Branch: `codex/otzaria-release-ui-selectors-20261120`.

The active iPad composition already used the original Maktabah Library, TOC,
Reader, native document buttons, and existing scene-lived workspace adapter.
It did not mount the retained `ChavrusaReaderHost`. Consequently, the existing
study overview had no regular-iPad entry point, and the retained navigation
chrome reporter had no callers under `Source`. The existing Release tests
also targeted the unused compact Safari text field and assumed the original
document strip exists with only one document.

This change connects the existing overview and restores passive reporting at
the original scroll delegate. It changes no book data, renderer, search engine,
annotation storage, Core package, workspace schema, or selected case manifest.

**Actual validation:** candidate portable exact-source logic **62/62 passed**;
the original base legacy binding **6/8 passed, 2/8 failed**, exposing its enabled
iPad legacy-sheet behavior. Syntax parsing and project registration passed.
**Apple SDK typechecking, Native acceptance, full Release acceptance, physical
devices, and visual acceptance for this source are NOT_RUN.** Explicit UIKit
and Binding substitutes in portable tests do not prove real windows or UIKit
callback scheduling.

## Product changes

- The existing `Exact9401ViewerToolbar` has a native overview action, including
  when a group has one or zero documents. It reuses the existing
  `StudyGroupsOverview`, `ReaderOverviewPresentation`, manager, and workspace.
  The original overview owns create/copy/move/reorder/close/relaunch behavior.
- A scene-owned request UUID remains live through actual UIKit dismissal or
  dismantle. Actual presentation records its mounted UUID. Closing the final
  book cannot dismiss the overview by resetting `manager.showingTabsList`.
  Stale/duplicate callbacks cannot retire another presentation; synchronization
  runs only after the matching completion is accepted.
- Native readiness is blocked from the request through matching actual
  dismissal/dismantle. Existing projection invalidation observes this state.
  The underlying original Reader and TextKit hierarchy remain mounted.
- The original phone presenter still uses its existing optional-lifecycle-free
  path. The legacy sheet remains the feature-off path; enabled iPad and phone
  layouts own their respective overview presenter.
- The original `ReaderNavigationChromeState` thresholds and original
  `ReaderTabsView` are reused. The latter still mounts only for
  `openTabs.count > 1`. Its passive container ID and visibility policy apply
  only when the enabled iPad host supplies the existing optional environment
  value. Nil preserves the original phone and feature-off policy.
- Exactly three passive report calls are restored in the original
  `iOSIbarotTextView` scroll delegate. Removing those three added lines yields
  the base delegate byte-for-byte after LF normalization. No delegate,
  contentOffset, renderer state, restoration, or pull-to-navigate behavior is
  replaced.
- The original event object and pan/top/begin payload remain. The actual
  sending scroll view is added so the consumer can verify the exact window.
  The consumer requires the selected original Reader object, viewer tab,
  active scene phase, attached original workspace, matching scene session,
  actual weakly observed anchor and sender UIWindow identity, key/visible
  foreground window, and no overview/reader popover/inspector. A detached,
  background, different-window or stale-owner signal cannot collapse this
  window's chrome. No global-window lookup is used.

The source reviewer found no blocker in overview UUID ownership or window
qualification. Cancel-before-mount while the anchor is detached/zero-sized
remains conservatively blocked until actual attachment or dismantle. Real
UIKit lifecycle and geometry remain Native gates.

## Release test controls and preserved requirements

All **39 existing test method definitions** in
`FaithfulReaderUIAcceptanceTests.swift` retain their original names and order.
This is a source-membership count, not an executed Native count.
The R27 file is unchanged; its LF SHA-256 remains
`d4ff446db4acdbb61e0ad19c14696e5194bafbba239ef86876e85a2de30e70cc`.

The tests now use the mounted native `reader-command-palette-launcher`, the
original palette input/results, and actual original tabs/overview cards.
Native navigation-bar containment, hittability, viewport bounds, pointer,
software keyboard, Escape, query retention, source text, locators, TextKit
identity, source/pixel positions, group operations, surviving UUIDs, and
cold-relaunch assertions remain.

Two viewport/scroll cases first open a second genuine book through the
original palette and return using the original document tab. This establishes
the original strip's count-greater-than-one precondition before measuring the
original Reader. The collapse case also closes an actually open sidebar before
testing the action that opens and restores it. It preserves the collapse,
restore, global-bar, original TextKit, and geometry assertions.

The SourceToolbar case observes the strip after its existing real second-book
selection. Pointer query retention is checked by reopening the actual palette
without typing; a native launcher button has no text-field value.

Production still opens **30 genuine documents twice**, observes ordinary
sidecar membership/counts without writing it, closes through original overview
controls **30 to 0**, opens the initial actual book, and verifies group
creation and cold relaunch. A single document's original UUID is observed from
its actual overview card because the native strip correctly does not exist
with one book. Counts 2 through 30 retain the original selected strip title and
viewport assertions. Production book membership is obtained from the actual
palette, with no invented IDs.

Direct changed Release cases:

- `testNativeVoiceOverSpeaksRealOverviewAndPaletteControls`
- `testPointerHoverClickAndHardwareKeyboardDismissal`
- `testSystemReduceMotionKeepsOriginalPaletteUsable`
- `testCandidateWindowResizePreservesOriginalReaderAndSearch`
- `testEnglishReaderAndOriginalPaletteInLeftToRightLayout`
- `testSidebarPreservesOriginalTextKitViewport`
- `testSourceToolbarPaletteAndOverview`
- `testReaderDocumentAndGlobalBarsCollapseAndRestoreOnManualScroll`
- `testNewEmptyGroupAndRelaunchPersistence`
- `FaithfulProductionReleaseTests/testRealProductionLibraryReaderAndGroupRestore`

The shared actual-window helper also affects the already selected
`R27NativePadTests/testNormalBootstrapNativeWindowResizePaletteAndInspector`.
The pending Native88 feature-off and profile-color cases exercise the preserved
flag-off path and the existing profile-management toolbar respectively.
Existing overview, group, phone, native routing, and reader tests remain
required regression scope. No case selection/count is changed here.

## Actual evidence

- `PORTABLE_VERIFICATION.json`: exact compiler/runtime results and named
  assertions. Base legacy binding compiles, runs, and fails exactly the enabled
  iPad getter/setter controls (2); the other 6 controls pass. Candidate passes
  all 62 controls, including original threshold, late mount, close-before-mount,
  stale/duplicate UUID, stale anchor, wrong reader/window/session, inactive
  scene, feature-off and real valid-path controls.
- `verify_portable_lifecycle.py`: extracts the actual current production
  lifetime, window qualification and scroll consumer methods, plus the original
  base legacy binding. It compiles them with explicitly documented substitute
  UIKit/Binding types. Generated compiler inputs and executables are kept under
  ignored `build/overview-release-ui-20261120`.
- `SOURCE_VALIDATION.json`: all 11 changed Swift files parse successfully;
  Windows sysroot warnings are retained, so this is not Apple SDK proof.
  Project app/package source registration passed (153 existing Otzaria ownership
  entries). All 39 original test names, exact original delegate parity, and
  unchanged R27 LF digest are recorded.
- `SOURCE_CONTROL_PROVENANCE.json`: actual source and LF hashes for current
  palette commands/results and original overview card/close labels. Parsed
  project membership proves the coordinator's new UIKit import and new
  lifetime file belong only to the `Maktabah-iOS` Sources target.

Reproduce portable logic with a Swift 6 toolchain:

```text
python docs/hq-integration/overview-release-ui-20261120/verify_portable_lifecycle.py --swiftc <absolute-path-to-swiftc>
```

## Bootstrap and prior-run boundaries

The existing Faithful default remains `.smoke`: real UI with the existing
DEBUG bootstrap bypass. R27 remains `.realUI`: normal bootstrap with explicit
provider preselection and its existing actual-source scenario setup.
The production Release case remains `.production`, without a DEBUG scenario.
Its runner provisions the full corpus before replacing the app with the
Release binary; this is not evidence that Release itself downloaded the corpus.
Full-v32 installation acceptance is separate.

No old Native75, Native78, SDK, or full-v32 result is transferred to this source.
Native78 run `44633736259` is independently watched on checkout
`7d05dd0bb25a7df307b35174e49e18d0f22eecee` / app
`5d8ef991554b01ba6bf3d39222c5ef6cc00a264b`.
No dispatch or cancellation was performed by this change.
