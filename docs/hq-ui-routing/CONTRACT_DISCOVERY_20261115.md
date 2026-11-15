# DISC01/02 corrected shared UI02 contract â€” 15 November 2026

Owner: P, primary Desktop chat `01a1df8a-23b0-77a0-bd90-c1dbfac06c2a`.
Worktree: `C:/Users/DAVID/Code/Maktabah-hq-actions-core-20261115`.
Branch: `codex/otzaria-ui-registry-20261115`; base `d39943b0c60347a9be63d071b212a5965e05430b`.

This packet supersedes the earlier discovery freshness/deadline description in API.md and the paused WIP status. Manager performs shared-contract acceptance for this wave. Native host integration and physical acceptance remain separate work.

## Frozen signatures for N

```swift
public protocol UIDestinationEligibilityPort: Sendable {
    func currentScene(sceneID: UIStableID, context: ActionExecutionContext,
                      invocation: ActionPortInvocation) async throws -> UISceneSnapshot
    func assess(_ descriptor: UIDestinationDescriptor, scene: UISceneSnapshot,
                context: ActionExecutionContext, invocation: ActionPortInvocation) async throws -> UIRouteEligibility
}
public protocol UISceneNavigationPort: Sendable {
    @MainActor func snapshot(target: SceneTarget, context: ActionExecutionContext) async throws -> UISceneSnapshot
    @MainActor func commit(_ command: UISceneCommand, context: ActionExecutionContext) async throws -> UISceneAcknowledgement
}
```

The mandatory `currentScene` has **no default implementation**. N must implement it against the exact authorized native scene selected by the trusted `sceneID`, using the SAME current backend authority injected into Core. It must independently observe current generation, Embedded RPC epoch and scene revision after relevant waits. An assessment that echoes a captured snapshot is deliberately insufficient. Missing/closed/unauthorized scenes must fail; never choose a global, first, foreground or similarly named alternative scene. Validate actual context/lifetime in the host; wire state grants no authority. Scene/lifetime revisions must prevent ABA and wrap reuse.

Discovery calls currentScene before Core advertisement, after it, after each eligible descriptor assessment and once immediately before returning. Every observation must match the originally supplied scene ID/revision and invocation backend/generation/epoch. Missing Embedded epoch is `unavailable`; differing current identity/revision/snapshot is `staleState`. All three supported backend variants use the same checks. No silent switch occurs.

The original monotonic invocation deadline covers the entire structured operation, including initial/final observations and Core advertisement. The scope consists of one operation child and one cancellable deadline child, with cancellation of both on exit. Host ports and clock MUST end waits promptly on cancellation and release continuations/resources. This is a **cooperative contract**: the structured group waits for its children, cannot interrupt an uncooperative port, and supplies no admission limit or Core worker bound. N owns finite native admission and observer lifecycle cleanup. No detached worker, second action executor or alternate permission policy is introduced.

RouteSpec, UIStateSpec, FocusSpec, PresentationSpec, SceneTarget, UIDestinationDescriptor, UISceneSnapshot, UISceneCommand, UISceneReceipt and UISceneAcknowledgement retain their compiled layouts. Version1 public/private codecs and the sole Core parser remain unchanged. Default registry remains empty; fixture/inventory metadata cannot be advertised as installed native capabilities. N registers only genuinely implemented surfaces after U's actual inventory reconciliation.

Before native commit N must resolve the actual target/tab/content/rights, validate current context and Core authorization, and call `UISceneCommand.validateCurrent` immediately before synchronous native mutation. After relevant layout/async completion, observe the real complete visible scene/route and validate `UISceneReceipt` against it. Receipt binding includes request, scene, backend generation/epoch, increasing scene revision, full prepared route/state/focus/panels/tab, and exact Core content receipt. Returning a requested route as an observation is invalid. Queued/foreground/backend-switch/unsupported/stale outcomes are explicit and never completed navigation. Core semantic ports remain canonical; no duplicate Resolver/parser/agent/permissions.

## Ownership and upstream review

