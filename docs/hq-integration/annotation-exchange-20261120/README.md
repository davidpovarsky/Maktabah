# Annotation envelope and durable exchange ledger — isolated component

## Status and scope

This is an Otzaria-owned, inert component for CROSS-APP task `1220545194715722`, following the Stage A ADR. It is not an embedded editor, an Anytype implementation, a transport, document synchronization, or an enabled application feature. `AnnotationExchangeCapability.liveExchangeEnabled` is `false`.

The branch starts at `9c908a5f73245848d58ed3ad019acac2efd84e34`. The implementation adds two downstream files under `Source/ChavrusaText/Annotations/Exchange`. It leaves `AnnotationRepository`, `SQLiteDatabase`, `SyncPendingStore`, the original editor, CloudKit, the Action Core parser, SDKs, signing, and accounts unchanged. Constructing the component performs no SQL or migration. There is no automatic installation, backfill, Save/Cancel hook, startup task, incoming apply operation, or consumer.

Registration follow-up `a16b151f` adds the two existing source files to `Maktabah`, `Maktabah-Direct`, and `Maktabah-iOS`. All three already compile the original annotation/SQLite sources and link `OtzariaActionCore`; no dependency or entitlement was added. Widgets and tests receive no new membership. This makes the component eligible for the next actual app build, not proof that that build has run. `PROJECT_REGISTRATION.json` records exact file/build/phase IDs. The shared Apple SDK regression driver gains the `annotation-exchange` component gate and preserves the separate crash/reopen logs. Apple execution remains a separate gate.

The accompanying acceptance runner compiles the entire original `SQLiteDatabase.swift` and `SyncPendingStore.swift`, the actual local `OtzariaActionCore` package, and the new component. All writable databases are fresh owned fixtures. Its one ZSTD boundary is fail-on-call and unexecuted; it is not a replacement SQLite implementation. Windows uses real Windows CNG `BCryptHash` SHA-256; Apple uses the component's CryptoKit implementation. Windows cannot qualify the Apple implementation, UIKit, CloudKit runtime, or application target.

## Original transaction and revision model

The original repository assigns `ckRecordId = UUID().uuidString` to a new annotation when absent and writes the annotation, tags, and original CloudKit pending row inside its SQLite transaction. `lastModified` is `Int64(Date().timeIntervalSince1970)`: two changes can share the same whole second. It is therefore never treated as a monotonic revision.

`AnnotationExchangeLedger` requires an explicitly injected original `SQLiteDatabase`. It does not open another connection. Original `SQLiteDatabase.transaction` owns the existing `NSRecursiveLock`, uses a savepoint when already inside a transaction, and rolls back on an error. A future approved Save integration can therefore put the original row write, original `SyncPendingStore.addPendingSync`, and ledger enqueue inside the **same captured handle's outer transaction**. A ledger enqueue failure must propagate through that outer transaction. Swallowing the error, calling a globally replaced repository handle, or sending before outer commit would violate the seam.

No such Save hook is installed here. The repository can replace its connection, and its public transaction helper silently returns if no database is present. Production integration must capture and validate one store/account lifetime, reject a missing/replaced handle, and avoid a false success from that helper. The component is not an authority for which database or account is currently active.

### Optimistic source witness

`captureSource` finds the existing annotation by its UUID without creating or changing one. The original UUID index is not unique; duplicate matching rows are rejected as ambiguous. The witness covers the complete actual row and associated tag rows, with explicit SQLite types. Integer values are exact decimal strings; floating values use their bit patterns; text and blob values retain bytes through Base64. This distinguishes embedded NUL and invalid UTF-8 source bytes that a C-string conversion could collapse. `lastModified` participates as ordinary source data.

Sorted-key JSON of those values produces a canonical local snapshot. SHA-256 binds that snapshot. The witness is an internal value and is not decoded from an incoming envelope. The canonical snapshot and the recaptured snapshot must be identical under the transaction, and the local ledger head must equal the caller's expected revision. Only then can the ledger increment its own positive `Int64` revision. Overflow is rejected.

This is a local optimistic witness, not a cross-device clock, CRDT, or canonical reference resolver. Local row/tag IDs deliberately participate in staleness detection. Source locator values are retained as original opaque metadata; no unsupported backend/reference mapping is invented.

## Envelope v1

