# Reader tab-bar policy on inactive global tabs

This is a narrowly scoped production candidate for the four native navigation-geometry failures in Release run 44665679661. It is not a Native PASS or a proven explanation of every captured layout difference.

## Change

`Source/UI/iOS/Views/iPadLayout.swift` retains the original Reader visible/hidden preference while `selectedTab == .viewer`. For an inactive Viewer, the same toolbar modifier uses `Visibility.automatic`. The Search, Annotations, History and Author content, native title styles, header dimensions, window controls, scroll qualification and all test assertions remain unchanged. The feature-off branch is unchanged.

Apple documents that toolbar visibility preferences propagate to the nearest container that renders the corresponding bar, including `TabView`. The existing workspace Viewer set an explicit parent tab-bar preference without checking the global selection; the original feature-off Viewer had no such parent modifier. The selected-tab binding already owns the enclosing TabView and triggers the existing reveal callbacks, so the candidate restores default component policy when Reader is inactive without introducing another owner.

Official references (read 2026-11-20):

- https://developer.apple.com/documentation/swiftui/view/toolbarvisibility(_:for:).md
- https://developer.apple.com/documentation/swiftui/visibility.md

## Original observed failures

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44665679661

Checkout `9cc346601bdb3fdda34c2c6ac59894f71dc9ea49`; app/tests `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`. Original sealed evidence is commit `f2a4eef9004710be8040e183d8713dc28f73c2c7`, folder `docs/hq-integration/release96-44665679661-20261120`. This change does not transfer any outcome from that run to new source.

| Configuration | Existing Native case | First actual mismatch |
| --- | --- | --- |
| iPad 11 | `testCandidateAnnotationsLandscapeMatchesOriginalNavigation` | Navigation height 108 versus original 160 |
| iPad 11 | `testCandidateGlobalSearchLandscapeMatchesOriginalNavigation` | Navigation minY 86 versus original 106 |
| iPad 11 | `testCandidateGlobalSearchPortraitMatchesOriginalNavigation` | Navigation minY 86 versus original 106 |
| iPad 13 | `testCandidateGlobalSearchLandscapeMatchesOriginalNavigation` | Navigation minY 86 versus original 106 |

All four precede the CandidateWindow failure in their respective simulator execution order. In the paired iPad 11 Search AX, the parent region also moves from y96 to y32; in Annotations, the large title moves upward by52 points and visually overlaps the top tab region. Authentic capture references and Git blob hashes are in `PAIRED_CAPTURE_REFERENCES.json`; no duplicate images were created.

## Boundaries and unresolved evidence

The source and captures support a scoped policy correction, but do not establish that this preference caused the native offsets. The parity helper does not pin `lastSelectedTab`, and its capture settlement only waits for Reader-specific geometry; however, consecutive Search failures mean saved selection alone is insufficient to label the problem fixture-only. The original annotation pair also shows a book-title readiness difference (ברכות versus Unknown Book (103)); this change makes no metadata correction or claim. No expected frames, labels, queries, font sizes, header styles or deadlines were adjusted.

## Validation actually performed

- Entire pre-change iPadLayout bytes matched original app7e, integrated comparison a68 and this branch HEAD33fad8. One replacement has an exact inverse restoring that whole file.
- Whole original iPadLayout syntax parsed with Windows Swift6.3.3 at08:13:21UTC, exit0, no diagnostics. This does not load/typecheck Apple SwiftUI.
- Independent read-only source review found no concrete type/lifecycle blocker.
- Apple SDK typecheck: NOT_RUN. Native geometry and active Reader auto-hide/restore: NOT_RUN on this candidate. The existing four cases and Reader behavior checks remain required.

`SOURCE_COMPARISON.json`, `VALIDATION.json` and `EVIDENCE.json` preserve the exact bounds and source-specific observations.
