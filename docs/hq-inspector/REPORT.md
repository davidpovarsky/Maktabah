# Inspector R04/F05 — local implementation handoff, 2026-11-15

[נועם | DEV] [MAIN_SESSION]

Task: 1219602987688876. Thread: 01a1dc8a-3c0e-7493-98cd-9a8062091a5d.
Repository/worktree: C:/Users/DAVID/Code/Maktabah-hq-inspector-20261115.
Branch: codex/otzaria-inspector-20261115. Base: df2a21941afa46da716387fce9de620865d2a151.
Status: local implementation ready for independent review; task remains OPEN / BLOCKED_DEVICE.

## Result

The current shared Inspector already provides metadata-first loading, generation checks, author batching and snippet hydration. Four remaining gaps were corrected:

1. The fallback reader tap path still launched a second eager `fetchLinksForLine` task. No production call site reads `otzariaLinkedSources`; the current host uses the shared session repository. The duplicate fetch is removed while preserving the locator, selected anchor, shell and same-line close behavior. Cached/mapped taps cancel outstanding anchor resolution.
2. Link SQL and snippet loading now check task cancellation before database access, at chunk boundaries and per result row before mapping/decoding. Cancellation propagates without an error log. Existing eager APIs still return full content when deliberately requested; metadata and snippets are not capped.
3. Whole-unit note membership is restricted to section scope and the exact `sourceLineIndices`, excluding neighbouring notes for segment scope and holes in sparse units.
4. A cold `AnnotationStore` book cache still executed SQLite synchronously inside MainActor `notes(for:)`. The adapter now awaits the existing Sendable book-scoped loader in a cancellation-linked detached task and rejects results after generation/backend/book changes. Persisted and unsaved notes retain their existing mapping.

## Ownership and hooks

Upstream main independently verified with `git ls-remote`: d46af139b3a265399c16d87f5923acd8e3444024. Its fetched tree contains no `Source/Otzaria` paths. The upstream object was shallow-fetched for inventory only; merge base is NOT_ESTABLISHED, and no ancestry/sync claim is made.

