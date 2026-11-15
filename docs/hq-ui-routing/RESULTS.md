# UI02 portable contract and registry evidence

Owner: primary UUID `01a1dc89-87bb-7521-b249-ed383392e940`. Branch `codex/otzaria-ui-registry-20261115`; base `2918825be8c5cc8ecee53d57e1f48ca51779cab4`; compiled API commit `fd51ee3f26c35f48211d11b49a56198eb6916584`. Exclusive downstream Contracts/Registry/Codec/Ports/Resources/tests and private docs. Core ownership retained for its two-file additive parser seam only.

## Implementation

One versioned route/state contract reuses Core backend IDs, qualified refs, destinations, invocation/cancellation/deadline contracts and trusted context. No second JSON parser, resolver, authority, policy or action executor. The registry has bounded descriptors/migrations, full state/focus/presentation checks and no default live destinations. Three synthetic fixtures stay undiscoverable. Public/private wire formats and schemas are separate. Arbitrary unknown fields, selectors, paths as UI IDs, injected context/permissions, mixed backends, unbound focus/scroll, unsupported variants and unknown/removed versions fail closed.

Private ingress is at most 32 KiB; public at most 4 KiB. Core enforces its parser byte/depth/node/numeric-token limits, duplicate keys (including escaped aliases), exact numeric handling and schema keyword contract. UI schemas cap component arrays and private strings and reuse Core search/reference definitions. Public codec rejects state/scene/tab/workspace/profile/private text, backend snapshots and private reference revisions; rejects path/URL work keys. It does not infer content shareability or publish URLs.

Discovery uses the real Core executor authorization/readiness projection plus an injected trusted host variant assessment with scene/revision/backend binding. It filters mutations, risk>=3, inventory/fixtures and unsupported backend metadata. Cancellation/deadline are rechecked after async host work. Scene pre-commit checks bind request, prepared tab/backend, scene/revision, generation and embedded epoch; receipt validation requires the exact complete route and matching trusted visible-state observation, plus exact Core receipt for content. This is a contract implementation, not live UI navigation.

## Executed verification

Environment: Swift 6.3.3, Windows x86_64-unknown-windows-msvc, Swift language mode 6, `-j 1 -Xswiftc -strict-concurrency=complete`, sibling Actions dependency, no downloaded dependencies or Apple SDK invocation.

* Initial API compilation/goldens: 2 XCTest methods, 0 failures, `results/ui-api-tests.log`.
* Minimal Core object ingress: 1 focused XCTest method, 0 failures, `results/core-object-ingress.log`; command used `--filter WireSecurityTests/testBoundedGenericObjectIngressReusesExactParser`. Prior Core26 and independent D62 were not rerun or inherited as validation of this new seam.
* Final UI suite command: `swift test --package-path Source/Otzaria/UIRouting -j 1 -Xswiftc -strict-concurrency=complete`: **24 XCTest methods passed, 0 failures**, including the original 2 API tests (not an additional 2). Breakdown: 7 codec, 5 discovery, 2 API, 5 registry, 5 scene-port. Final count/result and exact source hashes are in `results/summary.json` and `results/ui-registry-tests.log`. This final run has no compiler warnings.

Coverage: private/public golden round trips, explicit rename/removal and unknown/future state; duplicate/escaped keys, fractional integers, UInt64.max revisions, malformed roots/oversize/unknown fields; no wire authority; private public-field/revision/path rejection and public encoding validation; three backends x seven presentations with exact Core content/focus preservation; mixed backends/cross-work focus, full restoration state/selection bounds, private search using Core schema and draft-only data; invalid/duplicate registry/migrations; six origins x three mock backends through the actual Core authorization projection; unavailable/unsupported sources, rights/navigation/device/scene gating; host denied/not-ready/not-supported and stale results; cancellation/deadline during controlled host waits; exact receipt fields and observed scene; pre-commit stale/cancelled/deadline/scene/epoch cases; a conforming synthetic MainActor port distinguishes queue-only from actual in-memory commit and refuses a stale second commit. Fake state is identified explicitly and cannot establish native UI acceptance.

One final-expansion attempt executed 24 tests with 1 failed assertion because the newly handwritten legacy fixture had a different UUID than the canonical golden. Preserved in `results/ui-registry-attempt1-failed.log`. Corrected only that fixture UUID; final rerun evidence is separate. This was fixture inconsistency, not a native UI defect.

