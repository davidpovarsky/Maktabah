# Integration status — work in progress

Worktree: integration/sefaria-otzaria-20261108. Base: 59b01fa2d604facbcc3b3b1075a6283e7f1115db.

The user explicitly authorized implementation, CI, synchronization and TestFlight in the current chat. The original execution-package release restrictions are superseded by that authorization. No other working tree is modified.

Implemented: embedded inspector identity and real related content, Hebrew navigation preserving canonical references, normalized search languages/book identities, edition-aware preview requests, pinned Rust 7.0.1/schema10 with real SQLite indexing through a thin C ABI, paired cumulative search records, canonical lineIndex resolution, optional schema-aware versions/topics/metadata/alternative navigation/reference/anchor/decoration repositories. App target membership is explicit and additive.

Implemented native reader integration now includes per-reader edition selection in the existing View Options sheet (default merged text, original Hebrew edition titles, true book/version IDs), compressed edition text without merged fallback, original inline footnotes, and restricted copy/share/export for protected books. Version choices do not change canonical locator persistence keys or leak across reader tabs/database generations. Source notices remain original factual metadata. Sacred-name packed spans are decoded as metadata; new religious substitutions are NOT_SUPPORTED_YET and source text remains unchanged.

Search uses actual schema10 SQLite sources and stable paired cumulative records; exact pagination continues beyond 100 using actual totals. The original upstream Arc-backed cancellation registry is exposed through a separately owned C handle; cancellation bypasses the engine mutex and Swift tasks retain the registry safely through cancellation/close. Alternative navigation uses original line_alt_toc coverage for current location, excludes foreign anchors, and never substitutes entry IDs for canonical lineIndex.

In progress: native interactive tests, compatible production/mini artifacts and final combined-branch validation. Focused actual SDK compilation passed at e873d13c in run 42481871742 for the UI acceptance tests, sidebar/toolbar sources and modified palette/tab packages, with 66 workspace checks. Full native functional, iPad/phone/large-text and production Release run 42482169586 targets 302b62b4. No release readiness is claimed by compilation.

## Synchronization

Merged committed UI work through 661d53e0541779ae6c9ed7526cae5b1f273c708d from experiment/ipad-ui-faithful-from-9401 into this isolated branch. The other checkout is unchanged. Its coherent reader host, source-port memberships and TorahInspectorKit 19d1b35397af4f10ae70cfb3f444c9de87383b53 presentation options replace the older parallel downstream host. Existing semantic navigation helpers and the stronger embedded-source tests are retained. Superseded downstream model/view source files are retired only in this branch.

The known baseline workspace schema is imported once without modifying the original bytes; unknown formats remain opaque and archived. Actual persistence/scene/migration/rollback contracts pass 66 checks. New source memberships and both framework resources pass the repository's project-membership verifier (108 Otzaria Swift sources).

The first schema10 CI built all three Apple Rust slices successfully. Its fixture harness lacked ZSTDContextWrapper.swift and stopped before app/UI validation; that harness input is corrected. Subsequent actual SDK compilation found a capability OptionSet inference error in BackendComposition; the explicit typed local fixes it. Neither failed run is UI acceptance.

## Verified data identities

Production source is pinned to v36-20261101064231, schema7 asset seforim-schema7.db.zst. Actual schema_meta contains db_version=36 and db_schema_version=7, with no content_hash field. File identity therefore uses a streaming SHA256 over actual bytes, with cache invalidation for database generation, file identity/stat, SQLite data_version and WAL changes. The raw source SHA256 is c60fbd02b4cf7bda00dc5af16aa48b8bfe193b1121d29c9a048dc348ff42e9d6.

MiniTest10's database is derived twice deterministically from that authenticated source. Its raw database is 15,519,744 bytes, SHA256 9b96f8474435b88fb3312e947801cfef6260b51d41a8e21e3896e9192e8eb6d4. It preserves schema7 notes, protection/banner and divine-name tables along with versions, references, relationships and alternative structures. The current immutable package/profile is **v9**, retaining those same database bytes. Published v7 omitted required original engine metadata and is not installable; v8 packaging rejected an original empty runtime lock. The corrected packager preserves original metadata and omits only known runtime state/locks. All eleven packager/profile checks pass; actual v9 bootstrap remains pending. The official v36 index declares engine 7.0.0 and is not substituted for the required 7.0.1/schema10 downstream artifact.

Artifact acceptance builds the actual shipping embedded app and exports closed index files outside its owned simulator before deleting that simulator. Publication and final TestFlight remain pending until their respective gates pass.

The full v36 native corpus index/reopen stage passed in run 42468694097: 8,148 books, 7,660,127 documents, zero quarantined books and four real reopen searches. That workflow failed release creation with HTTP403 and did not retain its package, so it is not portability/publication acceptance. Corrected full run 42480486024 and mini run 42480483741 build at 013f0a9a; subsequent app changes concern native UI, not the engine, corpus or index format.

The user explicitly added the thirteen previously deferred iPad failures and the phone regression to this session. Prepared corrections and the genuine baseline evidence are recorded in ui-acceptance-repair.md. These failures must be rerun before this integration's TestFlight upload; the other chat's manual-beta exception does not satisfy this session's acceptance.

The latest synchronization check still finds UI commit 661d53e0 fully merged. That separate chat completed TestFlight build 10101 with known UI issues; it is not this integration's release. The primary checkout remains at 59b01fa2 with untracked diagnostics/helper files, which are left untouched and are not silently imported. This integration has no new commits from that UI branch outstanding. Final synchronization must be checked again before delivery.
