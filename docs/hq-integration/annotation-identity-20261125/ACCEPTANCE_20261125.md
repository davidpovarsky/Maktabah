# Legacy annotation identity: actual Mac component acceptance

## Outcome and scope

The explicit stable identity adapter is implemented and the relevant component
gates pass on the owner's real Scaleway Mac. The original annotation row,
ckRecordId, tags, original CloudKit queue keys and existing UUIDs remain
authoritative. A separately owned alias table is written only by an explicit
migration transaction. Lookup, normal editor inspection and cancellation never
register an alias or backfill a source row.

The product checkpoint is 2651cbf51c3c75bfe8da4073796d047c54f906a3.
Later b0a89ffa103cb31e4414576236aa748a0187674e contains acceptance fixtures
and the compatible fault observer. Root integrates PBX membership and the
explicit Backfill UI/planner independently. This report supplies no Native116,
Release114+2, app UI, native Anytype, live CloudKit, TestFlight, or physical iPad
acceptance.

## Actual executions

| Gate | Canonical source | SentinelX job | Actual result |
| --- | --- | --- | --- |
| Original whole Store/local editor | fbd5e241d8924ffd1e20078cd40c4fd950f76a70 | job_b4bb0942f7c1 | 43/43; 0 failures; original two cold-reopen gates passed |
| Legacy identity adapter | fbd5e241d8924ffd1e20078cd40c4fd950f76a70 | job_c547761302a7 | 24/24; 0 failures; separate writer/reopen processes and independent SQLite readback passed |
| Original exchange/SQLite | b0a89ffa103cb31e4414576236aa748a0187674e | job_ba5459c53ee0 | 28/28; 0 failures; actual process termination before/after COMMIT and cold verification passed |

All three compiled with real Apple Swift 6.4 and Apple SQLite 3.54.0 on macOS
27.0 arm64. The whole original Store/Repository/local/cloud ownership closure
compiles in the 43/24 executables. Only the existing explicit
UI/catalog/localization/configuration boundaries apply. The 28 executable uses
the original complete SQLite/SyncPendingStore/ledger closure; its original
AnnotationRepository runtime is not claimed.

The original 43 Swift assertions and cold validators are unchanged. Its cold
PIDs were 77264, 77265 and 77268; the same original UUID/row survived, two
immutable body revisions were present, and there were zero exchange
destinations. The legacy fixture retained CloudKit name
legacy_28_2_4_1700000001 with alias FF0F372F-2139-8112-BA14-7CBF849AABF9
across processes 77183 and 77185. Readback verified the same original row/record,
both exact opaque Hebrew component bodies, the original upload queue key and
zero external destinations. Independent Python SHA-256/UUID derivation also
matched that alias using the specified original-record domain separation.

The actual 28 fault receipts prove the authorizer denied the outbox INSERT
after real pending-queue/version/head inserts. The cancellation hook observed
actual version/head/outbox row IDs and cancelled that writer task once. All
original transaction rollback and queue-preservation assertions passed.
Production verifiedSchemaVersion remains unchanged; no foreign trigger
exception was added. Both crash controls terminated with exit 73 in original
WAL/synchronous=2 mode and passed verification in new processes.

## Exact source and reuse

Compiler inputs came from canonical committed Git objects on Oracle through
explicit exact-source archives. The status is
EXACT_COMMITTED_SOURCE_ARCHIVE_NOT_GIT_CHECKOUT; no Git history, HEAD, or
checkout was fabricated. The manifest verifies every input's relative path,
regular-file/mode, length, SHA-256 and Git blob SHA before and after.

| Archive source | Files | Manifest SHA-256 |
| --- | --- | --- |
| fbd5 | 92 | c3ec08fff4811d6414c77aefc5ad74e90f9014d46cc309839d95b1037d917540 |
| b0a8 | 92 | 84b9ca90087dc8d9bf9f83a22a2f9ce70d750b13c556f6eb999e46fe19469e95 |

The only fbd5-to-b0a8 change is
Tests/HQ/annotation-exchange/AnnotationExchangeTestSupport.swift: its owned
observer uses NSLock, keeping the original macOS 14 target. Every 43/24 compiled
and provenance file is byte-identical, so their actual passes remain valid for
that unchanged scope. Later product changes require explicit impact review.

## Evidence preservation

Original unedited results, cases, cold receipts, source manifests, hook
observations and compressed original logs are under evidence/.
Executable paths and hashes are in evidence/EXECUTABLES.original.json.

| Receipt | SHA-256 |
| --- | --- |
| local43 RESULT | 322a1c96884f24072ad8b4e2d9fa3bf427a7756b49761e4cb75a4ac313b32c93 |
| legacy24 RESULT | a2ec5f68741a784802885ed1eae0762ad0d245f7d2ac7981d6ed4d5cda8f0f9d |
| exchange28 RESULT | 8c0962aceb192be5d179f7f1d2ba2b9e460922aa4b8e056cd0d91698ad2d6f6c |
| Completed source/fixture/evidence archive | ae5029facb3f5359653112da5024443713548c1c5b6be920a37208598956ba1c |
| Historical failure archive | e35b386b895d7361b4259145b124eb7f994172b9c6ad1bd1728606ac39526635 |

The completed archive is 3,799,648 bytes with 385 independently verified original
files. The historical archive is 275,159 bytes with 176 verified originals.
Both are retained on the Mac under /Users/m1/builds/ and on Oracle in this
worktree's build/, with filenames
annotation-identity-completed-components-20261125.tar.gz and
annotation-identity-historical-failures-20261125.tar.gz.
The latter retains stale-closure, 26/28 trigger-injection and 41/43 constructor
failures without overwriting their original receipts. The subsequent macOS 14
fixture compile failure is retained in the completed archive.

The Library's prior 7/7 and multipart 37/37 evidence and the new Library update
policy 15/15 receipt were not modified or rerun. Full app Library v32/v40,
Groups100, native editor UI/sync, final build and distribution gates remain
root integration responsibilities.
