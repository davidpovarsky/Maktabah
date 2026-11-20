# Sidebar ownership and rollback decision record

Task: https://app.asana.com/0/0/1220036734132868
Scope: current planning/ownership reconciliation, not Native or physical acceptance.
Audited source: bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1.

## Existing composition and state ownership

iPadLayout owns the original global modes and a two-column NavigationSplitView.
Its sidebar supplies the original iOSLibraryView and the selected original reader's iOSTOCView as closures to downstream ReaderSidebarPager.
The detail remains the original iOSReaderTabView. The sidebar page changes do not allocate a new reader, book store, source provider or annotation owner.

ReaderSidebarPageCoordinator owns only page/query presentation state.
The Library query remains the original navigation manager's libraryViewModel.searchQuery.
TOC query ownership is scoped to the original active reader UUID. A binding retains its owning page/reader so a late callback cannot write another page's query.
The native page TabView and scoped directional recognizer share the same page coordinator; vertical list interaction stays with the original list. The actual behavior requires its existing RTL/LTR Native cases.

## Boundaries and exact hooks

Downstream owners: Source/ChavrusaText/ReaderHost/ReaderSidebarPager.swift and ReaderSidebarPageCoordinator.swift.
Protected composition: Source/UI/iOS/Views/iPadLayout.swift.
Protected TOC: Source/Features/Reader/iOS/Toolbar/iOSTOCView.swift.

The earlier exact hooks, original Git blobs, rejected alternatives, downstream paths and rollback scope are recorded in docs/hq-sidebar/UPSTREAM_HOOKS.md and upstream-hooks.patch.
Current additions after that record are not retroactively represented as the original patch. Existing ownership/exception records govern them, and the user's current task authorizes the new manager-directed repair.
No protected source is changed by this documentation tranche.

Rejected alternatives remain relevant: an independent Library search field would compete with the canonical query; recreating page branches loses original local state; a replacement reader/navigation stack would introduce another owner;
hiding the entire TOC toolbar would remove unrelated controls; an unscoped close-button suppression would break standalone TOC sheets.

## Feature flag and rollback

ChavrusaTextFaithfulReaderUIEnabled exists and defaults to enabled.
At this audit source the actual iPad viewer installs ReaderSidebarPager and Exact9401ViewerToolbar unconditionally, and the scene lifecycle attaches its workspace independently of this flag.
Consequently the flag's existence must not be described as a verified iPad rollout rollback.

Decision: retain the original feature-off acceptance gate, repair the existing flag at the actual iPad composition/lifecycle boundary in the manager's separately owned change, and verify both fresh flag-off no-sidecar behavior and preservation of existing workspace bytes.
The flag-off fallback must continue using the original reader/Library/TOC and preserve original target ownership; it must not delete/migrate data or emulate a pass by changing the test's sidecar checks.
The manager assigned that narrow work to the Native/QA lane after this finding.

For a binary rollback, revert the exact scoped implementation/attachment commits together with their host hooks after preserving later edits; do not bulk restore an upstream tree or erase sidecars, session files or databases.
Until the separate integrated flag fix and existing gate have run, rollback runtime behavior remains OPEN.
This RFC can support eventual closure of the planning task only; Sidebar UI/QA/parent tasks retain all actual Native and physical criteria.

## Required evidence

The existing Native subset contains Sidebar11201AcceptanceTests RTL body paging, LTR body paging, background/rotation state preservation, and original-bottom-TOC ownership.
The complete Release manifest additionally retains the original feature-off sidecar-preservation case, both iPad sizes and reader/accessibility regressions.
Prepared selectors and source inspection are not execution evidence. Physical iPad owner review of the original Build11201 complaint remains separate.
