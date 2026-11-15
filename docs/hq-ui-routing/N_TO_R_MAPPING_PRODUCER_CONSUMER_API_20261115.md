# N → R: required true-owner producer semantics

Owner decision: `NATIVE_MAPPING_PRODUCER_ASSIGN_R_20261115.md` in the single-manager HQ packet. R exclusively owns actual Store/adapter policy and any **unapplied** native setter proposal. N does not edit those files. P owns the immutable binding contract; N owns concrete observation, same-authority consumption and full-result cleanup. This document requests no activation, reservation, wire expansion or new app run.

## Required delivery shape

R may choose its concrete downstream type names. N needs a MainActor-isolated producer object/handle tied to the **actual store + exact scene/adapter/native manager ownership**, with these operations:

1. Synchronously obtain the current narrow ownership observation or an explicit unavailable/unsupported result. It must independently read actual owner data, not return a cached requested mapping. Include the real, nonpersisted, monotonic mapping epoch and qualified workspace/profile/target ownership needed below.
2. Subscribe to **synchronous invalidation before dependent changed source publication**, after successful validate/save. The nonthrowing callback lets N invalidate its existing admitted `NativeNavigationAuthority` lease. It must not require a Task, SwiftUI render or delayed checkpoint. No event/epoch change may escape a failed transaction or failed save.
3. Cancel/release the source subscription deterministically. A cancelled/old owner must never invalidate a replacement scene or a later admission. A weak consumer callback and bounded active scene/owner registrations are appropriate. No per-request uncancellable observation accumulation.

The callback can be a typed event or a real owner's observable narrow epoch compatible with N's inactive `NativeBindingSourceObservation`. A direct typed event is also acceptable; it need not adopt N helper types or import Core/UIRouting. P/N packages need not be merged into R's producer tree. N will use the actual final R packet/API, rather than ask R to adopt speculative DTO names.

## Ownership observation versus the P binding

| N/P consumer needs | Producer meaning |
| --- | --- |
| Actual owner identity/lifetime | Reference/handle to the real fixed owner and exact scene. This is producer lifetime evidence, never a replacement Core context/lifetime or a wire UUID. |
| `mappingRevision` | Real owner epoch for relevant ownership invalidation. Distinct from `StudyWorkspaceSnapshot.revision` and native directory render revision. No wrap/reuse/stable default for unavailable state. |
| Workspace/profile | Exact selected group/profile and actual membership; genuinely absent mode is distinct from detached/loading/invalid/missing source. No first/global selection fallback. |
| Target tab | A root surface has **no tab target** even if a background reader tab exists. Existing reader targeting requires the exact live active/selected tab and its actual scene/group/profile/backend/work identity; stale active ID must not fall back to the first tab. |
| Qualification | Replacement behind the same UUID, changed backend/work and lost membership invalidate. Locator/progress-only checkpoint, rename/order-only metadata and unrelated-scene writes preserve the relevant ownership epoch. |
| Live-native coverage | Explicitly distinguish Store ownership coverage from actual `manager.activeTabId/openTabs` coverage before delayed persistProjection. Store success cannot implicitly claim live-native coverage. Missing required coverage fails closed for that target. |

N will build P's existing mandatory `UIPublicNavigationLocalBinding` from those actual owner values, the exact directory/S snapshot and the required fields from the actual semantic surface projection. R should not return arbitrary `UIStateSpec`, create a second permission/backend coordinator, copy a public request into state, or fabricate presentation flags.

History/Settings project actual workspace/profile and explicit absent **target tab**. Reader/currentTab projects exact actual tab plus explicit `inspectorVisible=false/true`. `sidebarVisible` and `state.sheet` from the broader scene identity are not automatically part of these surface routes. N owns reading the exact UI presentation/component scalar fields and preserving the admitted boundary for their relevant changes. Current reader with inspector visible is still `.currentTab`, not proof of an installed `.inspector` presentation.

## Temporal guarantees N will verify

* N captures the original admitted `ActionNavigationState` and actual binding before the first await. Each relevant owner invalidation synchronously revokes that SAME authority through the original scene lease. No release/re-admit, independent permission counter or fallback source is used.
* A→B→A is observable even if final IDs match; readmission between consecutive writes cannot evade the next invalidation. Partial/mid-publication owner state must be unavailable to new binding, rather than a stable default epoch.
* A successful ordinary checkpoint and permitted presentation advance do not invalidate ownership. Native directory revision advances to the receipt's applied revision while the mapping epoch stays stable for the same owned mapping.
* Source attach/remove/unavailability, membership change, target replacement and owner lifetime replacement cannot be hidden by an unchanged UUID. A source failure/overflow must not wrap/reuse an epoch or advertise stable availability.
* Synchronous invalidation remains effective during Core's final shared backend await after an earlier native sink ACK. N retains the exact route/wrapper and original admission through the full result and final actor-return checks. Producer handles never grant mutation or replace Core's actual reader grant.
* Cancellation/teardown and old cleanup never revoke/release a later scene/admission. No callback throws back into Store after persistence succeeded; N catches authority invalidation failure and fails closed on its own native lease.

## Existing native setter gap and unsupported work

The delayed Store projection cannot itself cover immediate live `activeTabId/openTabs` changes. R's coverage/evidence must state which actual native mutation boundaries are connected. Any necessary upstream setter hook goes to the sole manager as an exact minimal unapplied patch, with necessity and rollback; N will not assume it was applied from a Store-only fixture.

No reservation allocator, newTab/content renderer, public-v2 handler/registry opt-in or URL publication is authorized by this producer seam. Existing manager.openBook still has no reviewed synchronous reservation-consuming entry. Those variants remain unsupported. N's existing70 portable tests and inactive helper do not establish actual native producer wiring.

R's immutable handoff should include actual producer/test source SHA, exact API/type definitions, coverage statement, source/epoch semantics, raw logs and method identities. N will independently consume that actual packet, reuse its actual Store/adapter producer with isolated test data, and run the existing strict same-authority/P binding/receipt/Core-final-await tests. No current frozen run will be retried or watched for this work.
