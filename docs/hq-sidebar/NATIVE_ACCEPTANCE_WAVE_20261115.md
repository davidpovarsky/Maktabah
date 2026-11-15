# U native sidebar acceptance activation — 15 November 2026

The retained Sidebar11201AcceptanceTests file has moved from the unregistered
`Tests/HQ/sidebar` directory into the existing synchronized
`Maktabah-iOSUITests` target. There is one test implementation and no project
membership edit or new harness. Historical portable checks/docs remain evidence
at their original SHAs; they are not native passes.

The two fixed-direction Hebrew RTL/English LTR cases and the added Home/activate/
measured portrait-landscape scene-continuity case now use the normal
realUI bootstrap, exact Otzaria preferred/backend arguments, isolated existing
UUID sidecars and the existing actual TextKit viewport observer. Required iPad
execution fails instead of skipping. The case checks the independent fixture
work key before exercising the sidebar. Native screenshots and hierarchy are
retained at opening and teardown, including on an assertion abort.

FaithfulReaderUIBase exposes two default-preserving test configuration
properties for this subclass. Existing test defaults remain smoke and no
extra arguments. R27NativeUIBase continues to override launchReader entirely;
the selected R27 reader/window case still follows its own realUI launcher.
The old eight healthy cases are historical until exact current source/test/
toolchain/dependency/data compatibility is certified separately.

The existing fixture oracle gains an optional sidebar-path read, enabled only
when Sidebar11201AcceptanceTests is selected. It runs after native installation
verification, confines the database to the owned disposable simulator, uses
SQLite `mode=ro&immutable=1`, independently resolves one exact book and its
complete category ancestry, rejects ambiguous/missing titles, missing parents,
cycles and excessive depth, and verifies unchanged database bytes afterward.
Environment values use the existing TEST_RUNNER forwarding convention.

## Executed evidence

- Seven fixture-oracle tests passed, including three new hierarchy/ambiguity/
  cycle tests. These are helper-unit fixtures, not UI acceptance.
- Existing actual sidebar portable policy: 27 assertions passed. Five source
  syntax parses and diff whitespace checks passed, including the active pager
  branch. Windows does not typecheck SwiftUI/UIKit.
- The genuine released miniTest10-v6 compressed asset was downloaded into U's
  ignored build directory. Compressed SHA256 `e9e6dedd...` and decoded database
  SHA256 `d3d9bfcc...` match the retained profile. A disposable local copy was
  opened read-only; no installed user database was accessed. Exact hashes and
  independently derived paths are in `CURRENT_FIXTURE_PATHS.json`.
- Actual paths: `ספרי מוסר / אחרונים / מסילת ישרים` (book3764) and
  `תנ״ך / תורה / בראשית` (book1). CI must derive these again from its actual
  verified native installation; the local report is not a native test result.

## Remaining native scope

The registered body-paging cases retain functional no-match/matching/excluded/clear-restore
catalog assertions, twenty fixed-direction body and twenty dot transitions per
language, exact TOC title/search ownership, one native sidebar toggle, preserved
reader object/source/offset/title/locator, and vertical scroll arbitration.
The added scene case also checks the actual reader object/source/offset, full
text/title/locator and TOC page after background/foreground and real orientation
changes. Actual run43728847352 (checkout01dd34af, sourcee8afde8e) built
successfully and executed all four selected cases: 0PASS/4FAIL/0skip. The
window case still failed the original Escape disappearance waiter. Both
body-paging cases failed before functional filtering because the test wrongly
required native NavigationBar search to be contained in the pager body. The
scene case selected TOC but stopped at its first viewport request, before Home
or rotation: the existing observer was attached only to the unused iPad host.
These outcomes do not establish filtering or scene-state product failures.
Exact SDK/device/event/visual evidence is sealed in
`../hq-ui-inventory/r27-escape/native-cancel/RUN_43728847352.json`.

Candidateb9077d4a widens the search oracle to the actual sidebar horizontal
column, including its NavigationBar, and mounts the existing read-only DEBUG
observer in Exact9401WorkspaceLifecycle. All functional/continuity assertions
remain. The original bottom TOC helper is also selected through normal realUI
bootstrap as a fourth Sidebar case, sharing the exact original test body.
Actual run43733876827 (checkoutbf463e03/sourceb9077d4a) completed
2PASS/3FAIL/0skip. The scene and original bottomTOC cases passed, with actual
screenshots reviewed and a real viewport report retained. The noninstrumented
Escape case still visibly retained the palette. Both paging cases passed the
no-match filter but stopped after test replacement produced the malformed
query `מסילת_151126__`: tapping the middle of the search field before deleting
moved the caret and left a suffix. The test now uses the observed native clear
Button (`Clear text` / `מחיקת המלל`) and asserts the exact query before filtering.
Body paging, matching and clear restoration remain unaccepted until rerun.
Historical eight are not fresh executions. Exact source/native dependency/data/
generated-project compatibility atb907 is sealed separately.

The next tests-only selection keeps app sourceb907 unchanged: two corrected
body cases plus a same-target native palette calibration. That case first
exercises the actual Close Button, then requires visible down/up result
selection through real hardware-key API, then tests full-window Escape. No
production rewrite follows from an unproved event-consumer hypothesis.
Prior run43723356743 built successfully but its sole window case failed the
original palette disappearance waiter; no Sidebar cases ran there.

Manager decision for this wave: retain one system-owned toggle and its standard
symbol; do not replace the control or reconfigure displayModeButtonItem merely
to change its image. The historical TOC-specific icon requirement is unimplemented,
not a completed fix. Its source task stays open if that criterion is still required.
Direct manager decision received in this Desktop chat; official API evidence is
in QA_CORRECTIONS.md. No application source change follows from this decision.
Physical iPad, VoiceOver/Dynamic Type, interrupted gestures, TOC selection and
multi-scene continuity remain open until their own actual evidence exists.
