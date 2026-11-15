# OtzariaActionCore

Dependency-free portable Swift6 semantic action package. All three wire backends
are first-class: `otzaria`, `sefaria`, `sefariaEmbedded`. No application, database,
UIKit, AppIntent, MCP or persistence integration is installed by this package.

Untrusted bytes must enter through `ActionWireCodec.decodeRequest`, which rejects
duplicate decoded JSON keys and bounded-depth/size violations before constructing
one validated DTO. Never decode or authorize raw bytes through a second parser.
`ActionExecutionContext` is supplied separately by a trusted adapter and is not
Codable. Request construction in Swift does not grant permission.

The immutable planning catalog/schema/example resources retain their original
bytes and historical planning labels; metadata for29 actions does not advertise
29 executable tools. G1 implements only five actions through injected ports.
No count, note save, package mutation or backend switching is implemented.

Run focused checks from the repository root:

```
swift test --package-path Source/Otzaria/Actions -j 1 -Xswiftc -strict-concurrency=complete
```

`ActionExecutor` now executes the five initial actions through injected ports;
tests exercise these on all three mocked targets. Engine/contract/adversarial
evidence is recorded separately in `docs/hq-actions-core/`. Fixture PASS never implies app/device support. Production
ports must honor generation+RPC epoch, cooperative cancellation, bounded work,
rights and exact identity; errors are not verified-empty collections. A native
UI sink must revalidate immediately before synchronous commit and acknowledge
actual completion. A queue handle never means that a reader opened.

Numeric tokens are classified mathematically before Foundation conversion.
Integral decimal/exponent forms retain exact Int64/UInt64 values; approximate
floating values never satisfy integer argument schemas. The original parsed
argument tree survives DTO construction, so later validation cannot lose that
distinction through another encode/decode pass.

The registry retains all29 historical descriptors but only five IDs are
implemented. `system.listBackends(includeModes:true)` explicitly returns
`not_supported/mode_discovery_unavailable`: the report port has no proven variant
catalog. Exact search variants are assessed with the same normalized defaults
used for execution. No silent fallback, occurrence count or mutating tool exists.

Resource bounds:64KiB raw requests, depth16,10,000 JSON nodes,512-byte numeric
tokens; scope200 works, paging limits from frozen descriptors; at most25 returned
candidates and2,000 Unicode scalar snippet length. Output is checked against the
trusted byte budget and frozen result schema. There are at most8 outstanding
provider workers,256 ledger entries and4MiB retained result payloads. Uncooperative
providers receive cancellation and cannot admit unbounded replacement workers;
they still must eventually stop themselves. The in-memory ledger deliberately
fails closed when full rather than evicting UI replay protection. Production
lifecycle/expiry policy remains a later integration decision.

Repeated UUIDs are bound to subject, correlation and authority; changed arguments
or authority fail closed. Same-authority replay checks the backend/epoch before
returning a cached result. Candidate refs are schema-checked; provider debug
reasons are omitted. Only an exact destination-bound UI receipt can complete.
