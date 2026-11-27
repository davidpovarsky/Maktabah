# Public Search continuation: original-source contract

Design baseline: integration `24cd9291dbc87d799c22a41f0bc73a82c6415bfa` (2026-11-27). This is source design, not application or native acceptance. The preceding eight Search continuation selectors and DEBUG probes remain NOT_RUN on an integrated app.

## Original requirements and the gap

| Original task | Required behavior relevant to this change | Current source at the baseline |
| --- | --- | --- |
| UI Automation `1220542361135050` | Search query, scope, mode, sort, paging and selected result through the common registry/Core; stable hit identity; no private query in an externally shareable link | First-page system search and original-source continuation exist, but only DEBUG invokes the continuation |
| UI-02 `1220542479938476`, G1 | Bounded versioned typed state/selection, registry discovery, strict schemas, no duplicate resolver or permission system | PublicV2 accepts only destination/backend/content/presentation/component; it has no Search record field |
| UI-03 `1220542361203468`, G2 item 3 | Global Search + query + filter + selected hit; exact original visible target; no silent backend change | Existing continuation binds the original list, query and item, but lacks a production caller |
| UI-04 `1220542420331748`, G3 | Semantic ShowSearchResults(query/scope/mode/result), real entities, stale/ambiguous/window/cancellation behavior | `NativeSearchIntentService.open` rejects any selectedHit/cursor presence; this original first-page contract must remain explicit |
| UI-05 `1220542420330496`, G3 | Direct URL Search filters + hit; versioned bounded URLs; preserve Widget URLs; no private query or arbitrary code | Existing v2/AASA transport can be reused; a parallel namespace would require separate Universal-Link authorization |
| UI-07 `1220542416158970`, G5 | Actual selected-hit/cursor, source/scene/backend/stale/replay/privacy/RTL/VoiceOver qualification | New runtime tests are not executed; title/snippet VoiceOver reachability is not unique focused-row/full-context traversal |

The original iOS26 wording is historical. The separately sourced owner's iOS/iPadOS27-only override remains applicable.

## Chosen public shape

Extend the existing PublicV2 DTO with one optional `searchReference` string. It is a canonical lower-case UUID identifying a bounded live metadata entry, not a Core token or permission. It contains no query, filter, source configuration, raw provider cursor/offset, scene/session/tab UUID, note text or authority. Explicit `backend` supplies the qualification; the two finite destinations supply the operation:

- `native.search.result`: reveal one already loaded, currently eligible original result.
- `native.search.nextPage`: request the next page declared by that same original source's current page ledger.

Both require currentTab, explicit backend and the reference. Both forbid content and component. Every pre-existing destination forbids the new field. Unknown fields, mixed payloads and invalid reference shapes fail closed. Existing public v1/v2 fixture bytes and legacy Widget paths remain unchanged. Encoding stays in `NativePublicNavigationURLV2`, including the already verified `https://davidpovarsky.github.io/chavrusatext/action/v2/*` namespace.

A separate `/action/search/v1` envelope was considered and rejected: it would split decoding and lie outside the established AASA path.

The trusted registration policy gains a finite Search reference requirement. A reference-required destination is not a generic root or a component. Generic PublicV2 variant discovery omits it until the typed metadata catalog supplies a real selection. `bindPublicV2` rejects a search reference before preparing a generic surface/reader plan. Decoding cannot manufacture an acknowledgement.

## Metadata is not operation authority

The metadata owner is attached to the actual original Search source and scene. It reads the existing original model/session, backend snapshot, input/result/presentation counters, submitted configuration, page ledger, original filtered identities and list attachment. It does not call the current `observe(invocation:)` merely to discover entities: that method creates operation tokens and requires real authority.

Add a narrow metadata-only read/validation seam next to the existing binding's `readStamp`, retaining the same original identities and bounds. A catalog entry is stable only during that qualified source publication. Repeated queries return the same metadata references. A replaced/retired source never reuses them, even if values later return to the same state. Original hit stableID, locator/version/language and exact identity bytes stay host-local and are checked against the actual loaded item; the public UUID does not replace those checks.

Keep a bounded current catalog per live original scene and weak source ownership. Discovery may return only currently eligible original items, with actual source titles/location/version/window labels. It may not submit a query, change a filter, select a window, allocate a Core grant, consume a continuation token or advertise an empty/exhausted source. Duplicate original identities are ambiguity, not first-match selection.

Execution resolves the untrusted reference back to the exact catalog entry, captures original source/scene/window before any await, and consumes the metadata selection once. A fresh Core-authorized original observation then yields the real operation token. Match the selected actual item/next-page source to the retained metadata; do not rediscover a replacement target after a change. The original preparation, original source claim and five-second deadline remain mandatory. No deadline renewal, hidden query restoration, root fallback or backend switch is added.

After ownership transfers to the original operation, its existing checked publication rules distinguish owned page/result changes from foreign input. Do not apply an indiscriminate pre-image equality check after an owned next-page effect, and do not rearm an Observation latch. Preserve actual refused/unqualified outcomes and earlier effects at every reporting boundary.