## Limits and next owners

READY_FOR_INDEPENDENT_REVIEW for this portable tranche after the recorded final PASS; source task remains incomplete. G1 interface/security review, real surface inventory from U, UI03 orchestration, accepted SDK03/07 shared host contracts and actual thin host adapter remain outstanding. No Orchestration/Integration/native original Reader/UI/project/widget/lifecycle/Hanlin/tool/model/MCP/store edits or app registration. No live database/index/content operation, push/merge, costly CI/signing/distribution or app device run.

Read the R27 owner directive/execution contract at the natural checkpoint. T/Q retain the sole actual iPhone+iPad OS27 runtime wave and pre-TestFlight acceptance gate. This new unwired package cannot inherit build3918864d or any earlier runtime pass. Current Apple compiler/simulator/physical iPad acceptance for these contracts is NOT_RUN. Only a genuine exact P-owned regression delivered from that wave should trigger scoped owner corrections; no speculative app edits or duplicate suite.

Rollback: revert the isolated UI02 commits, retaining all earlier refs/user work. The Core parser seam can be reverted with its matching wire test when no remaining downstream codec depends on it. No persistent user state was written.

## 15 November corrected DISC01/02 tranche

Preserved paused WIP completed in the same worktree. Mandatory exact-scene `currentScene` observes the same current Core authority around all discovery awaits. Entire invocation is inside a cooperative structured deadline scope. See CONTRACT_DISCOVERY_20261115.md for frozen consumer signatures and limits.

EXECUTED_PASS: Swift6.3.3 Windows strict concurrency, focused `--filter Discovery`: **19 XCTest methods / 0 failures / 0 compiler warnings** (13 review regressions + 6 discovery methods). Deadline tests return before finite safety release and clean cooperative pending continuations, including initial/final currentScene and Core advertisement. Two separate scenes share backend/revision to prove exact ID binding and absent-scene refusal. Manual clock now performs cancellable deadline waits and success cleans its timer without advancing it.

Raw before log preserved: 6 methods, 1 pass/5 failed methods/7 failed assertions. Two build-only fixture adaptation failures are also preserved (0 tests executed); neither is a native result. Exact source and log hashes are in results/discovery-review-summary.json; final raw output is results/discovery-review-after.log. Earlier UI24/Core26/independent62 are not added or relabelled as fresh evidence. No actual native host, Apple compiler/runtime, physical iPad or SDK execution by P. Full source tasks remain open pending manager contract acceptance and real native/provider integration.

## Manager acceptance and combined-source verification

Manager primary `01a1df85-6013-7270-b48d-8e10222e95c6` accepted this exact shared portable contract at `b9adb9c46ef04b0aac84ece0045ca7e420bc30d0` after reviewing the diff, mandatory no-fallback exact-scene/SAME-Core authority, generation/epoch/revision checks, cooperative cleanup, 18 source/fixture/manifest hashes and 4 raw log hashes, and the 19 writer XCTest results. **DISC01/02 CLOSED_PORTABLE**. This supersedes the historical pending-independent-review hold, not native/device requirements.

Manager reports true-two-parent merges into combined G1 `9e589d6f` and native UI01/navigation base `a6c5b1d2`, with Actions/UIRouting package trees identical. The manager independently executed the same 19 focused Discovery XCTest methods under Swift6.3.3 strict concurrency on combined G1: exit0 / 0 failures. This is a new combined-source execution of the same coverage, not 38 distinct cases and not P execution. Raw manager log was read directly and its final19/0 result checked by P:

`C:/Users/DAVID/Code/Codex-Agent-HQ/docs/otzaria/single-manager-wave-20261115/G1_DISCOVERY_9e589d6f.log`

SHA256: `fe60c65ccbe25b8fd79c36c2accf305f3a355506c366400ca86bfadbda072860`.

After U inventory reconciliation, manager activated independent N primary `01a1df99-3d84-7d03-9927-af9bf35022b9` with this exact contract. Native observer implementation, scene orchestration and visible receipts belong to N. Actual Apple/native/physical acceptance remains open; source UI02 is not DONE. No public signature or source behavior changed in this acceptance record.
