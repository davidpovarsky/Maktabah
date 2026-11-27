# RN inner navigation — exact source and authority proposal

Status: **review proposal; no product edits, Apple compilation, native run, or new Metro artifact**.

Read base: `aee6fdd1cd635323f6a773f6559a9d0bf717f6b4`. Root reports its later `43a8c10` is docs-only. The retained Sefaria gitlink remains `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`; all 34 distinct original files underlying the 45 inventory rows were retrieved at that immutable pin and matched the existing original SHA-256 proof. The existing admitted Vendor tree remains `9e4f188c5bedeef55ce95d97943f5e5046b6f3d6` and will not be silently retargeted.

## Four original semantic destinations

| Fixed destination | Original method, with original side effects retained | Exact original state and independent visible witness |
| --- | --- | --- |
| `native.sefariaEmbedded.library` | `ReaderApp.openNav()` | `menuOpen == navigation`, empty `navigationCategories`, loaded original reader; actual visible original `TextsPage` header `nav.browse_the_library` |
| `native.sefariaEmbedded.topics` | `ReaderApp.openTopicToc(true)` | `menuOpen == topic toc`, `navigationTopic == null`; actual visible original root `TopicCategoryHeader` `topics.explore_by_topic`. Original LoadingView is insufficient. |
| `native.sefariaEmbedded.learningSchedules` | `ReaderApp.openMenu("learning schedules")` | exact menu plus the original page header AND original `learning_schedules.description`. Header text alone is insufficient because it also occurs in the Library preview. |
| `native.sefariaEmbedded.dedication` | `ReaderApp.openMenu("dedication")` | exact menu plus actual visible original `Dedication` title `about.app_for_ios_and_android` |

These methods are called once through a closed switch on the actual pinned `ReaderApp` instance. No direct `setState`, footer restoration shortcut, method replacement, arbitrary selector, raw URL, query, content reference, account action, download/install, or JS expression is accepted. `openNav()` deliberately retains its original query/filter clearing and original navigation history behavior. Learning schedules and topics retain original data loading; a visible page does not prove all its network data is ready. Navigation is refused while the actual original display-options or interrupting-message modal is open, or while an authentication/private editing flow is the original active owner. No modal is automatically dismissed.

The original inventory marks dedication as unsuitable for a direct public action but suitable for semantic guide/Hanlin focus. The implementation can provide its finite native destination while retaining that exposure matrix: **no public AppIntent/Deep Link advertisement for dedication without an explicit reviewed reclassification**. The other three are meaningful static foreground navigation targets. No fifth public root is added merely because a source row exists.

## Same Core admission, bounded native-to-JS effect

The old `surface.awaitVisible` stays read-only and grants no mutation permission. Cancelling an ordinary asynchronous RPC only drops its response; that is insufficient for a queued mutating request.

1. Retain the exact existing parent, original source, runtime, backend/mapping, scene, and window before the first await. Capture root selection/settings/mode/book publication histories in the original one-shot observation read set. Preserve all current identity/generation comparisons and source lifecycle guards.
2. The existing Core canonical apply creates one private, unarmed handoff ticket for the exact fixed target, request, retained source, original deadline, surface/mount/scene/epoch and pending token. It is not a new Core grant. The same apply opens the existing original RN parent as today.
3. Only after the actual first original host joins and the same retained native admission/source validates may that same ticket be armed. No renewed deadline, refreshed source observation, replacement window, new Core grant, or fallback surface is allowed. A replay or second RPC cannot create another ticket.
4. The fixed private RPC reaches the actual visible `ReaderApp`. In that same JS turn, after checking the actual original instance, readiness, selected target prerequisites, modal state and registry identity, it calls one small **blocking synchronous native Boolean claim** and immediately invokes the one original semantic method if the claim succeeds. No promise, frame, timer, await, arbitrary callback or other JS work occurs between the claim and original method call.
5. The synchronous native claim does no I/O, UIKit work, MainActor hop, JS callback, policy resolution or user code. It atomically checks the original monotonic deadline, exact ticket identity/membership, retained runtime and the exact one-way source/lifetime fences; it consumes the ticket once. Lock order is runtime → retained parent observation → retained feature/backend observation → ticket. All claim closures are internal, fixed, bounded and non-reentrant. Native cancellation uses a nonisolated one-way revoke before any queued MainActor cleanup.
6. **Linearization is the native claim.** Cancellation/source change/deadline before claim means zero original navigation calls. After claim the original method and React render may already be committed: cancellation is reported honestly as cancellation/partial effect, never as a successful route or a guaranteed rollback. The app does not navigate backward automatically. If the original method throws, the ticket stays consumed and the real failure is retained.
7. A claimed ticket is not success. Within the original remaining deadline, actual original frame callbacks must observe the exact same ReaderApp/mount and selected original state; no synthetic target echo substitutes for this. Native completion additionally requires a unique visible original UIKit text/AX descendant in the exact owning React surface, real clipped geometry, same foreground window, no modal/transition, and (for schedules) the distinguishing original description. The existing source-locked native report remains the sole canonical ACK. Actual original labels are taken from the pinned English/Hebrew sources, not invented rendered markers.

