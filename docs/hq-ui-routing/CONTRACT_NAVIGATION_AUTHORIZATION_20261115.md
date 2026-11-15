# Canonical native navigation preparation — 15 November 2026

P owner: primary `01a1df8a-23b0-77a0-bd90-c1dbfac06c2a`, private worktree `C:/Users/DAVID/Code/Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-ui-registry-20261115`, source base `ec6191f4ed3f918d4734d1445eed2c992a7c844a`.

Manager requested two exact shared seams: genuinely UI-only descriptors must not invent semantic actions; native commit must have a synchronous canonical authorization guard. DISC01/02's mandatory currentScene and cooperative deadline scope remain in force.

## Shared Core API

```swift
public protocol ActionSynchronousBackendStatePort: ActionBackendStatePort, AnyObject {
    @MainActor func currentBackendSnapshot() throws -> ActionBackendSnapshot
}
public protocol ActionNavigationAuthority: AnyObject, Sendable {
    @MainActor func navigationState(sceneID: String) throws -> ActionNavigationState
}
```

`ActionNavigationState` is trusted, Sendable and non-Codable. Its initializer is `init(context: ActionExecutionContext, sceneID: String, lifetimeID: UUID, authorityRevision: UInt64, active: Bool)`. There is deliberately **no backend snapshot in N's native-context state**. Backend generation and actual Embedded RPC epoch can only come from the synchronous facet of the exact `state` object already injected into Core.

Production S source is `ActionLiveBackendBridge.shared`, the MainActor `ActionBackendCoordinatorFacade` backed by `BackendCoordinator.shared` and actual `SefariaJSRPCBridge` epoch. S owns adopting `ActionSynchronousBackendStatePort`, reusing the SAME live calculation as `snapshot()` with no second coordinator, delayed cache or captured-argument echo. The real RPC epoch is actor-owned in the historical source: a MainActor read is valid only after S provides actual synchronized authoritative storage also used by RPC. Until that proof exists, Embedded throws unavailable; Otzaria/Legacy with genuine synchronous authority can proceed independently. Canonical same-backend resource/profile/DB/index replacement advances the existing coordinator generation through S; no new snapshot field or secondary action-generation counter is introduced. P does not edit/copy S files. Tests use a synthetic authority, not this production facade.

N supplies the separate actual scene/context/lifetime owner via the additive Core initializer argument `navigationAuthority: (any ActionNavigationAuthority)? = nil`. All existing initializer labels remain valid. Native-context authority is injected once at trusted composition, never supplied/selected by a decoded route or per-call token argument.

`ActionExecutor.prepareNavigation(sceneID:invocation:context:) async throws -> ActionNavigationPreparation` prepares **UI-only** navigation. It takes the synchronous backend facet only from Core's retained `state`; callers cannot select another backend source. Missing facet or native authority returns unavailable, with no asynchronous/cached substitute. Preparation cannot be initialized or decoded by consumers. `ActionExecutionContext` adds synthesized Equatable while remaining non-Codable; its exact full trusted context (including subject, correlation, origin, rights, scopes, work bounds, scene, pairing and budgets) must match current native authority.

`ActionExecutor.checkNavigationDiscovery(sceneID:invocation:context:) async throws` checks metadata permission AND actual live guard availability, discarding its internal preparation without returning/retaining a grant or authorizing an effect. Missing native/synchronous authority or unavailable synchronous epoch proof cannot advertise an empty-semantic destination as ready. Permission reuses the existing canonical ActionPolicy primitive: discovery plus navigation scope for discovery, navigation scope for execution, existing backend/origin/device validation, and exact authorized foreground scene. No fake `system.listBackends` semantic requirement is added. `advertisedActions` is never a native commit grant.

`ActionNavigationPreparation.authorizeCommit(invocation:sceneID:destination:)` is a **synchronous MainActor, one-use** guard. It reads both retained authorities again, verifies active native lifetime, identical lifetime/revocation revision and full context, exact Core snapshot/generation/epoch, scene, invocation/request/deadline and optional exact reader destination, then applies the canonical navigation/work policy. Cancellation and monotonic deadline are checked on both sides of the synchronous observation. Successful authorization consumes this preparation; do not retry/reuse it or insert an await before mutation.

## UI02 API for N

`UISceneCommand.prepareNavigation(using:context:) async throws -> UIAuthorizedSceneCommand` only accepts implemented, genuinely UI-only descriptors with no content/private semantic state and empty requiredCoreActions. The wrapper binds the complete immutable scene command and has no public initializer or replaceable authorization/route.

`UIAuthorizedSceneCommand.authorizeCommit(current: UISceneSnapshot)` runs synchronously on MainActor. It checks trusted current scene/revision/backend against the bound full command and consumes the Core preparation using the retained live authorities. After it succeeds, apply **exactly `prepared.command.route`** immediately, synchronously. Then observe actual completion and keep the existing exact full route/state/Core receipt validation. Queueing is not completion.

