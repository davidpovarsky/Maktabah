# Otzaria Hanlin host adapter — compatible source, native integration blocked

## Implemented and verified

The thin actor conforms to the actual HanlinHostIntegration API at immutable
Hanlin commit bff3364d64f43b1d5235ead2b6e8f3756e890eed. It retains the existing
Otzaria ActionExecutor and calls its canonical registry, policy, wire decoder,
resolver and search ports. Four available read-only operations can be projected:
system.listBackends, catalog.resolveWork, catalog.resolveReference, search.query.
The other declared actions are not published as implemented tools.

The host supplies trusted current namespace/scene/generation/source revision,
backend snapshot, available actions and the original ActionExecutionContext.
Raw source arguments pass through ActionWireCodec, preserving exact UInt64
values and rejecting duplicate keys. Context/catalog/provider identity,
read-only guarantees, deadlines, output limits and bounded admissions are
enforced. Explicit cancellation covers authority lookup and active Core work.
Navigation delegates to the canonical host owner and validates its exact
Hanlin navigation result; queued is never reported as presented.

14 XCTest methods PASS, 0 failures, 0 compiler warnings, Windows Swift 6.3.3,
Swift 6 mode, complete concurrency checking. Real frozen SDK contracts, actual
ActionCore and this adapter compile together. Explicit actor doubles replace
backend data, current host authority and native receipts. These are contract
checks, not AgentCore/model execution, native navigation or installed AI.

The cancellation race was reproduced first: cancelling during authority lookup
incorrectly reached a Core port (two assertions failed). The same test passes
after bounded pending admission and cancellation tracking. A prior optional-wire
field bug was fixed by omitting an absent idempotencyKey, preserving the strict
canonical schema. Earlier Windows path-limit and timeout evidence remains in
the canonical phase evidence directory.

Reproduce with tools/hq-hanlin-host-contracts.py --hanlin-repo <existing Hanlin checkout>
--hanlin-sha bff3364d64f43b1d5235ead2b6e8f3756e890eed --artifacts-dir <new evidence dir>.
The harness copies immutable original contracts only into its disposable test
package and records all input hashes; it does not vendor an SDK into this app.

## Exact remaining upstream and app requirements

The frozen canonical Hanlin repository has a nested HanlinAgentSDK package with
a sibling-path HanlinPlatform dependency, but no root consumer package exposing
an accepted original ChatUI/Composer entry. SDK-03/07 and parent remain open in
Asana at the 2026-11-17 readback. No uncommitted PresentationSDK source was
consumed, and no SDK source, account or permission was changed.

Consequently this source is not registered in the application target. Production
installation requires a pinned consumable original SDK/UI dependency plus an
app-owned authority producer using the SAME ActionLiveBackendBridge, scene owner,
workspace identity, rights and navigation orchestration. The producer must derive
availability from live canonical discovery, revoke contexts on real ownership
changes, and retain native admission through an exact independently visible
receipt. It must not issue permissions from model data or create another store.

Broader reader/section/Inspector/focus routes remain gated by their own native
implementation and acceptance. Three actual multistep SDK/UI journeys,
Siri/Shortcuts, device acceptance and release are NOT_RUN. No second agent,
chat interface, model picker, credential store, MCP transport, permission engine
or conversation store was built.

The repository log is a line-ending-normalized transcript. result.json records
both its hash and the untouched raw canonical log hash/path.