## Production adapters

Add two foreground intents backed by one thin service: reveal a loaded Search result, and load the next original Search page. AppEntity/EntityQuery values expose only metadata reference IDs and titles; their IDs are versioned and backend-qualified. Distinct query types cannot interchange result and page references. The old ShowSearchResults first-page wrapper/query/service are unchanged.

The same service/catalog supplies a read-only link-encoding operation for a genuinely discovered target. URL execution goes through the existing single URL handler and original v2 codec/registry, then the exact same continuation entry as the intents. The typed outcome remains `ActionSearchContinuationOutcome`; a generic `UISceneReceipt` must never be fabricated for it. Success requires the existing original row/list/ledger/Core validation. Failure preserves the actual outcome while showing a fixed, privacy-safe error category.

The root-owned Composition will factor only the common entry boundary needed to accept an exact selected metadata entry, an origin and the original absolute deadline/request. Its existing in-app/DEBUG wrapper remains behaviorally unchanged. Registration, lookup and result joining are not alternative query or pagination executors.

## Ownership and proposed files

| Owner | Paths / changes |
| --- | --- |
| UI acceptance | `Source/Otzaria/UIRouting/Sources/OtzariaUIRouting/Contracts/PublicNavigationV2.swift`: optional field and finite trusted reference policy |
| UI acceptance | `.../Codec/UIRouteSchemas.swift`, `.../Codec/PublicNavigationV2Codec.swift`, `.../Registry/UIDestinationPublicNavigationV2.swift`: shape/normalization/policy/discovery/generic-binder guards |
| UI acceptance | Two bounded guards in `.../Registry/UIDestinationRegistry.swift`: reject reference-required generic RouteSpec and omit unresolved reference kinds from generic discovery; old non-reference bodies stay intact |
| UI acceptance | New `UIRouting/Tests/.../PublicSearchReferenceV2Tests.swift`; new Host public URL/reference/service tests; original fixtures/tests remain intact |
| UI acceptance | New `UIRoutingHost/Sources/ChavrusaUIRoutingHost/NativeSearchContinuationIntentService.swift` and `NativeSearchContinuationIntents.swift` |
| UI acceptance | New `UIRoutingHost/Integration/MaktabahNativeSearchContinuationCatalog.swift`; narrow metadata-only seam in existing `MaktabahNativeSearchContinuation.swift` |
| Root | Actual `MaktabahNativeRoutingComposition.swift`: finite descriptors, dependency registration, same source-bound entry and typed URL dispatch |
| Root | Actual `MaktabahNativeSceneSession.swift`: exact catalog owner/accessor/retirement hooks if needed; no independent live edit by UI acceptance |
| Root | Actual `MaktabahNativeURLHandler.swift`: branch only for validated finite Search reference, preserve legacy/single handoff and typed failure |
| Root | PBX, app/Host catalogs, AppShortcuts, final source admission |

App-layer interfaces/patches will be supplied for root integration. No Search engine, controller, first-page semantics, Core authority or original UI is replaced.

## Required controls

- Exact old v1/v2 fixtures encode identically; old unknown fields still reject; new reference on every old destination rejects.
- New destination without backend/reference, with content/component/non-currentTab, wrong kind/destination, noncanonical or oversized reference and mixed/contradictory URL payloads reject.
- Actual generic binder rejects before host/source/grant/effect calls; unresolved reference destinations are absent from generic root discovery.
- Metadata queries do not call Core admission/claim/apply, are bounded and preserve stable IDs within the exact publication.
- Missing, foreign backend/scene/window, retired, replaced, filtered, duplicate identity, exhausted page, input/result/filter/backend A→B→A and overflow refuse.
- A valid reference can select only its exact actual fresh-observation hit/page token. Cached reference replay and reentrant duplicate execution do not cause a second effect.
- Original absolute deadline/cancellation/source guard remains across waits; partial/refused/unqualified outcomes remain inspectable after late cancellation or reporting failure.
- Actual system intent and real custom/HTTPS URL selectors will separately verify original row/list/ledger plus exact source/scene/outcome. They remain NOT_RUN until qualified app/SDK/native execution.

## Explicit remaining scope

The first slice continues an existing submitted original Search. Missing/cold-restored catalog, changed query/filter/source, a different selected root/window, or an unavailable original list returns an explicit refusal. Durable private query restoration and a combined new-query-plus-chosen-result route are not supplied by this first slice. Background activation is supported only if the exact original source/window can be retained before the wait and independently validated after it; otherwise it is unavailable, not a different-scene fallback.

All three backends remain subject to their original source/ledger capabilities. No new mode/scope/sort is inferred from continuation support. Opening a selected hit in Reader is distinct from revealing the original Search row. Full focused-row/context VoiceOver, hardware keyboard navigation, production v40, app SDK/native execution and final UI03–07 acceptance remain open.
