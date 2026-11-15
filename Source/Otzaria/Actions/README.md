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

The API checkpoint establishes compilable DTO/port signatures only. Engine,
semantic validation and adversarial acceptance are tracked separately in
`docs/hq-actions-core/`. Fixture PASS never implies app/device support. Production
ports must honor generation+RPC epoch, cooperative cancellation, bounded work,
rights and exact identity; errors are not verified-empty collections. A native
UI sink must revalidate immediately before synchronous commit and acknowledge
actual completion. A queue handle never means that a reader opened.
