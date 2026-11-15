# OtzariaUIRouting

Downstream Swift 6 contract package, depending on the sibling `Actions` package. Deployment metadata is iOS 26; there are no Apple framework calls or application target changes. This package does not supply a native UI, Hanlin SDK adapter, authorization engine, router executor, or persistence store.

`RouteSpec` carries versioned private restoration state; `PublicRouteSpec` is a separate, smaller navigation format. Constructing a public route does not authorize publishing it. Scene observations, commands, receipts, eligibility and `ActionExecutionContext` are trusted in-process values, not wire authority.

The initial compiled API and golden-fixture checkpoint is documented in `docs/hq-ui-routing/API.md`. Fixture destinations are not claims about implemented native screens. Actual host behavior and physical iPad acceptance remain outstanding downstream work.
