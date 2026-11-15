# Build11201 sidebar acceptance — 2026-11-15

[מיה | UX] [MAIN_SESSION] · U lease · GIDs 1220036777923344 / 1220036883843537.

## Executed local evidence

- `py -3 tools/hq-sidebar-check.py`: PASS. Existing actual `ReaderSidebarPolicy` suite: **27 assertions**; unchanged tiling bounds, compact behavior, finite values and dot-strip RTL/diagonal/vertical policy. This does not exercise native body paging.
- Swift 6.3.3 frontend syntax parsing: PASS for coordinator, iPadLayout, iOSTOCView and prepared UI tests, plus pager with its Apple branch activated in a temporary copy. This does not resolve SwiftUI/UIKit/XCTest declarations.
- `git diff --check`: PASS.
- Remote upstream ref read: pinned SHA confirmed with `git ls-remote`, no fetch/merge/write.
- Manual ownership audit: only four leased source files; two narrowly scoped upstream hooks; no new app Swift source or project/target changes.

The first Python invocation resolved to a nonprinting system32 launcher; it is not counted as test evidence. Re-ran with `py -3` and recorded actual PASS output. An initial active-branch parse used an unsupported `-x` option; corrected with temporary `.swift` input and passed in the checked-in bounded runner.

## Prepared runtime regression cases — NOT_RUN

`Tests/HQ/sidebar/Sidebar11201AcceptanceTests.swift` contains two direction-specific cases. They use the existing app and isolated miniTest10 fixture, not mocked view implementations. Include this file in the existing UI-test target alongside `FaithfulReaderUIBase` only for an authorized run; no target membership or CI was changed here. Existing fixture dependencies and `FAITHFUL_VIEWPORT_DIRECTORY` must be configured. Test files have syntax coverage only, not Apple SDK compile coverage.

Each case types a genuine native Library query, performs five round trips using fixed physical direction in the center of the body (never the dots and never an opposite-direction retry), checks selected dots, search-query retention, one sidebar toggle/no `toc-close`, canonical reader title/locator, actual TextKit object/source/offset, and vertical scrolling. Diagnostic screenshots/hierarchy are retained. Native transition continuity and physical-device gestures still require human visual/runtime review.

The existing `FaithfulReaderUIAcceptanceTests/testSidebarPreservesOriginalTextKitViewport` also covers row/scroll retention, repeated dot changes and reader width/viewport; its old swipe test retries the opposite direction and therefore cannot alone prove RTL correctness. It was not modified or executed in this lane.

## Remaining acceptance matrix

| Scenario | Expected | Actual/status |
| --- | --- | --- |
| Library native search, keyboard/focus, category navigation | Search stays visible and canonical query/tree history survive round trip | NOT_RUN |
| Native horizontal body gesture, Hebrew RTL and English LTR | Correct physical direction; interactive transition and cancellation; two working dots | NOT_RUN |
| Vertical list rows, expansion/selection and edge swipe/back | Vertical scrolling and row interactions retained; native screen-edge action wins appropriately | NOT_RUN |
| Toggle ownership in Library, TOC, loading, empty and failure states | One functioning native split action, visible/openable with proper accessibility | NOT_RUN |
| Standalone/non-pager TOC sheet | Original Close action remains | NOT_RUN |
| Multiple reader tabs, active-tab TOC identity | TOC follows UUID without remounting reader; selected node stays accurate | NOT_RUN |
| Sidebar close/open, compact split, Stage Manager, rotation | Canonical visibility/compact bindings and reader mount/anchor preserved | NOT_RUN |
| VoiceOver, keyboard, Dynamic Type, Reduce Motion | Hidden page not accessible; no toolbar leaks or clipped control | NOT_RUN |
| Physical iPad runtime/visual evidence at final SHA | All affected scenarios with OS/model/screenshots | NOT_RUN — required before closure |

Status: implementation prepared for QA; both tasks remain open. No full build, project CI, expensive compile, simulator, TestFlight or user-data operation executed.
