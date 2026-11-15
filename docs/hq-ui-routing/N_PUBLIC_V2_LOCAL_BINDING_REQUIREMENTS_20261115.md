# N constraints for the corrected P host-local binding seam

This is the consumer response to P's refined mandatory **single synchronous MainActor** binding observation, captured before the first await and reread at guards/completion. It records requirements, not final P API declarations or a second native/backend authority. No source/handler/registration is activated and no frozen native candidate/run is changed. Exact names and implementation remain P-owned until the corrected packet is published.

## Binding source and meaning

| Value | Existing N source / required interpretation |
| --- | --- |
| Exact scene / native revision | `NativeSceneDirectory` using the actual `MaktabahNativeSceneSession`; never a globally selected/first window or a captured request echo. Use its current synchronous observation at guards. |
| Backend/generation/RPC epoch | The identical `ActionLiveBackendBridge.shared` passed to Core, through S's synchronous/async facets. No binding cache may mint a backend snapshot. |
| Context/lifetime/authority revision | Original `ActionNavigationState` from the existing admitted `NativeNavigationAuthority` lease; same context through full surface completion or the entire Core reader result. No new context or parallel authority. |
| Workspace/profile pair | Actual `StudyWorkspaceNavigationAdapter.selection.groupID/profileID` from this scene, with membership in the actual store. If workspace hosting is required but detached/unselected/switching, fail unavailable/stale. An explicit absence is acceptable only for a genuinely absent native workspace mode, never as a default. |
| Workspace ABA provenance | Actual `workspace.store.snapshot.revision` records writes, but also advances for ordinary checkpoints. It cannot directly serve as the unchanged binding mapping epoch. Comparing only group/profile IDs or waiting for SwiftUI `.onChange(selection)` can miss coalesced A→B→A changes. The real owner must synchronously classify mapping invalidation separately from checkpoints/permitted transitions, without a permission/backend mirror. See the independently tested constraint in `N_CORRECTED_V2_CONSUMER_PACKET_20261115.md`. |
| Target tab | Distinguish a root surface with **no tab target** from an existing exact native reader tab and from a scene-owned not-yet-visible tab reservation. A History/Settings root can have no target tab while an unrelated native reader tab exists. Explicit absence must mean no target for that semantic surface, not a false claim that the app has no tabs. |
| Correlation/reservation owner | Fresh local request UUID, exact admitted context/lifetime and finite original deadline. Resolve/current/release must refer to the same bounded process-local record. A late old cleanup must not release a reissued request or replacement scene/reservation. |

All capture/check operations touching N's native values are MainActor-isolated. A synchronous observation must independently read the current native selection/store revision, current exact directory scene, actual shared S snapshot and live reservation ownership. It may compare them with a retained local record; returning the record without these reads would merely echo stale state.

There must be a real pre-await baseline for native mapping as well as Core authority. A fresh post-await selection cannot erase a pre-resolution A→B→A transition. N establishes the bounded, nonvisible request/reservation record synchronously before calling the binder; the mandatory synchronous observation never allocates or changes native/visible/persisted state. Missing/unresolved record, expired deadline, mismatched request, remount, context release/re-admission or owner replacement must fail rather than return absent IDs.

An actual mapping invalidation must synchronously invalidate the **existing admitted NativeNavigationAuthority** as well as its local binding record. Merely noticing a changed revision on the next binding read would not protect Core's final post-sink backend await, when no further native binding callback may occur. In particular, the existing SwiftUI `.onChange(selection)` is not proof of synchronous coalesced-ABA invalidation. N must implement/test the concrete owner-change observation and finite cleanup for the future adapter; this requirement does not claim that observer already exists in the frozen handler.

## Precommit versus completion

The precommit native scene revision must exactly match the original bound scene. After native navigation, the actual scene revision must advance and match the receipt's applied revision; it cannot still equal the original precommit revision. The synchronous local-binding guard at completion must therefore distinguish these phases. It must preserve the **same workspace/profile/target-tab ownership and mapping epoch**, while checking the live completion scene/revision against the independently observed receipt.

