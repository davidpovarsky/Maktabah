# Original Settings update: same-process search readiness hooks

## Delivered scope

Six lines in two additive hunks connect the already registered ordinary Settings update case to search-owned `OriginalSearchDataUpdateReadiness`, finalized in commit `78f61e08694d463a289072c41c1e27f04c264c8d`. The helper's exact addition SHA256 is `0c50eda55965421f80cdd94f0e6e365c7399265ea527bb4bd543ec8c59abf36f`.

Selector remains:

`Maktabah-iOSUITests/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState`

No Source, SDK, project registration, installation, default, or user-state implementation changes. Existing transaction, real failure/rollback/Retry, integrity, cleanup, logical user-data preservation, saved-object reopen, and final cold-launch assertions remain unchanged.

The first call runs after actual failed-promotion recovery, the existing cold-open proof, and the old v40 database/manifest checks; it runs immediately before the final original Settings Retry. It requires both previously installed v40 search packages to become Ready through original Search Data and returns to the same original Library tab.

The second call runs after visible update success and exact committed official release/asset/digest validation, before the final cold launch. The caller supplies the current database byte count observed with `FileManager.attributesOfItem`, not a presumed v41 size. The helper requires both v40 packages to report their exact incompatible/unavailable status in the same observed original application process, stays settled for three seconds, and returns to Library. No query, repair, download, seed, or book-navigation action is added.

The helper uses the original public XCTest Application PID field and records its hierarchy digest before/after. It rejects the XCTest runner PID and any cold relaunch between the two calls. Its actual runtime status strings are currently Hebrew even under this case's `en_US` launch; this is not an English-localization acceptance.

Attachments added by the helper:

- `settings-update-warm-search-ready-before-final-retry`
- `settings-update-warm-search-mismatch-after-final-retry`

Each preserves sequence, actual original application PID, capture time, hierarchy digest, displayed statuses, and explicit scope. The after record binds the before observation. Additional actual PID hierarchies and original Search Data screenshots are retained by the helper.

## Actual verification

The whole modified `ProductionOtzariaAcceptanceTests.swift`, unchanged original `MaktabahUITestBase.swift`, and exact helper/dependency blocks from the committed search UI file were typechecked together against the original iPhoneSimulator 27 XCTest SDK with Swift 6 and the target's concurrency/import settings. The changed caller compiled with **exit 0, no new-class warnings, no errors**. Existing base/legacy diagnostics are retained.

This is **Apple SDK source checking only**. No Maktabah app launch, Simulator UI, Books Updates execution, warm readiness acceptance, or cold R08 acceptance was performed for this checkpoint. The search-owned helper's separate source check is not rerun or relabeled here.

Exact final caller SHA256: `03f61db1bd4720f3e68fffbdec523b3b8d5a0493f5636ae144fad6626d97c377` (72,871 bytes). Immediate previous caller SHA256: `122fdb0babaf9ceec8c34ba1695b9392ac62e53733f84587afe86231480c0108` (72,371 bytes). Removing only the two inserted hunks reproduces the previous bytes.

Owned Mac path: `/Users/m1/builds/otzaria-wave2-library-controls-20261127/ui-warm-readiness-attempt-1`.

Actual check finished at 2026-11-27 04:46:05 UTC. RESULT SHA256: `3a88a9cbf35282b9bc141787744e525460ff1f1837d7fb1f887576459f038595`. The helper-support extraction records each unchanged block and whole committed search-source SHA256 `6acb1e26a37bef05706662049e8ba755ccfd72d83e060a6c9405459ecec8ac37`. Exact compiler command, current input hashes, before/after input agreement and logs are retained.

`NATIVE_EVIDENCE.json` SHA256 `fc2a0020fb9baa99cffab49c1973e3dd0449f09bf199dafbd232b7049bfc0849` binds all six stored native files and the original decoded bytes of deterministic gzip archives. No cache or old evidence was deleted.

The remaining acceptance is the actual original Settings case with both previously installed published v40 packages and the real latest v41 update. Its separate post-update cold R08 case remains independently required.
