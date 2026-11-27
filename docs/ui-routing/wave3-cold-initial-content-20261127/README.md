# Original cold initial-content ownership

This packet gives the original Reader load an identity before its first callback or suspension. A native Profile/Group selection retains that exact invocation through the original section-token issuer; it cannot adopt a later token merely because the final book and locator happen to match.

The same change fixes original late-publication regressions. Replaced history/navigation work must stop before publishing a destination, navigation array, content, or cleanup for another load. The original content publisher now accepts an optional read-only validity closure and checks the same request between its existing publications. Ordinary callers use the default `nil` argument and keep the original sequence of effects.

## Historical correction

The first Group source comment described the legacy initial load as an “unretained Task.” That description was wrong: the original `backendLoadTask` is retained in `ReaderViewModel`. The actual missing boundary was an invocation identity **before** the original content token existed, plus validation at late resumptions and synchronous publication callbacks. The original source and prior wording remain preserved in the baseline; this packet replaces that comment and records this correction explicitly.

## Source scope

| Path | Change |
|---|---|
| `Source/ChavrusaText/Navigation/ReaderInitialContentRequest.swift` | New immutable invocation/source observation and request types; no retained Reader, feature model, executable public payload, or serialized authority. |
| `Source/ChavrusaText/Navigation/ReaderContentLoadCoordinator.swift` | Original lock owns a fail-closed monotonic source revision, pre-token request phases, one exact token handoff, and a read-only source observation. |
| `Source/Features/Reader/ViewModel/Extensions/Reader+Content.swift` | Retain the handle before original callbacks/awaits, carry it through the original resolution and publication order, retire only the exact terminal request, and guard later task cleanup. |
| `Source/Features/Reader/ViewModel/ReaderViewModel.swift` | Only `updateContentState` signature/body: an optional validator and checks between original publications. Removing those additions reconstructs the entire original file exactly. No storage changes. |
| `Source/ChavrusaText/StudyWorkspace/StudyWorkspaceNavigationAdapter.swift` | Keep the original stage/reservation and exact cold request instead of sampling a future token. Existing Store and native-operation authority are retained. |
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeWorkspaceSelectionBinding.swift` | Admit only a source-qualified original cold path; bind the same original absolute deadline; preserve completed source only after qualified completion. |

The two Session additions are proposals for the root integrator. They pass the already-existing invocation deadline into `bound.begin` and mark successful completion only after the original final validation. The packet does not write shared Session/Composition/PBX/catalog files.

## Invocation contract

`ReaderInitialContentRequest` captures the original Reader and book object identities, full book locator, input (initial ID, locator, or destination), backend and generation, and original destination. The coordinator advances its source revision before publishing a new request. Equal restarts, direct original token starts, cancellation, and invalidation retire previous observations. Exhaustion permanently refuses a new initial request.

The phases are `reserved → resolving → handingOff → issued → completed`. The original callback entry and token handoff consume their phase before any external callback. The original resolver declares its outputs, then the original coordinator issues the one token bound to that request. The Group reservation retains both the handle and its actual issued token; reading a new current token later cannot repair a stale request.

All asynchronous resumes and source checks compare that exact handle. A failed comparison or terminal cancellation/stale response invalidates only that handle. If another request has replaced it, the old invalidation cannot affect the replacement. The same rule protects cleanup of the retained `backendLoadTask`.

The native path receives the original command's absolute end; no timeout is renewed. Ordinary UI calls pass no native deadline. A completed original load keeps its real content token, while its source observation becomes a stable no-pending observation.

## Read-only loaded Reader fence

```swift
let observation = reader.contentLoadCoordinator.initialContentSourceObservation()
```

The result contains immutable `ownerID`, `revision`, `pendingRequestID`, and read-only `isCurrent`. It remains available for an already-loaded Reader with no pending initial request. A missing observation means the source is unavailable or its monotonic revision is exhausted.

For selected-note or commentary capture, require `pendingRequestID == nil` before reading the original selection and `isCurrent` before and after the existing checks. Capture from the exact current Reader and recheck that identity after the selection read. A current observation of an already-pending request is intentionally **not** an idle loaded source; old displayed text must not make that state admissible.

The controls include both starting a request while rendered fields remain unchanged and capturing the observation after that request is already pending. These are coordinator/source controls, not renderer substitutes.

## Validation and preserved failures

The first control capsule compiles the actual touched Reader functions, coordinator/request, original resolver/model types, and actual Group reader-source reservation over explicit backend, I/O, rendering, Store, and UI shells. The original source produced 3 passes and 4 failures; the first candidate produced 35 passes. Those exact results are retained as a limited boundary proof.

Peer review then found an internal publication gap: the first capsule's `updateContentState` shell did not exercise the actual publisher's later fields after a reentrant callback. A separate capsule compiles the **entire original publisher body** and the corrected body, selecting the original iOS/macOS conditional branches over declared platform-state shells. It covers real Observation callbacks on the original content field, the original `loadAnnotations` call boundary, nested Reader-state publication, terminal errors without a cancelled Task, and unchanged default-nil behavior.

The first publisher run is also preserved: its new full-destination assertions incorrectly expected a nil focus, although the original Otzaria resolver produces a same-line focus. Only that expected original destination was corrected; no field, history, state, cancellation, or source assertion was removed. The before/candidate source remains identical across that fixture correction.

| Capsule | Before | Candidate | Meaning |
|---|---:|---:|---|
| Initial invocation/Group boundary | 3 pass / 4 fail | 35 pass / 0 fail | Original load continuation plus explicit publisher shell; preserved separately. |
| Actual original publisher, iOS conditional body | 10 pass / 7 fail | 17 pass / 0 fail | Real publisher function, real Observation, explicit platform-state/backend boundaries. |
| Actual original publisher, macOS conditional body | 3 pass / 2 fail | 5 pass / 0 fail | Original callback body selected explicitly on Linux; no macOS app claim. |
| Full candidate files and Session proposal | — | 14 successful frontend parses | Six source files and one proposal, Debug/release. |

The initial publisher fixture's 14 pass / 3 fail result is retained independently from the corrected oracle. Linux source controls and frontend parsing do not qualify Apple SDK typing, rendering, system intents, or native UI behavior.

## Integration and remaining acceptance

The new request file needs the same original target membership as `ReaderContentLoadCoordinator.swift`. It is Foundation-only. Root owns that membership change and the two exact Session proposals. No new localization or Shortcut registration is required.

The packet is based on the admitted Group source at `ce4fe5a327168524f6f1fef1e7792a275ece0ebe`. Intake must compare each current source blob to the preserved preimage and combine the disjoint ReaderTools Session additions without resetting them.

Actual iPhone/iPad cold Group/Profile navigation, final TextKit/empty-Reader witnesses, background/foreign-root continuation, saved-document restoration, slow inactive-tab loads, and cancellation during real original rendering remain native acceptance work. Same-library/source qualification remains required; unqualified legacy book objects and unresolved foreign raw IDs remain unavailable to native Group routing. Their ordinary original UI path is preserved. This packet does not grant an automatic backend switch or substitute a generic root receipt for the original selected workspace.
