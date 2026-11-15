# Books Updates safety boundary — implementation handoff

[דנה | SEC] [MAIN_SESSION] OTZ-D-151126, 2026-11-15
Desktop UUID: 01a1dc86-01b1-71e3-b863-1b7f55ed21d3
Task: 1220539610434045. Parent 1220539630830553 remains Lead-owned.
Branch: `codex/otzaria-updates-20261115`
Base: `df2a21941afa46da716387fce9de620865d2a151`
Worktree: `C:/Users/DAVID/Code/Maktabah-hq-updates-20261115`
Status: bounded guard patch ready for integration review; original task remains OPEN.

## Result

The original updater now fails before catalog HTTP, staging, or target SQL when the library is not explicitly a Maktabah library with compatible metadata schemas. This also protects LibraryDataManager's periodic caller through the shared fetch entry, without editing LibraryDataManager. Listing versions opens existing files read-only. Mutation opens omit CREATE. Missing archive/FTS targets throw before ATTACH rather than silently allowing a later updated flag. Replacement attachments additionally use explicitly URI-enabled mode=rw/ro connections, preventing a disappeared file from being recreated between validation and ATTACH; source attachments are read-only.

Important actual-baseline constraint: BackendID currently has only otzaria, sefaria and sefariaEmbedded. Otzaria also advertises usesNativeMaktabahDataPath. That flag must not authorize original Maktabah updates. The guard checks the explicit raw identity `maktabah`; all current product backends therefore intentionally fail closed. This patch does not invent/register another backend or remap Otzaria. It hides the Books Updates menu on current iOS backends, and direct/macOS/periodic calls return an explicit unavailable error. Offline Maktabah updater/import and ID-change calls also fail closed on those unsupported backends; Otzaria's separate package/data installer is untouched. A future real Maktabah backend must have a separately verified update/recovery contract before enabling it.

The downstream service owns schema/column/table/FTS5 validation, canonical path+backend generation context, book/manifest identity checks and overflow-safe staging space estimates (three advertised copies + 64 MiB overhead). Existing-file SQL-open hooks recheck configured library identity. Online staged updates bind their original context and metadata version; apply rechecks across async author, queue and metadata boundaries. A failed/incomplete batch stops and blocks another attempt in the same UpdateViewModel. Cleanup is gated against the captured library paths.

CSV parsing rejects malformed rows as a batch, five-column rows, negative/overflow values and unmatched quotes before any download. The original parser is retained, with narrow validation hooks. Selection size arithmetic saturates rather than trapping. Duplicate author rows no longer trap Dictionary(uniqueKeysWithValues:). Raw SQLite extended codes/errmsg are retained with operation messages; database-open errors no longer print full private paths.

## Ownership and exact upstream hooks

Live original main/HEAD pinned via read-only ls-remote and GitHub tree API:
`bismillah-100/Maktabah@d46af139b3a265399c16d87f5923acd8e3444024`.
Local upstream/main is stale at `46e893c65139fbb1e582d6595b0d220ea912324a`. Current remote object is absent locally; no fetch or current-remote merge-base computation was performed. File ownership is confirmed by the pinned remote tree's matching blob IDs, not by stale ref assumptions.

All seven modified existing source files are UPSTREAM_OWNED. Six match original remote blobs before this change. iOSLibraryView already contains downstream divergence (base ede65ecf vs remote 1801e988); only the new local guard hunks are in scope.

| File under Source/Features/Library | Base blob prefix | Necessary connection/change | Why service alone cannot cover it |
| --- | --- | --- | --- |
| Database/Updater/BookUpdateManager.swift | e041494b | Attach preflight context at staging; identity/version/capacity validation; guard work-directory/copy/cache entry | Original concrete methods directly start HTTP/copy work |
| Database/Updater/BookUpdateMgr+Fetch.swift | 10fe299b | Preflight shared periodic/list/network entry; propagate version failures; readonly version lookup; validate original CSV parser | Original function swallows SQL errors and directly opens CREATE; five-column subscript trap is upstream |
| Database/Updater/BookUpdateMgr+Import.swift | 5d5a8b1c | Context guard on offline/apply/ID entry; revalidate around awaited stages; require existing archive/FTS/sources; throw missing target | Original method mutates/attaches files and returns normally on missing target; extensions cannot override it |
| Database/Updater/BookUpdateMgr+SQLite.swift | 1ebd757b | Existing-file guard; remove CREATE; enable URI mode for existing-only replacement attachments; redact path from open error; real SQLite code | Original shared open helper selects mutation flags directly |
| ViewModel/BookUpdateVM.swift | bcd0632b | Capacity/retry/partial-download/cleanup/context hooks; clear stale list; overflow-safe selected bytes; nontrapping author map | Original UI can repeat failures, cleanup a newly selected path or apply a partial batch |
| Updates/BookUpdateView.swift | df466461 | One disabled predicate on actual Update selected button | Service cannot control the native button's visible state |
| iOS/iOSLibraryView.swift | ede65ecf | Three short presentation/periodic/menu guards | Service alone blocks writes but leaves misleading downstream UI exposed |

