# Search lane provenance and minimal hooks

[נועם | DEV] [MAIN_SESSION] — 2026-11-15
Chat: 01a1dc89-716c-7a01-b6fc-49cb16fe7822
Base: df2a21941afa46da716387fce9de620865d2a151
Upstream pin: d46af139b3a265399c16d87f5923acd8e3444024

GitHub Git Trees API returned the exact pin, truncated=false (upstream-provenance.json).
The local object is absent; no fetch/merge was needed. Both Source/ZayitSearch/**
and Source/Otzaria/Search/** are absent from upstream, hence DOWNSTREAM_OWNED.
Pre-edit status was clean. Read-only df2a..850b9e47 review found existing identity/
pagination and fingerprint work in that branch; no merge/cherry-pick or bulk copy.
This lane keeps the base API and makes focused compatible corrections.

## S-HOOK-01 — SearchModeView.swift
UPSTREAM_OWNED: Source/Features/Search/iOS/SearchModeView.swift.
Pinned upstream blob: 2a556caa65b0e86802ec4c5a2d69f10f89b79b50.
Hunk: insert a branch between populated results and regular/compact idle views:
`else if session.showsSearchFeedback { UnifiedSearchFeedbackView(session: session) }`.
Also mount `UnifiedSearchPagingFeedbackView` through one `safeAreaInset` on the
existing results view so a failed next page has a visible retry without removing hits.
Necessity: only this parent chooses the empty-result surface. A downstream feedback
view cannot appear unless the parent mounts it. State, strings and actions stay in
existing downstream UnifiedSearchWorkspaceView.swift. Existing idle/filter UI stays.
Tests: presentation-policy matrix and wiring check, Swift parse; actual iPad UI OPEN.
Rollback: remove this inserted branch and downstream feedback type.

## S-HOOK-02 — SearchResultItem.swift (extended exclusive lease)
UPSTREAM_OWNED: Source/Features/Search/Models/SearchResultItem.swift.
Pinned upstream blob: 68b7d86be161a574eebf64661c14d382ffcba8f8.
Hunks: optional `backendHitID: String?`; nil default initializer; encode/decodeIfPresent;
identity getters prefer supplied hit identity and preserve existing fallback unchanged.
Necessity: shared native result list uses SearchResultItem.id/stableID and Codable.
A downstream cache alone cannot distinguish same-locator hits; locator/versionTitle
must retain their real reader/version meaning. A new parallel result type would
replace upstream list/model flow. This is identity transport only, no backend logic.
Tests: old JSON decoding, nil-default identity, two same-locator hits, roundtrip,
stale-query navigation; actual device navigation OPEN.
Rollback: remove optional field and prefer-hit clauses; old JSON remains decodable.

## S-VENDOR-01 — ZayitSearchViewModel.swift (conditional extended lease)
VENDORED_PORT_WRAPPER: Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift.
Git origin 0985b29c6b1ad6d9945b0e3042387ce8853b37c9, David's isolated Maktabah
Zayit port integration; first blob was a tiny ObservableObject wrapping our
ZayitSearchRepository. README identifies this as 'Maktabah Zayit Search Port',
CODEX-INTEGRATION-INSTRUCTIONS explicitly assigns integration wrappers here.
Subsequent fork commits d6c768a8, 47edc4f2, 2457f573, 640ebe4c evolved this wrapper.
No evidence of exact third-party Swift source; Rust/third-party engine remains untouched.
Hunks: wrapper paging cursor, request snapshot, append/dedup, cancellation/generation
and error/loading states. Existing repository/FFI already accepts offset/limit and
returns isLastPage; no ABI/index/schema changes. Downstream extension cannot access
private repository or generation safely; duplicating the entire view model is worse.
Tests: real wrapper with fake actor repository: 125+ hits, duplicates, final/empty page,
error retry, filters/request snapshot and cancelled/late query. No index rebuild.
Rollback: revert this wrapper hunk and downstream paging wiring together.

No project membership edits; added production code stays in existing Swift files.
Reviewer: pending independent QA/integration. Physical iPad gates remain OPEN.
