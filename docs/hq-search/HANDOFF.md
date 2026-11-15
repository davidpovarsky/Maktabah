# Search / Index implementation handoff — 2026-11-15

[נועם | DEV] [MAIN_SESSION]
Desktop chat: 01a1dc89-716c-7a01-b6fc-49cb16fe7822
Worktree: C:/Users/DAVID/Code/Maktabah-hq-search-20261115
Branch: codex/otzaria-search-20261115
Base: df2a21941afa46da716387fce9de620865d2a151
Upstream pin: d46af139b3a265399c16d87f5923acd8e3444024

## Implementation

- Zayit: failed/missing restores can retry; unchanged ready sessions are reused.
  Installation/removal revision invalidates each private session. DB, lexical DB,
  profile and index metadata changes invalidate its stamp. Configuration/reset/
  forget operations serialize and superseded work cannot publish readiness.
  Incompatible/repair/FFI errors remain visible instead of becoming zero hits.
  External folder restore still supplies its own lexical DB and ignores an unrelated
  managed-package mismatch; source mode is part of the reuse stamp.
- Native search: use existing downstream presentation policy for distinct loading,
  error, missing-package and genuine zero-result feedback; retry/Search Data and
  search-without-book-filter actions. Next-page errors retain hits and show retry.
- Identity: optional backendHitID transport preserves old init/Codable/id fallback.
  Zayit opens only the exact cached hit ID; old or missing IDs never use title/page.
  Reader locators retain their actual book/page semantics.
- Otzaria metadata: cumulative stable records pair each hit and presentation.
  Pagination uses consumed engine rows, deduplicates visible IDs, snapshots the
  submitted request/filter/backend/profile and clears metadata on a new search.
- Zayit paging: offsets 0/50/100+, request snapshot, append/dedup, generation/
  cancellation, last/empty page stop and retryable paging errors. Existing FFI,
  repository, Rust, schema and prebuilt indexes remain unchanged.
- Otzaria readiness: validate with a new engine, compatibility and document count;
  invalidate repository cache and confirm a reopened repository count. Preserve
  the specific failure reason for local index repair; do not replace it with
  remote-discovery errors or infer health from a cached successful query. Existing
  canonical trusted metadata recovery remains; it is not bypassed. Readiness runs
  off MainActor and stale profile/refresh/install completions cannot replace status.
  Repository query/count hold its existing recursive lock through use, protecting
  invalidation from closing an engine during an operation.

## Files / provenance / integration

- UPSTREAM_OWNED: Source/Features/Search/iOS/SearchModeView.swift — only feedback
  mount (empty states + one results safeAreaInset), 3 added lines.
- UPSTREAM_OWNED: Source/Features/Search/Models/SearchResultItem.swift — optional
  identity transport, 9 additions / 1 signature-line replacement.
- DOWNSTREAM_OWNED: existing Source/ZayitSearch and Source/Otzaria/Search files.
- VENDORED_PORT_WRAPPER: only Vendor/ZayitSearchPort/Swift/ZayitSearchViewModel.swift;
  lineage/necessity and extended lease recorded in HOOKS.md.
- New production Swift files: NONE. No pbxproj/target membership change.
- New tests/tools/evidence only under Tests/HQ/search, tools/hq-search-*, docs/hq-search.
- No merge/cherry-pick: 850b9e47 comparison was read-only. Existing reader line/anchor
  and fingerprint changes from that branch were not imported or rewritten.
- Hook audit: HOOKS.md; exact baseline-relative hunks: upstream-hooks.diff.
  Exact remote pin provenance: upstream-provenance.json and upstream-identity-provenance.json.
  Remaining merge risk: small overlaps in the two upstream files; existing legacy
  upstream divergence is not made approved or functionally verified by this change.

## Evidence and boundaries

- EXECUTED_PASS: Swift frontend parse of all 11 modified production Swift files.
- EXECUTED_PASS: portable Swift fixtures; final output recorded in portable-tests.log.
  Runs real SearchResultItem, engine models, result store, presentation policy,
  Zayit view model/session; source-extracted real readiness and Zayit navigation
  branches; real Otzaria manifest/policy. FFI/repository, observer dependency and
  storage boundaries are fixture doubles. This does not validate Apple Combine
  delivery, SwiftUI type checking, real engine/database content or physical UI.
- EXECUTED_PASS: 101 small-metadata release checks, v32-metadata-audit.json.
  Both immutable v32 releases exist, with SHA256-verified small manifests, matching
  GitHub part metadata, matching official source asset and canonical DB identity.
  Otzaria engine pin/resources also match this base. This supersedes the historical
  assumption that no v32 release exists. It does NOT verify index payload bytes,
  full download/install, current installed manifests or known-match search.
- Earlier expanded harness run failed on a missing fixture storage-capacity type;
  it was corrected by including the actual portable declarations, then passed.
- Python on PATH resolves first to an empty C:/Windows/system32/python entry here;
  fixture scripts were executed with real Python312/python.exe. Earlier attempted
  script edits through that empty command made no changes; final source/tests are
  confirmed by Git diffs and actual Swift compilation/execution.

## Assigned acceptance status

| GID | Scope | Current acceptance |
| --- | --- | --- |
| 1220539465608963 | P0 Zayit restore/error/filter | implementation + fixtures ready; physical iPad root cause/logs/3 known Hebrew phrases/cold-warm/backend/multi-tab OPEN |
| 1220539645638524 | Otzaria metadata/status | fresh-open diagnostics + fixtures ready; actual installed manifest/engine/repair across relaunch + interrupted install/OOM/low-disk/production DB OPEN |
| 1219602829324347 | R01 stable hit navigation | implementation + exact-ID branch fixtures ready; real native navigation acceptance OPEN |
| 1219602829324283 | R03 pagination metadata | 125-hit stable metadata fixtures ready; actual 101+ UI results/tab return/new query OPEN |
| 1219603004720303 | F03 paging beyond 50 | 125-hit paging/error/retry/cancel fixtures ready; real FFI/scroll/UI acceptance OPEN |
| 1219674938327411 | production v32 | publication metadata verified; payload/install/reuse/search/pagination and actual iPad manifests OPEN |

No task is DONE, and no physical device pass is claimed. No project CI/build/archive,
push/merge/publication/TestFlight, dependency installation, production DB/index
payload download or user-data mutation was performed.

## Recovery / rollback

Normal recovery is explicit retry or Search Data using existing validation; never
force-delete/download a user's index to diagnose this report. Capture installed
manifest identities, active profile, engine build/count and errors first (no raw
queries or book contents required). For device acceptance, use an authorized
fixture first, then owner-provided logs/installed production identity read-only.

Rollback the coherent implementation commit on an integration branch if needed,
including the two tiny upstream hooks and wrapper paging wiring. Keep manifests/
evidence for diagnosis; legacy Codable data remains readable because identity is
optional. No schema migration or data rollback is required.

Final fixture result: EXECUTED_PASS — 185 assertions; final portable run 51.25 seconds. Metadata audit: 101 PASS / 0 FAIL. Final 11-file Swift parse exit 0. See portable-tests.log and swift-parse.log.
