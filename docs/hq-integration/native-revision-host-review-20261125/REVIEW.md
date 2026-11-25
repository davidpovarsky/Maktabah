# Host conditional native revision — independent source review

Reviewed: 2026-11-25 UTC. Reviewer: editor/sync lane. This is a read-only architectural review of the root integration owner’s implementation. It does not certify an application build, native runtime result, UI journey, remote acknowledgement, or completed C–F acceptance.

## Exact inputs

- Maktabah integration source: `ed1fab6f1a085eb71c69fae8ec5b34e25fafce9c`, branch `codex/otzaria-final-delivery-20261125`.
- Anytype SDK product/API: `a91d572cb2df2b05c7d93520732eecd7380294fd`.
- SDK typecheck evidence descendant: `42d8c3f4f2aaa68cc89fe045eca8ed4f3b0c1eda`.
- Exact reviewed file hashes and Git object identifiers: `INPUTS.json`.
- The SDK final changed-primary typecheck passed on the real Mac in `job_dc3d094e7a65`; the preceding 11-primary pass and full source-closure equality are retained in that SDK evidence. This review does not reinterpret these focused checks as a complete framework or host build.

## Result

No blocking mismatch was found in the Host/SDK API signatures, actual source ownership, separate SQLite revision preparation, or late native drain history. Two bounded receipt/validation improvements were recommended before the host source freeze and accepted by the integration owner; their implementation and tests require separate evidence.

### 1. The update operation preserves the fresh-import uncertainty fence

`AnnotationLocalEditorNativeRevisionPreparation` is a distinct closed owner type. It retains the original saved snapshot, account/Space comparison, native target, exact frozen SQLite image and source lifetime.

`ownsNativePreparation` and `bindNativeImportRetirement` inspect the original storage/observation identity and one-way parent lifetimes. They do not query or adopt the old fresh-import attempts table. Reusing these ownership helpers therefore does not defeat the earlier permanent possible-dispatch fence.

The new revision schema and transition do not delete, reset, reclassify or reuse the old import receipt. The revision token still comes only from a current original account session.

### 2. The actual native read owner survives replacement preparation

`AnnotationOriginalEditorSourceObservation.bindReplacement` requires the exact already-installed `readSource`, current local session, matching annotation UUID, prepared session UUID, saved revision, source digest, account and Space. It retains the read owner and attaches the new import-source lifetime to the same source/presentation retirement.

An annotation event retires the local observation, original native read owner and local session. The newly linked replacement owner is closed by the same lifetime. Scene/profile invalidation and original database retirement remain connected.

### 3. The actual saved SQLite source is checked after suspension

`prepareNativeRevision` uses `requireNativeSavedSnapshotLocked` inside the existing serialized database transaction and both original lifetime guards. It compares the full current source, revision and version, verifies the supported original rich body and absence of a pending deletion, then stores the exact immutable source image and target.

`markNativeRevisionMayHaveDispatched` repeats that same saved-source comparison after asynchronous file/native preparation. It requires the exact prepared row, matching request SHA-256 and bounded request bytes, and atomically changes a single prepared row to possible-dispatch. It then reads back the exact row. Replay, a different owner and an altered image cannot create a dispatch permit.

The session returns committed history as `recordedWithoutOwnership` when ownership is lost after commit. It does not convert the committed SQLite transition into a rollback claim.

### 4. A durable request witness precedes native dispatch

`AnnotationOriginalEditorRevisionAttempt.prepare` obtains the nonconstructible token from the actual original native read. It prepares the SDK’s one-use replacement operation without invoking it and preserves the exact request bytes/hash, native object, causal heads, root digest, source, original read response and retained comparison-file hash.

`invoke` verifies this witness, performs the SQLite possible-dispatch transition and checks currentness immediately before the actual one-use SDK invocation. There is no explicit Host suspension between that final currentness check and invoking this operation.

The SDK product at the pinned commit provides all consumed signatures: `requestBytes`, `requestSHA256`, token fields, replacement factory, history fields and the existing cancellation scheduling enum.

### 5. The late callback preserves actual observed effects

The SDK’s actual drained callback retains `AnnotationOriginalEditorRevisionHistory` independently of the presentation. It stores the native response and cancellation history even if the awaiting UI has already retired.

A verified result requires an SDK-created verified receipt bound to the exact source/object. A confirmed pre-write native conflict remains a conflict. Unknown, incomplete or `applied_unconfirmed` observations remain unverified. A returned await is not interpreted as remote delivery.

Local revision history always records `remoteDeviceAcknowledgement: false`. It cannot mint a current SDK token or authorize another dispatch.

### 6. The UI makes a separate explicit resolution choice

The normal annotation UI opens a receive/update presentation using the actual saved note. The existing unsaved-editor guard and local-only runtime stop guard remain prerequisites. The review preserves both complete versions before offering a choice.

Update does not silently refresh a stale token, create a replacement object or retry an uncertain result. It distinguishes verified local native readback, pre-write conflict and unverified outcome. Closing/removal retires the source and schedules actual cancellation/drain rather than asserting rollback.

## Recommended improvements accepted by the integration owner

1. **Match the public token bounds in the Host comparison value.** The reviewed `AnnotationLocalEditorNativeRevisionTarget` accepts up to 4,096 heads and does not bound each head’s byte length or strict ordering. The actual SDK token already guarantees at most 64 strictly sorted unique heads of at most 512 UTF-8 bytes. The current UI obtains this value only from the closed token, so this is a consistency/early-validation improvement, not a discovered alternate authorization route. Apply the same bounds in the Host.

2. **Bind historical result files back to their request witness.** The reviewed `mappings()` checks the result’s response hash and identity, but does not load its `request.json` and compare the exact source, request hash, object, expected heads/root and retained original read. Validate this relationship and the captured-profile path before following the stored read URL. These files remain historical selection data; successful parsing must never grant native authority.

The integration owner confirmed both changes would be applied before its next freeze. This report reviews the exact input above, not the later amended source.

## Focused acceptance still required

- Genuine SQLite controls for a prior uncertain import remaining byte-identical while a distinct conditional revision is prepared.
- Source/revision changes during suspension refusing the later transition before native dispatch.
- Replay, cross-owner preparation, altered request/image, corrupt or mismatched witness/result and schema shadow refusal.
- Durable possible-dispatch history across process restart, and late callback evidence after presentation retirement.
- Integrated iOS build against the final native SDK, ordinary UI confirmation/cancellation and private unsaved drafts.
- Native same-object rich update and strict post-write readback; the native lane was still diagnosing an actual `applied_unconfirmed` result at review time.
- Separate real peer observation, stale-token conflict after a remote change and cold account reopening. The unchanged previous two-process original-engine roundtrip remains historical evidence; the new CAS phase must establish its own results.

No completed C–F status is asserted here.
