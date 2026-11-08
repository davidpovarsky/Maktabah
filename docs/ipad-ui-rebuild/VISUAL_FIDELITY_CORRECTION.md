# Visual fidelity correction — 2026-11-08

Working tree: `Maktabah-ipad-ui-faithful-rebuild`; branch `experiment/ipad-ui-faithful-from-9401`; start SHA `661d53e0541779ae6c9ed7526cae5b1f273c708d`. Primary session, no subagents, no Asana writes, no reset or main merge.

## Original-source review

`source-audit-20261108.json` records 31 actual pinned original/port comparisons. All previously recorded original hashes match the previous manifest. Fourteen comparisons are normalized-text identical, including the entire original TorahSegmentDetailView at `19d1b35397af4f10ae70cfb3f444c9de87383b53`. All ten requested DuckDuckGo source files, the owner Safari Swift source/archive and Gelatin source exist. Changed source-to-port patches are refreshed under `source-diffs/`.

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

New candidate build/UIKit/UI/visual results: pending. Local portable suites: 379/379 assertions and 61/61 workspace checks passed. TestFlight: not dispatched. A source comparison or Windows compile cannot establish UIKit/SwiftUI visual acceptance.

## Validation follow-up

The complete initial `1a6515d3` matrix remains running. The original `f092f399…` reference run 42500710349 built successfully but failed before XCTest: installing the tiny original Safari oracle timed out on runtime 27.2, then `simctl list devices -j` timed out during the recorded owned-device restart. No screenshot or app-acceptance result is claimed from that failed infrastructure attempt.

Available-runner evidence confirms runtimes 27.0, 27.1 and 27.2 and a successful original preflight on 27.0. Subsequent comparisons prefer the installed SDK's matching 27.x runtime, retaining the 27-major gate, supported-device checks, immutable reference SHA and exact case verification. This does not assert 27.2 is unsupported or identify the root cause of the service timeout. The superseded retry 42504499979 was cancelled before Native tests; replacement reference 42504883842 uses this explicit SDK-matched preference.

Manual diagnostics have a separate concurrency suffix from a full matrix so verifying the final font correction does not cancel an already-running complete matrix. No automatic trigger, test assertion, test selection default, release gate or diagnostic `fullMatrixAcceptance=false` safeguard is changed. This workflow is fork-owned (absent from the pinned upstream tree).

Experimental signed production-profile TestFlight run 42505423827 targets exact app source `c9386186093e499a8952e39f70f677c6eb264c79`, build 10201. The owner's current attachment explicitly permits experimental delivery without a complete green Native gate. This is not Production approval; archive/export/signature/upload/Apple processing still must pass. Subsequent changes are verification metadata/CI only; app source is identical.
