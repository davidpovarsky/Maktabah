# Same production authority for async and synchronous commit checks

Wave15.11.2026, S thread01a1df8a-df83-7f53-a190-7e582a40aaba.
Owner/manager explicitly extended S to the canonical resource invalidation seam
in `Source/LibraryBackend/BackendCoordinator.swift`. It is downstream-owned,
absent from pinned original upstream d46af139b3a265399c16d87f5923acd8e3444024;
last existing source commit e1e4064bc6ae7c320ae5b83bee5fb0e0c8a36265.

The actual RPC epoch now resides in ONE synchronized storage cell inside the
existing RPC source file. The RPC actor alone writes it. Actor reads and
`currentSessionEpoch` synchronously read the SAME cell under a short NSLock;
there is no MainActor mirror, echo or unsafe actor read, and no lock across await.
`ActionBackendCoordinatorFacade.currentBackendSnapshot()` reads the live
coordinator and actual epoch; production `snapshot()` delegates to that method.
An isolated async-only Embedded composition cannot produce synchronous proof
and throws unavailable. Other backends remain independent of that capability.
P owns the public synchronous protocol. The factory file now declares exact
conformance to P's frozen `ActionSynchronousBackendStatePort` from Core commit
065148d3662b5322bdd5dea038405079cd3a66c3. S does not edit/redeclare the protocol.
The app target must consume that Core commit for the conformance to compile;
the older portable package in S's branch does not contain the new protocol.

For Otzaria, the production factory samples the existing R-owned
`OtzariaMaktabahBridge.generationSnapshot()` without editing R source, actual
profile/path and S repository publication revision/current disk fingerprint.
The DB/profile/path are sampled again before accepting the witness. Every
facade snapshot reads a CURRENT witness. The coordinator retains the last witness
only to detect change and increments its canonical `generation`, cancelling
captured in-flight work. No second action counter, backend selection, tab restore,
defaults write, snapshot schema extension or use of Embedded rpcEpoch for Otzaria.

The Search companion increments its source revision on invalidate/close and
exclusive-indexing boundaries. Existing installer/indexer publication paths
already invalidate before/after. Additional manager-owned index entry points
now invalidate around active identity writes, promote/clear and trusted recovery
directory moves. The fingerprint compares actual DB metadata and bounded raw
meta/identity bytes; revision detects supported A->B->A changes between snapshots.
A separate tiny revision lock means synchronous guards do not wait behind the
repository lock held across a long native FFI query.

Limits: this is current-state observation and immediate drift rejection, not a
lock spanning Core policy/UI mutation across actors. P owns its precommit and
post-receipt lifetime checks and any stronger explicit commit barrier. External
out-of-process filesystem writes outside supported publication paths are sampled
via current metadata; an unobserved out-of-band ABA that restores every byte and
timestamp is not claimed detectable. Real Apple/native/device evidence is pending.

Additional scoped Legacy fix: downstream `SefariaDTOs.swift` no longer converts
missing/malformed/negative search totals into zero. The existing stabilization
runner gains a focused `--search-total-only` entry exercising the actual DTO.
No exact-count claim is introduced; aggregate action precision remains unknown.

Verification artifacts: wave-sync-authority-tests.log (67 predecessor assertions),
wave-resource-authority-tests.log (76 assertions PASS), and
Search wave-resource-readiness.log (14 assertions PASS). These compile real coordinator/facade/RPC/
runtime/adapter sources with explicit provider/transport/storage doubles.
No native/Hermes or physical PASS is inferred from them.
The focused existing Legacy stabilization runner passed 4 explicit valid totals
and 8 invalid/missing-total cases on the actual DTO. The final factory/P protocol
conformance is syntax-parsed only here; Apple compilation belongs to the
manager's coherent target with Core065 and the Search companion.

Rollback: targeted revert of this authority packet and Search companion. It
changes neither persistence format nor user data and does not trigger a release.
