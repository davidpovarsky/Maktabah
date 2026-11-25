# Final original SQLite acceptance ? 2026-11-25

Status: **EXECUTED_PASS** for the scoped Apple Foundation/original SQLite gates below.
All executions used exact committed source `57a4193d1d8a684b7ae4aff6642c1d256048d151`.
The shared product core is `ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f`.
This is not an application, original Anytype engine/editor, UI, CloudKit transport,
peer synchronization, or TestFlight acceptance result.

| Original gate | Actual result | SentinelX job | Raw RESULT SHA256 |
| --- | --- | --- | --- |
| Native-revision SQLite fencing | 36/36; 3 distinct cold/crash recovery pairs | job_144852cddd68 | be5a8662225f971ebf8b61fac56025e8234a9f68df06dcfcca6001b222fdec13 |
| Original atomic local-editor regression | 43/43; both original cold-reopen gates | job_693164f0d6cc | 4686298448b2cd2f9d193d5f343eba343c71f3692d209627a68f25412f2ccb78 |
| Complete long-note preservation | 23/23; separate writer and cold-reopen process | job_d5d72ef1d14f | ac9045a56e599be441937490cb7fd8a78fc71e3074fda9140fd169220f352f47 |

There were 102 actual component cases and six cold/crash recovery gates. None is
reported as a fresh native SDK or UI execution. Original36 and original43 test
assertions are unchanged; the original43 suite was rerun because ce0 changed
shared preparation/commit behavior. The prior 28/24, Library7, Multipart37,
Core4194 and other historical proofs are neither rewritten nor credited as
executions of this gate.

## What the actual tests prove

The revision gate exercises the original SQLite one-use conditional revision
record, durable exact request, stale source/target/profile/session rejection,
permanent fresh-import dispatch fence coexistence, ownership retirement,
pending deletion and strict schema/temp/trigger rejection. It observes real
SQLite rollback and abrupt exit73 before and after COMMIT, then independently
reopens the actual databases in different native processes. The original
annotation, tags, outbox, history and acknowledgement state remain protected.

The long-note gate exercises the actual shared persistence/session with explicit
first-conversion preservation. It validates complete UTF-8 bytes, exact prefix
preview, policy-bound intent/replay, original row/tag/delete concurrency,
owner retirement, rich-body refusal, ordinary-save semantics and real UPDATE
followed by an authorizer-denied version INSERT. The latter observes the UPDATE
before proving complete rollback; it is not a refusal before entering the write.
The unchanged original fixture implementation is extracted byte-for-byte.

The independent cold readback checks the actual stored 36,400-byte mixed
Hebrew/English/emoji note against its exact SHA256, the 8,192-byte preview, one
rich revision, actual payload/body/source bytes, stable CloudKit record identity,
tags, timestamp and original pending upload. SQLite integrity is `ok`; external
exchange outbox count is zero. The body fixture remains explicitly an opaque
component body, not an Anytype native archive.

## Exact source and artifacts

The 93-file source archive was validated before and after each scoped execution:
path, mode, Git blob, byte count and SHA256. It is an exact committed source closure,
not a manufactured Git checkout. The 83 product inputs retain their committed
baseline. Apple Swift6.4 and the selected real Scaleway Mac SDK/compiler were used;
the complete toolchain strings and commands are in the unmodified raw results.

`raw-evidence.tar.gz` contains all raw receipts, logs, generated package/source
closures, actual SQLite fixture databases including their WAL/SHM companions,
the three exact executed binaries, and the original source archive.
Only compiler caches/intermediates are excluded; those and all original evidence
directories remain on the Mac. The archive contains 469 inventoried source files,
34,928,685 uncompressed bytes, plus the inventory itself.

- Archive bytes: 6,218,470.
- Archive SHA256: `cef1d6de1aaece41544663ed98f8fd1f628291ec2f99ccf38a6a860a99e8b01d`.
- Raw inventory SHA256: `996f8d3bdc408319bd0b31a810a157b309e4a0ded30c47bf163f7c42783ef9f8`.
- Source archive SHA256: `e8c5b96c6e1275c690abe790b50f2094dfe8e05a94e96d67a84edf04ef558337`.
- Source manifest SHA256: `0ccb03f7eacafe06a711c21d2a2225574ec72fd41b4950a8e4e062a148bb6eb4`.

Mac source:
`/Users/m1/builds/otzaria-sqlite-final-57a4193d-source-20261125`.

Mac raw result directories:
`/Users/m1/builds/otzaria-sqlite-final-57a4193d-{revision36,original43,long23}-attempt01-20261125`.

Mac verified archive:
`/Users/m1/builds/otzaria-sqlite-final-57a4193d-proof-attempt02-20261125`.

Oracle independently verified durable copy:
`/tmp/otzaria-sqlite-final-proof-20261125`, transfer job `job_085ea2ee53b6`.
Every archived member was read back and checked on both hosts before publication.
The first archive attempt failed only because its executable discovery assumed the
older SwiftPM directory shape; no test reran. Its actual diagnostic is retained in
`packaging-attempt01.json`. The successful attempt used exact RESULT/binary-path
records and verified each executed binary SHA.

## Resource accounting and final reuse

The three gates ran sequentially. Each launch recorded actual free space and
remaining concurrent-growth/OS reservations. The original committed long-note
runner retained its conservative1GiB source/compile requirement; runtime reduced
its own remaining allowance to128MiB after compiled output was paid. No other
agent's process or artifact was changed.

For a later product commit, reuse requires matching the actual active compiled
source/fixture/dependency/toolchain closure against these exact results. Any
iOS-only additions require their own iOS verification; a source review of an
excluded region is not an iOS build or runtime pass. Keep the original SHA/run
identity of every receipt. Final application/SDK/UI/Live acceptance remains open.

Independent later-source review of `6f6e3c2a3ebfcc5b8c36247e113b65306d644b7d`
confirmed that its new SDK batch retirement links are wholly inside the existing
iOS/Anytype conditional regions. The actual macOS Models projection, including
its #else branch, remains byte-identical: 4,956 bytes, SHA256
`1d58b2e4638c409f7a5492e6dc3cfd16ae6e5b346559262569de8e6888fe509f`.
Persistence and Session whole files also remain identical. This narrowly excludes
that bridge from invalidating these component results; it grants no iOS/runtime
acceptance. See `INDEPENDENT_IOS_EXCLUSION_REVIEW.json`.
