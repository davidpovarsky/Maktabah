# N actual downstream app binding adapter

Implemented in `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativePublicBindingAdapter.swift`, with actual downstream composition/session/host connections. It consumes immutable R `44f518fcccce6bd20127f39eea8462d7a7a9dd47` APIs and the existing SAME NativeNavigationAuthority lease, Core/P050 port and scene directory. It is not a documentation-only or test-only adapter. The production default is `futurePublicBindingsEnabled = false`; no current handler, registry policy, URL, content/newTab/reservation or reader executor is enabled.

## Lifetime and observation

The adapter retains one fixed source handle/sourceID, weak actual manager/workspace references, exact manager owner identity and the original scene lease. Each binding re-reads R's qualified live-native observation, exact scene, current S backend and existing admitted authority. Source/owner replacement, unavailable coverage, missing sourceID, backend mismatch and retired lifetime refuse. It never allocates a tab, caches a requested map, manufactures rights/context, remounts or re-admits an old operation.

It subscribes with R's typed `subscribeInvalidation`, revoking only its original lease synchronously at the prepublication fence. No await, Task, SwiftUI onChange or ready notification repairs/revokes a replacement admission. Failure to invalidate unmounts only that exact lease. Callback cleanup clears that scene's existing composition context and revokes the actual presentation wait; lifecycle unmount cancels the subscription. Late old-lease cleanup cannot affect a replacement scene lifetime.

The factory `configureFuturePublicBinding` defaults off and constructs the adapter from the original registered manager/session/lease/directory/backend. Its weak presentation closure also checks the actual session projection still owns the same workspace object, so an old source cannot silently serve a substituted app workspace before a coalesced callback. An installed adapter handles ownership invalidation synchronously. The downstream host's later workspace notification updates projection but does not revoke a freshly admitted operation for the same fixed producer; replacement/nil owners retire the binding. With no adapter installed, that callback performs the existing current-v1 invalidation unchanged.

## Exact shapes and independent presentation

History root/currentTab and Settings root/sheet bind actual R group/profile and explicitly absent target tab. They project neither sidebar nor inspector; background reader state and arbitrary UIStateSpec fields are not copied. History requires the actual unfiltered root. Existing presentation readiness still blocks competing native presentations.

Current reader/currentTab additionally requires an independently live `NativeSurfaceWitness` observation matching the current projection, exact active tab/backend/work/reader lifetime, same currently observed content, nil focus, sameTab and a known inspector Bool. Both true and false are preserved. Unknown inspector, changed work/focus, missing native visibility, inspector/sheet/newTab variants and components refuse. The reader's sidebar remains unprojected. R's ownership epoch stays independent of directory/render revisions and these presentation scalars.

`publicBindingPresentation` reads the existing session's live visibility check and compares its independent evidence with the fresh native projection. It does not turn the model/request into visibility. Actual app currently has no reader marker: current-reader binding therefore stays unavailable even if the model contains that content. There is no claim that the current app Core has installed a reader sink, or that this read-only binding enables content execution.

The port preserves the original authority revision across its own directory await, including explicit readmission of an equal context. P retains the original binding/authority through the one-use surface preparation or canonical Core reader result. Neither this port nor its advisory eligibility replaces Core policy or the strict full N receipt.

## Actual dependencies and unapplied connections

R-owned source files were not modified in N's branch. The current N workspace adapter includes newer approved startup-adoption code absent from R44's whole blob, so overwriting it would lose work. `N_APP_BINDING_R44_DEPENDENCY_UNAPPLIED.diff` is the exact three-path R44 delta, checked and applied only in a temporary copy of current N source. That combination preserves the exact R44 producer block and the existing newer startup adoption; its hashes and successful check are in `N-app-binding-R44-dependency.json`. Manager/R integrates this dependency before app compilation. N's tests consume the exact immutable R implementations independently; the N app files alone are not a complete app target without that dependency.

Three additional exact checked proposals remain unapplied:

- `N_APP_BINDING_REGISTRATION_UNAPPLIED.diff`: one additive file reference/build entry/group entry in the existing iOS app target. Manager also supplies R's policy source registration.
- `N_APP_BINDING_LIFECYCLE_UNAPPLIED.diff`: actual host mount connection after session creation, gated by the unchanged false internal switch. It does not alter public routing/registration.
- `N_APP_BINDING_LEGACY_READER_WITNESS_UNAPPLIED.diff`: exact protected one-line passive marker on the legacy iPad reader detail. Requires explicit owner approval for that file/hunk under the upstream integrity policy. It is not applied or proof of other reader layouts, UIKit behavior or content readiness.

`N-app-binding-proposals.json` records original/proposed hashes and applicability. R's separate protected native setter/lifetime hook remains UNAPPLIED. These proposals require manager's exact review/application and app/SDK/native acceptance. There is no request to modify the currently frozen native run or branch.

## Verification

Final strict Windows Swift6.3.3 joint suite: **107 distinct XCTest methods / 0 failures / 0 compiler warnings** = previous Host84 + P review2 + actual-R consumer7 + new actual-app-adapter14. Earlier focused12 and intermediate full106 are historical subsets, not additional cases. New tests compile the entire actual production adapter unchanged and exact extracted factory, workspace-update/invalidation, workspace-identity and session presentation methods. They use actual R Store/policy/models/persistence/producer body, actual N/Core/P and isolated real disk persistence. UIKit/SwiftUI/native setter owner/visibility shells are explicitly doubled, including R's proposed-hook boundary. The host SwiftUI body, full app graph and real native visibility are not Apple-compiled or executed here.

Discriminating cases cover uninstalled-hook refusal despite successful Store, all-backend strict full surface receipts, checkpoint stability, missing/current-reader visibility and false/true inspector, root field isolation, unsupported/mismatched content, same-turn ABA/original preparation revocation, actual Core LAST backend-await revocation after exact earlier ACK, ready-notification admission, original-lease cancellation/replacement safety, synchronous backend getter revocation, default-off factory, no late coalesced ready revocation, owner substitution before callback, passive evidence mismatch and same-context readmission over an await.

Exact inputs/methods/source Git blobs/raw logs are in `N-app-binding-inputs.json` and `N-app-binding-report.json`; preparation/proposal/finalization scripts are included. Raw log/input paths have narrowly scoped `-text` attributes. Source files carry both working SHA-256 and expected normalized Git blob identity. No result is inferred from CI startup or compilation against doubles.

Packaging-only correction `dc6c24ae1b05d49559e30affeaee477049370c51` separately preserves the prior R93 packet's exact six emitted byte streams/hashes. Its receipt proves their earlier Git difference was solely CRLF normalization. It changed no Source, result or method and did not rerun93. The current-v1 N/P backport remains separate and immutable. Manager's current native43752226209 is untouched/unqueried by N. Native/Apple SDK/physical acceptance and activation remain OPEN.
