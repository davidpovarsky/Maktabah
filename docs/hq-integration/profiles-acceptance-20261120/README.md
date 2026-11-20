# Profile colors, historical migration and acceptance reconciliation

Source base: bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1. Work branch: codex/otzaria-acceptance-reconciliation-20261120.
This tranche follows the user's standing authorization and the manager's explicit scoped assignment.
It does not dispatch Native CI or change Core/UIRouting packages, the Native manifest, signing, provider capabilities, or user data.

## Delivered code

The existing StudyProfile model gains an optional semantic color (blue, teal, green, orange, red, purple).
A missing value decodes as nil. Nil is omitted when encoding and keeps the original inherited symbol style.
No workspace schema bump, migration or eager sidecar write is introduced.

The original profile editor exposes a native color Picker, including an explicit default option.
Save commits name, icon and color together through the original StudyWorkspaceStore.transaction.
Cancel only discards editor state. The existing rename API preserves the selected color.
The existing profile-management row and profile-menu icon render the selected color; no alternate editor or store is added.

All four production files, the existing portable test and the existing Native test file are absent in the verified original-upstream tree d46af139b3a265399c16d87f5923acd8e3444024.
They are downstream-owned. This change does not add a protected-source exception.

## Executed validation

- 89/89 portable workspace checks passed: the previous 61 plus 28 new historical-migration/color checks. Exact command and output: workspace-tests-initial.json and workspace-tests-initial.log.
- The historical fixture generator compiled and executed the unchanged production Codable declarations from f092f3996927251d105dfb9243dfac487b196534 (before the workspace) and bfc7f5a6aa849ab7e9a892cf63c693a8f49ac8a1 (before color). See historical-fixture-generation.log and tools/fixtures/study-workspace/provenance.json.
- Five Swift files passed syntax parsing with the Apple target enabled on the Windows Swift compiler. The retained SDK/sysroot warnings make the boundary explicit: this is not Apple-framework typechecking.
- Current source-port hash reconciliation and its independent file/diff verification are recorded separately. Historical evidence is not rewritten.

The new tests begin with the historical encoder's JSON bytes, decode the actual production iOSReaderSession and StudyWorkspaceSnapshot types, use BackendSessionIntegrityRepair and the actual workspace store/attach path, and check exact identity, locators, selection, viewport, archive bytes, idempotence and cold reload.
They also check legacy missing-color decoding, byte-preserving load, one atomic revision, persisted round-trip, untouched profiles/groups/scenes, rename preservation, real write-failure rollback, reset to omitted default, and explicit/default profile creation.
The identities and book titles in those fixtures are constructed test data. No catalog existence, real user session, UIKit hydration or production-provider claim is made.

## Prepared Native acceptance

Selector: StudyProfileNativeAcceptanceTests/testProfileColorSaveCancelAndColdRelaunchPreserveWorkspace.

The new class is appended to the existing FaithfulReaderUIAcceptanceTests.swift and inherits R27NativeUIBase's realUI bootstrap.
It requires an actual iPad Simulator; it is not a phone or physical-device result.
It uses the original profile menu/editor/Picker/Save/Cancel, and only reads the uniquely assigned actual workspace sidecar.
It observes a second profile created through the real UI; Cancel leaves profiles unchanged; Save produces the visible selected color and only the intended profile field;
the other profile, groups, scene selections and original reader locator remain intact; cold relaunch retains the choice; explicit default removes the optional key.
Native screenshots and exact before/after sidecars are retained by the test.

Apple SDK typecheck and this Native case are NOT_RUN in this tranche. The manager owns final registration and execution together with the integrated source.
No parent task is completed on the strength of portable or syntax checks.

## Reproducibility and rollback

Run python Scripts/CI/test-faithful-workspace.py for the actual portable suite.
The optional historical fixture regeneration/checker requires the exact historical Git objects and Swift; ordinary CI tests use the committed JSON and do not require an unshallow fetch.
Run python tools/fixtures/study-workspace/generate-historical-fixtures.py to compare generated historical bytes; --write is the explicit fixture-generation operation.
Run python docs/hq-integration/profiles-acceptance-20261120/verify-provenance.py for the bounded source-port ledger.

Revert this tranche's commit to remove the new UI and optional field. Existing Swift Codable readers ignore an unknown color key; user files, the original reader session, annotations, books and database are not deleted or rewritten for rollback.
A subsequent ordinary old-version save can omit the optional cosmetic choice, so preserving that choice across a binary downgrade is not promised.
The separate iPad feature-off gap is owned by the manager/QA and is not fixed or marked verified here.
