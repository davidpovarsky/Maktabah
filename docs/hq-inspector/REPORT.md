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
