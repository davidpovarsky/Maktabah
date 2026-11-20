# Local annotation body and original Store session candidate

## Status and exact source

Source candidate: `4be6c9b27fa6c882275cddf209f5959cb9b9690b`, parent `689d8db5a1186272779b278a5a86752ed9acef6a`, authoring branch `codex/otzaria-local-annotation-editor-20261120` in `davidpovarsky/Maktabah`. This is a local persistence/host-session candidate. It does not mount an Anytype editor or complete CROSS-APP acceptance.

Actual Linux results are **18/18 source-extracted SQLite statement controls**, **15/15 Python evidence-gate controls**, and exact source-preservation checks. Swift parsing, typechecking, the **43 whole-source Apple component controls**, and the **two separate-process cold-reopen gates** are **NOT_RUN**. The original exchange 28+2 regression is prepared as a required follow-up, not transferred from its earlier source. No workflow was activated by this authoring tranche.

The separate successful Anytype Apple43 result concerns the original Anytype document/writer components. Its success does not establish compilation or execution of these 43 Maktabah local-body controls.

## Concrete consumer and transaction

`AnnotationStore.makeLocalAnnotationEditor(annotation:supportedFormats:)` is an explicit extension on the actual original Store. It accepts an already-saved original row and its existing CloudKit UUID, captures the current original profile database handle, and creates a one-way local host lifetime. There is no default body format or synthesized Anytype document, Space, account, or renderer.

The new consumer reads the original annotation through its original row mapper and retains the canonical ledger source witness. Preparing a save binds the captured session/profile/UUID, source bytes, expected version, mutation ID, exact declared body format, preview, and editor revision. The commit revalidates these values on the same captured SQLite handle. Within one original outer transaction it changes only the plain note preview and `lastModified`, queues the original pending CloudKit upload, and records a new immutable body version through the original ledger with explicit destinations `[]`. It creates no external outbox delivery or acknowledgement.

The original live ledger entry point still rejects an empty destination list. Its shared commit body is otherwise preserved. The source proof restores its original complete bytes after removing the explicit local wrapper, local scope choice, and added read APIs. `liveExchangeEnabled` remains false.

Same-mutation durable replay returns the existing receipt without another preview update, timestamp, version, or publication. A completely rolled-back attempt has no durable timestamp to retain. An older mutation cannot overwrite a newer head. Once a transaction actually commits, later retirement produces `completedWithoutOwnership` with the actual receipt; it is not reported as rollback and is not retried automatically.

## Ownership and preservation

The Repository adds only a captured-handle boundary and synchronous one-way invalidation at its existing setup/connect/disconnect mutation points. An A→B→A profile change or reconnect cannot revive the old lifetime. Transaction code does not reacquire the Repository state mutex; it uses the captured handle plus an independent short lifetime mutex. The original disconnect state→SQLite ordering is preserved.

Read publication now rechecks both the actual original source witness and current body version after asynchronous work. Save delivery uses the same guard. A fabricated request cannot carry valid source/version fields but different inherited document bytes: snapshot document and version must agree exactly, and preserved envelope fields are inherited from the fresh database version inside the transaction.

Legacy notes are readable without installing the new ledger schema, changing the UUID, or backfilling a body. Existing unsupported envelope/body versions remain readable as their exact bytes and cannot be edited by a consumer that has not declared the format. Unknown fields in supported envelopes survive a supported edit; prior immutable payload bytes remain unchanged. Partial/future database schemas are refused, not repaired by reads. The fixture's two-block payload is deliberately opaque test data and is **not an Anytype serialization claim**.

Normal `AnnotationStore.swift`, the Annotation model, original Save/Cancel sheet, CloudKit manager, SQLite driver, pending queue, codec, and original exchange driver/tests are byte-identical. Original tags, locators, range metadata, colors, timestamps other than the intended note modification, and existing queue entries are retained. A later ordinary plain Save preserves historical rich bytes but makes the prior source-bound body stale; this candidate does not invent an implicit format conversion or conflict resolution.

New source files are registered in the same three original app targets as the existing ledger: `Maktabah-iOS`, `Maktabah`, and `Maktabah-Direct`. No package, SDK, resource, entitlement, signing or target configuration is changed. A standalone fixture compiling the complete Repository must now also include the new LocalEditor source dependency; the prepared Apple driver does so.

## CloudKit boundary remains explicit

After a real local commit, the consumer invalidates the existing Store caches and emits its existing payload-free tree invalidation. It admits the existing plain-record upload only while the captured owner/source is current. The original upload pipeline then uses `Task.detached` and its debouncer, later reads `core.zoneId`, and removes pending rows through its existing coordinator after awaits. This tranche does **not** prove that later live transport/account/profile completion is still owned by the editor. It neither cancels nor rolls back a previously admitted remote operation. If immediate publication is refused, the original pending upload remains durable in its captured profile database.

Future live CloudKit completion ownership is a distinct integration seam. No fake destination, live exchange enablement, remote ACK, or remote rollback is used to bypass it.

## Evidence and remaining Apple work

`SOURCE_PROOF.json` authenticates 18 canonical base inputs, proves 15 unchanged inputs and exact inverses for the three modified originals, enumerates all nine target source memberships, and lists the 43 unique component declarations. `BASE_INPUTS.json` carries the original Git blob, SHA-256 and byte counts. `SOURCE.patch` is the complete existing-file delta. The sealed archive retains all originals, all 11 candidate files, the reproducible source-proof script, source publication receipt, and every executed SQL/Python result.

SQL attempt 1 is retained on the earlier source before the final read-publication guard; SQL attempt 2 passes the same 18 checks on the exact final source. Both execute real SQLite statements, constraints and transaction rollback, but not Swift control flow. The 15 Python controls use explicitly synthetic receipts to prove the evidence gate rejects missing/duplicate/failed cases, false cold-process identity, changed bytes, revisions and external deliveries. One also exercises independent readback against the exact source-extracted original schema. These are not 15 application cases.

`APPLE_PLAN.json` gives the bounded commands. The new driver compiles the complete original Repository/Store/model/SQLite/queue/ledger/codec and Core package with the new session, using the installed Apple Foundation/Combine/CryptoKit/SQLite3 modules, original macOS 15 deployment floor and one compiler job. Unrelated catalog/UI/CloudKit boundaries are explicit. It then requires all 43 cases and three distinct executable processes: initial save, cold reopen with a second real save, and a second cold reopen. Exact UUID/row/source/payload bytes, both immutable versions, original tags/queue and zero external destinations are independently checked with Python SQLite. This is component process persistence, not an app relaunch or UI mount.

The original Anytype importable target/resource boundary and actual Maktabah mount are still separate work. A real renderer must retain its genuine document/controller ownership and declare its actual body format before connecting this session. Apple compilation/execution, original exchange regression, original app target builds, actual renderer editing, Native Save/Cancel/cold-launch behavior, and physical-device acceptance remain open.
