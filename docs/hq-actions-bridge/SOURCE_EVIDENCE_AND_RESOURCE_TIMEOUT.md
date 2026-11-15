# Legacy source evidence and direct Embedded resource timeout correction

Owner/manager extended S to exactly `LibrarySearchPage` in downstream-owned
LibraryBackendModels.swift and to its existing SefariaRemoteStore population.
No Reader/PlainText/SQLite or shared Action wire DTO changed.

LibrarySearchPage now carries optional typed source evidence: backend, actual raw
hit count, complete mapping flag and verbatim optional total relation. Existing
initializers and old encoded pages retain nil evidence. The existing Legacy
provider records the actual DTO relation and refuses dropped identity rows.
Missing relation is never inferred eq; lower-bound/unknown nonempty pages retain
their raw-consumed next cursor rather than falsely reporting exhaustion.

The action projection accepts Legacy zero only with actual eq, zero raw hits,
complete mapping and a proven exhausted position. Dropped/malformed/foreign source
evidence cannot become zero. Nonzero aggregate action precision stays unknown;
occurrence counts remain unsupported. Canonical hit refs must belong to their
actual catalog work, without splitting, trimming or inventing aliases.

The production shared factory now verifies Legacy search readiness against the
existing provider's actual search endpoint with a synthetic one-row read-only
query (2s timeout, one attempt). It does not use user text, reset UI search
sessions or write a disk cache. A positive source observation expires after5s;
transient-state invalidation cancels/resets the observation. This is availability
observation, not a promise a later network operation cannot fail. Caller-supplied
trusted observations remain supported in isolated explicit compositions.

Embedded native timeout/cancellation can clear its native in-flight flag while
the original JS resource promise remains active. The direct Relationships
adapter now consumes a fresh nonce-bound JS resource-stability proof both before
and after its real related/catalog path. It reuses the canonical decoder and
does not require search readiness. If a JS resource promise outlives native
timeout, reads do not dispatch/return stable zero. If a resource promise starts
during related fetch without native epoch change, the final proof rejects it.

Executed Windows Swift6.3.3 strict-concurrency integration:100 assertions PASS
on actual coordinator/facade/RPC/runtime, actual Relationships adapter, actual
SefariaRemoteStore/DTO/HTTPClient and native Foundation URLSession boundary with
an explicit in-memory URLProtocol transport. No live endpoint, Hermes, UIKit or
device is represented by those doubles. The production provider's real mapping
method is used directly; no second provider is built. Initial expanded compilation
required adding its actual localization dependencies to the existing harness;
one test-local duplicate variable name was corrected before the final PASS.
The Foundation test URLProtocol Sendable availability warning is retained in the
raw log; it does not concern production HTTPClient/RemoteStore.

Also reran15 BackendSemantics XCTest methods,0 failures. Actual JS dispatcher
promise-counter/identity tests remain the preceding source proof; this packet
changes only Swift handling, not JS semantics. Native compilation, matching
Metro bundle and physical acceptance require the NEXT coherent candidate, not
the already frozen fe6f5fe5 run. Rollback is a targeted revert; no data migration.
