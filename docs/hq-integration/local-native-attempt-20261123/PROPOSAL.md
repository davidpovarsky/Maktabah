# Saved-row original-native attempt persistence — source proposal

Status: PROPOSED, product files unchanged, no SDK/native execution.
Base: `83e7e6db234117e43a5b025c0cf923aecedfaa4a`.
Owned branch: `codex/otzaria-local-native-attempt-20261123`.
Owned worktree: `/mnt/development/projects/worktrees/Maktabah-local-native-attempt-20261123`.

## Decision

Add a private attempt history to the same captured original annotation SQLite database. The active key is the saved annotation UUID in its fixed `otzaria.local.annotation` namespace. **Session, row ID, revision, database URL, account and Space are not parts of the active uniqueness key.** A possibly dispatched attempt blocks another attempt even when any of those comparison values change. A new database connection uses its real captured handle; a historical row inside that database is never hidden because its original path/session changed.

The proposed early account/Space-partitioned key was corrected before any product edit, following root's exact saved-row constraint. Account and Space remain immutable byte-exact comparison data, not native authority and not a way around uncertainty.

No original SDK call, native-object identity writer, second database, outbox message, ACK or fabricated saved revision is added. The root-owned facade must separately retain the real original SDK caller/selected-Space/source captures and join this local transition to its same native attempt.

## Exact original boundaries

| Original file at the base | Existing boundary used |
|---|---|
| AnnotationLocalEditorModels.swift:15–46,64–75 | One-way editor/connection lifetimes; captured original DB, pending store and row mapper; snapshot contains actual row/UUID/DB URL/session, full source and version. |
| AnnotationLocalEditorPersistence.swift:31–40,128–179,182–224 | Actual captured-handle read; same session/row/DB/source/version validation; supported active rich body and exact no-destination local envelope. |
| AnnotationLocalEditorPersistence.swift:74–125 | Original saved-row transaction and after-COMMIT receipt delivery remain unchanged. |
| AnnotationLocalEditorPersistence.swift:272–374 | Existing original DB serialization plus outermost-transaction refusal and DB → editor → connection lifetime lock order. |
| AnnotationLocalEditorSession.swift:36–79,120–176 | Existing MainActor busy/cancellation/detached-worker conventions. New wrappers are additive; normal Save/CloudKit delivery is unchanged. |
| SQLiteDatabase.swift:122–169,296–318 | Actual NSRecursiveLock and nested SAVEPOINT behavior; successful outer transaction returns only after COMMIT; current binder supports integer/text/null, not Data. |
| AnnotationRepository.swift:79–169 | Actual connection capture and replacement/disconnect retirement, without later global repository lookup. |
| AnnotationExchangeLedger.swift:299–345,477–541 | Actual full source canonical bytes and immutable full saved-version read/validation. |
| AnnotationExchangeLedger.swift:817–903 | Existing native fence requires a pending outbox delivery; its outermost durable transition is relevant precedent, but it cannot be used for a local body whose destinationsJSON is exactly `[]`. |
| TorahAnnotationEnvelope.swift:110–119,149–198 | Original frame/body/envelope bounds and strict supported-envelope decode. |
| ActionWireCodec.swift:38–49 | Exact original 2,097,152-byte annotation-envelope budget; generic action ingress stays unchanged. |

Full Git blob and SHA256 bindings are in SOURCE_BINDINGS.json. LocalEditor persistence/session originated in fork commit `4be6c9b27fa6c882275cddf209f5959cb9b9690b`; the proposed edits stay in these downstream-owned files. SQLiteDatabase, Repository, Ledger, source observation, Mount, envelope/codec, project and Vendor are read-only.

## Frozen comparison image

Preparation accepts an expected snapshot and target account/Space comparison data. Under the original DB lock and both local lifetimes it reads the *actual current* snapshot, requires exact owner/source/full-version equality, and freezes that freshly read value. It does not trust a separately supplied body.

The durable row keeps:

- Generated local attempt UUID, original session UUID, actual annotation row ID/UUID, fixed namespace and captured DB URL as history.
- Exact target account/Space UTF8 strings; nonempty/no NUL, case- and normalization-sensitive. The original SDK has no independent 512-byte ID cap, so the earlier exchange identifier rule must not be imported.
- Complete original source canonical bytes and digest. The source's metadata is already present in the unchanged saved version's envelope and must equal the actual captured source metadata.
- All eight fields of the saved AnnotationExchangeVersion: mutation UUID, namespace, annotation UUID, **current saved revision**, source digest, payload digest, exact payload bytes and exact destinations JSON.
- Rich body format/version, byte count and digest derived from that exact unchanged payload. The body bytes are retained inside the original full payload rather than stored as a second editable document.
- State: `prepared`, `dispatch_may_have_occurred`, or `abandoned_before_dispatch`.

Neither persisted records nor historical observations reconstruct an AnnotationLocalEditorSnapshot, source witness, original caller, selected Space, native result, or authorization. Only a newly validated live session can create a new opaque preparation.

The native frame's historical `capturedAgainstRevision` is not parsed or rewritten by this persistence extension. The saved revision is the CAS authority; the opaque original body stays byte-identical. SDK framing/body validation remains a separate original SDK boundary.

## Same database and schema ownership

DDL_PROPOSAL.sql describes two small owned tables and one partial unique index. No foreign key references an outbox or the original versions table. Exact original version bytes are frozen in the attempt row, so the attempt does not interfere with the existing original ledger table-rebuild guard or require manufacturing a delivery.

