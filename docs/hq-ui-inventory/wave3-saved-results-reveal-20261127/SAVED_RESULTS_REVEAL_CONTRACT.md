# Original Saved Results reveal — bounded source contract

Base: `24cd9291dbc87d799c22a41f0bc73a82c6415bfa`, Source `23cdfce49553927656ef79c6db10f654c889e2fc`. Live upstream main was independently read as `4203de5fd77beb119e5826e039be1a61325f7be0`; the isolated Git merge base is `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. No upstream sync is performed.

## Exact original owner and eligibility

The original `GlobalSearchToolbar` exposes Saved Results only through `usesNativeMaktabahDataPath`. The actual Otzaria registration sets that flag to true. This first slice requires that same active Otzaria capability and the already existing original Search parent. It does not select a different backend or root. A stale/cold/foreign window is refused.

`SearchModeView.showingSavedResults` remains the original sheet owner. The sheet still constructs `iOSSavedResultsView`, and that original view keeps its native NavigationStack, lists, rows, alerts and menus. Its two existing original loads remain unchanged inside passive begin/defer lifetime brackets. No new database, file, query execution or recreated UI is introduced.

The primitive public root is `native.savedResults`, `.sheet`, explicit Otzaria, no content or component. Root handles its ordinary existing PublicV2 registration and URL handoff. The existing `/action/v2/` namespace is sufficient for the parent. This packet does not edit PublicV2 or the generic registry owned by the public Search work. Typed folder/result references first use the thin AppEntity service; any future selected-record public field must be separately integrated into the same existing strict codec. It must not encode a folder name, query, SQL ID, path, window or grant.

## Precise scope

- Cold **sheet root** from the already mounted original Search parent: one original `showingSavedResults = true` publication inside canonical apply; wait for actual original sheet/list evidence and original load completion.
- Warm **folder page**: retain the actual original FolderNode and its complete original ancestor objects; publish only the original NavigationStack path, then require the actual folder page witness.
- Warm **result row**: retain the actual original ResultNode, parent chain, private filter and complete tree publication. Publish the original path if needed, scroll the original list and require the exact original visible result row.
- No result button activation. `loadResult`, `loadSavedResults`, save, move, rename, create and delete operations are byte-preserved and are not called by these routes.

Cold cached folder/result references are unavailable. The original sheet task rebuilds node objects, so retaining only a numeric ID and resolving a new object after the await would substitute a fresh source. The original reload is neither skipped nor treated as an owned node-mutation allowance. Global-page-to-Search continuation and durable query/record restoration remain separate open requirements.

## Source and lifecycle proof

`OriginalSavedResultsLoadLifetime` is passive, shared-platform metadata. It closes before each original detached load, remains closed until every exact outstanding load settles, advances a monotonic revision, and consumes completions before callbacks. Exhaustion or invalid completion fails closed without cancelling or changing the original load. A sticky retired state survives synchronous Observation reentry. The initial weaker draft is retained for a meaningful counterexample.

`MaktabahNativeSavedResultsSource` captures the existing model, settled load revision, exact roots/dictionaries/parent map, actual object identities and node fields. A one-shot original Observation latch catches changed observed values and A→B→A; the explicit original load lifetime also retires an old tree when a load publishes an equal collection. Swift Observation may suppress a direct equal-value array assignment, so that unsupported shortcut is not relied upon. Original root equal-value State writes pass through the existing private monotonic publication owner. SQL-ID equality alone is never accepted. Duplicate IDs, cycles, missing parents, ambiguous indexes and bounded-catalog overflow refuse. The source contains private values only for local equality/filter checks; no public payload or log receives them.

The original sheet owner provides captured Binding getters/setters, not copied State values. Every local path/filter/modal publication invalidates a pending source before changing State. Only the exact one-use path or sheet publication of the current canonical command is permitted, with the allowance consumed before callbacks and actual post-set value/revision checked. Extra/reentrant/equal writes retire the request. Ordinary UI writes are never blocked.

Before the first await, retain the actual scene/backend observation, original root/tab/mode/Settings/workspace/reader publications, exact Search and sheet host tokens, and the original window observation. Later readiness reads revalidate that same proof; they never obtain a new grant, recapture a source or renew the original five-second deadline. Current path/filter/source and any foreign modal remain checked through report completion.

## Proposed original-host interface

The new `MaktabahNativeSavedResultsBinding` exposes only app-owned methods:

- `catalog()` and `isAvailable` are metadata/readiness reads, with no load or grant.
- `retain(record:requestID:)` accepts nil only for the primitive root and captures the original source before awaits.
- `validateSource(requestID:)`, `begin(requestID:validate:)`, and `apply(requestID:)` join the existing retained Core command.
- `observedItem(requestID:)` and `withValidatedSurface(requestID:report:)` require the real original parent/page/row witness before the existing final acknowledgement.
- `finish(requestID:completed:)`, `releaseSource(requestID:)`, `retire()` and `unmount()` preserve exact pending identity and release order.

The host registration APIs are private application seams carrying original Binding accessors and actual view/scene/window identities. They are not executable public route fields. An initial cold sheet host may join only after that same command applied its original presentation setter. Replaced/detached hosts, including a return to an old object, retire the source. Layout callbacks are deduplicated actual geometry evidence, never a manufactured ACK.

## Ownership

| Path | Ownership / exact delta |
| --- | --- |
| `Source/Features/Search/iOS/SearchModeView.swift` | Upstream origin with existing downstream hooks; capture the existing saved-sheet setter, exact owner token and passive will/did publication hooks only. |
| `Source/Features/Bookmarks/iOS/iOSSavedResultsView.swift` | Byte-identical to pinned live upstream before edits; expose its original typed NavigationStack path and private State boundaries, add passive markers/ScrollViewReader around the original lists. |
| `Source/Features/Bookmarks/ViewModel/ResultsViewModel.swift` | Byte-identical upstream; one passive lifetime member. The existing `onTreeChange` callback remains untouched. |
| `Source/Features/Bookmarks/ViewModel/Extensions/Results+Load.swift` | Byte-identical upstream; exactly one begin/defer pair per original load. Removing those pairs reconstructs the exact original file. |
| New `Source/ChavrusaText/Bookmarks/OriginalSavedResultsLoadLifetime.swift` | Downstream passive shared-platform metadata. |
| New Host service/intents and Integration Saved Results source/binding/witness files | Downstream original-owner adapters. |
| Session/Composition/Projection/registry/PBX/catalog | Root applies exact separate proposals. No concurrent shared live writes. |

## Evidence boundary

Controls must cover original-load concurrency/cancellation/reentry, sticky retirement/overflow, tree replacement/ABA/duplicate identity, exact scene/window/request, private-filter preservation, one-use original State publications, parent-only false acknowledgement, and post-ACK cancellation without erasing the canonical return. The original UI must supply final native evidence; source controls cannot establish UIKit, AppIntents metadata, VoiceOver, production data, physical device or final UI03–07 acceptance. No Mac run is authorized for this packet until root coordinates the qualified app.