This is a bounded cross-runtime navigation effect and a point-in-time selected-state/visible-view proof. It does **not** claim atomic ongoing JS state after the receipt, all inner targets, data completeness, VoiceOver traversal, or native acceptance before the actual build/run. Native header resolution must fail closed if the actual RN renderer does not expose a unique original descendant; that is a runtime acceptance issue, not permission to substitute an echo marker.

## Exact proposed owned source paths

New native source:

- `Source/SefariaEmbedded/UI/SefariaEmbeddedSemanticNavigation.swift` — finite target, private one-use ticket, immutable proof, bounded thread-safe ticket registry.

Narrow existing native owners:

- `Source/SefariaEmbedded/Bridge/SefariaJSRPCBridge.swift` — add the short non-MainActor runtime-locked claim boundary; preserve existing MainActor commit/report and every original RPC/runtime field.
- `Source/SefariaEmbedded/UI/SefariaEmbeddedNativeSurfaceHost.swift` — read-only original descendant witness and exact host/lifetime invalidation.
- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfaceBinding.swift` — same retained source and pending request; optional fixed target, handoff/cancellation, structured target wait and exact proof.
- `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfacePresentation.swift` — original sheet/witness correlated to its actual fixed target; old root behavior unchanged.

Downstream Vendor hooks (nothing under `Upstream`):

- New `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSemanticTargets.js` — closed target switch and exact original-state predicates; no copied UI or method monkey patches.
- `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurface.js` — pass the actual original class instance through its existing private registration.
- `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurfaceRegistry.js` — separate finite handoff/observation API; preserve the existing root-only API and lifecycle semantics.
- `Vendor/SefariaMobile/Integration/JS/chavrusaRPCFacade.js` — one fixed private semantic handoff dispatch; no change to engine/resource/query actions.
- `Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.swift` — tiny synchronous Boolean claim on the existing module.
- `Vendor/SefariaMobile/Integration/iOS/ChavrusaSefariaBridgeModule.m` — exact `RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD` export, supported by the pinned React Native public header. No generic executor.

`ChavrusaRoot.js`, Metro argv/config, package/Pod locks, imported engines, original gitlinks, resource inputs, existing root contract and old qualification receipts stay outside this product delta. The reviewed Vendor contract will require an explicit new exact-source transition for every changed/new downstream path and fresh original Metro before any app qualification.

## Shared files — proposals only, root applies

- `NativeComponentSourceObservation.swift` — a narrowly typed internal-use source-locked claim operation over the **same** irreversible invalidation latch; no reset/rearm/renewal. Existing `validate()` and all old controls unchanged.
- `MaktabahNativeComponentBinding.swift` — expose the same backend-coupled latch to that bounded claim, preserving coordinator/generation comparisons and the retained original Combine subscription.
- `MaktabahNativeSceneSession.swift` — retain the exact target and original deadline, root publication read set, same parent fence, release/unmount/Notes invalidation, and report correlation. No shared edit by this lane.
- `MaktabahNativePublicBindingAdapter.swift`, `MaktabahNativeRoutingComposition.swift`, `MaktabahNativeSceneProjection.swift` — fixed route registration/availability/public exposure and actual target projection; same original request and Core authority. No generic fallback.
- Root owns PBX membership and any catalog additions. No UI/Core authorization, owner signature, PR verifier, runtime qualifier, release admission, or cache-policy change.

If the actual shared lifecycle cannot provide a synchronous one-way fence for a prerequisite, the new target remains unavailable; it must not read MainActor state synchronously from the JS thread or weaken the original predicate.

## Required meaningful source controls

- Preserve existing root registry/native source controls and their actual original inputs.
- Execute the original ReaderApp navigation method bodies, with explicit React/domain boundaries, and verify each target's exact original state/history/filter effect. Verify unknown target, wrong original class, display options, interrupting modal, active auth/private editor, failed mount and duplicate registration refuse without invoking an original method.
- Queue the actual private RPC, then cancel/revoke/change runtime or source before delivery/claim: zero original calls. Remove only the native claim to show the negative control detects the late effect. Expired ticket, replay, wrong request/scene/mount/target, consumed ticket and overflow refuse.
- Exercise the real thread-safe Swift ticket/fence/runtime bodies for simultaneous cancel/claim and source publication/claim, one winner and no deadlock/reentry; no MainActor dispatch in the synchronous method. Preserve after-claim partial-effect/cancel behavior explicitly.
- Actual selected state is necessary but insufficient: wrong/hidden/old/detached native header, Library's same schedules title without schedules description, transition/overlay, changed epoch and late JS reply must not report completion.
- Additive actual system-intent/native selectors will retain original selectors and real original target witnesses. They remain NOT_RUN until the final admitted Metro/app and original native driver execute them.

The 45-row mapping is a classification of source and navigation suitability, not 45 successful UI tests. The four targets above remain PROPOSED_UNIMPLEMENTED at this checkpoint.
