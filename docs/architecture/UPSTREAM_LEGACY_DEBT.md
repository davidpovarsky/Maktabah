# Upstream divergence — historical debt, not approval

Created 2026-10-22. This is a risk register, NOT a claim that all affected behaviors have been tested or that every upstream edit has been exhaustively mapped.

At the current integration branch, downstream changes overlap original Maktabah code in the reader, search, library and iOS navigation. Examples requiring hunk-by-hunk review:
- Source/Features/Search/iOS/SearchResultsListView.swift
- Source/Features/Search/iOS/SearchModeView.swift
- Source/Features/Library/Database/LibraryDataManager.swift
- Source/UI/iOS/Managers/iOSNavigationManager.swift
- Source/UI/iOS/Views/iOSMainView.swift
- Source/UI/iOS/Wrappers/iOSIbarotTextView.swift

The upstream v4.2 merge had numerous conflicts and subsequent build/TestFlight evidence. Those are NOT proof of functional parity. The reports UPSTREAM_SYNC_CONFLICT_LEDGER.md, UPSTREAM_SYNC_CHANGE_COVERAGE.md and UPSTREAM_SYNC_VALIDATION_MATRIX.md are historical evidence, not blanket permission or full runtime acceptance.

**Status: LEGACY_UNREVIEWED.** Do not add more downstream logic to these upstream-owned files. Before any future integration, enumerate ALL divergent paths and hunks against the exact pinned upstream commit; move custom behavior to fork-owned adapters when separately approved. Any genuinely unavoidable hook needs specific owner permission recorded in UPSTREAM_EXCEPTION_REGISTER.json.

Outstanding gates: full per-file provenance, review of conflict semantics, actual iPad functional regression matrix and explicit owner closure. No project code changes are authorized by this document.
