# Remaining original result-selection and paging owner contract

This is a scoped implementation proposal, not a completed feature or native result. It is based on actual source read at commit 9c6d3b96efcd210f12645bdc442ff747d02807e5; source excerpts/hashes are in ORIGINAL_RESULT_OWNERS.json.

## What already owns the behavior

UnifiedSearchSessionController owns query/configuration, results, submission/cancellation/pagination revisions and dispatch to the original engines. Its loadNextPage() uses the original hasMore/loading/dirty guards and dispatches to the existing backend loader. Its openResult(_:using:) resolves the original result through the existing reader path. These must remain the owners; a new headless search/cache cannot stand in for their current result list.

SearchResultsListView owns the original grouped list, expanded previews and selected version index. Groups use original locator identity; rows have .id(group.id). SearchResultItem.stableID includes the source hit ID or locator/version/language. A displayed group can therefore contain several different result identities. Choosing the first group/version is not equivalent to selecting the requested hit.

SearchViewModel and OtzariaTextSearchViewModel own their original pagination request/offset/result storage. The unified public controller currently exposes no source-bound cursor for the system surface. Diagnostic page observers are read-only evidence, not commit authority.

The current ActionSearchResultsQuery deliberately accepts only the original first-page query fields, rejects searchHandle/nondefault paging, and has no selected-hit field. The retained MaktabahNativeSearchResultsBinding correctly requires no unrelated pagination change during its one submission. The new intent does not bypass those rules.

## Smallest coordinated next packet

1. **Wave2: add a narrow source-owned result observation/selection contract to the existing unified session.** Expose a read-only current result-page identity bound to the same exact session and original model instances, backend/RPC snapshot, byte-exact submitted configuration, original search generation and submission/cancellation/pagination revisions. Include stable result identity + original locator/version/language and a source-owned optional next-page identity only where the original engine can validate it. It must invalidate on clear, cancel, configuration/backend/result-owner changes and ABA, including same-value lifecycle publications where necessary. A transient callback/cache alone cannot be authoritative.

2. **Original view owner: retain the exact mounted list and its existing version/expansion setters.** A bounded selection request resolves the supplied qualified hit against the actual current original results, selects the original matching version when needed, reveals that original row through its existing group ID and returns only after the same row/version has real visible layout evidence. The view must reject replacement, filtered-out/missing/ambiguous hits and source changes. It must not copy SearchResultItem arrays into a second feature store, tap an unrelated action, clear a filter or select another result to make the request succeed. Opening the reader is a distinct requested action and must use its canonical reader receipt.

3. **Core/UI owner: add an explicit typed continuation contract instead of silently widening the old first-page query.** A small separate operation for a retained current result selection/page continuation can preserve the original search.openResults strict contract and its existing tests. Its input must carry qualified source identity and an opaque source-owned page/selection token rather than an arbitrary external offset or query-bearing URL. The new command authorizes only the exact retained original session operation. A selected hit on an unmaterialized page requires the original supported continuation under a bounded budget; there is no unbounded provider search or loop to find it.

4. **One original continuation, one acknowledgement.** The host applies the authorized existing loadNextPage() at most once for a validated next-page token, or applies only the original list's reveal/version state for an already loaded hit. It waits on original completion/layout under the same retained request/source/deadline. A real page/hit receipt includes the validated current original page/result identity, actual revision advance where relevant and visible row evidence. Cancellation, repeated/stale tokens, exhaustion and any foreign/local source transition refuse without rearming the proof. Existing first-page binding rules stay unchanged.

5. **Only then expose hit/cursor system parameters.** Source entities must resolve through that original owner contract, not parse arbitrary row IDs or reuse another scene's token. ShowSearchResultsIntent can compose the explicitly supported semantic operations while preserving each actual prior result/receipt if a later step fails. Until that contract is reviewed and proven, supplied hit/cursor values continue to return not_supported.

## Exact likely lease, subject to Wave2 coordination

- Source/ZayitSearch/UnifiedSearchSessionController.swift: passive source publication + narrow original result/page owner methods.
- Source/Features/Search/iOS/SearchResultsListView.swift: original row/version/expansion host registration and exact visible-row witness.
- Source/Features/Search/iOS/SearchModeView.swift: the existing global list call site forwards the exact retained owner; no reader or engine rewrite.
- Original backend paging owner methods only if their current offset/request proof is not accessible; reuse SearchViewModel/OtzariaTextSearchViewModel, keep engine/pin/data semantics.
- Separate additive Core/UIRouting typed continuation contract, original source binding and source tests; UI agent owns Session/registry/Composition wiring.
- New native original row/page selectors on iPad and iPhone, including versions, stale page, cancellation and filtered loaded lists, run only through final qualified app.

This proposal does not reserve or edit those files. Root coordinates Wave2 and the shared routing owner before implementation. It is intentionally separate from the already tested first-page intent packet.
