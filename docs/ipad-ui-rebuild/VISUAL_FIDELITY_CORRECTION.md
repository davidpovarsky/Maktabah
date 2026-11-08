# Visual fidelity correction — 2026-11-08

Working tree: `Maktabah-ipad-ui-faithful-rebuild`; branch `experiment/ipad-ui-faithful-from-9401`; start SHA `661d53e0541779ae6c9ed7526cae5b1f273c708d`. Primary session, no subagents, no Asana writes, no reset or main merge.

## Original-source review

`source-audit-20261108.json` records 32 actual pinned original/port comparisons. All previously recorded original hashes match the previous manifest. Fourteen comparisons are normalized-text identical, including the entire original TorahSegmentDetailView at `19d1b35397af4f10ae70cfb3f444c9de87383b53`. All ten requested DuckDuckGo source files, the owner Safari Swift source/archive and Gelatin source exist. Changed source-to-port patches are refreshed under `source-diffs/`.

Further pinned-dependency review found the original `DesignResourcesKit/Fonts/Font.swift` factories in Git objects, even though that dependency folder is not checked out in the reference tree. Its `daxBodySemibold`, `daxSubheadSemibold` and `daxFootnoteSemibold` functions are now copied exactly, with private file scope, replacing the earlier UIFontMetrics/system-size approximations. Original SHA-256: `9ca6e76e744090cb10984d40fe770de2051dd3b24d81f5fcefac2adaf7bd4b33`. This follow-up is later than the initial `1a6515d3` full matrix; focused exact-source SDK/native verification is separate.

| Component | Original and precise integration |
|---|---|
| Inspector | Unmodified TorahInspectorKit `19d1b353…`; `usesMinimalChrome=false` restores regularMaterial, continuous 22pt corners, 1pt border, original shadow and 8pt padding. Only the two optional headings stay hidden. The existing workspace state machine always floats the enabled-sidebar Inspector, so it never reserves a brown docked column. |
| Safari toolbar | Owner `SafariToolbarSearch-MyApp.swift`, `safariToolbar(compact:)`: original HStack 6/11pt spacing, 54pt row, 52pt SafariGlass/GlassButtonGroup surfaces, 39×44pt source button geometry, original overview-plus group. One native principal ToolbarItem owns the full composition. Original library search, matched geometry ID, spring and Gelatin motion-only are retained. |
| Toolbar adaptation | Browser-only share/download/back demo actions are omitted. Existing native Maktabah book-info/Inspector actions remain attached to their original reader. iPadOS27 retains its required native split sidebar action; earlier regular-width systems use the existing source sidebar group. The width reservation accounts for native split/actions; Native narrow-window verification is required. Only duplicate opaque navigation-bar backing is hidden; SafariGlass remains the material provider. |
| Open books | Original DuckDuckGo controller/layout/cells/flare at `f1d57448…`. The host moves the overview/add actions into Safari and supplies `showsToolbarButtons=false`; the source controller default remains true. Hidden source controls reserve zero width; unchanged TabsBarLayout takes zero button width/gap. Empty membership has zero host height, hit testing and accessibility. Original folding, selection, close, pointer, drag and scroll code remain. |
| Overview | Retain existing source Grid/List collection/cells, exact 14pt spacing, 1–4 columns, 140–209pt grid height, 2.7-row rule, 664pt list cap and 70pt rows. Match original drop animation completion order. Stable-ID/local-controller/membership guards reject stale and foreign drags. Existing original RTL swipe, context actions, mode toggle and public ScrollableTabBar fallback remain. No replacement grid or snapshot service is added. |
| Sidebar | Keep the mounted original Library and TOC UIKit trees, swipe/tap actions and 44pt dot targets. Move the existing two dots to a transparent bottom safe-area inset; remove `.background(.bar)` and its full-width surface. |
| Scrolling | Existing downstream pan-distance state and original delegate notification hooks remain; no offset, renderer or delegate replacement. Native collapse/restore and unchanged TextKit identity remain required gates. |

ScrollableTabBar intentionally uses its original public AdaptiveTabContent at `abcd4ed8…`; private UIKit/ABIBridge paths remain excluded. CommandPalette remains the original module at `9ed36f80…` with the already documented query-binding adaptation. Gelatin movement remains the owner's original motion-only equations; no saturation/brightness changes. Reader preview capture is unavailable in the original app; the existing honestly unavailable overview preview remains a documented domain adaptation, not a fidelity claim for browser screenshots.

## Ownership

