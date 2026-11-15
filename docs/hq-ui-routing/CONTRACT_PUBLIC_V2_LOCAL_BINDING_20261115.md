# Public v2: mandatory trusted local binding

Corrected shared packet after `90f8974a1ff19f5f4733e57bca94af26e3c58774`. N's `2b846845` reproduction correctly showed omitted actual workspace/profile IDs. Its passing negative proved `scene_receipt_mismatch`, not native success. This packet fixes mapping before immutable preparation. Frozen native checkout/run and current v1 handler remain independent.

## Current API

```swift
public protocol UIPublicNavigationBindingPort: UIPublicNavigationEligibilityPort, AnyObject {
    @MainActor func observePublicNavigationBinding(
        _ intent: PublicNavigationSpecV2, requestId: UUID, sceneID: UIStableID
    ) throws -> UIPublicNavigationLocalBinding
}

@MainActor public func bindPublicV2(
    _ intent: PublicNavigationSpecV2, scene: UISceneSnapshot,
    context: ActionExecutionContext, invocation: ActionPortInvocation,
    core: ActionExecutor, host: any UIPublicNavigationBindingPort,
    clock: any ActionClock = SystemActionClock()
) async throws -> UIPublicNavigationPlanV2
```

Caller `localTabID` is removed. Discovery eligibility alone cannot bind a plan. No default mapping exists. Non-Codable `UIPublicNavigationLocalBinding` requires every initializer argument:

- actual sceneID/sceneRevision/backendSnapshot;
- real selection/reservation owner's monotonic mappingRevision;
- workspace/profile/tab: `UIPublicNavigationObservedID.absent` or `.present(UIStableID)`;
- sidebarVisible/inspectorVisible: optional Bool fields projected by the exact independent native witness.

Explicit absence means genuinely observed absence for that target, never missing mapping. Nil presentation fields mean that exact surface witness does not project them; unavailable required observations must throw. Reader currentTab's actual inspector false remains false. Only inspector presentation derives the permitted target true, which completion must actually observe. Other presentation fields preserve their actual values, including false. No arbitrary UIStateSpec, selected item, private payload, context, permission, text/value or caller-supplied lifetime is accepted. The public DTO/schema/URL remain local-ID free and unchanged.

The synchronous observer reads the actual selected scene/model and pre-existing bounded nonvisible reservation for the request. It must not allocate visible/persisted state, substitute a first/global scene, echo desired state or fabricate caches. N prepares/releases reservations and preserves identity through the intended transition to the same committed tab. A background active tab is not automatically the target surface's projected tab.

## Original authority and mapping retained

Before its first await, the MainActor binder captures preparation from the same injected Core native authority/synchronous backend facet, then the local observation. New Core `prepareNavigationSynchronously(sceneID:invocation:context:)` uses these same sources/policy; existing async preparation delegates to it. New `validateFreshness()` is nonconsuming observation, never a grant or replacement for commit/completion. There is no second coordinator/authority, mirrored snapshot/context or permission policy.

Mapping and original canonical freshness are rechecked after initial currentScene, exact host assessment and final currentScene awaits, and after the structured deadline scope returns. Mapping values/revision reject selection drift and change-then-restore ABA. Context, active state, authority revision and lifetime come from canonical authority, not the mapping DTO. Missing mapping fails closed.

Actual IDs and required preserved presentation fields enter RouteSpec before the immutable command. An internal non-Codable guard remains inside UIValidatedRoute. Surface retains the original one-use Core preparation. Structural reader retains the original local/lifetime boundary through its independently issued actual Core invocation; canonical execution, Resolver, content grant and sink/receipt remain mandatory. Do not reconstruct/revalidate a new route and discard the retained guard.

Final synchronous MainActor authorizeCommit re-reads mapping/original authority, then consumes the actual command grant. Completion preserves strict complete-route/receipt/independent-observation equality, rereads mapping/original authority after layout waits, then validates the consumed grant. No dropped observed fields, wildcard receipt, requested-state echo, re-preparation or rollback claim is introduced.

N must invalidate the **existing admitted native authority** on selection/reservation invalidation, including ABA, so Core's final post-sink await sees the same revocation. Mapping revision is real owner evidence, not another permission counter. Intended presentation/reservation transitions preserve admission; do not re-admit a replacement context. N retains admission through full surface completion or full Core reader result, carries the original outer deadline/remaining budget, and releases unused reservations. This shared seam does not implement those native lifecycle obligations.

## Actual verification and limits

Final complete UIRouting run: **81 distinct XCTest / 0 failures / 0 compiler warnings**. This includes the previous 75, adapted to mandatory actual local observation, plus six new methods. Final focused Core Engine run: **18 distinct XCTest / 0 failures / 0 compiler warnings**. Intermediate 17/0 and 23/0 are not added. The first candidate failed to compile due to conflicting isolation annotations and executed zero tests; its log is retained. Corrected MainActor code compiled in both final runs.

The positive test uses independently constructed History/Settings projections from fixture workspace/profile IDs, matching N's repro shape, and exact complete receipts across all three synthetic backends. Reader uses actual Core/Resolver/sink/receipt across three backends and four synthetic registered presentations, actual fixture tab, preserved false inspector for current/newTab/sheet and independently observed true for inspector. No installed native support or actual reservation behavior is proved.

Negatives cover missing/stale mapping, genuine observed absence, workspace/profile drift and ABA, lifetime replacement, revoke/restore authority ABA, tab replacement, presentation drift and generation changes at all three host awaits and between binding/commit. Post-effect completion ABA is refused while effects remain one (no rollback claim). Deadline/cancellation cleans every gated cooperative await before finite safety release. Existing denied-work, stale generation, strict codec/v1/golden, discovery and final-Core-await tests remain in the full run.

Exact 52-input working SHA256/Git blobs, unchanged wire/golden checks, method names and raw log hashes: `results/public-v2-local-binding-summary.json`. Source delta: two existing Core files, three existing UIRouting source/test files and two new UIRouting source/test files. No upstream UI, S/I/R, manifests, current handler, project, CI/workflow, signing or gates changed. Apple/native runtime, real v2 URL import/publishing/shareability, actual reservation lifecycle and physical acceptance remain **NOT_RUN/open** by P. Manager/N review remains required before enablement.
