# Saved-row native attempt bookkeeping — reviewed candidate

This candidate adds only two new extensions and their internal opaque data types to the existing local editor persistence and Session files. Every original byte of both files is preserved as an exact prefix. The actual product diff and its reverse were applied in an owned diagnostic directory; the reversed complete files equal the original Git blobs at 83e7e6db234117e43a5b025c0cf923aecedfaa4a.

## Persistence contract

The fixed namespace plus saved annotation UUID is the only active-slot key within the actual captured SQLite database. A possible dispatch blocks a different session, revision, account, Space, path spelling or numeric-row comparison from preparing a second attempt for that saved UUID. Account and Space strings are exact UTF8 comparison data, with the original SDK's nonempty/no-NUL policy; they do not construct an account, Space, selected-Space lease, caller or import permission.

Preparation freezes the original complete source witness, full current version, original payload bytes including unknown fields, original body bytes and body format/version, saved revision, captured database URL, annotation ID/UUID, session ID and exact comparison IDs. It requires a current editable saved row with the original no-destination local version and no pending delete. Historical capturedAgainstRevision bytes inside the body are untouched; this layer does not decode or confer authority on the SDK archive.

The active states are prepared and dispatch_may_have_occurred. A preparation object can be constructed only by a successful new preparation on its actual storage. It cannot be decoded from history or adopted by another session. A current new session can read the actual prepared record and explicitly abandon it through the same SQLite CAS, leaving its immutable history. Marking and abandonment serialize on the original connection. Once abandoned, the old object cannot mark the old or a subsequently prepared attempt. A possible-dispatch record cannot be abandoned or cleared by this API.

The actual original SQLite lock is acquired before the distinct editor and connection lifetime Mutexes. An already-open outer transaction is refused as insufficient proof of a durable marker. The same lifetimes and original outer transaction remain held through COMMIT. The body constructs each nonoptional result before COMMIT; no throwing currentness/cancellation check follows a successful COMMIT. Session delivery can be classified recordedWithoutOwnership, preserving the actual durable receipt instead of hiding it behind cancellation or inviting retry.

History discovery never installs schema. Creation is explicit during preparation. Reads and writes verify the complete exact main schema, implicit/explicit index identities, singleton version and absence of temporary owned-table shadows. Unknown or malformed active-state/UUID records remain blocking evidence. No source, annotation, tags, sync_pending, original version, outbox, native identity or CloudKit callback is changed by bookkeeping.

## Actual new controls

The new executable compiles exact original SQLiteDatabase, SyncPendingStore, ledger, envelope codec, local lifetime/models, CloudOwnership, complete candidate Persistence and Session methods, and the actual original OtzariaActionCore target. It links the real installed SQLite and OpenSSL libraries. Explicit Linux/application adapters provide the Annotation value shape/row mapping, original-store entry dependencies and the unconfigured CloudKit platform boundary. The synthetic opaque body is not represented as a valid native archive.

| New component case | Actual assertions |
| --- | ---: |
| Read-only discovery, whole saved image and preservation of original tables | 15 |
| Exact UTF8 identity comparison, invalid values and IDs beyond an invented 512-byte cap | 7 |
| Original outer-transaction requirement for all three writes | 5 |
| Complete source/version/revision/pending-delete CAS | 9 |
| Explicit prepared abandonment, no adoption and stale token rejection | 9 |
| One-way possible dispatch across session/revision/account/Space changes | 8 |
| Real original DB serialization of concurrent mark versus abandon | 3 |
| Actual SQLite COMMIT veto, precommit cancellation and receipt after successful COMMIT cancellation | 7 |
| Retired owner waiting for the original DB lock | 2 |
| Temporary shadow, future schema, unexpected trigger, noncanonical UUID and unknown state | 10 |
| Actual Session entry points without save/cache/event/CloudKit publication | 5 |
| Separate process exit immediately after marker COMMIT, then genuine process reopen and newer revision | 4 |
| Total | 84 |

The first 11 cases ran once and passed. The process durability case used two distinct actual PIDs: the first exited with intentional code 73 immediately after the real COMMIT, and the second reopened the same actual file and passed. These are 12 cases / 84 assertions, zero failures and no old suite replay.

Compilation preparation failures are retained exactly: an omitted empty original test-target directory caused SwiftPM fallback overlap; the declared adapter lacked original Annotation equality; the new control used a nonexistent enum property; and the first link command included both a combined module product and its intermediate objects. Each was corrected in owned control preparation only. No product source correction was required. The final actual Swift 6 complete-strict-concurrency compile completed with an empty compiler error log. Full duplicate-symbol output is losslessly retained as gzip with its original hash.

## Evidence and limits

SOURCE_ADMISSION.json binds the two original/afterimage files, actual full inverse, materialized original Git inputs, final compiler input closure and observed outcomes. CONTROL_ENVIRONMENT.json binds the installed compiler version, SQLite/OpenSSL headers/libraries, exact binary and C module maps. controls-evidence contains the original command/result/stdout/stderr receipts and separate-process results. The original in-memory source receipt is not a runtime acceptance record.

No SDK or native importer was invoked. No Apple application was built or run. No valid native archive was fabricated or asserted. The actual same-attempt SDK invocation, validated closed result, saved-row identity writer and any success/retry policy after a possible dispatch remain outside this candidate. Product promotion and native activation require the parent's source review and later exact-source integration.
