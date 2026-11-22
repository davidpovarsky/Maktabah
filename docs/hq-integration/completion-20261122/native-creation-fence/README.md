# Native annotation creation fence — persistence component

Application source: **e78ddef1cd156bd2118e1ed23eb56376e65d0a7c**, parent **c838f470b1576b0c2ccc970f597d4f59f1bfc0ea**. The source commit adds 326 lines to the existing downstream-owned AnnotationExchangeLedger.swift. Its original 33,283-byte prefix is byte-identical.

The change supplies an explicit persistence boundary before a future original Anytype object creation. It records an intent against the existing exact pending outbox delivery, commits uncertainty before a caller could dispatch, and prevents a newer delivery from bypassing that earlier intent. It does not invoke a native object API.

## Product boundary

The existing original SQLiteDatabase, transaction/savepoint implementation, serialization lock, envelope codec, digest, source witness, revision head and pending outbox remain the authorities for their current responsibilities. No second database engine, body codec, recovery-size rule or native identifier generator is added.

The optional extension owns three tables: a strict version-1 discriminator, creation attempts, and identity observations. Explicit installNativeCreationSchema is required. Construction, base ledger installation, reads and application startup do not install these tables. Existing v1 tables and global PRAGMA user_version are unchanged. Partial/future/altered schema and native-table triggers are refused without repair.

| API | Boundary |
| --- | --- |
| prepareNativeCreation(for:) | Requires the exact current pending outbox commitment, active rich body, current revision and original source; records or rereads one prepared intent. This is not a body-format qualification or dispatch permit. |
| markNativeCreationMayHaveDispatched(_:) | Requires a prepared exact commitment. Holds original serialized access, refuses an enclosing transaction, performs the original top-level transaction and verifies autocommit after COMMIT. Only the first transition can return. |
| nativeCreationFence(destination:namespace:annotationUUID:) | Reads the earlier exact commitment even if a newer local revision exists. There is no reset on absence or empty native search. |
| recordedNativeIdentity(destination:namespace:annotationUUID:) | Reads a strict stored observation, with exact scope/message/fence binding. A stored ID is not a current native identity/body receipt. |

The full identity scope is destination/account/Space/namespace/annotation UUID. The identity table has forward scope uniqueness and reverse native-object uniqueness within destination/account/Space. There is **no production identity writer, reset API, RPC, body application or ACK integration**. The new methods have no application callers; SOURCE_CALLSITES.txt records the actual source search.

The future SDK adapter must alias creation attempt ID to the already durable message ID. It must supply a distinct opaque original identity-readback receipt and, separately, an applied-body receipt with actual current owner/account/Space/source checks. Pure policy values, caller booleans, metadata markers and digest presence cannot grant ledger write/ACK authority. Receipt consumption must revalidate the exact pending commitment synchronously at the original SQLite commit boundary; this component adds no generic validator port.

## Review findings fixed before publication

### SAVEPOINT release was not a durable dispatch boundary

The initial draft used the original composable transaction API directly. Root review identified that a nested SAVEPOINT can return while an outer transaction can still roll back. That source draft is retained in SOURCE_DRAFT_INITIAL_NESTED_GAP.patch; it was a static review finding, not a fabricated execution failure.

The final transition uses the existing withSerializedAccess and dbPointer. It checks sqlite3_get_autocommit before entering the original transaction, refuses nesting with nestedDispatchTransition, and holds serialization through the actual COMMIT and postcondition check. The tests exercised nested refusal/rollback, two original connections, cancellation at an actual SQLite UPDATE, and abrupt termination inside the outer transaction.

### A UUID case variant hid an earlier uncertain intent

After the initial 18 controls passed, an additional real Swift/SQLite negative reproduced a data-integrity gap on draft SHA256 9ad84c76b77b6819df4e0ae2fc45c72079d269b98b69cc0a7693bc2c0da88636. Fixture-only SQL changed an uncertain attempt's stored annotation UUID to lowercase. The original new reader used binary comparison, so preparing a newer pending revision created a second intent. The retained RED result has rowCount=2 and two distinct existing outbox message IDs.

The fix changes exactly three annotation-UUID predicates to COLLATE NOCASE and adds canonical UUID decoding/equality in both native readers. A matching lowercase/mixed-case row or multiple case variants now produces corruptRecord. It is never silently missed, adopted, rewritten or dispatched. Destination/account/Space/namespace/native object IDs and exact message/outbox binding stay case-sensitive. The owned DDL is unchanged.

UUID_CASE_FIX.patch and UUID_CASE_FIX.json record this delta. The same negative on fixed source returns corruptRecord with one retained uncertain row. Additional controls cover prepared case variants, colliding attempt rows, noncanonical/colliding identity rows, all public fence operations and preservation of other identifiers' casing.

