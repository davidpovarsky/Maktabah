# Native follow-up: verified failure and restoration repair

## Status

Code commit: `f5d53f3928e8a2319de19373103dcbe3f3153e3c`, parent `f802143e9ec15e624f71ecd81899ad42a1217ce2`.
Only product change: `Source/UI/iOS/Views/iOSMainView.swift`.
Full-file Swift syntax and 18 new compiled restoration controls passed.
**Native acceptance of this repair remains PENDING. No Apple UI test was rerun during publication.**

The original [run44969361774](https://github.com/davidpovarsky/Maktabah/actions/runs/44969361774)
completed FAILURE at2026-11-22T02:36:42Z on wrapper
`3bb181f4d3ca1bde9f1ce43de40d1f3658d821c5`, application source
`62095a46f3eda10df87fad49812083ba163ee3ef`. App and UI runner build passed.
All six original cases executed: **3 PASS / 3 FAIL / 0 SKIP / 0 NOT_RUN**.
The successful observer job recorded a failing GitHub run; it is not an app acceptance pass.

| Original case | Actual result |
| --- | --- |
| `FaithfulReaderUIAcceptanceTests/testSystemReduceMotionKeepsOriginalPaletteUsable` | PASS |
| `FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal` | PASS |
| `R27NativePadTests/testNormalBootstrapPaletteHIDComparison` | PASS |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchLandscapeMatchesOriginalNavigation` | FAIL: restored-tab candidate y86 versus original y106, tolerance1 |
| `FaithfulReaderUIAcceptanceTests/testCandidateGlobalSearchPortraitMatchesOriginalNavigation` | FAIL: restored-tab candidate y106 versus original y86, tolerance1 |
| `R27NativePadTests/testNormalBootstrapPaletteKeyboardDispatchCalibration` | FAIL: selected-result comparison after real DownArrow |

The passing cases remain evidence for their exact original source. They are not automatically
credited to a later source or rerun without a relevant change.

## Actual restored-tab evidence

`GLOBAL_NAVIGATION_FRAMES.json` derives both native navigation bar frames from all eight original
capture hierarchies. Raw TXT files, XCTest export manifests and four restored-tab PNGs are retained.

For `lastSelectedTab=0`, flags-off and candidate agree at navigation y106 in both orientations.
For `lastSelectedTab=3`, landscape candidate uses y86 while flags-off uses y106; portrait flags-off
uses y86 while candidate uses y106. The native tab buttons remain at y32 through y76.
The containing Search split-view starts at y32 or y96 respectively. Both real navigation bars,
search input, history and book sidebar move together; bar widths/heights remain the same.
This is visible in the retained PNGs. The flags-off original also enters the alternate layout.

The source initialized `iOSMainView.selectedTab` to Reader, restoring the saved destination only
from `iPadLayout.onAppear`. A restored global destination could first mount a Reader container,
whose original and enabled implementations have different structures. The previous changes to
tab-bar visibility alone did not make restored startup deterministic.

## Bounded repair

The existing scene composition root now reads the existing `lastSelectedTab` before first TabView
construction, applies the existing `iOSTab.canonical` and backend availability rules, creates one
original navigation manager, and initializes selected tab and current mode together. Missing or
invalid preferences fall back to Reader; unavailable Search/Authors also fall back to Reader.
Each scene retains its own original manager.

Existing iPad/iPhone onAppear normalization, saved preference writes, backend-change handling,
Reader session restoration, tab-bar policies and UI tests remain byte-identical to the base.
No offset, inset, UIKit override, delayed retry, tolerance/deadline change, assertion removal or
feature disablement was added. This eliminates the transient initial Reader destination; the
original native comparison must still demonstrate the resulting geometry.

`SOURCE_REVIEW.json` records exact input/output hashes, a complete inverse proving no other change
in iOSMainView, preserved adjacent sources/tests, and equality of the failing app's iOSMainView
preimage with the integration base.

This authorized development change touches a protected composition root. Its exact final hunk
must remain in the final owner patch manifest. No owner signature or approval record was invented.

## Controls executed once

`tools/test_initial_global_navigation.py` compiles the exact existing enum and the new initializer,
with declared narrow doubles for SwiftUI State, UserDefaults, backend capabilities and manager
storage. Seventeen preference/capability cases cover legacy canonical tabs, supported tabs,
missing/corrupt preferences, unavailable modes, mode alignment before mounting, one manager/read
per initialization, and no preference mutation. One scene-identity control checks independent
managers and stable first-scene state. The complete iOSMainView also passed Swift frontend syntax.

Raw commands, compiler output, exact compiled harness and source hashes are under `controls/`.
These results do not prove SwiftUI State behavior, actual UserDefaults persistence, UIKit layout,
Apple typechecking or physical-device acceptance. Existing passed component suites were not rerun.

## Keyboard coordination

The retained calibration before/after AX snapshots and images were handed to the root integrator.
Its independent inspection found real selected-row movement from recent Genesis to catalog
Genesis after DownArrow; those rows have the same label but different original item identities.
Root owns the separate exact-item-ID accessibility/test correction. This branch changes no
keyboard implementation or keyboard UI assertion.

## Artifact integrity and durable evidence

| Artifact | Bytes | SHA-256 | ZIP entries |
| --- | ---: | --- | ---: |
| Evidence14735253756 | 20,480,209 | `228e3fd02e3063afbc3cb8a59cc3d85907219399c48ab7fb870a1ff1585971a6` | 99 |
| Captures14736147772 | 433,737,125 | `97e5a1de4128a282d631abe104fa273ad77b5b1ba010e6fbc84ef47290c0252d` | 3,015 |

Both full archives matched GitHub digests and passed every member CRC. The first bounded captures
transfer timed out after480seconds; retained240,009,216bytes were resumed with validated HTTP Range
for the remaining193,727,909bytes. No second full download or Native execution was started.
Small priority AX/PNG ranges unblocked analysis; all17 priority files were later proven identical
to the fully verified archive.

Raw archives remain at
`C:\Users\DAVID\Code\Maktabah-release-push-consumer-20261122\build\native6-44969361774`.
The repository retains exact run/jobs metadata, source/binary bindings, all three original case
summaries and test records, failing case logs, input diagnostics, capture manifests and relevant
raw AX/PNG entries. `FILE_HASHES.json` binds every evidence payload; `.gitattributes` preserves bytes.

## Remaining acceptance

Integrate this source with the separately owned keyboard correction and Repository repair, bind
one exact application source, then run both original Search comparisons and affected keyboard
calibration. Preserve all existing assertions and genuine HID interaction. Root owns the focused
wrapper/source freeze and subsequent full Native/Release gates. No task was marked complete.
