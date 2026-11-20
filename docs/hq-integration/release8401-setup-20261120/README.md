# Release A3 ordinary-reader setup and diagnostic 38 recipe

Status: source preparation corrected; candidate Native and Apple typecheck NOT_RUN.

## Authentic failure and bounded correction

Run 44665679661 tested checkout 9cc346601bdb3fdda34c2c6ac59894f71dc9ea49 / app 7e777509d486a17bec5b4bd437a9ac7f51d3a43a.
Build8401SevenDefectsAcceptanceTests/testA3_OrdinaryReaderHasNoClearSearchHighlightButton failed at original line 118, waiting 20 seconds for reader-document-tabs.
It was the third executed case, before CandidateWindow. The sealed run evidence is in docs/hq-integration/release96-44665679661-20261120 (commit f2a4eef9004710be8040e183d8713dc28f73c2c7).
Original failure rows and exact case log excerpts are retained here, without re-running or reclassifying them.

The original Reader strip mounts only while more than one real book is open. It cannot close the last document. Its close control also uses a stable UUID identifier and the original localized Close Tab label; the old setup searched a different Hebrew label prefix.
The correction opens the existing StudyGroupsOverview, closes each observed unique original grid/list UUID through the same RTL swipe already used by the original suite, waits for that exact cell to disappear, and requires both zero remaining cells and the source's actual empty-group state.
The 20-document bound remains. No default/session/sidecar/DB writes occur from XCTest; only the original UI performs closes in the disposable Simulator.

All code before and after this setup is unchanged, including cold relaunch, ordinary Reader existence, absence of clear-search UI, and the original observed zero-highlight assertion.
The original 15-second Reader gate and 600-second native case gate remain. New navigation uses existing 20-second setup existence gates; original 15-second overview deletion waits are reused. These are explicit new setup operations, not a relaxation of the post-relaunch oracles.

## Validation actually performed

- Swift 6.3.3 Windows frontend parse of the one changed test file: exit 0, zero warnings.
- Exact normalized-source inverse: only the A3 cleanup changes; every other test/method and the complete post-cleanup block is identical.
- Original execution_groups and validate_selections: 38 unique selected declarations and exact group partition pass.
- No portable test doubles, Apple typecheck, UI execution, or rendered-highlight success is claimed.

A1's earlier positive-highlight count0 failure remains unresolved. Its original method/oracle is unchanged and included in the diagnostic recipe; the conditionally guarded alternate search-flow case is not used as proof of a positive highlight.

A source-only peer review confirmed the original close-to-zero owner and preserved post-relaunch oracles; its first-card readiness comment was applied with a bounded wait before counting cards.

## Diagnostic recipe

DIAGNOSTIC38_RECIPE.json is an application recipe, not an operational/canonical manifest. Root must first merge the current source fixes, freeze the exact new app/test source and original provenance pins, then derive one immutable diagnostic branch.

Selection: original focused 13 union all original repair 12 = 25 (16 iPad / 9 iPhone), plus 10 unique existing Release methods on11-inch, the existing phone overview method, and A1/A3 = 38 (28 iPad / 10 iPhone).

| Group | Selected | HID |
| --- | ---: | --- |
|11|9|false|
|11-search|8|false|
|11-reader|6|false|
|11-sidebar|1|false|
|11-window|4|true|
|phone|10|false|

Keep top-level HID true and diagnostic_only true. Canonical Native 92 and Release 96 UI plus 2 oracles/five configurations remain unchanged and still required.
The diagnostic branch retains all 92 original rows/history/requirements, appends 13 clearly diagnostic rows (catalog 105), and executes 38. The 67 unselected canonical cases are not passed or waived.
Two Trimmed methods contain four heading assertions; they are two leaves here, not four device executions.

The original R27 ui route supplies actual app Documents through TEST_RUNNER_FAITHFUL_VIEWPORT_DIRECTORY for every group and retains URL, SQL oracle and HID transports. It records actual XCTest/helper hashes and exact source/binary provenance. The old separate ui_diagnostic_cases workflow input is not mixed into this path.
The 11 added Faithful methods retain their existing smoke tier; the 2 Build8401 methods retain smoke/Sefaria. They are actual native UI tests, with no claim of normal-bootstrap coverage. The original 25 methods keep their own unchanged launch tiers.
