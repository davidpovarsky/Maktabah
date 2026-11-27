# Original Sefaria RN surface — Wave 3 source packet

## Delivery state

This packet implements the finite original Sefaria surface parent required by UI-03, task `1220542361203468`: “Sefaria Embedded RN surface באמצעות bridge/epoch/ready במקום פתיחת UI שגוי.” The source packet depends on the separately reviewed shared Session/Composition/PublicBinding/Projection/Host packet owned by `ui_acceptance` on `f8d9be6c`.

**Source implementation and bounded source controls are supplied. Apple app compilation, Metro/Hermes bundling, the four new native selectors, and physical acceptance have not run on this source.** This packet does not establish Native116, Release114, SDK qualification, or TestFlight readiness. The primitive root does not provide direct component routes for the 45 historical RN inventory rows.

Worktree base: `68b191f56c4fc1644d0b2a3478f05e9935770d20`. Isolated branch: `codex/otzaria-wave3-sefaria-native-surface-20261127`. The original Sefaria gitlink remains `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c`. A fresh read of the original Maktabah remote HEAD/main returned `4203de5fd77beb119e5826e039be1a61325f7be0`; merge base is `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. No upstream sync, package/pod/npm pin, signature, policy, ownership registry, SDK payload or generated Xcode project change is included.

## Actual problem and behavior

The declared `SefariaEmbeddedNativeSurfaceHost` had no real construction call. Its lifecycle adapter returned the headless bootstrap window's root before considering requested module properties. Diagnostic stage 13 declared success after allocation and reading `subviews`, without mounting the original React UI in the requesting scene.

The feature now creates a fresh root from the **existing original Expo React factory**, for the fixed downstream module `ChavrusaSefariaVisibleSurface`. That module imports the actual pinned `ReaderApp`, state reducer/context, theme, error UI and native gesture/safe-area libraries. No Reader rendering or original Sefaria component is reimplemented. The original headless bootstrap window and facade dispatch remain independent.

The finite parent is `native.sefariaEmbedded`, sheet presentation, only for the actual `.sefariaEmbedded` backend with original catalog/reading capability and ready transport. It does not switch backend, select another Maktabah tab/book, mutate the workspace or accept arbitrary JS input, selectors, content/focus, new-tab or RN component journeys. Cold presentation and a warm presentation reuse the same original scene/manager/store ownership. The process-wide visible-root lease prevents another scene from moving or duplicating the single original ReaderApp and its process-global listener names.

The separate shared packet performs the canonical public/Core operation once, under the original admission and deadline. It also retains the original root tab/mode/book/Settings and Workspace setter publication histories at +0. Its independent native marker acknowledges only through `withValidatedSurface`; allocation, SwiftUI selection and JS readiness alone are not ACKs.

## Source and concurrency boundaries

The bridge's actual epoch, ready, listener and resource fields share one source-owned authority. Every lifecycle publication, including repeated equal-value callbacks, increments a non-rearmable revision. Exhaustion remains unavailable. A retained token holds this authority and compares its exact observation; it is not a MainActor mirror.

`withValidRuntime` holds a recursive source lock through the synchronous native apply/report section, checking before and after. Read-only, same-thread validation may reenter it. No actor call, RPC, suspension, JSON encoding or UI lifecycle dispatch is performed inside that lock. The retained Session validator and native observation callback are synchronous internal ownership checks. Contending lifecycle writers wait for the section to end. The feature's `changed` notifications, RPC and serialization occur outside it.

Direct `bumpSessionEpoch` and its callers use a depth-owned transition boundary. Its `cancelAll` and epoch write retain their original order; an inner completion cannot open an outer transition. The original native module begins a source-owned transition **before** changing its listener/executor state or enqueueing ready/error/transport updates. Each queued boundary completes exactly once after its original actor operation. Invalidation also keeps an outer boundary through `super.invalidate`. Out-of-order completion remains closed until every boundary settles. Dropping an unfinished boundary does not manufacture completion. The original RuntimeManager `resetState` and subsequent awaited bump keep their order, enclosed by the same boundary before the first mutation.

The binding retains exact SourceEntry membership and a unique Pending token. Admission and report callbacks are bracketed by fresh membership/source validation. All waiters and awaits carry the same retained request rather than looking up a later request with the same UUID. An early release invalidates and finishes the active request. Only a successfully completed, exact receipt proof may survive normal outer-source release.

`awaitOriginalSurface` runs inside the original Session structured visibility/deadline operation. It waits for the exact original UIKit host, then performs the original RPC `surface.awaitVisible`, racing it against host invalidation. It cancels and joins its other child before releasing its retained source. Cancellation resolves the native continuation; any late, bounded read-only JS response is ignored by the existing bridge request table. No probe obtains a new Core grant or extends the retained deadline.

The JS registry checks one exact native surface/mount/scene/epoch/nonce. It reads the real `ReaderApp` instance's `loaded` and `_completedInit` and actual React `onLayout` evidence on a real animation frame. It rejects duplicate ownership, cold first-mount ABA, detach, errors, mismatches and deadline expiry. **The JS response is point-in-time original-state evidence; this packet does not claim a cross-thread atomic snapshot of arbitrary later React state.** Final native acknowledgement separately requires the retained bridge runtime token plus fresh, owned, visible UIKit window/controller/geometry evidence and the original shared source checks.

## Review corrections and preservation

The first peer draft's copied Pending/member checks and standalone bump boundary were preserved before correction. The unchanged original native callback/reset and Workspace setter bodies are negative baselines. All raw compile/run attempts, including expected failures, remain in `raw`.

Two final cleanup changes were reviewed after the last compile control: an exact cold-creator request/identity pair powers `dismissNewSurface(requestID:)`, allowing the diagnostic's defer to close only its own newly created surface even if fresh evidence or cancellation fails; and controller detach always offers the exact owner a detach callback, including a partial `willAttach` that fails its postcondition after ownership was retained. The binding's exact controller identity guard prevents foreign cleanup. These changes are source-reviewed and await the integrated app build. The already-tested retained-request methods are byte-compared to their controlled extracts in `SOURCE_PROVENANCE.json`; the final host and full binding are not represented as UIKit-compiled.

The small control runner now pins the same original source commit explicitly for its negative baseline, so committing this packet cannot accidentally substitute a moving HEAD for the old native/Workspace source. This preserves the retrieval performed during the recorded run and does not change an assertion or expected failure.

## Evidence and exact limits

| Evidence | Actual outcome | Limit |
| --- | --- | --- |
| Real bridge/runtime Swift 6 strict-concurrency controls | 25 passed, 0 failed | Linux source execution; no Apple UI |
| Verbatim retained-source membership methods | 14 passed, 0 failed | Original runtime lock; reduced ownership collaborators |
| Verbatim native callback/reset boundaries | 8 passed, 0 failed | React/UIKit boundary fixtures; only ObjC attribute removed for Linux |
| Verbatim original Workspace setter revision callbacks | 7 passed, 0 failed | Original callback methods; no native presentation |
| Actual JS surface registry | 24 passed, 0 failed | Node execution; no rendered React tree |
| Earlier standalone bump body | 1 expected failing control | Preserved negative baseline |
| Earlier membership methods | 12 expected failing controls | Preserved peer draft, not hidden |
| Original queued native callbacks/reset | 7 expected failing controls | Demonstrates pre-enqueue source gap |
| Original Workspace callbacks | 7 expected failing controls | Demonstrates foreign modal ABA visibility gap |
| Deliberately weakened revision / nested transition / synchronous lock | 9 / 3 / 1 failing controls | Counterfactual copies only |
| Deliberately weakened JS init / mount identity / first-mount ABA | 1 / 1 / 3 failing controls | Counterfactual copies only |
| Apple app, SDK, bundle and native selector runs | **NOT RUN** | Root owns final source freeze/build capacity |

Final Swift control receipt: `c30be503dbc6bd5f48a05160d396176ca6bee1ed38af6c2b7888f41c06a82be4`, copied unchanged from the isolated `build/rn-surface-source-controls-20261127-attempt3/controls/RESULT.json`. Earlier attempts 1 and 2 remain separately identifiable. Compile stderr includes a test-only weak-variable diagnostic; it is not reported as empty. A first JS negative-run harness failed while collecting an unresolved counterfactual; that invocation is retained separately. Its frame-driving harness correction produced the separately recorded final results and did not alter the production registry.

No additional compile/cache creation followed root's capacity stop. The original component runner, native aggregate selectors and their assertions are unchanged. The current generated SDK/app source receipts were not retagged.

## Original owners and placement

`SOURCE_PROVENANCE.json` records exact base blobs, introduced commits, current source hashes, remote/pin evidence, final controlled-method comparisons and target notes. Original Maktabah `iOSMainView.swift` remains a protected shared seam: its only delta supplies the existing diagnostic with the canonical visible-surface provider. A downstream adapter cannot provide that existing caller's actual manager without this minimal injection. The original MainView root selection/Settings publication edits owned by the UI sibling are disjoint.

All Sefaria bridge/adapter/native-module/Integration JS modifications are traced fork-owned additions (principally `b13aabcd300d91aae13d152875163e33906bcb7e`); the diagnostic runner originates at `7be24ab648de8539afdb161c0551d605ce3c1e18`. The Workspace adapter originates at `15ad8ac0596056503e52082ae3d8c0b13499fdd5`; its new counter is source publication metadata, with no original presentation behavior change. The pinned vendor subtree, licenses, existing engine/RPC actions and Objective-C export declarations are untouched. The stage 11 `searchLive` catch-as-pass concern was assigned to Wave 2 and is not silently corrected or accepted by this packet.

## Build membership and pending native work

| New file | Required registration |
| --- | --- |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfaceBinding.swift` | Same iOS app/native-test memberships as the existing Workspace/Phone parent bindings; `#if os(iOS)` |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeSefariaSurfacePresentation.swift` | Same iOS composition/host memberships; `#if os(iOS)` |
| `Source/SefariaEmbedded/UI/SefariaEmbeddedSurfaceContract.swift` | Foundation contract wherever the existing Sefaria diagnostic/provider types compile; check both original iOS/macOS memberships, not only UI binding targets |
| `Maktabah-iOSUITests/NativeSefariaSurfaceAcceptanceTests.swift` | Existing iOS UI-test target only; four additive selectors, no aggregate selection edit |
| `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurface.js` | Existing Metro/Hermes Integration graph via `ChavrusaRoot.js` import; regenerate authentic bundle/source receipts |
| `Vendor/SefariaMobile/Integration/JS/ChavrusaVisibleSurfaceRegistry.js` | Imported by the visible root and existing RPC facade in the same original bundle |
| `tools/test_sefaria_visible_surface_*` and source-control runner | Repository tools only; do not add to application targets |

The four additive native selectors use actual system `NativeDestinationEntity` discovery and `OpenNativeDestinationIntent`, the original realUI bootstrap, exact persisted workspace, real canonical reader log and original RN FooterTabBar controls (Texts/Topics/Saved/Account), followed by native Close. They cover cold+warm iPad, cold+background-warm iPhone, and unavailable Otzaria backend on each form factor. They are declared, not executed. Original first-run React prompts/resources remain original behavior; any prompt/ready/layout/transition failure in the final run must remain visible rather than being skipped or replaced with a synthetic marker.

Root must integrate the paired shared packet, register the files, honestly regenerate source/bundle admission, build Debug/Release against qualified original SDKs, then run these selectors alongside the unchanged required product suites. Actual iPad/iPhone and physical acceptance remain pending.

## Rollback

Revert this scoped feature commit together with its paired shared routing packet and root's corresponding PBX registrations. Preserve the raw evidence and original pin. No persisted Maktabah data migration, original dependency upgrade or vendor source rewrite is introduced.