## Executed validation and exact reuse

All new persistence controls compile the whole current original SQLiteDatabase, SyncPendingStore, TorahAnnotationEnvelope and AnnotationExchangeLedger, plus unchanged original AnnotationExchangeTestSupport and the current actual OtzariaActionCore dependency. Windows system SQLite and the original CNG digest run; no in-memory substitute is used.

Toolchain: Swift 6.3.3, Windows 11, SQLite 3.53.4. This packet is a Windows persistence-component result; it contains no Apple app build, SDK qualification, Native UI execution, native object RPC, network operation or production identity/ACK proof.

| Evidence | Exact result |
| --- | --- |
| attempt-01 | Initial fresh compilation reached its 300-second timeout before tests ran. Source bytes were unchanged. Owned-process observations are retained; no child compiler remained when continuation started. |
| attempt-02-resume | Same owned build cache continued; compilation finished in 86.6 seconds. All initial 18 new controls and all 3 crash/reopen pairs passed. |
| attempt-03-uuid-red | Exact old product draft, one additional UUID negative. Compilation passed; the invariant failed with two intents, proving the reported gap. |
| attempt-04-uuid-green | Only the reviewed ledger change refreshed the compiled source. All 6 new UUID controls and all 13 affected existing new-component controls passed. All 3 crash/reopen pairs passed on fixed source. |
| REUSE_AND_CONTROL_IDENTITY.json | The 5 unchanged schema controls are retained from attempt-02; their reachable schema code and all original 18 test bodies are byte-identical. |

The final coverage consists of **19 controls executed on fixed source, 5 exact schema-control reuses, and 3 fresh crash/reopen pairs**. The selected rerun is necessary because the affected scope readers changed. Core194, the original exchange28, earlier Cloud48/import9, classifier16/callback4, Native and Hanlin suites were not rerun for this component.

Each crash writer calls the original abrupt termination helper (TerminateProcess exit73). A fresh executable process reopens the actual database. The final process pairs are:

| Boundary | Writer PID | Reopen PID | Expected persisted state |
| --- | --- | --- | --- |
| Prepared intent | 11268 | 4208 | Prepared survives; the first top-level uncertain transition can still occur. |
| Committed uncertainty | 22752 | 31588 | Uncertainty survives; another dispatch transition is refused. |
| Nested outer transaction | 33828 | 27080 | Uncommitted prepared intent rolls back; nested transition was refused. |

Each reopen also checks the exact original outbox payload/message/mutation/digest, original annotation/tag rows and CloudKit queue, pending delivery and absence of invented identity/ACK. This is a process-crash proof, not a power-loss or native-engine recovery claim. Identity rows used for uniqueness/read negatives are explicit fixture-only SQL.

VALIDATION_SUMMARY.json binds the exact fixed ledger hash and all compiler inputs. Original and compiled source bytes stayed unchanged during every recorded execution. Full result JSON, stdout/stderr, source manifests, crash receipts and Sentinel job receipts are retained. Disposable SQLite fixtures and build outputs remain ignored.

## Integration and publication scope

This branch publishes the source-only commit separately from this evidence packet. APPLICATION_SOURCE.json binds the isolated application trees to e78ddef1. Scripts/CI, workflow files, project membership, dependency pins and canonical/in-flight Native/SDK inputs are unchanged. No workflow is dispatched from this neutral branch; the push-route inspection is retained.

The parent integrator owns the actual merged application source and must update its existing source bindings and perform the mandatory merged-source preflight once. No redundant ordinary-HQ run is attributed to this isolated branch, whose pre-existing CI pins still name its earlier application source. Ordinary HQ source/build admission remains separate from optional original-editor Stage B SDK admission.

Stage C/D is not complete. Original owner-checked object creation/readback/body application, opaque receipt consumption, production identity mapping and ACK still need their original SDK integration and actual acceptance. The qualification create/reopen SPI is not used as a production substitute.

## Existing task reconciliation

ASANA_SCOPE_REVIEW.json preserves the live 03:14 UTC project review: 49 top-level tasks, 31 open and 18 completed. No additional task was proved ready for closure; none was closed here. The existing CrossApp parent remains open.

The same packet retains a precise correction of stale Core status. Historical v3 run 44830431710 on da20cace0519d7a3e0aaca6e7cd14d51b5a3d210 succeeded; its source-specific Core194/full-app metadata had already been recorded by the API task. The read-only metadata verification and comment 1220765862152875 reconcile the Core task without rerunning the suite, downloading old artifacts or extending that result to current Native/live acceptance.
