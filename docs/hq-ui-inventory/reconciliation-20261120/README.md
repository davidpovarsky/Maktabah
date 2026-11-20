# UI-07 / UI-06 source crosswalk — 20 November 2026

Source: [`0e879ae85c4533a7687095cf640f1dc02baf0e60`](https://github.com/davidpovarsky/Maktabah/tree/0e879ae85c4533a7687095cf640f1dc02baf0e60). Tasks: [UI-07](https://app.asana.com/0/0/1220542416158970), [UI-06](https://app.asana.com/0/0/1220542467495722). This is a docs-only source reconciliation. **No app, Native, real-model, provider or physical-device case was executed in this audit.** The current owner continuation supersedes the historical pause; all technical acceptance gates remain.

## What is now mapped

`CROSSWALK.json` preserves every one of the 294 unique inventory IDs and supplies explicit source dispositions for three backends × five ingress families: **4,410 potential coverage cells**. These are not test executions. Each cell's fresh runtime result is `NOT_RUN_BY_THIS_AUDIT`. Historical receipts remain attached to their original source elsewhere; none was transferred to this source or expanded into these cells.

The generator reads immutable Git blobs at the exact source, the original QA requirements and the current pinned external source objects. All 294 retained source anchors were found, including the pinned Sefaria Mobile and TorahInspectorKit sources. This establishes source presence and location, not target membership, a mounted view, arbitrary control focus, backend readiness or runtime success.

Four separate layers are retained:

| Layer | Actual source finding | Meaning |
|---|---|---|
| Core implemented | `ActionRegistry.implemented` contains **8** of 29 catalog actions | The executor has the action path; authorization, runtime capability and UI completion still apply. |
| Host wired | App Composition installs **10** destination descriptors and connects original Core, Registry and Scene owners | This is a programmatic host surface; it does not automatically become a tool, intent, URL or button. |
| Production consumer exposed | Two routing AppIntent definitions/shortcuts, public-v2 rules for eight descriptors, a bounded Hanlin metadata binding and source-link transition | Scope is derived from the actual entry point, not inventory IDs or metadata. |
| Native executed | **0 fresh executions in this audit** | Parent-owned Apple/Native results require their own exact source and per-case evidence. |

### Counts and historical discrepancies

The `Source/UIRouting/Resources/ui-surface-inventory.v1.json` path suggested during the handoff is absent from this source. The actual inventory is `docs/hq-ui-inventory/continuation-20261118/UI_ROUTE_COVERAGE.json`.

| Preserved artifact/revision | Count |
|---|---:|
| `current/UI01_CURRENT_HANDOFF.json` | 282 |
| `continuation-20261118/RECONCILIATION_REPORT.json` | 282 declared |
| Continuation inventory commit `07b596b87ea84eb0d16f35e1699c7141e8ad46cf`, source `8e35c7d9bebbdd93933686f35b4dead9e3f22994` | 292 actual |
| Later continuation revisions, including `b3871b1ff65baa92c56ca3bd960a53be8c18221e` | 293 actual |
| Current retained continuation inventory, last changed at `2af989c6deeaca9d4fd8609ebd0b2e10aa096400` | 294 actual |

The 294-row inventory consists of 227 retained rows + one visible-cancel row + 54 native-search rows + 12 native-contract rows. The generator retains twelve immutable historical count observations. Neither 282 nor 292 was deleted or relabeled as a current runtime count. The initial machine output was created before the bounded history lookup; it is retained separately under `initial/` and superseded by the final count reconciliation.

## Current route / consumer scope

All paths below are at the frozen source. Full file SHA256 values, current anchor lines, original hashes and current external pins are in `CROSSWALK.json`.

| Semantic surface | Core / installed destination | Actual entry scope and limits |
|---|---|---|
| Library, TOC, History, Search, Annotations roots | `native.library`, `native.reader.toc`, `native.history`, `native.search`, `native.annotations` | Public-v2 and original foreground intent path, conditional on exact mounted owner/backend. Opening a root does not select every child/control. |
| Settings root | `native.settings` / sheet | Root presentation only. No setting change or subsection/control destination follows from this descriptor. |
| Original Reader Inspector | `native.reader.inspector` | Conditional original Reader/selection ownership and visibility; not arbitrary Inspector tab/item focus. |
| Canonical Reader | `reader.open` → `native.reader`, currentTab/newTab | Core resolver, native owner, exact canonical section/focus and actual receipt. Same-tab cross-book restrictions remain; a new tab uses the existing reservation. This does not expose arbitrary pixel/range selectors. |
| Search field | `native.search` + `native.search.query` | The only registered component anchor in this composition. Focus uses the live original field; public input does not carry a private query. |
| Commentary | `reader.openCommentary` → original Reader path | **HOST_API_WIRED_NO_PRODUCTION_CALLER** for the new semantic wrapper. The source-backed resolver and Core/Scene path exist; no new AppIntent, Hanlin tool or production UI control calls this wrapper. |
| Search results | `search.openResults` → `native.search.results` | Same host-only distinction. Original manual search remains its existing flow. The new API's callers are DEBUG acceptance probes. Private query parameters are not public URL state. |
| Unsaved note draft | `notes.prepareDraft` → `native.reader.noteDraft` | Same host-only distinction; original note editor, exact source/presentation ownership, no automatic save. No `notes.saveDraft` implementation is inferred. |
| Remaining controls/items | No exact registered destination mapping | Source may exist and original manual UI may work. The generator does not turn a related Core action into an exact control route or imply absence of the original feature. |

Source owners are `MaktabahNativeRoutingComposition`, `MaktabahNativeSceneSession`, `MaktabahNativeSceneBindings` and `MaktabahNativeSceneProjection`; the final receipt remains owned by `NativeSceneNavigationOrchestrator`. `NativeDestinationIntents` / `NativeReaderIntents` / `MaktabahNativeIntents` establish intent metadata; `MaktabahNativeURLHandler`, `NativePublicNavigationURLV2` and the original WidgetDeepLink path establish URL boundaries. The `catalog-status.json` value `liveDestinations: 0` describes the default fixture-only package catalog; it does not override the app's ten injected descriptors.

The crosswalk maps 24 inventory rows to exact roots or the stated canonical-reader subset, three to the new host-only APIs, two to the delegated legacy URL handler and three to ingress definitions. Other rows retain `NO_EXACT_DESTINATION_MAPPING`. These counts include multiple inventory rows describing the same destination; **27 conditional AppIntent rows do not mean 27 AppIntents**. Three ingress-definition rows are metadata surfaces, not independent UI destinations.

## Hanlin, Guides and security boundaries

The original SDK adapter maps four transport names, but the production binding permits only `system.listBackends`, `catalog.resolveWork` and `catalog.resolveReference`. `search.query` is mapped in the adapter yet intentionally unavailable in that binding. The context currently has `navigation` and `discovery`, with no `contentRead` scope or content-right grant. Core requires both scope and backend rights for risk-tier-1 text access. Adding an advertised name alone would not establish permission.

For UI, the actual Hanlin path identified here is a resolved-source link through the original SDK API 1.2 transition, chat dismissal, Core and the original Reader acknowledgement. It does not expose arbitrary inventory controls or the three new host-only actions. Metadata lookup alone is not a UI route. Real-model interaction and three multi-step journeys remain separate `NOT_RUN` gates. Remote MCP has no paired-active-device execution established by this audit.

No product Guides workflow runner is established in the inspected host composition; all Guide cells remain `NOT_IMPLEMENTED`. The existing Guided Tours research/acceptance work is not reclassified as a running automation feature. No coordinates, selectors, new providers or alternate route pipeline were introduced.

Public URLs preserve the strict existing codecs and cannot supply scopes, grants, private draft/query text or persistent mutations. The legacy numeric history/annotation URLs are delegated to their original handler and are explicitly distinguished from a new Registry receipt. The inspected iOS entitlements contain no Associated Domains; a custom-scheme source path is not Universal Link/AASA acceptance.

## Backend and platform gates

| Backend | Source conditions retained for every mapped cell |
|---|---|
| Otzaria | Exact active generation; actual catalog/reference/local-index availability; current original native owner. |
| Sefaria Legacy | Exact active generation and source-backed references; real search also requires network readiness. |
| Sefaria Embedded | Exact generation and RPC epoch; host/catalog readiness; search readiness and response-fidelity proof. Reset/no-transport and stale epochs cannot become success. |

All ten descriptors declare the three backends, but `BackendSemanticProfile`, Core policy and live scene eligibility determine availability. This crosswalk does not claim all three are available or tested. Inactive backends require an explicit switch outcome; no implicit switch is added.

The current Xcode project declares **iOS deployment target 27.0**. UI-07's iOS 26 acceptance cannot be satisfied by that binary. No target or SDK was downgraded; compatibility requires a separate API audit/build decision. iOS 27, physical iPad, Hebrew RTL, VoiceOver, Dynamic Type, keyboard, responsiveness and memory remain actual execution gates.

## QA handoff and reproduction

The original HQ `requirements.json` was read unchanged: SHA256 `5eb5fbdb55bfded61250b7e8db322d2e488dd277fc60a8077abbc402303816da`, 51 case families, 14 groups, three backends and five ingress families. Its case IDs/titles are preserved in the new report. Its old “inventory not delivered” / “SDK fake shell” prerequisite text remains historical and does not describe the now-integrated source. We did not change or run its checker as if that would execute product cases.

For each claimed future acceptance, attach the actual case and exact source/runtime receipt to the relevant cell and risk dimensions: cold/warm/background/multiwindow, backend/RPC/source revisions, cancellation/deadline/replay, privacy/permission, exact content/focus/selected hit, and accessibility. Root/Inspector presentation does not close settings-subsection, child-node, query-results or component-focus tests. Existing Native scenarios must be reconciled individually; a selected-case count is not full-inventory coverage.

`reconcile_current.py` reads the pinned source and external Git objects, preserves the historical inventory, and writes a new output path. `EXECUTION.json` records the exact executed command, exit 0 and report digest. `CROSSWALK.json` contains every backend/ingress cell, the explicit manually reviewed semantic mappings, 29-action implementation dispositions, ten descriptors and source hashes. `SOURCE_REVIEW.md` records the additional protected-integration seams without changing or enabling them.

Only this new documentation directory changes. There is no product, workflow, provider, Hanlin capability, signing, data or historical-inventory mutation in this branch.
