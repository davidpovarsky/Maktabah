# Books Updates: source identity, caches and saved references

## Scope and status

This is a read-only source audit of the Books Updates path and official producer metadata. The audited Maktabah integration baseline is `cce695b38e801c1121524ed8776d6606604d7778`. It does not report execution of a v41 database, Settings UI, or either installed search engine after a real update.

The subsequent Inspector generation repair is committed separately as `9d4c6ded641fad00cb9e0ca6fd0b931731e5c3fd`, with original-source Apple Catalyst controls under `../inspector-generation/`. Search readiness and source validation are owned by the search agent and require their own final commit and receipts. These findings are not permission to substitute a component pass for production UI acceptance.

## Official target observed

At 2026-11-27 01:34:46 UTC the official published target was release `459809828`, tag `v41-20261126162443`. The requested v40 production acceptance remains separately pinned to release `455390662`; ordinary Settings must continue to resolve the real latest release.

`RELEASE_METADATA.json` contains parsed captures of four small official assets. Each original response was checked against the GitHub asset's byte length and SHA-256 before parsing. The receipt records those original hashes; the pretty-printed receipt is not claimed to be the original asset bytes.

| Asset | ID | Original bytes | Original SHA-256 |
| --- | ---: | ---: | --- |
| build_provenance.json | 797405530 | 6774 | 9e72f025299cf518b84e11c22d821edc4fc2f37b7153d949e7df30cfe16303a4 |
| seforim-schema7.db.zst.manifest.json | 797419887 | 589 | 59f87a390c404ac60d75df7812cc6217eeb40e4de31336d3a2cb01e1f3d05ccb |
| library_stats.json | 797405753 | 82 | 7effff3262c0db07ddd6eaffe0e4d5b63c96fb5bfbac38787094a2bd2058e9c5 |
| patch-v40-v41.db.zst.manifest.json | 797419752 | 8541 | 4f1d6543b930e4fc6d45d05f86faee777f1140f12795f1bb22f7dbb514a85687 |

The full v41 archive is declared as 2,124,305,356 compressed bytes with SHA-256 `f768b8f871d51b3f97eac3a0c508a4d4b11f8620c42a2d5dc30da839ecd954ec`, split into 1,992,294,400 and 132,010,956 bytes. Its manifest does not declare the extracted database byte length or SHA-256, so a precise uncompressed peak-disk figure is not established here. Official statistics declare 8,270 books, 7,934,869 lines and 7,005,434 links.

Only metadata was downloaded. Neither the v41 full archive nor the 14,618,117-byte v40-to-v41 patch payload was downloaded for this audit. Changed table hashes in the patch manifest establish changed table content, not which primary keys or positional references changed.

## Existing completion and invalidation chain

At the audited baseline:

1. `Source/Otzaria/Bootstrap/OtzariaBootstrapAdapter.swift` installs within the backend coordinator's exclusive resource-update boundary, then resets the bridge and closes open Tantivy engines.
2. `Source/LibraryBackend/BackendCoordinator.swift` advances its resource generation before and after exclusive updates, cancels registered resource work, and clears resource witnesses.
3. `Source/Otzaria/Features/Settings/OtzariaLibraryUpdateView.swift` reports completion and requests normal library reload.
4. `Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift` handles `managedLibraryDidUpdate` by clearing Otzaria view-model cache while retaining the workspace store.
5. `Source/LibraryBackend/QualifiedLocatorStore.swift` and `LegacyIdentityRegistry.swift` preserve canonical backend/work/position references. They do not bind each saved reference to a database release or migrate a positional `legacyLine` through a versioned line-ID mapping.

That sequence does reset several resources. It does not by itself prove every retained consumer has rejected its own cached data.

## Confirmed source defects and ownership

### Search/index identity

