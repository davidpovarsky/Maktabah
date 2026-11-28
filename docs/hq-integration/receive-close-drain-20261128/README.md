# Original annotation receive: joined consumer close

## Result and scope

The source finding reported to the Maktabah inbox on 28 November is repaired in
the existing downstream original-editor consumer. Close first fences new work,
then cancels and joins the retained startup and admitted operation. An actual
native revision invocation additionally joins its real drain callback and the
detached durable history/linked-reconciliation write before SDK close can release
the account owner. Late UI stages cannot reopen closing, failed-close or closed
state. Real committed/read/revision outcomes remain retained; cancellation is
never reported as rollback or remote acknowledgement.

There is one owner chain. No worker awaits closeTask. The SwiftUI begin caller
retains an explicit startup task; its cancellation cancels that task but cannot
drop the close barrier's retained handle. A prepared but never invoked revision
does not await a callback that cannot arrive. A failed durable history write
keeps the presentation/account and the actual error in closeFailed. Such an
unresolved write is not converted into success or an automatic native retry.
Original SDK Stop failures retain their existing explicit retry behavior.

## Source and ownership

Baseline is ccad81d5b5256027239c38ce0eaba028f6fb887a, Source tree
f47fd5b11b0ed4b9220f7a5142b2b54c8285c04b. The live upstream main was independently
read as 4203de5fd77beb119e5826e039be1a61325f7be0; merge base is
a0ed0df908a6cb38bc459d4baaeb400f447b2fc4. Both application files are original
fork additions with their full lineage recorded in SOURCE_PROVENANCE.json.
No upstream implementation, SDK source, UI layout, catalog, project membership,
signature registry, trust policy, source guard or acceptance assertion changed.

The real d6090c03b9ac4e5760941e34f4c04478db4ae59f SDK implementation was inspected
on the Mac, including its original one-use invoke and finishIfDrained bodies.
Every first invoke reaches the original drain even when source admission fails;
the consumer's existing one-use guard prevents a second invoke. The new boolean
is set immediately at that actual call, not at local preparation or dispatch
intent. SDK_DRAIN_CONTRACT.json retains full file hashes and exact method bodies.

## Verification actually executed

On the Scaleway Mac, Xcode 27 / Swift 6, exact extracted consumer lifecycle and
history methods were compiled with complete concurrency checking and warnings
as errors. The historical close method failed both focused barrier assertions.
The corrected methods passed all 20 assertions, covering startup cancellation,
local commit completion, delayed native callback and durable write, uninvoked
preparation, preserved unknown outcome, history failure, original Stop failure,
explicit retry, synchronous admission, reentrant close and late UI writes.

The controls use explicit SDK, UI and persistence boundary doubles. They prove
the exercised consumer ordering; they do not run Anytype, SQLite, the original
editor UI, multiwindow, cross-app sync, current full App or native acceptance.
Both complete changed production files also passed iOS 27 parser checks. Parsing
does not establish imports, module type checking or App/SDK linkage.

The first candidate link failed because its executable output path collided
with the candidate source directory. RESULT.json and its original stderr are
retained. The continuation changed only the executable output to bin/candidate;
every source byte stayed identical, and the original compile/RED was reused.
RESULT2.json records the successful continuation. No passing checks were rerun.

Apple root: /Users/m1/builds/otzaria-close-drain-20261128-r14au62f.
Actual owned allocation at completion: 34,430,976 bytes, under the 64 MiB budget.
The immutable raw archive contains all 24 source/result/log/binary members,
excluding only the reusable compiler module cache. Each member has a SHA-256 in
apple-controls.manifest.json. Archive: 144,372 bytes,
SHA-256 551477c80fe66bab0beb8a684616d3417e03760a7dc97014f29a400d1f0b3d0b.

## Reproduction and integration

Tests/HQ/annotation-exchange/receive-close-drain/generate.py extracts the exact
current methods and the exact historical close from ccad. It generates the same
control source as the executed artifact; it does not start a compiler itself.
Use --source-root and a fresh --artifacts-dir on an admitted Apple runner, then
the recorded strict swiftc invocation and the two executables. The original
close executable is expected to exit 1; the candidate is expected to exit 0.
Inspect the explicit case results, not just an aggregate exit status.

The source patch is limited to the two named downstream files. Revert those
precise hunks to restore the baseline; no data/schema migration or native retry
is involved. The worktree materializes only this scope and the required guidance
to avoid another 745 MB checkout. Its full Git index preserves the other files.

## Remaining product gates

Current d609 SDK/App qualification, real original-editor close/Stop/cancellation
and account-switch journeys, two-instance propagation, warm/cold reopening,
Native116 (historical 82 pass / 34 fail), Release114+2, production v40, final
authentic owner records, canonical merge target and TestFlight remain open.
This milestone closes the demonstrated source/control gap, not those gates.
