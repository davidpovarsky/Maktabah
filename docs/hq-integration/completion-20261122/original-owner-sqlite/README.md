# Original Owner + original SQLite composition controls

This packet joins the unchanged original Anytype EditorDocumentWriteOwner, Lifetime, Operation and InvocationDispatchBinding with the complete original Maktabah SQLiteDatabase. It uses six new fixture-only controls and a separate-process readback. Current preparation status: NOT_COMPILED / NOT_EXECUTED; actual outcomes must be read from the later retained execution receipt.

## Source and fixture boundary

The original Owner source is anytype-swift commit 553d4ae90eb8fb0ec21b5ecc319b43db40d2dba2, canonical SHA256 b0ae02be8c28c22246d29bf927cb154e10019d841f3b831771f968a8938f7d46. Seven dependency files are reused byte-for-byte from the existing property-modal-controls ZIP (SHA256 1d21d47b8cd407675265c87a82a2c6a32d1dee537b524eed6f10179ed7194514). Only the original ProtobufMessages import is removed when compiling these original files in the same module. The marked OriginalChannelPinPermission region retains its exact bytes with a Foundation import.

OriginalTypePermissionProbe supplies explicit disposable document/permission values; the new FixtureDocument supplies an editable immutable document value. These are not an engine, account service or Owner implementation. The actual Owner and all its admission, operation, rejection and drain behavior are unchanged. No previous modal/property controls or entrypoint is included or rerun.

SQLiteDatabase comes unchanged from integrated application67518e8df6975c976e8f1cd9e622328dc45985fc. The existing fail-fast UnusedZstdBoundary only satisfies the unrelated compressed-column symbol; these tests never invoke it. Every table is explicitly named fixture_fact, fixture_parent or fixture_child in a disposable database. No production ledger table/schema/version, native identity writer or native receipt API changes.

## Six actual composition controls

1. A current Owner admits a real outer SQLite transaction; COMMIT succeeds, an independent connection sees the row, and current-owner success is published.
2. Account retirement before Owner admission rejects the body; no SQL transaction or durable row is created.
3. A separate thread calls the actual account Lifetime.beginClosing after Owner admission. The admitted original transaction commits, then the original Owner returns completedWithoutOwnership. The durable row is retained while current success stays false.
4. Retirement after actual COMMIT, before the Owner wrapper returns, likewise preserves the durable row and reports completedWithoutOwnership; the fixture performs no reset or recreate.
5. A deferred foreign-key violation allows the transaction body to finish and fails at the real SQLite COMMIT. The original transaction rolls back, restores autocommit and leaves no fact/child visible to a fresh connection.
6. The actual Owner pending registry/onDrained callback and account Lifetime.waitForOperationsToDrain remain pending while the synchronous admitted transaction/closure is active. Explicit synchronization establishes the ordering; a bounded250ms negative hold checks noncompletion. Both drains then return after the real outer COMMIT, with the row intact and no current success.

A second executable process opens all six databases using the original SQLiteDatabase, verifies the expected rows, checks the failed deferred child never survived and records a PID different from the control process.

The fixture composition seam uses the existing Owner method outside the existing database serialization and outer transaction. It does not expose a production writer or provide native identity/body authority. This packet measures admission/drain and durability, not actual AccountManager/Space runtime, original ObjectShow/export, schema classification, rich-body application, transport, ACK, original-editor UI or StageB-F acceptance. A future production writer still needs the separately reviewed opaque native proof and exact pending-delivery validation at this boundary.

## Running the new packet

Use the existing installed Swift compiler with Swift5 language mode and complete strict-concurrency checking, matching the verified original Owner portable dependency envelope. Windows uses the original Windows SDK winsqlite3 header/import library. The portable runner also retains an Apple SDK SQLite path without introducing a replacement module map; no Apple execution is claimed by preparation.

Run run-original-owner-sqlite-controls.py with a new explicit --result-dir. It creates a fresh owned build, records exact canonical/compiled source hashes, executes only the six new cases and the one fresh-process readback, then verifies all source/copied bytes remain unchanged. It preserves raw stdout/stderr, compiler and binary hashes, commands, actual Owner outcomes, independent durable-row observations and process IDs.
