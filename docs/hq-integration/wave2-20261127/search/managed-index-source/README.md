# Managed search identity after Books Updates — source checkpoint

## Result and scope

The exact retained Apple source controls reproduce the stale-index defect at `8c073dae8345eaf8c84c413019a8eb6141e4c84e`: **11 pass / 26 fail**. The candidate passes **37 / 37**, with compile and execution exits 0 for both variants. Apple Swift is 6.4, target `arm64-apple-macosx27.0.0`.

`RESULT.json` verifies every candidate source hash against this worktree or an unchanged original Git blob omitted by the sparse checkout, and every baseline hash against the original Git object. `SOURCE_RECEIPTS.json` also binds the exact extracted bodies and compiled Swift files. `COMPILE_RUN.json` retains commands, binary hashes and every assertion result. The raw archive is 88,581 bytes, SHA-256 `ecd3ff10cc19c12b66212c8ca82f005eca43653b39dd7c84719d4daadc75ccc6`.

These are **source/component controls**. They execute the original admission, cache, readiness and publication methods with a controlled native engine, dictionary and UI/provider boundary. The database fixture is 128 bytes and the release tags are explicitly `fixture-v40` / `fixture-v41`. This is not a real database, Tantivy result, published-package install, UI, offline or performance acceptance. The earlier real 7,925,185-document validation and published v40 packages remain separate evidence.

## Defect

Ordinary Otzaria search checked only whether the index directory existed. A cached engine was returned without a current source check, and a newly opened engine could read the retained v40 index after Books Updates installed a different database. Readiness had a second hole: an identity with the current engine commit was accepted from matching database size without the trusted artifact/database manifest tuple. Thus an equal-size replacement could remain Ready, while a different-size replacement could still reach the ordinary query path.

Zayit returned successfully from managed compatibility validation when the database installation manifest was absent. Its configuration stamp omitted the receipt contents. Its restore path also assigned a fresh current stamp after an awaited configure, which could label an older configured engine with a newer source identity.

## Product changes

- **Artifact policy:** every managed admission now requires the trusted source manifest, original producer and catalogue binding, including exact engine commits. The installed database manifest's byte count must agree with the physical file and the index manifest. The existing reviewed directional producer compatibility remains intact.
- **Index manager:** a shared read-only validator performs bounded metadata reads and binds the selected managed database to its adjacent installation manifest. Recovery finishes before the read scope. Readiness still uses a fresh engine and checks the declared document count.
- **Repository:** every ordinary cold open and cache hit is admitted against the current source. Stale cached engines are closed; retained index files remain present. Queries reject a source change before returning a page. Ordinary reads use the existing migration → database → search → cache lock order. The query path never invokes recovery or repairs an identity.
- **Otzaria view model:** initial and next-page publications compare the captured resource observation with the current one on the main actor. A source error revokes Ready without reclassifying an ordinary query error as a corrupt source.
- **Unified controller:** a backend/resources change synchronously invalidates both Otzaria status generations and Zayit restore generations, in addition to clearing rows.
- **Zayit distribution:** a managed source cannot fall through a missing manifest; the selected path, receipt, profile, release/digest and actual byte count must agree. The explicit external-folder contract is preserved.
- **Zayit session:** the complete bounded receipt and selection revision participate in readiness. Stable source observations bracket status/configure awaits. The comparison excludes newly added `configuredPaths`, so assigning the configuration itself does not masquerade as a source change. The concrete external paths also bracket their configure await.

The seven production files contain 247 added and 42 removed lines. No new app observer, provider override, corpus seeding, network-denial hook or alternate search UI was added. This validation trusts the application's verified installation receipt and cooperative storage ownership; it does not rescan a multi-gigabyte database for every query or claim protection against an arbitrary external writer preserving all metadata.

## Controls and preserved behavior

The 37 cases cover valid cache reuse and reopen; exact and qualified original producer metadata; production and mini profile contracts; missing database/index manifests; same-size and different-size update; unchanged database path/size/mtime with a changed receipt; wrong catalogue/count; absent identity requiring explicit recovery; source change during a query; initial/next-page changes before main-actor publication; status-generation invalidation; Zayit status/configure races; and legacy external-source behavior.

The complete production policy/models and original Darwin storage-lock implementation are compiled. Extracted methods are unchanged. FFI count/open/search, dictionary setup, path/provider setup and unrelated UI members are explicit controlled boundaries. No old result can be credited merely because the controlled engine returns a row: the negative cases assert rejection before that boundary, source-safe publication, and retention of the original files.

The existing `hq-otzaria-read-compatibility.py` extraction harness is adjusted to include the new helper and complete multipart-capable database model closure. Its fixture owner now exposes the original selection observation and canonical adjacent receipt filename. Its assertions are unchanged. Python parsing passed; the older full suite was not rerun by this checkpoint.

## Evidence history and replay

The archive retains the initial missing fixture-enum member compile diagnostics, the superseded nanosecond-mtime fixture attempt, and the final successful controls. The equal-mtime control now first assigns an exactly representable whole-second timestamp, avoiding a Foundation/APFS rounding artifact. Final attempt 4 verifies canonical Git bytes, including original EOF formatting; it is the admission receipt for this commit. Earlier attempts are retained as history, not substituted for the final result.

To replay the retained candidate on an owned Apple runner, extract `apple-source-controls.tar.gz`, then compile `attempt4/candidate/*.swift` with the exact flags in `COMPILE_RUN.json` (`-parse-as-library -swift-version 6 -strict-concurrency=complete -j 1`). Run that binary with a fresh owned output directory argument. `cases/RESULT.json` lists the assertions and explicit scope. The corresponding baseline files are retained under `attempt4/baseline`.

## Remaining integrated acceptance

The actual v40 library and both published index packages must be exercised through the original UI on the integrated build. The separate post-Books-Updates R08 case will run only after the original Settings flow installs the real newer library, preserve both v40 index packages, attempt original queries and reject old readiness/results. That native case, all real full-library/page/offline cases and the full application build are not claimed by these source controls.