The existing `UISceneCommand.validateCurrent(_:now:)` remains a structural stale/deadline check for compatibility; it cannot grant permission. Native consumers use the authorized wrapper in addition to actual host capability/content/UI existence checks.

Implemented descriptors may have `requiredCoreActions=[]` only for navigation-only risk2, nonmutating surfaces with no required content or private semantic state. Registry validation rejects content under a descriptor without reader.open. Empty semantic declarations do not authorize arbitrary content, searches, saved notes, backend switches, commands/selectors or persistent mutations. N's trusted host must also validate actual workspace/profile/item/focus/component access and capability before applying UI state.

## Content path remains canonical

Core's existing reader.open still validates through the same Resolver, work scope, backend authority, UI sink and exact Core receipt. When native context authority is configured, it attaches a Core-minted content-bound preparation to the additive `ActionOpenReaderCommand.navigationAuthorization` property. UI-only public prepare cannot mint a reader grant.

Inside the existing sink, N builds the actual bound UISceneCommand and calls `prepareNavigation(readerCommand:) -> UIAuthorizedSceneCommand` using the exact Core-delivered command. Its invocation, scene and destination must match. Content commit currently supports exactly the required semantic action `["reader.open"]`; extra/unimplemented semantics fail closed. Supplying a UI-only preparation in a fabricated reader command cannot authorize content because the Core preparation's destination binding differs. Descriptors/fixtures and bare decoded routes are not native grants.

Legacy non-native Core sinks with no configured native authority remain source compatible; their commands carry nil navigationAuthorization. Such a command **cannot** pass the UI02 native prepared-reader path. Configuring native authority while lacking the synchronous backend facet fails closed. This does not claim all older/native call sites automatically adopted the guard.

## Authority and execution limits

No general Swift protocol can prove a host implementation reads truthful live data. Exact retained source-object identity is enforced by Core composition; the synchronous facet's semantic same-source guarantee must be implemented by S against the real coordinator/RPC epoch and verified natively. If that proof is unavailable, return unavailable; never mirror a stale async snapshot or infer an epoch. P's synthetic tests do not certify S's production implementation.

N owns actual context issuance/revocation, exact scene mapping, lifecycle cleanup and finite admission. Keep one current trusted context per admitted scene request/correlation; reissue/refresh after relevant awaits, then prepare/check against that exact record. Advance authorityRevision on every permission/revocation event, including revoke/restore ABA; replace lifetimeID on lifetime replacement. No reset/wrap/reuse of revision/lifetime as a way to revive a grant. Disposal must invalidate active records even while old prepared objects remain retained.

This is an immediate-precommit and post-observation contract, NOT a barrier spanning cross-actor RPC state and UI mutation. A real epoch/resource change may occur after the synchronous read. N must observe the actual canonical snapshot again for the receipt, and Core reader.open retains its post-sink canonical recheck. If it changed, return stale/noncompleted with truthful effect uncertainty; never assert rollback/no effect merely because receipt validation failed. No await-held lock, unsafe actor access or cross-actor atomic commit guarantee is introduced.

The guard authorizes a synchronous native mutation only; it is not a new semantic executor, resolver, durable replay store or effect reconciler. Existing Core semantic ledger/budgets remain unchanged. N's native admission/queue/request association must prevent unbounded pending preparations and duplicate dispatch; expired/cancelled/uncertain native effects must not be reclassified as completed or automatically retried. MainActor scheduling/readiness waits remain cancellation cooperative. The final guard has no await, but it cannot prevent a trusted caller from ignoring it or mutating a different route; correct native host wiring and runtime receipt tests remain required.

## Ownership / validation record

All touched application files are downstream-owned `Source/Otzaria/Actions/{Policy,Ports,Engine}` and `Source/Otzaria/UIRouting/{Registry,Ports}`, plus their downstream tests/docs. Original upstream pin remains `d46af139b3a265399c16d87f5923acd8e3444024`; none of these package paths is upstream-owned. No original UI, project/manifest/workflow/lock, S Bridge/Integration/BackendSemantics, I Resolver or R Reader file is changed. Recovery is a scoped manager-reviewed revert of this additive packet, preserving other worktrees.

Execution results and exact working/Git hashes will be recorded in `results/navigation-summary.json`. Native Apple/compiler/physical UI/provider acceptance is separate from the portable synthetic authority/sink tests.

## Verified portable source packet

