# Ordinary Settings update acceptance

## Status and source boundary

The added `ManagedLibraryUpdateAcceptanceTests.testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState` lives in the already registered `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift`. The three historical v32 tests and their pinned source constants are preserved. This is an additional managed-v40-to-actual-latest gate; it does not relabel v32 or component evidence.

Apple SDK typecheck passed with source SHA-256 `5093acece3e24a951f796f7ce238a739a25df6a71dfc7d9a73c8ae8fcd0fe504` and unchanged base SHA-256 `2a422d019d1451548ef2df17b46fc39d1bbb0535be94392ee725bcdb6ec64e94`. The command uses Swift 6, iOS 27 arm64 Simulator, Xcode 27.0/Swift 6.4, MemberImportVisibility and the actual approachable-concurrency features. `settings-ui/typecheck-attempt-2/RESULT.json` records the exact command and input hashes; terminal exit was 0 at 2026-11-26 23:29:06 UTC. The raw 74 warnings are retained. Attempt 1 failed because the standalone harness omitted the SDK Developer/usr/lib Swift XCTest overlay; its original log is retained separately.

**Runtime status: NOT_RUN.** A successful typecheck does not prove native UI behavior. No app or simulator was launched by these compile checks. The metadata helper has Python syntax validation only until the common native lane executes it on its owned installed app. A real Settings Retry/rollback failure journey is a separate additive checkpoint under preparation; the current case covers ordinary discovery, download pause, retained bytes, cold reopening, resume, completion and current-version recheck.

## Exact current and target sources

Current managed production source: release 455390662, tag `v40-20261123094345`, 4,355,063,808 database bytes, SHA-256 `8389709c1702753af6f0719ef1c98c09854450e48ebb05fe1f95486b26348b01`. The prior 7,925,185-document validation remains attributed to its original receipts.

Normal Settings retains the real `https://api.github.com/repos/Otzaria/SeforimLibrary/releases/latest` lookup. At preparation, actual latest is release 459809828, tag `v41-20261126162443`. Its full asset is exactly `seforim-schema7.db.zst.manifest.json`, rather than any similarly suffixed patch manifest. The official full manifest is 589 bytes, SHA-256 `59f87a390c404ac60d75df7812cc6217eeb40e4de31336d3a2cb01e1f3d05ccb`; its 2,124,305,356-byte archive SHA-256 is `f768b8f871d51b3f97eac3a0c508a4d4b11f8620c42a2d5dc30da839ecd954ec`. Official stats report 8,270 books, 7,934,869 lines and 7,005,434 links. The XCTest fetches and validates these public metadata asset sizes/digests at execution, then independently checks installed SQLite integrity and counts.

No native-bootstrap release selector, database override or test workspace namespace is used in this gate. Frozen v40 bootstrap/search acceptance remains a distinct earlier phase. Run this updater only after all gates that require installed v40.

## Same-container preparation and execution

Keep the same owned installed app/simulator used for v40. Leave a genuine book open in the ordinary production Library tab. Existing `.realUI` reader/group/annotation test classes select miniTest10 and often a UUID workspace namespace, so their state is not automatically ordinary production preparation.

The context helper discovers the installed app data container through the original `simctl get_app_container` command. Supply only the actual managed database path already observed by the native installation lane:

    python3 Scripts/CI/prepare-managed-library-update-context.py \
      --udid "$UDID" --database "$ACTUAL_MANAGED_V40_DATABASE" \
      --output "$EVIDENCE_DIR/settings-update-context.json"

If there is no unique existing annotation repository inside the app data container, open original Reader/Notes once to initialize it, or supply its observed `--annotations-path`. The helper never creates or inserts annotation records. It writes a context and a separate proof marked `CONTEXT_PREPARED_UI_NOT_RUN`; it does not claim the database hash check performed by the XCTest.

The common test runner must forward `OTZARIA_LIBRARY_UPDATE_CONTEXT` pointing to this JSON to the XCTest process, and preserve its real `SIMULATOR_UDID`. Select:

    Maktabah-iOSUITests/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState

Context keys are `simulatorUDID`, `databasePath`, `downloadsPath`, `annotationsPath`, `qualifiedLocatorsPath`, `workspacePath`, `expectedCurrentTag`, `expectedCurrentSHA256`, `expectedTargetID`, `expectedTargetTag`.

The correct ordinary stores are app data `Library/Application Support/Maktabah/qualified-locators-v1.json` and `Library/Application Support/ChavrusaText/StudyWorkspace/workspace-v1.json`. Legacy `History.sqlite` does not own source-qualified Otzaria favorites. Production downloader storage is managed `Otzaria/Downloads/Maktabah/Otzaria/Downloads`, from the two original storage resolvers, not an inferred shortened folder.

## Original UI data creation and assertions

The XCTest creates a uniquely marked quick note through Study Tools → Notes → Add Note, enters its tag in the original comma-separated field, and saves. Read-only SQL then requires the exact annotation/tag relationship. It opens the original History tab and uses a real book-row star, explicitly excluding the toolbar Add Favorite sheet launcher; the qualified store must contain an Otzaria favorite. It opens All Tabs → Tab group actions → New group from current tabs, enters a unique name in the original prompt and saves. The observed ordinary sidecar must contain a new group and disjoint copied document UUIDs. The active reading unit must remain unchanged. No raw database rows or synthetic workspace JSON are injected.

Preservation snapshots include all annotation/tag/relationship columns, source-qualified locator mappings/favorites/history, profiles, group identity/order and tab identity/position. Only legitimate history `lastOpened` refreshes and workspace bookkeeping revision/OS scene identity are excluded; notes, tag relationships, favorite/source/position data and group membership are nonempty and required. Receipts attach hashes instead of arbitrary private note contents.

The Settings journey starts at the original `main-settings-button` and `settings-otzaria-library-updates` navigation link. It observes the exact actual latest tag, starts the real download, pauses after at least one MiB, checks retained native part bytes and unchanged old corpus/manifest/user state, cold-relaunches, resumes through the same original control, and requires actual native success. It verifies the committed official release/asset identity, SQLite quick_check and counts, safe transaction/download cleanup, preserved logical user state, a fresh database hash and a cold original-reader reopen. A final normal Settings check must report that the library is current. HTTP Range packet evidence remains attributed to the separate native bootstrap gate.

## Ownership and execution evidence

Oracle source worktree: `/mnt/development/projects/worktrees/Maktabah-wave2-library-20261127`, branch `codex/otzaria-wave2-library-20261127`, integration base `29a731e273f9a757c743c49e182fece0e8047d46`. This checkpoint changes only the registered downstream test file, a new standalone metadata helper and this lane's evidence. Product transaction fixes and their nine real-filesystem controls remain in earlier commits `0d0a010c3ee1edda244f9fb37431016d12320234` and `618dd4d1fdabae66b4f515436e006c216734a36e`.

Mac checks ran only under `/Users/m1/builds/otzaria-wave2-library-controls-20261127`, with one owned module cache reused sequentially. Actual initial UI typecheck footprint was 96,636 KiB; no shared cache or other agent's artifacts were removed. The root agent owns common app/simulator execution and publishes runtime receipts separately.