| File | Ownership | Change |
| --- | --- | --- |
| Source/Otzaria/Reading/OtzariaLineSourcesService.swift | DOWNSTREAM_OWNED | Cooperative cancellation only |
| Source/Otzaria/Reading/ReaderViewModel+OtzariaLineSources.swift | DOWNSTREAM_OWNED | Cancel stale anchor work; remove unused eager fetch |
| Source/Otzaria/Reading/MaktabahTorahInspectorAdapter.swift | DOWNSTREAM_OWNED | Notes scope and asynchronous cold-note loading |
| Tests/HQ/inspector/FixtureBoundary.swift | DOWNSTREAM_OWNED, new | Instrumented portable boundary types |
| Tests/HQ/inspector/InspectorFixtures.swift | DOWNSTREAM_OWNED, new | Behavioral regression fixtures |
| tools/hq-inspector-fixtures.py | DOWNSTREAM_OWNED, new | Disposable SQLite setup and focused Swift runner |
| docs/hq-inspector/** | DOWNSTREAM_OWNED, new | ACK, provenance, logs and handoff |

Upstream source edits: NONE. Minimal upstream hook register: NONE. AppContainer, ReadingUnit/bridge contracts, Kit, project membership, lockfiles and shared HQ registers are unchanged. No new app Swift source needs project registration. Pre-edit status/diff was clean; exact pre-edit matrix and rollback are in ACK.md. Manual ownership review was performed; no automated upstream guard PASS is claimed.

## Executed checks

Original lane command at 5aa235a11e34d755f3745d402c267687885ec212: `py -3 tools/hq-inspector-fixtures.py` (Windows Swift 6.3.3, Python 3.12.5, SQLite 3.45.3). See fixtures.log; the focused corrective run below supersedes its Notes evidence. The runner compiles the actual service, grouping, classification, preview, tap extension, Annotation value model and exact adapter notes/membership methods. Only framework/DB boundary types are substituted. The service's generated SQL executes against a disposable real SQLite database through Python stdlib. Production zstd decoding is replaced by a counted plain-text decoder. Temporary fixtures do not access user data or install dependencies.

| Scenario | Result |
| --- | --- |
| 100/500/2000 links: exact IDs, counts, grouping and last locator | EXECUTED_PASS |
| Reversed/duplicated/sparse section indexes; coverage across 400-line SQL batches | EXECUTED_PASS |
| Metadata payload and decoder calls remain zero; 12 visible snippets and every full requested snippet preserved | EXECUTED_PASS |
| Legacy/split content projection, single-line eager compatibility, partial/missing snippets and duplicate target fan-out | EXECUTED_PASS |
| Forward/inverse/range coverage and per-side suppression | EXECUTED_PASS |
| Real SQLite failure versus loaded-empty, retry, decoder failure propagation | EXECUTED_PASS |
| Cancellation before SQL, at metadata row 7, after first SQL batch and before snippet decode 7 | EXECUTED_PASS |
| Segment/section notes, sparse gaps, book/backend isolation and Sefaria section membership | EXECUTED_PASS |
| Actual tap extension: immediate shell/selection, no eager SQL task, same-line close and stale-task cancellation | EXECUTED_PASS |
| Actual async notes method: main-actor heartbeat while loader blocked; persisted and unsaved notes retained; stale generation/backend/book and cancellation rejected | EXECUTED_PASS |
| git diff --check; manual changed-path ownership review | EXECUTED_PASS |

The same fixtures compiled against base df2a21941afa46da716387fce9de620865d2a151 fail with the expected behavioral assertions (exit 1):

| Baseline log | Expected assertion |
| --- | --- |
| baseline-all.log | cancelled metadata request succeeded |
| baseline-scope.log | segment cannot include all section notes |
| baseline-tap.log | tap does not schedule duplicate eager fetch |
| baseline-notes.log | cold notes loader must leave MainActor responsive |

## Remaining acceptance and limits

- BLOCKED_DEVICE: physical iPad with FULL seforim.db; first/middle/last Psalms, Berakhot, explicit segment versus section, last-source navigation, shell responsiveness, rotation/multitasking and tab changes.
- NOT_RUN: production immutable DB EXPLAIN/index audit, zstd/contention/RSS/hang traces and before/after p95. Fixture process overhead is not an app performance benchmark.
- NOT_RUN: full Sefaria snippet/Notes create-edit-delete runtime regression, SwiftUI rendering, app/Xcode compilation and independent review.
- Cancellation is cooperative. It does not interrupt a SQLite statement while waiting for a lock or before SQLite yields its next row. Shared connection ownership/API remains frozen.
- AnnotationStore's existing nonthrowing loader still determines annotation-query failure behavior. This change moves that existing operation off MainActor; it does not change its storage contract.
- GitHub Actions, builds/archives, push/merge, TestFlight and production/user DB operations were not run.

Next reviewer: independently review the three source diffs and exact fixture boundaries, then arrange the physical/production matrix at the final integrated SHA. Keep GID 1219602987688876 open until all original acceptance gates pass.

Rollback: revert only this lane's local commit(s), or remove its branch after review. No schema, data, dependency or project migration requires rollback. Integration risk is limited to possible concurrent changes to the same downstream methods; no original Maktabah source was edited.

## QA correction — same-book range changes

Independent Roni thread 01a1dc8b-f9bd-7d63-a628-7ad3d06196e8 reproduced an old Notes request consuming a newer selection range within the same book at frozen 5aa235a. The backend/generation/book guards cannot distinguish that change. The correction snapshots `selectedSegmentRange` alongside the original locator before suspension. The original request retains its exact range fallback while later requests use the newer range; section scope retains its own unit membership. No identity-only guard is used because range changes can occur with the same locator.

- EXECUTED_EXPECTED_FAIL: `py -3 tools/hq-inspector-fixtures.py --source-ref 5aa235a11e34d755f3745d402c267687885ec212 --case notes`, exit 1, `same-book segment request must preserve its original range; locator changed=false`. Evidence: baseline-same-book-notes.log.
- EXECUTED_PASS: `py -3 tools/hq-inspector-fixtures.py --case notes`, exit 0. Four blocked-load combinations cover segment/section scope with range-only changes and locator+range changes in the same book. Assertions preserve both direct original notes and the original range fallback while excluding the newer unrelated note. All prior Notes heartbeat, persisted/unsaved and generation/backend/book/cancellation checks also pass. Evidence: notes-immutable-range.log.
- REUSED_VERIFIED_PASS: prior links/SQL/grouping/snippets/tap checks from 5aa235a; their production files are unchanged by this correction. No broad suite or Apple build was repeated.
- Production hunk: only move the range snapshot before await plus an explanatory comment in downstream MaktabahTorahInspectorAdapter.swift. Rollback: revert the follow-up commit. Independent retest and all physical/production gates remain OPEN.

## Wave restart: source-isolated Embedded selection and Notes (2026-11-15)

Acting thread 01a1df8b-4498-76c1-8cca-cd5c11120b7a, [נועם | DEV] [MAIN_SESSION].
Owner activation: Codex-Agent-HQ/docs/otzaria/single-manager-wave-20261115/OWNER_ACTIVATION.md.
Pre-edit branch codex/otzaria-inspector-20261115 at a1bfa5f8ec89535115fd825efdd292d8e3bee5e3 was clean. Upstream HEAD reverified by git ls-remote as d46af139b3a265399c16d87f5923acd8e3444024; this adapter remains absent from that upstream tree. No merge-base/ancestry assertion is made.

Corrected two source identity errors in downstream MaktabahTorahInspectorAdapter.swift:
- Explicit Sefaria/Embedded segment selection now requires active backend and the same work as its section. Section fallback preserves locator.backend instead of hardcoding sefaria, and rejects a stale foreign section.
- Notes now require matching backend AND work before accepting equal canonical/preferred reference text or section containment. Equal text/ranges in another provider/work cannot establish annotation identity. Existing range fallback, immutable pre-await range, cancellation, cold background loading and unsaved notes remain intact.

Only production adapter changed (9 added/6 removed); no Reader/SQLite, Core, shared ports, Kit, project, workflow or upstream hooks changed. Test boundary types and the existing Python harness were extended to extract actual selection/currentUnitSelection/otzariaSelection/locator(selection) methods plus original Notes methods. Locator cache lookup, framework/bridge values and DB/decoder remain explicit substitutes; this is not native rendering or RPC proof. Exact remembered backend/work/position is asserted. Native TextLocator has no catalog/data revision fields; no revision is fabricated or silently claimed as verified.

EXECUTED_EXPECTED_FAIL at frozen a1bfa5f8:
- selection-baseline-20261115.log: equal-ref foreign backend/work Notes are included (sefaria).
- provider-baseline-20261115.log: Embedded selection returns the wrong provider.
Both commands exited 1 at their behavioral assertion after successful compilation.

EXECUTED_PASS: py -3 tools/hq-inspector-fixtures.py --case all, exit 0. Evidence fixtures-wave-20261115.log, 11 groups (100/500/2000 relationships; two content layouts; error/empty/retry; cancellation; note scope; actual tap; cold Notes including same-book immutable range; source selection/Notes). selection-fixed-20261115.log separately records focused success. Windows Swift6.3.3 / Python3.12; portable boundaries only. Existing FixtureError output is an intentional baseline assertion, not a hidden compile failure.

Native execution availability: apple-doctor confirms Windows has no Apple SDK. Connected Desktop Commander torah-social reports Linux, not a Mac. No physical iPad/full corpus, production ZSTD, RSS/p95 or native source/Notes result is inferred. Manager owns coherent S/P/I app target composition and cross-feature acceptance. Both source tasks remain OPEN. Rollback: revert this wave correction commit; preexisting a1bfa5f8 stays intact.


## Continued wave: document mode and cancelled warm-source lookups

Pre-edit HEAD1c2fa5cfc3288bf16720e2345ce0b6dac3d571d2, same branch/worktree, clean. Acting thread01a1df8b-4498-76c1-8cca-cd5c11120b7a, [נועם | DEV] [MAIN_SESSION]. Ownership/provenance remain downstream-only. Three production lines changed in the existing adapter: previous/next descriptor reads now use the immutable effectiveMode already used to load the requested document; activeLocator checks cancellation before it can return a cached source. No Reader/SQLite implementation, Core, S adapter, app/project/workflow/Kit or upstream edit.

The existing fixture harness now compiles the entire actual mapOtzariaDocument and activeLocator methods, actual ReadingUnit/UnitMode/Descriptor models, actual neutral library section/version/text-mode types and actual OtzariaInspectorDocumentMapper. These production models/mappers are read for compilation only; no source edits were made to them. TorahInspector document value types and the getReadingUnit/adjacent service boundary are explicit test substitutes in DocumentFixtureBoundary.swift. The point-source branch invokes the actual fetchLineContent service SQL against the disposable SQLite fixture with its counted plain-text decoder. This strengthens method coverage without claiming Apple, native rendering, genuine corpus units or ZSTD proof.

EXECUTED_EXPECTED_FAIL against frozen1c2fa5cf, after successful compilation:
- document-mode-baseline-20261115.log: requested paragraph document used chapter adjacent descriptors.
- source-gate-baseline-20261115.log: cancelled warm-cache source lookup returned data.
Each command exited1 on its intended behavioral assertion.

EXECUTED_PASS: py -3 tools/hq-inspector-fixtures.py --case all, exit0, 13 groups. fixtures-source-document-20261115.log retains all prior11 groups and adds nine current/requested mode combinations with exact sparse source/adjacent refs and remembered mode; single-line point SQL fast path without whole-unit fetch; blocked document loader generation/cancellation rejection before cache writes; exact/missing/foreign/unknown source guards and cancellation before cached data. Windows portable Swift6.3.3 only. Existing links100/500/2000, error/empty/retry, cancellation, immutable Notes range, source Notes isolation and actual tap cases all pass with the actual model extraction.

Manager assigned SefariaEmbeddedRelationshipsAdapter exclusively to S after I reported real response failures becoming empty arrays and full sourceRef being used as workKey. I does not duplicate or edit S catalog/RPC/parser work. Source/Notes native acceptance awaits the genuine combined S/I packet. The root project board records the separately discovered unbounded locator cache and the canonical-identity prerequisite for safe eviction; no unrelated cache refactor was made. FullDB, iPad, productionZSTD/RSS/p95 and native runtime gates remain OPEN. Rollback: revert this follow-up commit only.


## Genuine pinned miniTest10 source audit (Windows portable boundary)

Production source under test remains8cc9c6752763de742d2c1ceef3c407a87eb002c7; this follow-up changes only existing test boundary/fixtures/runner and evidence. No application source changes. Existing actual BookSchemaCompatibility and LineContentCompatibility scalar SQL projections are now compiled by the runner instead of fixture equivalents; this correctly exercises the real missing-filePath fallback on schema6. P/R/S-owned production files are read, not edited.

Data: existing miniTest10-v6 profile, archive7774478bytes SHA256 e9e6dedd2ceaadbe46234612c359e5bd8add00c348be8eaeba85cf029fa5c4d3; extracted DB15470592bytes SHA256 d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef. The exact pinned release asset was downloaded/extracted into ignored build/hq-inspector-corpus-20261115 only. Existing Scripts/verify-mini-test10-profile.py PASS validates10book IDs,18879line/content rows,4851links,1608coverage rows,526suppressed sides,1ZSTDdictionary, schema6/version32, foreign keys and integrity=ok. Evidence miniTest10-identity-20261115.log. No user/installed database was opened.

Command: py -3 tools/hq-inspector-fixtures.py --case corpus --database build/hq-inspector-corpus-20261115/miniTest10.db. Explicit corpus mode requires that exact size/digest under this worktree's build directory. Queries use SQLite mode=ro&immutable=1; the file SHA is rechecked after completion. Archive and database are retained in ignored build cache, not committed. The default synthetic suite remains stdlib-only; corpus mode uses the already installed Python zstandard dependency.

EXECUTED_PASS12 corpus windows: entire indexed source book plus first/middle/last line for each of Tehillim28(2678lines), Berakhot103(2875lines), DerashotHaRan3152(528lines). An independent Python row/set oracle iterates genuine link/coverage/suppression records rather than using the production SQL CTE. Every complete source identity tuple(linkID, linkedBookID, linkedLineID, linkedLineIndex) matches. All-book relationship counts1238/1460/255 respectively; genuine point windows may correctly be empty. Grouping preserves every returned relationship, only requested tail snippets are hydrated, and the last real source's snippet equals its exact point-query content. miniTest10-source-audit-20261115.log.

88 actual readonly queries were retained with parameters, row/frame counts and raw EXPLAIN QUERY PLAN. All26 metadata queries used idx_line_book_index as a covering book/line search; none decoded content frames. Coverage/suppression and source/target links used their genuine indexes; no unindexed link scan was observed in those plans.27 dictionary-compressed frames were decoded for requested snippets/point parity at the Python boundary. Database SHA remained unchanged. Raw audit miniTest10-source-audit-20261115.json; compact identity/index/frame/source-hash summary miniTest10-source-summary-20261115.json. Source SHA256 values describe UTF8 production text normalized exactly as compiled by the fixture.

EXECUTED_PASS existing13-group synthetic suite after real schema-projection extraction: fixtures-native-schema-20261115.log. Explicit outside-build corpus DB and --database on noncorpus mode are rejected with expected exit2 before compilation/DB access: corpus-boundary-negative-20261115.log. Runner syntax check also PASS.

Limits remain strict: dictionary decoding here uses Python/libzstd, NOT production Swift/C decoder; no Apple app, UI, iPad, MainActor/RSS/p95 or full production performance claim. miniTest10 is a genuine schema6/v32 subset, not the current production release. During read-only source preparation, official latest was verified as v38-20261112163847(443459877), whose DB is multipart schema7. Assigned I's release parser still selects monolithic asset names. This concrete compatibility/source-pin issue was routed to manager for D/R ownership; I did not alter their downloader or silently call v32 data latest production. Exact native/coherent source and physical acceptance remain OPEN.