| Field | Contract |
| --- | --- |
| `schemaVersion` | Positive exact integer; supported version is `1`. |
| `namespace` | Explicit bounded identifier for the annotation domain. |
| `annotationUUID` | Existing stable UUID; no generated replacement/backfill. |
| `originatingApp` | Bounded identifier; descriptive provenance, not authorization. |
| `source` | Present/absent state, canonical snapshot SHA-256, original source fields and tags. The note body is excluded from locator metadata. |
| `richBody` | Opaque `format`, positive `formatVersion`, exact Base64 body bytes. The component does not interpret Anytype blocks or flatten rich data into preview text. |
| `textPreview` | Separate bounded text; never used to reconstruct the rich body. |
| `editorRevision`, `title` | Optional bounded strings. Editor revision is opaque, not the ledger revision. |
| `deletionState` | `active` requires present source. `tombstone` requires absent source, no rich body, and empty preview. |

The codec reuses the existing public Core strict JSON parser, including grammar, escaped-equivalent duplicate key rejection, exact integers, and depth/node limits. The whole envelope is limited to **65,536 bytes**, including Base64 and metadata. Rich content that does not fit is rejected intact; it is never truncated. This first bounded contract does not support arbitrary large rich documents or attachment transfer. Preview is at most 8,192 UTF-8 bytes, title 1,024, editor revision 512. A source witness is bounded to 8 MiB; a large witness can still be too large for the envelope limit and fail explicitly.

Decoding a known version retains the exact input bytes, including future keys, whitespace, and number spelling. Re-encoding the typed value is not an unknown-field preservation API. Outgoing storage uses the exact accepted bytes. An unknown positive schema version retains exact bytes in an `unsupported` inbox record and cannot be committed to the outbox. Unsupported syntax, invalid versions, malformed known fields, duplicate keys, and oversized input fail without execution.

## Durable storage and receipts

Explicit `installSchema()` creates five namespaced tables and a pending index. It does not change original tables, `user_version`, or foreign-key settings. Schema version, unique identities/revisions, allowed states, positive integer revisions, and bounded required fields have SQLite constraints. This is an initial schema installer with a fail-closed version gate, not a general upgrade/repair framework for an arbitrarily damaged database.

| Table | Purpose |
| --- | --- |
| `otzaria_annotation_exchange_schema` | Explicit singleton component schema version. |
| `otzaria_annotation_exchange_heads` | Local revision for each namespace and annotation UUID. |
| `otzaria_annotation_exchange_versions` | Caller mutation UUID, exact envelope Base64, digest, source digest, revision, and canonical destination set. |
| `otzaria_annotation_exchange_outbox` | Independent message UUID and pending/acknowledged state for each destination/account/Space. |
| `otzaria_annotation_exchange_inbox` | Exact scoped incoming bytes, version, and `pending_review`/`unsupported` state. No apply action. |

The original SQLite binder accepts strings and scalars, not `Data`. Exact bytes are therefore stored as canonical Base64 TEXT without modifying the original binder. The payload is stored once per version, with per-destination outbox rows. Neither the component nor its ACK removes or acknowledges a row from the original `sync_pending` table.

An outgoing commit binds the caller's stable mutation UUID to the exact payload bytes/digest, namespace, annotation UUID, source digest, and destination set. A retry returns the original message identities and revision. Changing the bytes or destination set under that mutation UUID is an explicit conflict. A historical retry can return its prior receipt after a newer revision or tombstone exists; it cannot move the current head backwards or recreate the source row.

An ACK binds **message UUID, destination, account, Space, namespace, annotation UUID, ledger revision, and payload digest**. A wrong field rejects the ACK. The first correct ACK changes only that outbox row. Repeating it returns a no-op. An old ACK cannot consume a later revision or a different destination. Reads validate persisted payload digests and supported outbox envelopes; a dangling outbox version fails rather than appearing as an empty queue.

Inbox messages are scoped to destination/account/Space and message UUID. An exact retry is a no-op; reusing that identity for different bytes or receipt metadata is a conflict. Known envelopes wait for review. Unknown versions remain quarantined. Neither path changes annotations, advances an outgoing head, saves a document, or emits a success ACK.

Scope values are explicit opaque identifiers, not account authentication. A future adapter must bind them to the active authenticated account, Space, and store lifetime before calling the component. Checksums detect mismatched data; they are not signatures, peer authentication, or access control. Old-account rows are retained and do not appear in a different account's scoped query. No global “current account” fallback exists here.

## Acceptance and evidence

Run with the installed toolchain:

```sh
python3 tools/hq-annotation-exchange-acceptance.py --artifacts-dir build/annotation-exchange-acceptance/fresh-run
```

Use a fresh output directory; existing reports are never overwritten. The runner records the exact commit, per-file SHA-256 before/after, compile and execution commands/logs, named component results, and separate process termination/reopen receipts. It independently checks a retained payload against Python `hashlib` and compares original CloudKit queue row bytes before/after ledger work.

The owned schema fixture mirrors every original annotation/tag column and index. The original `AnnotationRepository` class and CloudKit runtime are not executed. The original full connection and queue implementations are executed. Fixture writes represent the approved future transaction seam; they are not evidence that the application Save flow has been integrated.