The audited call chain was `UnifiedSearchSessionController.handleBackendChanged` → `clearResults` / `stopEngineWork` → `OtzariaTextSearchViewModel.clear`. Clearing results did not revoke the Otzaria readiness state. Ordinary query entry checked the index directory, while `OtzariaTantivySearchRepository` could open or reuse an old index without validating it against the newly committed managed database identity.

Relevant files are:

- `Source/ZayitSearch/UnifiedSearchSessionController.swift`
- `Source/Otzaria/Search/OtzariaTextSearchViewModel.swift`
- `Source/Otzaria/Search/OtzariaTantivySearchRepository.swift`
- `Source/Otzaria/Search/OtzariaSearchIndexManager.swift`
- `Source/Otzaria/Search/Distribution/OtzariaSearchArtifactService.swift`

Managed artifact readiness also had a same-build path that did not require the full source manifest validation. This is a concrete source-level path by which a retained v40 index could appear ready after a v41 promotion. It is not a claim that a native v41 search was observed returning a wrong result.

The search agent owns the repair: validate current managed receipt and database identity before readiness and query/cache use; revoke both controller generations synchronously; prevent an awaited configure result from being stamped with a different source identity. Read-only cross-review also identified the asynchronous Zayit restore/configure stamp race and sent it to that owner. No search source is changed by this library audit commit.

### Inspector retained session

`Source/Otzaria/Reading/OtzariaReaderSourcesInspectorHost.swift` placed the generation observer in the visible Inspector branch. The retained `MaktabahTorahInspectorSession` in `MaktabahTorahInspectorAdapter.swift` owned both a TorahInspectorKit repository and adapter locator/unit/link caches. Hiding and reopening the Inspector could retain the old generation's session/cache.

Commit `9d4c6ded641fad00cb9e0ca6fd0b931731e5c3fd` binds session/repository/cache access to the current resource generation, invalidates both cache layers through existing APIs, moves host observation outside the visibility branch, and rejects stale asynchronous provider publication. Ordinary first appearance stays open. The exact original-source Catalyst controls changed from baseline 2/12 to candidate 12/12; they use explicit host/provider boundaries and are not application UI or full-corpus acceptance.

## What producer IDs promise

The official v41 provenance pins producer commit `adb91b287dc6085d702819ff9a20d14d6da666bc`. Three unmodified files from that exact commit are retained under `producer/`, with URLs, Git blob identities, SHA-256 and sizes in `PRODUCER_SOURCE.json`:

- `DELTA_UPDATE_WORKFLOW.md` describes stable natural book keys based on source name and canonical Hebrew title, and line allocation based on book ID, content hash and occurrence index. Unchanged content plus reused build state can retain primary IDs; changed content can receive a new ID.
- `RELEASE.md` documents the previous build-state seed and logical patch roundtrip.
- `IdAllocator.kt` defines the book and line allocation interface. It does not promise that a line's ordinal `lineIndex` remains fixed.

The application currently persists Otzaria `legacyLine` positions. A stable database `line.id` is therefore insufficient to prove a saved note, favorite or tab still points to the same text. This audit does not infer actual v40-to-v41 line-index drift without the databases. The new Settings case checks concrete saved objects against their actual pre-update source quote and canonical book/title/locator after the real update.

## Native follow-up

The additive `ManagedLibraryUpdateAcceptanceTests` case now creates real ordinary UI fixtures and later reopens both original/copied groups, the saved Note editor and the original History/Favorite card. It requires the pre-update context quote to appear in the actual reader and checks saved canonical references and current database title. See `../settings-ui/SEMANTIC_REOPEN.md`.

This is a captured-object scope, not an all-books/all-lines proof. It also does not require the entire v41 reading-unit body to equal v40, because legitimate upstream content changes are possible.

## Producer attribution

The retained producer files are unmodified upstream evidence, not Maktabah product implementation. Their original license and additional attribution terms are preserved in `producer/LICENSE`.

Powered by the technologies that drive Zayit — https://zayitapp.com/
