# Reader / source overview context replacement

Owner request: replace the reader with the source overview, no sheet, retain reader state/scroll, inspect real Simulator screenshots, then deliver corrected TestFlight. Execution: `[נועם | DEV] [MAIN_SESSION]`, NORMAL; QA in the same primary session. No subagents, Asana writes or main merge.

Start: `e95e4269f3bd48a95fcbdb3a9f630c48f55650cc`, branch `experiment/ipad-ui-faithful-from-9401`. Build10401 is the older rejected sheet presentation. Build10501 was cancelled before Archive/upload. Earlier passes do not verify this replacement.

## Source and implementation

Pinned DuckDuckGo `f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32`, `Main/MainViewController+Segues.swift` lines241/290/293/297: `segueToTabSwitcher`, custom transition delegate, `.overCurrentContext`, native `present`. The source WebViewTransition fills the context's final frame. [Original source](https://github.com/duckduckgo/apple-browsers/blob/f1d574485cf2f0586bcb284e8b3ca8c2f6ff7f32/iOS/DuckDuckGo/Main/MainViewController%2BSegues.swift#L241).

`ReaderOverviewPresentation` is a nonvisual context-sized UIKit anchor attached to the existing host. It uses the source presentation contract and explicit close actions. The reader stays mounted; no rehosting, recreation, scroll/delegate writes or restoration on Done. [Apple's view-retention contract](https://developer.apple.com/documentation/uikit/uimodalpresentationstyle/overcurrentcontext).

Both iPad and enabled-phone hosts replace their overview sheet entry. Source Grid/List and the public group selector remain. Separate existing profile-management sheets retain their behavior. Selecting the active card closes without navigating/restoring its reader. Opening the overview does not reveal reader chrome and move its viewport. The browser's WebKit-specific snapshot transition has no reader equivalent; no fictitious preview or new animation is invented.

## Ownership and checks

Production Swift edits are downstream: new ReaderOverviewPresentation.swift, ChavrusaReaderHost.swift, CompactStudyWorkspaceHostModifier.swift and StudyGroupsOverview.swift. Original reader/library/search/notes/bottom bar/navigation managers, pins and project settings remain unchanged from this correction's start. The protected project has exactly four additive iOS membership entries for the new adapter, under the existing owner-authorized registration seam; see OWNERSHIP_AND_AUTHORIZATION.md and PROTECTED_HUNKS.diff.

Actual UIKit tests inspect style, absence of a sheet controller, context bounds, touch routing, retained scroll view/exact offset across repeated returns, and close-before-attachment behavior. The existing UIApplication-hosted source test workflow compiles/runs the real adapter.

Three actual-app cases cover iPad landscape/portrait and conventional iPhone: genuine manual scrolling, full-context bounds, covered original controls, Grid/List, Done return and active-card return; exact TextKit object/source character/pixel-anchor preservation. Before/overview/after full-display screenshots and hierarchies are required. The existing read-only DEBUG viewport observer is also attached to the enabled phone; production has no additional observer.

## Verification and delivery

App source: `20bff505d3ee735d43201a35f4f9cd2e1fd56894`.

- **SDK PASS:** [42528223635](https://github.com/davidpovarsky/Maktabah/actions/runs/42528223635), Xcode27.1 / 27A9275, real iPhoneSimulator27.1 SDK, object-code generation of the actual adapter/component-test sources and black-box UI tests. All61 workspace contracts passed. This is not runtime/visual acceptance.
- **UIKit source/component PASS:** [42528226791](https://github.com/davidpovarsky/Maktabah/actions/runs/42528226791), actual Simulator step completed successfully at 2026-11-08 22:19:43 UTC. Final console verifies43 UIKit cases/zero failures, including both ReaderOverviewPresentationTests, plus4 chrome-state and45 CommandPalette tests. All61 workspace contracts passed.
- **Actual app build FAIL / UI NOT_RUN at20bff505:** the same Native run failed because ReaderOverviewPresentation.swift was missing from the explicit app Sources phase. Self-contained SDK/component checks did not establish production membership. Four additive registration entries correct this; the existing Sources-phase verifier now runs before the costly faithful SDK/component/app stages and checks this adapter. No presentation-code or test-assertion change. The previous run produced no replacement screenshots and is not app/visual acceptance.
- **Actual-app capture/return acceptance PENDING on the registration correction:** do not dispatch the corrected TestFlight upload before the three replacement cases and full-frame captures have been reviewed. The next exact diagnostic selection contains these three cases; the unrelated broad toolbar/drag case was not reached in the failed build and is not counted as executed. Other Native failures must retain their exact SHA and cannot be called a full quality pass.
- **Corrected delivery NOT_DISPATCHED.**
