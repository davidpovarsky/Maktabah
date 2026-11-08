# Visual fidelity correction — 2026-11-08

Working tree: `Maktabah-ipad-ui-faithful-rebuild`; branch `experiment/ipad-ui-faithful-from-9401`; start SHA `661d53e0541779ae6c9ed7526cae5b1f273c708d`. Primary session, no subagents, no Asana writes, no reset or main merge.

## Original-source review

`source-audit-20261108.json` records 30 actual pinned original/port comparisons. All original hashes match the previous manifest. Fourteen comparisons are normalized-text identical, including the entire original TorahSegmentDetailView at `19d1b35397af4f10ae70cfb3f444c9de87383b53`. All ten requested DuckDuckGo source files, the owner Safari Swift source/archive and Gelatin source exist. Changed source-to-port patches are refreshed under `source-diffs/`.

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

New candidate build/UIKit/UI/visual results: pending. TestFlight: not dispatched. A source comparison or Windows compile cannot establish UIKit/SwiftUI visual acceptance.
