# Pre-edit source and ownership admission

Baseline: `15d283aa0ccbbfe6966f26a2c182810cb39fdafa`. Live public upstream: `bismillah-100/Maktabah`, branch `main`, commit `4203de5fd77beb119e5826e039be1a61325f7be0`; merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. Exact Git blobs, source SHA256s and read-only command outcomes are retained beside this file and in INPUTS_1–5.

| Path | Provenance | Necessary change and owner |
|---|---|---|
| Source/ZayitSearch/UnifiedSearchSessionController.swift | Downstream original unified UI owner; absent upstream | Search owner: source-lifecycle observation, atomic one-shot continuation and original provider dispatch. No provider/cache replacement. |
| Source/Features/Search/iOS/SearchResultsListView.swift | Existing upstream-derived original list | Search owner: optional downstream list/row lifecycle and exact original version/expansion setters; scoped synchronous prefetch arbitration. The original grouping, controls and default paging remain. |
| Source/Features/Search/iOS/SearchModeView.swift | Existing upstream-derived original composition | Search owner: inject the same Unified session's optional downstream list owner into the existing global List. |
| Source/Otzaria/Search/OtzariaTextSearchViewModel.swift | Downstream original Otzaria owner | Library owner: passive request/commit/cancel journal only. |
| Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift | Downstream Swift adapter, absent Maktabah upstream | Library owner: passive original Zayit request/commit/cancel journal only. Rust/provider contract untouched. |
| Source/Features/Search/ViewModel/SearchViewModel.swift | Existing upstream-derived original model | Library owner: one passive ledger instance. |
| Source/Features/Search/ViewModel/Extensions/Search+Execution.swift | Existing upstream-derived original execution | Library owner: capture original request and source terminal transitions; explicit existing pagination overload for exact requested offset. |
| Source/ChavrusaText/SearchContinuation/* | New downstream adapter/policy | Single-owner additive implementation and no result store/provider. Library owns OriginalSearchPageLedger.swift; search owns other new files. |
| Source/Otzaria/Actions/Sources/OtzariaActionCore/Contracts/ActionSearchContinuation.swift | New downstream contract | Search owner: separate typed source/token/operation/receipt/sink; existing first-page query and validator unchanged. |
| Source/ChavrusaText/UIRoutingHost/{Integration,Sources,Tests} new continuation files | New downstream host adaptation | Search owner: strict retained source operation, thin service and focused controls. No Scene/registry/Composition edit. |

Root notified Wave3 coordination task1220939535420506 comment1220949535776986. User authorization covers necessary hooks; this matrix records provenance and avoids concurrent edits. Reader owns a separate narrow original first-page binding fix after a proven guard gap; it is not part of this branch.

New Oracle worktree: `/mnt/development/projects/worktrees/Maktabah-search-continuation-20261127`, branch `codex/otzaria-search-continuation-20261127`. Source tree and tracked status were clean at creation. Minimum protected Oracle capacity is687,865,856 bytes; creation measured1,163,350,016→1,159,299,072 bytes. No Apple/SSH/native/App/SDK build authorized for this packet.
