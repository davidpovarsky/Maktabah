# U QA follow-up — 2026-11-15

[מיה | UX] [MAIN_SESSION]. Review input: Roni/Q on immutable `ac22bd3bf2eafad3936236eb699735e1c78e8835`; app source remains implementation `d77045feb24f1dc025e0554b2a2bf252a3bf5e14`. This follow-up changes prepared tests/docs only.

## U-QA-01 — functional catalog search oracle (prepared NOT_RUN)

The original prepared test checked query echo/retention only; it could pass with disconnected filtering. Corrected it to require:

1. Two real seeded books in the unfiltered native Library tree, `מסילת ישרים` and `בראשית`, reached through actual category paths without opening either book.
2. A no-match sentinel query empties catalog cells. A disconnected search field cannot satisfy this.
3. Query `מסילת` shows the expected `מסילת ישרים` book row and excludes the known nonmatching `בראשית` row, including after each page round trip.
4. Clearing the query restores the original catalog row snapshot and both book rows.

Exact fixture hierarchy labels are not fabricated from golden text queries. The UI run must supply `HQ_SIDEBAR_MATCH_PATH` and `HQ_SIDEBAR_EXCLUDED_PATH`, each a JSON array of the real root/category/book labels exported from the already provisioned **miniTest10/v6** corpus. Last elements are constrained to the two titles above; missing paths fail closed. Source identity is `Source/Otzaria/DataProfiles/miniTest10.profile.json` (10 IDs; DB SHA256 `d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef`). Export paths from the fixture's canonical `book.categoryId` and `category.parentId/name` chain, matching the existing `OtzariaLibraryDataAdapter`. Configure category grouping in fixture setup. No DB was opened, copied, installed or downloaded here. These two path environment values have **not been generated/verified** in this lane; fixture provisioning remains a prerequisite, not a claimed test PASS.

Prepared coverage now includes **20 fixed-direction body transitions and 20 dot transitions per language** (10 round trips each), with actual reader identity checks. The historical suite is no longer the only prepared source of 20-dot coverage. All these runtime assertions remain NOT_RUN.

## U-QA-03 — toolbar ownership oracle (prepared NOT_RUN)

On TOC, the prepared case now requires the localized TOC title and exactly one visible sidebar search field with the exact localized `Search Contents` placeholder, different from Library's placeholder/query. It continues requiring absence of `toc-close` and one native/custom split toggle. This is intended to catch search/title preference leakage from the two stable NavigationStacks; source inspection alone cannot establish correct runtime toolbar ownership. Actual localized strings were read from `Source/Localizable.xcstrings`.

## U-QA-02 — requested TOC-specific toggle icon remains OPEN

The requested page-specific icon is **not implemented**. It was not covered by the original four-file change, and must not be marked accepted as part of the single-toggle repair.

The exact public candidate was checked in current official Apple documentation via apple-devtools workflow inspection/documentation routing (no authority workflow or SDK build dispatched): [UISplitViewController.displayModeButtonItem](https://developer.apple.com/documentation/uikit/uisplitviewcontroller/displaymodebuttonitem.md). The page declares a get-only `UIBarButtonItem` property, limits it to **classic** split interfaces (it does not affect column-style interfaces), and says: “Don’t change the configuration of the returned button.” It states that UIKit updates the appearance automatically. Our existing downstream helper explicitly operates on `.doubleColumn`, so mutating that classic button's `image` is not a supported solution here. [UISplitViewController](https://developer.apple.com/documentation/uikit/uisplitviewcontroller) also documents automatic appearance of the column-style toggle according to split behavior.

No documented column-style page-specific icon setter was established. Traversing native navigation items to overwrite a discovered system item's image would depend on undocumented containment/identity and could be overwritten on mode changes. It was not implemented. A custom replacement could offer a page-specific symbol but changes toggle ownership and requires a separately scoped design/lease; no duplicate custom button was added. Keep the icon criterion OPEN pending an approved supported alternative or an explicit owner decision to retain UIKit's system symbol. Physical runtime remains NOT_RUN. This is a concrete API/constraint finding, not a claim of universal API impossibility or permission to close the requirement.

Validation in this follow-up: changed UI-test file syntax parsed with local Swift frontend; `git diff --check` passed. No SwiftUI/UIKit/XCTest typecheck, build, CI, simulator or device run. Prior 27 policy assertions remain prior evidence at d77045fe; they are not rerun or counted as runtime evidence for these test-only changes. Historical guard FAIL_CLOSED remains recorded unchanged.