All production edits are downstream ChavrusaText/Otzaria adapters or source ports, except the essential enabled-path return in `iOSReaderWorkspaceView.swift` documented in OWNERSHIP_AND_AUTHORIZATION.md. No library, search engine, bottom-toolbar action, book navigation, annotation implementation, Inspector package source, package pin or project membership changes.

## Verification status

Before evidence is the actual `661d53e0` run [42447373973](https://github.com/davidpovarsky/Maktabah/actions/runs/42447373973), artifact `faithful-native-evidence`. It includes genuine UIKit/app tests and screenshots; it failed Native acceptance. Its screenshots show the separated toolbar groups and full-width white dot footer. They are comparison evidence only.

New real UIKit coverage checks 0/1/2/30 book membership with toolbar-owned controls and no reserved trailing action area. Native coverage now checks overview/add reachability and strip absence for an empty group before/after relaunch, plus constant reader width across FloatingPanel closure. Existing strict regression assertions are retained.

The screenshot helper now retains actual screenshots/hierarchies **before** its unchanged strict native-settling assertion, labelling timed-out images `UNSETTLED-`. Such images are diagnostic, never automatic acceptance. A separate original-Inspector case retains its source screenshot before the unchanged reader/pixel assertions can abort. No failing assertion was removed or relaxed. The focused SDK compiler now includes all nine actual source-port files alongside the existing real standalone toolbar/pager sources; no stubs or replacement app views.

Latest candidate source is `dd7b1eb5119544ed28c12d1ea4a3653dddce9842`. Focused SDK run [42510176334](https://github.com/davidpovarsky/Maktabah/actions/runs/42510176334) passed actual Xcode27.1/27A9275 object-code generation for all 13 real standalone/source-port files, the real UI test sources and 61 workspace contracts. Local portable suites passed 379/379 assertions and 61/61 workspace checks. Final Native diagnostics [42510775166](https://github.com/davidpovarsky/Maktabah/actions/runs/42510775166) and experimental TestFlight build 10301 [42510779413](https://github.com/davidpovarsky/Maktabah/actions/runs/42510779413) remain in progress. Neither SDK code generation nor Windows checks establish visual acceptance.

## Validation follow-up

The complete initial `1a6515d3` matrix remains running. The original `f092f399…` reference run 42500710349 built successfully but failed before XCTest: installing the tiny original Safari oracle timed out on runtime 27.2, then `simctl list devices -j` timed out during the recorded owned-device restart. No screenshot or app-acceptance result is claimed from that failed infrastructure attempt.

Available-runner evidence confirms runtimes 27.0, 27.1 and 27.2 and a successful original preflight on 27.0. Subsequent comparisons prefer the installed SDK's matching 27.x runtime, retaining the 27-major gate, supported-device checks, immutable reference SHA and exact case verification. This does not assert 27.2 is unsupported or identify the root cause of the service timeout. The superseded retry 42504499979 was cancelled before Native tests; replacement reference 42504883842 uses this explicit SDK-matched preference.

Manual diagnostics have a separate concurrency suffix from a full matrix so verifying the final font correction does not cancel an already-running complete matrix. No automatic trigger, test assertion, test selection default, release gate or diagnostic `fullMatrixAcceptance=false` safeguard is changed. This workflow is fork-owned (absent from the pinned upstream tree).

The cancelled first experimental signing attempt 42505423827 targeted `c9386186093e499a8952e39f70f677c6eb264c79`, build 10201. It was cancelled during Archive after inspecting the genuine old expanded-palette capture. Final job evidence confirms that exported-IPA validation, upload and Apple processing were all skipped; build 10201 was not delivered. The owner's current attachment explicitly permits experimental delivery without a complete green Native gate. This is not Production approval; archive/export/signature/upload/Apple processing still must pass for the replacement build.

## Expanded search integration correction

The actual `661d53e0` capture `563CC6E9-8F4F-47FB-8D90-B32EBA3CB498.png` shows global tabs over the palette input and an opaque rectangular backing beyond its source corner. Those host paths were unchanged in the first correction, so they required a further engineering fix before delivery.

The palette's UIKit hosting view is now clear/nonopaque; the original CommandPaletteView retains its own material, 22pt shape and shadow. Two nonvisual public-UIKit window-origin probes connect the actual native toolbar to the original expandedSearch placement. They do not draw controls or change any native bar, safe-area preference, reader subtree, delegate or offset. Window coordinates avoid assuming two native hosting graphs share a SwiftUI coordinate space. While expanded, weak-target main-run-loop display links track native bar movement; they stop when closed/detached and the host closes library search on disappearance.

The original toolbar's outer 7pt top padding and expandedSearch's 6pt padding determine the placement: `expandedY = actualToolbarTop - 7 + 6`, retaining the original 2pt relationship to the 52pt collapsed surface centered in the 54pt row. Original source geometry, matched geometry identity, spring and Gelatin code remain. No new visual composition or animation is introduced. A real native-frame assertion now requires the typed palette input to clear the global History tab's actual frame; the keyboard screenshot is retained before that assertion.

Execution: `[נועם | DEV] [MAIN_SESSION]`; evidence review: `[רוני | QA] [MAIN_SESSION]`. This is one primary session, no independent subagent review. The worktree's common Git directory is the approved Maktabah repository; team/role instructions and relevant Asana task state were read. Safari task `1220036884173010` and tabs/groups task `1220103384037482` remain open; no Asana writes are authorized or performed.

## Immutable original reference result

Reference run [42504883842](https://github.com/davidpovarsky/Maktabah/actions/runs/42504883842) completed PASS: original app `f092f3996927251d105dfb9243dfac487b196534`, test source `c9386186093e499a8952e39f70f677c6eb264c79`. All four selected methods actually executed and passed, with no missing methods: original Safari compact/expanded oracle; original Inspector reference; reader/library/search/annotations/Inspector captures; original Light/Dark/Sepia captures. This is an 11-inch diagnostic reference, not full-matrix acceptance. The recorded actual runtime was 27.2, SDK27.1; the preference did not produce a matching runtime in this run. Comparisons must retain the recorded runtime rather than imply identical environments.

Actual images and exact per-case execution evidence are retained at `C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/original-9401-passed/`. Source compact/expanded and original Inspector images were visually inspected in the primary session. Original Inspector capture retains its source rounded material card and the old docked surrounding brown column; the requested integration deliberately removes that column while preserving the card. No candidate visual approval follows from the successful original reference.

## Complete changed-file inventory

Delta from the user's starting commit `661d53e0` (including tests, provenance and CI; this inventory is generated from Git):

- `.github/workflows/sefaria-embedded-validation.yml`
- `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift`
- `SOURCE_TO_PORT_DIFF.md`
- `Scripts/CI/run-faithful-ipad-matrix.py`
- `Scripts/CI/typecheck-faithful-ui-tests.py`
- `Source/ChavrusaText/ReaderHost/ChavrusaReaderHost.swift`
- `Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift`
- `Source/ChavrusaText/StudyWorkspace/UI/DocumentTabsHost.swift`
- `Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/TabSwitcherPagePort.swift`
- `Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/TabsBarView.swift`
- `Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/TabsBarViewController.swift`
- `Source/ChavrusaText/StudyWorkspace/UI/DuckDuckGoTabsPort/Tests/TabsLifecycleTests.swift`
- `Source/ChavrusaText/ToolbarSearch/LibraryCommandPaletteAdapter.swift`
- `Source/ChavrusaText/ToolbarSearch/ReaderToolbarActionAdapter.swift`
- `Source/Features/Reader/iOS/iOSReaderWorkspaceView.swift`
- `Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift`
- `docs/ipad-ui-rebuild/OWNERSHIP_AND_AUTHORIZATION.md`
- `docs/ipad-ui-rebuild/PROTECTED_HUNKS.diff`
- `docs/ipad-ui-rebuild/STATUS.md`
- `docs/ipad-ui-rebuild/VISUAL_FIDELITY_CORRECTION.md`
- `docs/ipad-ui-rebuild/source-audit-20261108.json`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-Font.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabSwitcherPageViewController.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabViewCell.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabViewGridCell.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabViewListCell.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabsBarView.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/DuckDuckGo-apple-browsers-TabsBarViewController.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/Owner-Safari-ChavrusaReaderHost.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/Owner-Safari-LibraryCommandPaletteAdapter.swift.diff`
- `docs/ipad-ui-rebuild/source-diffs/Owner-Safari-ReaderToolbarActionAdapter.swift.diff`
- `docs/ipad-ui-rebuild/source-provenance.json`

## Experimental TestFlight delivery — verified

[Run 42510779413](https://github.com/davidpovarsky/Maktabah/actions/runs/42510779413) completed SUCCESS for exact app commit `dd7b1eb5119544ed28c12d1ea4a3653dddce9842`, version **1.0.0 (10301)**, production data profile. Automatic provisioning validation, signed Archive, archived entitlement/profile validation, App Store export, exported IPA/signature/bundle validation, App Store Connect validation and upload all passed. Apple processing completed **VALID**, `expired=false`, observed `2026-11-08T19:18:48.718022+00:00`. This is the owner's explicitly authorized experimental delivery without full Native quality approval, not an App Store submission, main merge or Production quality approval.

[App Store Connect — TestFlight](https://appstoreconnect.apple.com/apps/6809559414/testflight). Apple app ID `6809559414`; build ID `0f6c6bbd-dc26-4e37-a97b-6e8c8c7a6855`. Tester-group assignment/installation availability was not separately verified; no public invitation URL is invented. Signed IPA, processing JSON and build evidence are retained externally under `evidence/testflight-10301/` in the supplied rebuild package. No credentials or signing material are committed to the app repository.

Downloaded IPA SHA-256 independently matched the CI checksum: `470623ff66f9805e5519f01cf23ead49ce0ed79c0bda1fead30e25476da3429a`. The actual IPA Info.plist confirms `ChavrusaText`, `com.davidpovarsky.chavrusatext`, version1.0.0/build10301; `local-artifact-verification.json` records this read-only check.

External evidence helpers in the supplied package: `audit_visual_fidelity_continuation.py` (pinned-source/hash/diff audit) and `compare_visual_fidelity_captures.py` (full-frame actual screenshot comparison with native EXIF orientation, no masks or generated UI). These are outside the app repository.

## Actual dd7 Native result and further native-width correction

[Run42510775166](https://github.com/davidpovarsky/Maktabah/actions/runs/42510775166) completed FAIL, not an infrastructure-only failure. Actual hosted components passed: **40 UIKit XCTest cases**, chrome-state Swift Testing and original CommandPalette Swift Testing; app build/install/launch passed. Nine selected 11-inch app cases executed: **4 passed, 5 failed**. Passes: original trimmed Inspector landscape/portrait (including unchanged reader width across close), Light/Dark/Sepia, original sidebar/TextKit viewport identity. The separate phone case failed, so total selected app cases were **4 PASS / 6 FAIL**.

The actual palette screenshot and strict native frame assertion confirm that the expanded typed input clears the global tabs and the rectangular opaque UIKit backing is gone. Original material rounded Inspector and absence of its brown docked column, plus transparent sidebar footer, were visually inspected. Full visual parity is not approved.

Remaining failures: overview did not open from its toolbar action (both main and empty-group cases); LTR and narrow-window strict original bottom-toolbar settling; a lost application process during scroll launch; phone's original book-tabs action unavailable. Grid/List/drop/empty-group later assertions were consequently not reached in this run. No assertion is removed or relaxed.

Evidence identifies two concrete issues for follow-up. The actual native title container was 692pt wide while the fixed source row demanded 734pt in portrait: source overview x4..43 lay partly outside its native host x20..712; landscape has the same 16pt escape. The narrow actual screenshot shows system actions drawn over source actions. The source HStack now accepts the native host's width proposal (`minWidth:0`, existing ceiling retained), instead of imposing an exact width. Source button dimensions, groups, spacing and search composition remain unchanged. New actual bounds checks and pre-assertion diagnostic captures verify source actions and retain evidence if presentation still fails. The original bottom-toolbar settling assertion remains mandatory; narrow source action checks run before that separate gate.

The selected phone was **iPhone Duo**, runtime27.1, with an actual 466x678 window and a different regular/native-toolbar configuration, not a conventional compact portrait iPhone. The matrix now selects a numbered conventional iPhone profile supported by an available27.x runtime; exact type/runtime remain recorded. This does not claim Duo acceptance or change the app's original phone layout. Conventional phone acceptance remains pending.

Actual screenshots, strict execution JSON and logs: `C:/Users/DAVID/Code/ChavrusaText-rebuild-package-20261104/evidence/after-dd7b1eb5/`. Diagnostic/UNSETTLED images remain labelled as such. Build10301 is still the verified earlier experimental binary; a replacement will include the width correction only after its own signed delivery passes.

The actual Sepia comparison also exposed a white unoccupied strip beside the selected source flare. The host already supplied the original reader colors, but did so after `loadViewIfNeeded`; the controller's root background was decorated only at initial load/trait changes. The controller now reuses its existing source `decorate()` only when an injected resolved theme color actually changes. Identical updates retain native cells/interactions. No source color, shape or flare equation is changed. A real UIKit test checks the loaded background, unchanged membership/selection and cell identity under identical theme reinjection. Fresh runtime visual verification is pending.
