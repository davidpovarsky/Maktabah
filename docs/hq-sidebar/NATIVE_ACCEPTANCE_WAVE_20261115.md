# U native sidebar acceptance activation — 15 November 2026

The retained Sidebar11201AcceptanceTests file has moved from the unregistered
`Tests/HQ/sidebar` directory into the existing synchronized
`Maktabah-iOSUITests` target. There is one test implementation and no project
membership edit or new harness. Historical portable checks/docs remain evidence
at their original SHAs; they are not native passes.

The same two fixed-direction Hebrew RTL/English LTR cases now use the normal
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

The registered cases retain functional no-match/matching/excluded/clear-restore
catalog assertions, twenty fixed-direction body and twenty dot transitions per
language, exact TOC title/search ownership, one native sidebar toggle, preserved
reader object/source/offset/title/locator, and vertical scroll arbitration.
They are NOT_RUN at this test revision until a real selected workflow executes.
Current priority remains the already running focused Escape/Inspector case.

TOC-specific system-toggle icon is still OPEN. The manager has been asked for
the material choice between the system-owned native symbol and one replacement
native Button using public toolbar(removing: .sidebarToggle) and canonical
column visibility. No new source implementation or acceptance was inferred.
Physical iPad, VoiceOver/Dynamic Type, interrupted gestures, TOC selection and
multi-scene continuity remain open until their own actual evidence exists.
