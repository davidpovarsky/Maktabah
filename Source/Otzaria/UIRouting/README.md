# OtzariaUIRouting

Downstream Swift 6 contract package, depending on the sibling `Actions` package. Deployment metadata is iOS 26; there are no Apple framework calls or application target changes. This package does not supply a native UI, Hanlin SDK adapter, authorization engine, router executor, or persistence store.

`RouteSpec` carries versioned private restoration state; `PublicRouteSpec` is a separate, smaller navigation format. Constructing a public route does not authorize publishing it. Scene observations, commands, receipts, eligibility and `ActionExecutionContext` are trusted in-process values, not wire authority.

Use `UIRouteCodec` for all untrusted private/public ingress and public egress; ordinary synthesized Codable is not a validation or publication boundary. Private state is bounded to 32 KiB and public navigation to 4 KiB. Both use Core's existing strict parser and canonical reference/search schemas. Only explicit version-0 rename/removal rules migrate; unknown IDs/versions fail closed. Public encoding never automatically projects private state or grants shareability.

`UIDestinationRegistry` validates structure and backends and offers bounded discovery through the actual Core executor plus a trusted host assessment. Its default catalog is empty. `fixtures()` contains three synthetic descriptors that never appear in live discovery. No native screen is marked implemented in shipped resources. Host scene/tab/workspace/profile existence, text resolution, variant readiness, rights and commit-time authorization remain host/Core responsibilities.

The compiled API and golden-fixture checkpoint is documented in `docs/hq-ui-routing/API.md`; portable evidence and actual limits are in `RESULTS.md`. Actual host behavior and physical iPad acceptance remain outstanding downstream work.
