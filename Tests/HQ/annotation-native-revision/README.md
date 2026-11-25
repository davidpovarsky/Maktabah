# Conditional native revision: original SQLite component gate

Status: **NOT RUN**. This checkpoint authors a new focused gate against root product commit
`ce0f62baba7360514e7fa8cad21f0caaf2d0ab8f`. It does not claim an accepted SDK, UI, live
synchronization, or final application build.

## Source boundary

The driver imports the original 25-file local annotation editor driver source list,
compiles its complete production Swift files and original local Actions package,
and extracts only the byte-identical reusable fixture prefix before
`@MainActor\nfinal class LocalCases`. It does not execute or edit the original 43 tests. Those 43 tests must now run separately because the shared prepare/commit gained explicit long-note preservation.
The existing explicit catalog, unrelated UI and CloudKit callback boundaries remain
unchanged. The opaque rich-body/request fixtures are not native Anytype archives.

`product-inputs.json` records the full reviewed original source closure as Git blob,
mode, size and SHA-256 from the exact root checkpoint. The new driver rejects a
different product closure and verifies all committed source before and after the run.
An exact committed source archive may be used on the real Mac via the existing
`tools/exact-source-archive.py` source-identity interface; an archive is never reported
as a Git checkout.

## New gates

The separate 36-case inventory covers the complete saved image, permanent original
fresh-import fence coexistence, one-use revision CAS including a real two-task race,
exact request bytes, stale source/revision, session/profile/lifetime ownership,
pending deletion, strict schema/temp/trigger/index rejection, bounded request/target
validation, actor routes and retirement. Each valid preparation/dispatch comparison
captures every original schema object and typed cell, tags, version history, queues,
ACK state and original CloudKit callback observation.

Two failure cases use the actual owned SQLite update and commit hooks. They require
the real revision INSERT or UPDATE and the COMMIT callback to have occurred before
the induced rollback. They do not substitute a foreign trigger for a production
write failure. Retirement during the actual INSERT is requested on another thread,
because the original owner lease correctly spans COMMIT.

Three additional independent process pairs exercise prepared cold reopen, abrupt
exit 73 from the actual SQLite COMMIT hook after UPDATE, and abrupt exit 73 after
the actual COMMIT returns. They use real WAL/FULL databases. Reopen uses the original
Store/session; independent Python SQLite then verifies integrity and every original
typed row/schema, all frozen image hashes, exact request durability and the permanent
fresh-import fence. All six writer/reopen PIDs must be distinct.

## Execution and resource contract

Run only on the existing real Apple arm64 host. No compiler download or alternative
runtime is allowed. Use a fresh evidence directory for every attempt and an explicit
current incremental resource plan, coordinated with the storage owner:

```sh
python3 tools/hq-annotation-native-revision-acceptance.py \
  --artifacts-dir /Users/m1/builds/OWNED-EXACT-ATTEMPT \
  --anticipated-concurrent-growth-gib CURRENT_APPROVED_GROWTH \
  --os-margin-gib CURRENT_APPROVED_OS_MARGIN
```

The driver initially reserves at most 1 GiB for its own source/build outputs and uses
one Swift compiler job. After the binary exists, its recorded remaining fixture
budget is 128 MiB. Already written inputs are not reserved twice. Live checks may
stop only this driver's own process group; they never stop or clean another owner's
work. Raw failures, process/crash markers, source inventories and final RESULT.json
are preserved. Apple native/API/UI gates remain separate and pending.
