# Native creation persistence boundary

The existing AnnotationExchangeLedger has one additive same-file extension. The original file prefix is byte-identical; original tables, envelope/codec, source witness, outbox/inbox, UUIDs, pending CloudKit queue and global user_version are unchanged.

An explicit installNativeCreationSchema call adds three owned extension tables and a separate strict discriminator version1. Construction, base install, reads and app startup never install it. Partial/future/altered DDL or native-table triggers are refused without repair.

prepareNativeCreation requires the exact existing pending outbox bytes and identity, current revision and current original source metadata, plus active rich-body presence. It records or rereads one prepared intent per destination/account/Space/namespace/annotationUUID. The format is not qualified by this persistence operation.

markNativeCreationMayHaveDispatched holds existing withSerializedAccess, refuses an outer transaction using actual sqlite3_get_autocommit, then performs the original top-level transaction and verifies autocommit afterward. Only the first prepared→uncertain transition may return. No RPC is invoked. Nested SAVEPOINT release cannot be presented as a durable dispatch fence. The initial unsafe draft is retained as a review finding.

nativeCreationFence reads an older commitment even after a newer revision exists. A newer message cannot replace an uncertain older create, and zero native search candidates cannot reset it. No reset API exists.

recordedNativeIdentity is a strict read of a stored fact with forward and reverse uniqueness. There is no production identity writer. A pure assessment DTO, boolean, stored ID or metadata digest is never an opaque original SDK identity/body receipt, native authority or ACK. These future bindings remain unavailable until the real facade supplies owner-checked original readback receipts.

New controls use the full original SQLiteDatabase/SyncPendingStore/envelope/ledger and original AnnotationExchangeTestSupport without edits; current actual ActionCore compiles as their dependency. The existing cache inspected belongs to seven changed Core sources and is not reused as the current binary. No Core194/original28 suite is scheduled. The initial 18 component controls passed. After the reproduced UUID-case defect was fixed, 13 affected controls and 6 new UUID controls passed on fixed source, with all 3 abrupt termination/reopen boundaries repeated because they read the modified scope; 5 unchanged schema controls were reused with exact source/body evidence. Identity values in a storage constraint/read test are explicitly fixture-only SQL, not native engine results.

The compact Asana review and one historical Core194 metadata reconciliation are retained in this same packet. No additional task is declared complete.

UUID scope queries find case variants, then require canonical stored UUID text and the exact requested identity. Noncanonical or multiple matching rows fail closed without rewriting. Destination/account/Space/namespace/native object identifiers remain case-sensitive. The RED record preserved two intents on the old draft; fixed source refuses the same setup with one retained uncertain row.