Construction and read-only status discovery never install schema. Preparation may explicitly install the complete owned schema in its own transaction only after the actual saved rich body has been validated. A partial, modified, future or shadowed schema is refused; no repair/backfill occurs. Verify exact main.sqlite_master SQL, the expected implicit primary index and the one owned partial index; reject unexpected triggers, objects or temporary-name shadows. All SQL is qualified to `main`.

Source and payload byte ceilings come from the actual original contracts: source canonical bytes <=8,388,608; original envelope <=2,097,152; opaque body <=1,064,976. Since the existing binder has no Data case, store exact source/payload bytes as canonical base64 TEXT and validate encoded size before allocation/decoding. No SQLiteDatabase change is needed.

Status discovery returns bounded state/attempt/version/digest metadata and an opaque observation. It need not allocate historical IDs or payloads. Marking verifies the immutable row against the already retained exact preparation, with SQL byte-exact comparisons and the original known byte ceilings. An account/Space string is not silently truncated or normalized to fit a new limit.

## States and explicit abandonment

| Current stored fact | Allowed next operation | Result |
|---|---|---|
| No active attempt | prepare current actual saved row | Commit a fresh prepared row and retain a fresh session-bound opaque preparation. |
| prepared | mark with that original preparation and unchanged current saved source/version | Commit dispatch_may_have_occurred once. |
| prepared | explicit abandon with the exact previously observed attempt UUID/state and a current live local session | Commit abandoned_before_dispatch, retaining all immutable history. No preparation/caller is returned. |
| prepared owned by another/old session | prepare or adopt | Refuse. Read history; explicitly abandon if still prepared; then prepare a new actual row with a fresh attempt/caller. |
| dispatch_may_have_occurred | any prepare/mark/abandon across any session/revision/account/Space | Refuse; keep the original uncertainty. |
| abandoned_before_dispatch | old preparation mark | Refuse. A separately prepared new attempt can occupy the saved-row active key. |

Abandonment is safe only because every supported dispatch path must first win the same database's prepared→may-have-dispatched CAS. If the old marker wins, abandonment sees possible dispatch and refuses. If explicit abandonment wins, the old opaque token no longer matches a prepared row and cannot mark. No empty native search, elapsed time, Task cancellation, caller retirement, changed account or error changes this rule. No old original SDK caller is adopted.

The row UUID active key also prevents delete/recreate of the same saved UUID with a different numeric row ID from bypassing a possible dispatch. History remains in the existing database when the row or source changes. The extension does not claim global coordination between independent unrelated database files.

## Lock, transaction and receipt sequence

1. The MainActor session takes its existing busy gate and captures the same storage/owner before dispatching its one detached worker. Cancellation retires the same owner and cancels that worker.
2. The worker acquires the original connection's withSerializedAccess. Reject sqlite3_get_autocommit == 0 before any durable prepare/mark/abandon operation; a released SAVEPOINT is not a committed fact.
3. Check the captured actual DB path/owner before entering nonrecursive lifetime closures. Then hold DB → editor lifetime → captured connection lifetime through the original transaction and COMMIT. Require distinct lifetimes; never call requireCurrent/read/isOwned while those Mutexes are held.
4. In the transaction use pure owner-field checks plus snapshotLocked, requireEditable, exact whole source/version/body comparisons, pending-deletion refusal, strict schema checks and exact state CAS. Last cancellation check occurs before COMMIT.
5. Allocate the exact observation/transition result before COMMIT. Successful transaction return is the durable local fact. After it, do not throw ownership, Task cancellation, current-source or native checks that could hide the committed receipt.
6. The session may label delivery `recordedWithoutOwnership`; it still returns the actual committed record. No didCommit callback, CloudKit publication, annotation cache update or native call occurs for an attempt-state write.
7. Only the root-owned future facade, after receiving the *first actual committed marker*, may continue its already captured original SDK attempt. It revalidates the actual SDK/local source ownership. Retirement or SDK failure after the marker preserves uncertainty and cannot produce a fresh local dispatch permit.

The local marker is historical comparison evidence, never native authorization. A successful marker followed by refusal before SDK invoke is conservatively retained as possible dispatch; there is no automatic reset. An uncertain local SQL error is not interpreted as permission to invoke; the caller retains its error and inspects recorded history without retrying the original handle.

## Proposed product delta

1. AnnotationLocalEditorPersistence.swift: append one private extension containing owned DDL verification, exact row mapping/current-saved-row validation, read-only history, prepare, explicit abandon and one-way mark. Opaque preparation/transition types can live in this same file with fileprivate initializers, so no externally constructible dispatch token is needed.
2. AnnotationLocalEditorSession.swift: additive busy/cancellation/after-COMMIT wrappers for those methods. Existing methods remain byte-exact.
3. At most one new model file is reserved if it improves organization; it must contain comparison/error/history data only. The opaque preparation constructors stay controlled by persistence. No project change or SDK import is required.

INTERFACE_PROPOSAL.swift.txt names proposed interfaces, not existing APIs. CONTROLS_PLAN.md lists only new affected cases; nothing has been run and no old suites will be replayed for this proposal.

## Remaining integration boundary

Root owns the original registered SDK caller and whole-operation admission, actual selected Space and closed-import operation/Start/Cancel/Observe/Release joins. A real original result must exist before any native-object identity writer is proposed. The native source owner owns its endpoints. This packet neither changes nor qualifies those boundaries. Product edit, source controls and native activation remain pending review of this exact proposal.