Abrupt-termination cases deliberately terminate a child process with exit `73`, once after committed enqueue and once before its outer transaction commits. That child exit is never called PASS. A separate new process reopens the database and verifies exact committed replay or rollback of the uncommitted original/queue/ledger changes. This qualifies the tested process-termination recovery, not device power-loss durability or cloud synchronization.

### Observed Windows results

| Attempt | Exact source | Actual result |
| --- | --- | --- |
| `attempt-01` | `f070f218c28611d93146b276a1ff77d75b7a693f` | Compile failed: the test support's Foundation UUID conflicted with Windows RPC UUID. No cases executed. |
| `attempt-02` | `9dc3d29198b39276bc9730b5624171b029be85b2` | Compile passed; runtime exited `3221225501` during the cancellation fixture without a case receipt. No pass count is attributed. The bounded LLDB attempt yielded no trace; its limit is recorded. |
| `attempt-03` | `4dc61536a2ee319cafa21742d0bf858e3d15db52` | **27 PASS / 1 FAIL** of 28 named cases. The detached C callback boundary was fixed in the harness. The failing new regression demonstrated that an inner join omitted a dangling original tag association. Crash gates did not execute after the failed component suite. |
| `attempt-04` | `44a83552c007226ac46f7a48d65c7266cbccec05` | **28 PASS / 0 FAIL**, then **2 separate process-termination/reopen gates PASS**. Both interrupted children exited `73`; both new verifier processes exited `0`. |

The final run was SentinelX `job_6552b8fa62dd`, 2026-11-20 01:33:27–01:34:50 UTC, on Windows 11 with Swift 6.3.3 and actual SQLite **3.53.4**. Both crash fixtures observed `journal_mode=wal`, `synchronous=2`, through the original connection API. The component/test source bytes were unchanged throughout execution. The source fix includes the actual association IDs in a left join, preserving dangling links and duplicate multiplicity in the witness; a peer performed a separate read-only review of that change and reported no blocker.

Python independently verified the exact retained rich envelope SHA-256: `1ec5d78ea1971ac472ad074b3c008790cba52afac3e1d8d1129c4800e2d4b169`. The two original CloudKit queue rows were byte-identical before/after the successful outer transaction's ledger operation; the serialized exact typed row-byte representation has SHA-256 `9e8e94a07d9541850ff0d3cf811760c9011d245ab74f2c59f2dbf32d19d1e610`. This compares original queue row bytes, not the whole database file, which necessarily changes when new component tables are written.

Named cases additionally cover inert construction, explicit schema/version/constraint rejection, unknown-version quarantine, exact opaque rich bytes and future fields, close/reopen retry, malformed JSON/UTF-8/base64/UUID/size, missing/duplicate UUIDs, same-second edits, tag/locator/NUL changes, stale source/revision, exact idempotency, every ACK scope field, old ACK/new revision separation, original delete-wins queue behavior, nested enqueue failure and outer rollback, tombstones, account-scoped inbox, corrupt payload/orphan outbox, pre-cancellation, cancellation after an actual SQLite trigger INSERT, and eight concurrent writers with one commit/seven explicit stale revisions.

These are named executable component cases, not XCTest/Native test counts. Initial failures, RED, GREEN, commands, receipts, and per-file hashes remain in `evidence/`; no failed observation is replaced. Native, physical device, Anytype, transport, signing, Apple CryptoKit, and original editor execution remain `NOT_RUN` unless separately qualified.

## Remaining integration gates

1. Run the newly registered component harness on Apple against the exact source, qualifying CryptoKit and Apple SQLite, and pass the actual three-target app build. Target membership is now registered; execution is still pending.
2. Add the original Save/delete hook only after binding a captured repository handle to an active store/account lifetime. Keep original row/tags/CloudKit enqueue and the ledger operation atomic, and preserve original Cancel behavior.
3. Define the original editor's rich document representation and ownership, non-lossy attachment references, revision/conflict semantics, and large-document policy. No Anytype editor extraction or live consumer is present.
4. Implement authenticated destination/account/Space transport and ordered per-annotation delivery. The ledger alone does not supply signing, authorization, encryption, remote ACK provenance, retry scheduling, conflict resolution, queue retention/quota, or incoming application.
5. Qualify original editor open/edit/save/reopen, cancellation/lifetime, visibility, RTL/accessibility, and Native behavior. Exercise the required 5,000-annotation and physical two-device/real-account synchronization acceptance before claiming CROSS-APP completion.

The capability stays OFF until those consumer and ownership gates pass. The original app, editor, source rows, CloudKit queue and SDKs retain their existing behavior.