An owned reservation→committed transition may preserve binding identity only when the exact reserved tab becomes the actual tab under the same request/lifetime. Preserve that reservation ownership token/mapping epoch through final Core completion, then release it. A different tab, a user-selected replacement, close/reopen, ABA, another request or a replacement scene must invalidate it. Observer/layout state changes naturally advance the directory's scene revision; that render revision must not be mistaken for an unchanged local-mapping epoch.

The surface consumer must commit the ORIGINAL `UIAuthorizedSceneCommand` returned by binding. N's existing raw-command orchestrator cannot simply discard it and obtain a new grant. The future entry will reuse the existing bounded admission/driver/observer/receipt machinery while retaining that wrapper and its original binding guard. The reader consumer still needs the actual canonical Core-delivered reader command, invocation and content grant; a structural route or local reservation is not that grant.

## Additional exact-shape constraint for reader routes

The current `MaktabahNativeSceneProjection.surface(.reader)` independently includes `state.inspectorVisible` from the actual reader model, including explicit `false`. P983's binder produces `true` for inspector presentation and `nil` for other presentations. Correcting workspace/profile alone therefore does not make every reader shape consumable: current/newTab content with actual `inspectorVisible == false` still differs from a route with nil. No observed field may be dropped to make the receipt pass.

Before opting in a content presentation, agree its exact private state shape and native behavior. For example, if a plain reader presentation explicitly closes the inspector, the immutable route must express `false` and the real driver must perform/observe that navigation behavior; otherwise a narrow trusted observation must preserve the actual agreed state. Do not add arbitrary `UIStateSpec` input or import state through the public DTO. Keep unimplemented/unagreed variants unsupported. The current production host advertises no reader/content v2 variant, so this is a future consumer constraint, not a frozen-run regression.

## Current native tab creation constraint

The current `iOSNavigationManager.openBook` starts an asynchronous Task; its private `presentReader` either selects an existing book tab or constructs `ReaderTab(id: UUID(), ...)`, updates native state and persists the session. `OpenBookOptions` has no reserved tab identity. Calling this route during binding cannot honor a preassigned reservation or provide the required adjacent synchronous final guard. A reservation allocator alone is insufficient.

Keep new-tab/content variants unsupported until the actual reader owner and manager provide/review an additive reservation-consuming commit seam. Do not predict the manager's random UUID, append a visible tab before Core authorization, patch this upstream-owned private function without its exact owner gate, or swap the bound ID after commit. Existing-tab support must also validate that the same exact tab still exists in this scene/backend/workspace; never use the manager's convenience first-tab fallback.

## Acceptance requested for the corrected contract and N adapter

* The already retained actual-shaped root History workspace/profile receipt succeeds on all three synthetic backends; explicit no-workspace mode is separately intentional and checked.
* Missing binding/reservation, stale context, foreground loss, remount, release/re-admit of the same context and workspace/profile A→B→A fail before native effects; actual store revision is represented even if the final IDs match.
* Guarded binding across each host/backend await retains original context/lifetime/mapping baseline. Deadline/cancellation release all finite reservations, observers and continuations before success can escape.
* Owned scene revision advance and exact reservation→same-tab commit can complete; replacement/closed/reused reservations, wrong tab and old cleanup cannot.
* Reader current/newTab/inspector shape tests use independent actual-shaped workspace/profile/tab/inspector state. Structural plan tests must not construct the observed route by copying the requested private state.
* Settings component focus must reveal/focus without setting values/activating controls; before/after actual control/data checks remain native acceptance. No new public registration follows from portable success alone.

These constraints can be implemented without exposing any workspace/profile/tab/scene/correlation/context identifiers in the public DTO or URL. P owns the corrected narrow contract and retained guard; N owns the concrete observation/reservation adapter and original-wrapper consumption. Native/physical v2 acceptance remains open.