Actual remote upstream HEAD queried read-only: `d46af139b3a265399c16d87f5923acd8e3444024`. No common merge-base with this downstream branch (`git merge-base` exit1); this is not an upstream-sync task. Git history attributes UIRouting to downstream commit `0c502e107f7d9f90611672f55fb0d65ff0ee61b2`, and `git ls-tree` at the actual upstream pin contains no UIRouting paths.

| Files | Classification/origin | Change | Validation |
| --- | --- | --- | --- |
| Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Ports/SceneNavigationPort.swift | DOWNSTREAM_OWNED / 0c502e10 | Mandatory independent exact-scene observer contract | Focused discovery compilation/tests |
| Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDestinationRegistry.swift | DOWNSTREAM_OWNED / 0c502e10 | Fresh observations and entire-call deadline composition | Mutable authority, two-scene and deadline regressions |
| Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Registry/UIDiscoveryCancellationScope.swift | DOWNSTREAM_OWNED / preserved WIP | Structured cooperative deadline scope | Initial/final/assessment/Core waits and cancellation |
| Source/Otzaria/UIRouting/Tests/OtzariaUIRoutingTests/Registry/{DiscoveryTests,DiscoveryReviewRegressionTests}.swift | DOWNSTREAM_OWNED / existing and preserved WIP | Conforming same-authority fixtures, cancellable manual clock, focused regressions | Exact portable log and hash manifest |
| docs/hq-ui-routing contract/results | DOWNSTREAM documentation | Evidence and consumer handoff | Exact source/log hashes |

No upstream-owned file, project/manifest/workflow/lock, Core source, Resolver, Bridge, Reader or user data changed. No new upstream exception is needed. Rollback is a manager-reviewed revert of this isolated packet; do not reset preserved worktrees. Merge risk is the intentionally required new protocol method: native consumers must implement it correctly, not add a fallback. Native UI, Apple compiler/runtime, Hanlin host graph and physical device acceptance are NOT_RUN by P.

## Executed evidence

Corrected focused Windows Swift6.3.3 strict-concurrency build and **19 XCTest methods / 0 failures / 0 warnings**, including 13 review regressions and 6 affected discovery methods. Logs and exact working-source hashes: `results/discovery-review-summary.json` and `results/discovery-review-after.log`. Before-fix reproduction and both fixture build-only failures are retained. Native/physical tests executed: zero. No healthy unrelated suites rerun.

## Manager acceptance and combined-source verification

Manager primary `01a1df85-6013-7270-b48d-8e10222e95c6` accepted this exact shared portable contract at `b9adb9c46ef04b0aac84ece0045ca7e420bc30d0` after reviewing the diff, mandatory no-fallback exact-scene/SAME-Core authority, generation/epoch/revision checks, cooperative cleanup, 18 source/fixture/manifest hashes and 4 raw log hashes, and the 19 writer XCTest results. **DISC01/02 CLOSED_PORTABLE**. This supersedes the historical pending-independent-review hold, not native/device requirements.

Manager reports true-two-parent merges into combined G1 `9e589d6f` and native UI01/navigation base `a6c5b1d2`, with Actions/UIRouting package trees identical. The manager independently executed the same 19 focused Discovery XCTest methods under Swift6.3.3 strict concurrency on combined G1: exit0 / 0 failures. This is a new combined-source execution of the same coverage, not 38 distinct cases and not P execution. Raw manager log was read directly and its final19/0 result checked by P:

`C:/Users/DAVID/Code/Codex-Agent-HQ/docs/otzaria/single-manager-wave-20261115/G1_DISCOVERY_9e589d6f.log`

SHA256: `fe60c65ccbe25b8fd79c36c2accf305f3a355506c366400ca86bfadbda072860`.

After U inventory reconciliation, manager activated independent N primary `01a1df99-3d84-7d03-9927-af9bf35022b9` with this exact contract. Native observer implementation, scene orchestration and visible receipts belong to N. Actual Apple/native/physical acceptance remains open; source UI02 is not DONE. No public signature or source behavior changed in this acceptance record.
