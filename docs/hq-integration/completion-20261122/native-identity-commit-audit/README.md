# Native identity COMMIT audit — 22 November 2026

## Result and scope

No confirmed defect in the current pending-create/dispatch transaction boundary was found. No product file, schema, codec, authority API or test was changed or executed for this audit. The proposed NUL-truncation scenario was discarded after tracing the actual original column reader; it was never reproduced or used to justify a patch.

The reviewed Maktabah source is [0ea7218331d1441d37d06d43333e579f267056e3](https://github.com/davidpovarsky/Maktabah/commit/0ea7218331d1441d37d06d43333e579f267056e3). Its Ledger remains byte-identical to the previously reviewed native creation-fence source, SHA256 `26dc7075df6d73f9dc9c5d2cc46547d9496d71c96469fe8adf3a4e779d9b53cc`. Exact Git blobs and SHA256 values for the six cited files are retained in AUDIT_SOURCE_INDEX.json.

## Existing boundaries verified in source

| Requirement | Existing implementation and implication |
| --- | --- |
| Exact pending commitment | AnnotationExchangeLedger.requireMaterializablePendingDelivery rereads by messageID and requires exactly one row, full delivery equality and pending status. Equality includes mutation, destination/account/Space, namespace/UUID, revision, payload digest and original payload bytes. |
| Fresh-dispatch source | The same private helper decodes the existing envelope, requires active rich-body presence, compares the current exchange head and captures the full original source witness. Source metadata includes the digest of original annotation fields and tag rows. These checks occur inside the original transaction in both prepare and mark. |
| Durable first-dispatch fence | markNativeCreationMayHaveDispatched retains the original withSerializedAccess lock, refuses an existing outer transaction, runs the original transaction and checks autocommit afterward. A nested SAVEPOINT cannot authorize a native dispatch. Repeated uncertain transitions are refused. |
| Earlier uncertainty | nativeCreationFence reads the earlier stored commitment even after a newer head exists. A new revision cannot replace that attempt. The read is a local stored fact, not native proof. |
| Local deletion | AnnotationRepository.deleteAnnotationRow deletes annotation/tag rows and queues the original CloudKit delete in the same transaction. Normal deletion therefore cannot leave a transactionally visible old source row between those operations. |
| Existing owned Cloud completion | AnnotationLocalEditorPersistence validates exact source/version, pending row and write stamps under its original DB/lifetime locking. Its lifetime locks are a distinct implementation; they must not replace Anytype's original admission/drain semantics. |

Relevant sources:
- [Ledger](https://github.com/davidpovarsky/Maktabah/blob/0ea7218331d1441d37d06d43333e579f267056e3/Source/ChavrusaText/Annotations/Exchange/AnnotationExchangeLedger.swift)
- [Original SQLite wrapper](https://github.com/davidpovarsky/Maktabah/blob/0ea7218331d1441d37d06d43333e579f267056e3/Source/Core/Database/SQLiteDatabase.swift)
- [Existing local/Cloud persistence](https://github.com/davidpovarsky/Maktabah/blob/0ea7218331d1441d37d06d43333e579f267056e3/Source/ChavrusaText/Annotations/LocalEditor/AnnotationLocalEditorPersistence.swift)
- [Original annotation repository](https://github.com/davidpovarsky/Maktabah/blob/0ea7218331d1441d37d06d43333e579f267056e3/Source/Features/Annotations/Database/AnnotationRepository.swift)

## Discarded NUL hypothesis

The initial source-review hypothesis assumed that SQLiteRow.string truncated TEXT at an embedded NUL. Tracing its actual call showed that this Ledger uses SQLiteDatabase.swift's OpaquePointer.columnString, which reads sqlite3_column_bytes and constructs a String from the complete UTF-8 buffer. Embedded NUL bytes therefore remain visible to the existing identifier/digest/base64 validators.

The separate Source/Otzaria/Core/OtzariaSQLiteStatement.swift has a C-string reader, but it is not the implementation used by this Ledger. Conflating those two readers would have justified an unnecessary change. The hypothesis was explicitly withdrawn before any test or edit. This audit makes no new claim about that separate helper.

## Future identity recovery: creation R1 versus current R2

A concrete contract distinction remains for the future opaque receipt consumer. The fresh-dispatch helper intentionally requires the current head and live source to match the supplied delivery. After an uncertain creation for revision R1, a later local revision R2 or deletion correctly makes R1 ineligible for a new dispatch. At the same time, the recovery reader intentionally retains R1's original creation commitment.

A future identity-only writer must therefore choose an explicit policy:

1. Retain a conservative conflict while current local state differs; or
2. Bind the immutable creation commitment R1 and a separately captured current local guard (source, head and deletion state), then revalidate both together inside the same original top-level COMMIT.

The second option is a future design requirement, not an implemented writer. It does not relax the existing dispatch checks, replace the uncertain attempt, overwrite the body or acknowledge either revision. The SDK owner confirmed this distinction. Existing ledger reads can supply data for such a guard, but a value or caller boolean does not supply native authority.

The [published original SDK contract at b854e7f3](https://github.com/davidpovarsky/anytype-swift/blob/b854e7f3f59690134bcabdef88527b61517d5ab5/docs/pinkha/torah-integration/production-annotation-20261122/CONTRACT.md) still requires real account/Space permission, original native identity/schema readback, a retained exclusive-read barrier and original synchronous Owner admission. No public identity writer or opaque identity/applied-body receipt currently exists.

The durable COMMIT outcome must remain separate from the Owner publication outcome. A committed-then-retired result is a durable fact requiring later revalidation; it cannot be reset, replayed as create or published as current-owner success. Identity recovery alone never proves body application or grants ACK.

## Evidence reuse

The published held-read fixture evidence is [364a8fc6](https://github.com/davidpovarsky/Maktabah/tree/364a8fc6cca4501f7bbfec5f33056640c6686147/docs/hq-integration/completion-20261122/original-owner-exclusive-positive). Its one actual positive assertion, preserved negative result and distinct-process readbacks remain unchanged. The initial RED and the six earlier standalone controls remain frozen. This read-only audit did not rerun them and does not extend them to held-read retirement/COMMIT-failure combinations, Apple execution, native receipts, Stage B–F or Sync acceptance.