Exact zero-context patch with original/new line spans: [upstream-hooks.diff](upstream-hooks.diff). No unrelated formatting or original method body rewrite. The TaskLocal scope surrounds the original apply body without reformatting it. Register update belongs to Lead; this audit is supplied for incorporation into the shared hook register.

New DOWNSTREAM_OWNED production source: `Source/ChavrusaText/BookUpdates/MaktabahBookUpdateSafety.swift` (Foundation + SQLite3). New test sources/tools/docs remain in the leased paths.

## Validation actually executed

- EXECUTED_PASS: `tools/hq-updates-test.ps1`: **37** actual downstream schema/catalog/capacity/identity/attachment checks against installed Windows SDK SQLite **3.53.4**, plus **2** actual adapter-entry checks with compiler doubles. Missing attachment creates no file; a Unicode/space/#/% filename resolves and its readonly attachment rejects writes. Question-mark URI escaping is checked without attempting an invalid Windows filename. One earlier fixture-only run attempted that invalid Windows filename and failed; corrected final run exited 0.
- The CSV tests compile the original parseIndexCSV/trimHeader/CSVParser implementations extracted mechanically from current source, not a rewritten model.
- The adapter is checked in Swift 6 mode. The standalone fixture core compiles/runs locally; generated files stay inside ignored Tests/HQ/updates/.build, and disposable DB roots are checked against that directory before creation/removal. No installed user DB, app settings key, or installed index was opened/modified. Compiler doubles use an isolated absent defaults key and do not write defaults.
- EXECUTED_PASS: scoped Swift frontend syntax parsing of all seven modified upstream source files; `git diff --check`.
- Local reproducible log: `Tests/HQ/updates/.build/verification.log` (ignored artifact). Test runner never downloads dependencies. It uses the installed Windows SDK header/import library and real Python via py -3.12; the system32 python stub produced no evidence in the earlier exploratory attempt.
- NOT_RUN: actual Apple-framework typecheck/build, app XCTest, compatible Maktabah full update, archive/FTS/main rollback fault injection, disk/permission behavior on Apple OS, VoiceOver/RTL/Dynamic Type, iPad relaunch/upgrade acceptance. Portable syntax/typecheck is not Apple runtime acceptance.

## Integration dependency

Tomer owns project.pbxproj in the separate integration worktree. Confirmed registration commits: `72d30e1f` (source wiring), integration handoff `242571c9a1502d068410c82af753ba2a8a2b0bbf`. He reports exactly eight added PBX lines to include the service in all three app targets (none widget/tests). No source was merged/copied/cherry-picked. This source branch alone has no project registration and must not be described as a build-ready product. Registration and source are one review batch; neither has Apple build evidence yet.

## Remaining safety/acceptance limits

1. The exact missing table on the owner's Build11201 device is still unknown. Several original executeStatement call sites can produce the same prefix; full redacted sqlite3_errmsg and operation/path identity are needed. Static inspection does not prove the Otzaria DB was modified: legacy AppConfig paths are independent of backend selection.
2. Original per-archive table copy, FTS rebuild, special author write, main metadata write and cache publication are separate commits. This patch blocks the current unsupported backends; it does not implement cross-file recovery for a future enabled native updater. IntegrationCache publication still occurs inside original replacement before main metadata save. No claim of all-or-nothing native update success is made.
3. Context uses canonical paths, schema and backend generation checks; it does not authenticate a signed data manifest, pin file inode identity, or make backend transition and SQL mutation one global lock. No real native backend is enabled by this patch. Those contracts must be resolved before enabling compatible production updates.
4. Capacity is an estimate based on catalog size; it is not a guarantee of space throughout download/FTS/recovery. New archive provisioning is intentionally unavailable through a missing path; a separate explicit validated provisioner is required.
5. Failure retry latch is per view-model session; it is not a durable repair journal. Error fallback prose is English; full localization remains unverified. Mac presentation is not hidden but its common fetch/SQL path is blocked.
6. Physical iPad acceptance remains BLOCKED_DEVICE, and the Asana task stays OPEN. No CI, full build, signing, TestFlight, push or merge occurred.

## Recovery and rollback

Code rollback: revert the scoped source commit and Tomer's registration as one coordinated batch in an isolated review branch. Never reset/clean another checkout or overwrite user changes. This lane did not mutate installed data and needs no user DB rollback.

Future compatible-update fixture plan: sentinel main 0bok, special Auth, archive b1/t1 and real FTS5; inject failure after every author/archive/FTS/metadata/cache phase. Validate old/new book/TOC/FTS/version/flags across restart and profile switch. Use an explicitly quiesced consistent set or SQLite backup snapshots with a durable recovery journal. One connection backup is not a synchronized snapshot of four live databases. Do not copy a live .sqlite file alone or delete WAL/SHM after unchecked checkpoint failure.

Authoritative SQLite references: [existing-file open flags](https://www.sqlite.org/c3ref/open.html), [ATTACH semantics](https://www.sqlite.org/lang_attach.html), [URI connection/attachment modes](https://www.sqlite.org/uri.html), [WAL multi-database atomicity limits](https://www.sqlite.org/wal.html), [backup snapshots](https://www.sqlite.org/backup.html). These support the recovery constraints; no user DB recovery operation was run.