Final strict Swift6.3.3 Windows executions: **44 UI02 XCTest methods / 0 failures / 0 warnings**, including **15 new navigation authorization methods**, plus a separate **18 existing Core EngineTests / 0 failures / 0 warnings** verifying the shared policy refactor and reader/replay/admission behavior. The final UI filter includes Discovery (all19), Registry (5) and ScenePort (5) alongside the15 new methods. These counts overlap earlier executions and are not added to them.

The first in-progress compilation was invalidated by a source edit during build and executed zero tests; its log is retained. Earlier49/0 full-UI and12/0 intermediate runs are preserved but not relabelled as final-source acceptance. Final exact working SHA256 and Git blob IDs plus all raw-log hashes: `results/navigation-summary.json`. Final logs: `results/navigation-final.log`, `results/navigation-core-engine.log`. No native/S-production/physical execution by P.

Coverage includes isolated changes to subject/scope/origin/allowed backend/work bounds/rights/scene, revoked active state, authority-revision ABA, replacement lifetime, request/scene/content binding and one-use consumption, deadlines/cancellation, discovery-vs-execution, missing actual guard/facet/native context, separated canonical backend/native authority, same-backend canonical resource generation, before/after Embedded epoch drift and unavailable Embedded proof without blocking the other two backends. Content still exercises the actual Core resolver/sink/receipt path on all3 synthetic backends; forged/missing/UI-only preparations cannot authorize content.

## Additive post-observation authority validation

Follow-through from source `065148d3662b5322bdd5dea038405079cd3a66c3`: a structural UISceneReceipt check cannot prove current permission after an awaited UI observation. Reusing the one-use commit guard for that check is intentionally forbidden. The canonical additive read-only APIs are:

```swift
@MainActor ActionNavigationPreparation.validateCompletion() throws
@MainActor UIAuthorizedSceneCommand.validateCompletion(
    receipt: UISceneReceipt, observed: UISceneSnapshot) throws
```

For N: after the authorized synchronous mutation and any cancellable native layout/visibility wait, obtain the actual observed scene/result and call `prepared.validateCompletion(receipt:observed:)` before publishing acknowledged/completed. It checks the exact complete route, request, scene/revisions/backend and content receipt, then re-reads the same retained S backend authority and N context/lifetime through Core's existing canonical policy. Deadline, caller cancellation, changed subject/correlation/scopes/origin/rights/work scope/scene, inactive/replaced/revoked lifetime or canonical generation/RPC epoch refuse completion even if the captured UI receipt remains structurally valid.

This creates no new grant and never resets the consumed commit guard. It cannot authorize/repeat mutation or replace admission/callback deduplication. A pre-commit/discovery-only preparation cannot validate completion. Bare `receipt.validate(for:observed:)` remains a structural compatibility API, not a complete current-authority acceptance check.

Core reader.open additionally performs this current-authority check automatically on an acknowledged native sink command whenever native authorization is configured. This also refuses a superficially matching ACK from a sink that never consumed its required commit guard. Queue-only results remain queued without requiring an already-applied effect. Unconfigured legacy/non-native sinks retain their existing behavior; they still cannot use UI02's guarded native path.

A failed/cancelled/expired completion can follow an actual UI effect. Preserve that fact/uncertainty in the native host outcome; missing effects in a Core failure is not proof of no effect. Never infer rollback, retry automatically or mark completed. This is still immediate precommit plus fresh post-observation checking, without an atomic barrier across actors. No new S/N/R/I source, UI target, workflow, schema, resolver, replay store or backend snapshot field is introduced.

Portable verification of the completion addition: strict Swift6.3.3 Windows **19 NavigationAuthorizationTests / 0 failures / 0 warnings** (15 existing +4 new methods), plus **2 focused legacy Core EngineTests / 0 failures / 0 warnings**. New cases prove an exact captured receipt alone remains structurally valid after revocation, while canonical completion refuses it; cover post-effect lifetime/subject/scopes/rights/work/scene/resource generation/RPC epoch changes, deadline/cancellation, consumed-guard requirement, full UI receipt binding, no regrant, actual-reader ACK refusal when the native guard was skipped or revoked after an effect, and unchanged queue/legacy behavior. Reader positive paths exercise the existing resolver/sink/receipt chain on all3 synthetic backends.

Exact source/Git/log hashes: `results/navigation-completion-summary.json`; final logs `navigation-completion-tests.log`, `navigation-completion-legacy.log`. Older44/18 and other runs are not added or inherited as final-source coverage. No Apple/native/physical/S-production case was executed.

Final ordering correction: retain the acknowledged reader preparation through the common last backend/readiness await, then run canonical validateCompletion immediately before returning. No further readiness await follows it. Native context must remain admitted through the full Core result, not just sink ACK. Red/green reproduction and limits: [COMPLETION_FINAL_AWAIT_20261115.md](COMPLETION_FINAL_AWAIT_20261115.md).
