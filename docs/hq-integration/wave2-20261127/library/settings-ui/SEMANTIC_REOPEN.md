# Settings update: actual saved-object reopen gate

## Status

The final source in `Maktabah-iOSUITests/ProductionOtzariaAcceptanceTests.swift` has SHA-256 `122fdb0babaf9ceec8c34ba1695b9392ac62e53733f84587afe86231480c0108`. Only the additive `ManagedLibraryUpdateAcceptanceTests` class changed; the pre-existing classes remain byte-identical.

Apple SDK typecheck passed on the Scaleway Mac at 2026-11-27 02:44:08–02:44:09 UTC. `typecheck-attempt-6/RESULT.json` SHA-256 is `92e05043ebac84d09b0bf2c5199655fd4b4ed86edf23d1f25e1f290157fba206`. It records the exact source and base-file hashes before/after, command, exit 0, 74 existing warning diagnostics, no new-class warnings and no compiler errors.

**Native application UI execution: NOT RUN by this evidence commit.** No corpus install, simulator launch, xcodebuild or application success is inferred from the compiler result.

Attempt 4 is also retained. Its raw `warning_count: 148` counted every occurrence of the diagnostic marker, including rendered source annotations; its actual warning-header count is 74. The original receipt is unchanged. Attempt 5 reports 74 diagnostic headers correctly. Both source hashes and compressed raw logs remain distinct.

## Exact execution contract

The existing registered test selector remains:

`Maktabah-iOSUITests/ManagedLibraryUpdateAcceptanceTests/testOrdinarySettingsUpdatePreservesProductionLibraryAndUserState`

Prepare `OTZARIA_LIBRARY_UPDATE_CONTEXT` using `Scripts/CI/prepare-managed-library-update-context.py` for the same actual owned Simulator UDID and app container that completed ordinary managed-v40 installation. Require the original current v40 source/manifest admission. The helper must discover or receive actual paths; it does not create user rows, copy a library or seed an unrelated test namespace.

Run this phase after both v40 search packages, Reader/Inspector and Groups100, because it replaces the managed library with the live official latest release. The observed target is v41 release 459809828, tag `v41-20261126162443`; the test independently verifies that the original Settings release discovery still resolves exactly to the context's target. If latest changes, rebind explicitly rather than treating another target as v41.

## Real fixture setup

The test first selects the original Library tab in the ordinary workspace. It preserves an already visible canonical reader. Otherwise it reads the real full-v40 catalog identity for Berakhot (book 103, title ברכות), opens the unique hittable Library palette, searches that actual title, taps its unique original result and requires a hittable nonempty reader with the exact canonical book ID. No namespace or database rows are seeded. It then creates the following through existing user controls:

1. Open History & Favorites, identify the card for the current canonical title, and use that card's own Add Favorite star if needed. Read the actual source-qualified favorite/history identity and open the card into a hittable reader. The selected book must have one unambiguous favorite locator.
2. Tap a real visible source paragraph to open Inspector, then create a Note with a unique body and tag through its original editor and tag field.
3. Read the created row from the actual annotations database without writing SQLite. Require its canonical Otzaria book/legacyLine locator to resolve in the original full v40 database.
4. Capture a nontrivial source quote from the note's actual context and require that quote in the original reader's exposed text. Whitespace and directional formatting controls are normalized; no alternate text corpus is substituted.
5. Capture the current ordinary group/document IDs and canonical session fields, then copy the current tabs through the original group UI. Require a distinct saved group and document.

The semantic proof stores the actual title, book ID, reader locator, note ID/context/locator, favorite locator, original group and copied group. It does not synthesize any of these fields.

## Existing transactional gates retained

The test still uses the actual original Settings install action to:

- begin a real split full-library download;
- pause after at least one MiB and verify the old database hash, old manifest and logical user state;
- cold-open the old reader with the retained download intact;
- create a token-marked immutable obstruction only at the pending metadata path after original recovery finishes;
- resume the download and require the observed original UI metadata-promotion failure;
- verify rollback of the full old database and manifest plus logical user state;
- remove only the verified owned obstruction, cold-reopen the old reader and invoke actual Retry;
- verify success against current official manifest asset/release/digest, SQLite quick_check and published full-corpus book/line/link counts;
- verify preserved notes, tags, favorites, reading positions, ordinary workspace/profile/group IDs and tab order;
- cold-open the new library and recheck its exact locally observed full hash without redownload.

The raw HTTP Range acceptance is a separate original installer gate. A retained-byte check in this case is not relabeled as an HTTP response witness.

The managed transaction filenames are `seforim.db.previous`, `seforim-installation.json.previous` and `seforim-installation.json.installing`. Successful finalization removes them. The final controller must require their absence, not expect a retained v40 database after successful cleanup. Old v40 identity is checked before update, pause, rollback and cold recovery. Current v41 identity is checked after success.

## New post-update semantic gates

Only after the original complete logical-state comparison and the v41 cold launch does the case perform these legitimate navigation actions:

- Select the original group, require its exact saved group/document/session identity, tap the original card and verify a hittable reader with the saved canonical book, title, locator and context quote.
- Repeat for the copied group after a real group transition. Both group UUIDs and document UUIDs must match the saved objects.
- Open the saved Note from the actual restored source's Notes panel. Require its original body in the real editor, original tag in its field and unchanged persisted row including locator/context. Cancel the editor and return to the real reader, where the captured source quote must still be present.
- Open the saved original History/Favorite card, require unchanged canonical favorite/history identity and title, and verify the real reader source again.
- Finally revisit ordinary Settings and require the actual up-to-date state with no install action.

The current original Notes route opens the editor; it does not expose a dedicated go-to-source action. The case therefore checks the real source context in the restored reader surrounding that editor, without claiming an invented Note navigation button. Inspector segment Note creation is not evidence of UIKit's exact selected UTF-16 range.

The quote requirement is scoped to the captured objects. It does not assert full v41 body equivalence to v40, all-ID stability, or a migration guarantee for every book.

## Receipts and attachments

`NATIVE_CONTRACT.json` lists exact fixed attachment names and dynamic UUID name patterns. Successful case execution must be read from the actual xcresult in addition to the attachments. Screenshots or a JSON attachment alone cannot establish that the test passed.

The final `settings-update-installed` JSON records the observed new database SHA-256, old v40 SHA-256 and committed installation manifest. The semantic pre-update attachment captures real canonical references and source quote. Per-route attachments record each post-update source check; the saved Note editor has its own screenshot.

The UI runtime remains the authority for selector behavior, original adaptive group controls and any defects found in the integrated candidate.

## Ordinary Library prelude checkpoint

The semantic-only source 17ef068e and successful attempt 5 remain preserved. Prelude source 122fdb0b is the current runtime contract. All saved-object and transaction assertions from the first preservation call onward remain byte-identical. Both the existing-reader and real-palette routes emit settings-update-reader-prelude-state JSON plus a settings-update-reader-prelude screenshot. The broader production test that intentionally leaves an empty group is not invoked.
