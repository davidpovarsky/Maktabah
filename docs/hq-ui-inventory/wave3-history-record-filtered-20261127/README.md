# Filtered History record-window metadata

Follow-up to `a1aad59adda0b27f0a2264d507ded9753cecdb1a`. This packet completes the read-only window-metadata gap for the typed record route while preserving the existing generic History root and public URL contracts.

## Exact change

`MaktabahNativeRoutingComposition.intentHistoryRecordWindows()` reads the existing original Registry descriptor, current backend snapshot, current qualified filtered History/Favorites catalog, and actual mounted scene/session/binding identities. It advertises no window for an empty/foreign catalog or unavailable original owner. It rechecks the backend and catalog before returning.

Only the two History-record call sites use this method: the record service's window provider and the private typed record execution's fresh window equality check. The generic `intentRootEntities()` method remains byte-for-byte unchanged. There is no new context, grant, public schema field, fallback or record identity supplied by this metadata helper.

The existing History record binding now includes the original `iOSTab.history.isAvailable(for: BackendCoordinator.shared.activeCapabilities)` predicate. Original Settings/modal/owner/publication restrictions remain. The original retained one-shot History query/model observation, qualified-store publication token, full record locator, exact scene/backend, and actual native row witness remain required through completion. A fresh metadata result does not revive a revoked source.

## Actual source controls

| Run | Result | Meaning |
| --- | --- | --- |
| Replay the actual original generic metadata provider for the new filtered-window case | 1 method, 3 expected assertion failures, exit 1 | Nonempty query yielded no window, scene or History destination |
| Candidate metadata provider | 10 methods, 0 failures, exit 0 | Read-only filtered metadata and existing retained card/row/source constraints over declared boundaries |
| Four changed Swift files, iOS 27 frontend syntax | 4 parses passed | Syntax only, not Apple SDK typing |
| Two additive system-intent selectors | NOT_RUN | Requires integrated qualified app and native runtime |

The original portable Core/UIRouting/Host packages compile in the same previously verified private cache. The metadata source methods, generic root method, binding source, parent/counters, original publication and geometry methods are verbatim source extractions. Scene/window registrations, UIKit/SwiftUI/Combine, domain models and the Core-lifetime callback are explicit test boundaries. Record hashing is the same explicitly declared deterministic boundary as the previous binding capsule. No actual Core authorization, Apple AppIntents delivery, UIKit layout or application receipt is claimed.

The baseline is an exact old-provider replay within this source capsule, not a run of the entire old application. Candidate and baseline test bodies are identical for that case. Original 27 binding test bodies were compiled unchanged as shared fixture context; only the new ten-method class was executed in the candidate phase. Historical 12/27 results remain in the prior packet and are not relabeled as new runs.

The ten controls cover filtered metadata with the generic contract intact; cold original parent/card proof; warm Favorite proof; an empty filtered catalog; retained and completed query ABA; dictionary/session/binding scene mismatch and missing owners; background identity versus foreground execution and real blockers; original descriptor/backend/presentation requirements; stale actor/backend publications; and final query/backend change during metadata construction.

Actual runtime: baseline 2026-11-27 09:49:41–09:49:59 UTC; candidate 09:49:59–09:50:11 UTC. The baseline raw SHA-256 is `9a918a38bcb6deb0e75f4933cc4570335711f9657c883f7042345205624e98c1`; candidate raw SHA-256 is `099fd97c8c6087af632805d649af5a1a5007d209da61c21da6241552dc1b857d`. Raw logs, exact input closures and both generated source variants remain under `evidence/`.

## Additive native cases

The whole 212,559-byte previous NativeRouting test file remains a byte-exact prefix (SHA-256 `67b579969c146eb6fd01e6d0c00a8e982cc5bea2ee3351ac12b932bbaed16bac`). The whole 2,255-byte previous six-selector file also remains a byte-exact prefix (SHA-256 `28f965184793c4f82c41063637b2e1b91d7c21489b7c32c69b275e97e393df90`).

Only these two selectors are added:

- `NativeHistoryRecordAcceptanceTests/testFilteredHistoryRecordFromLibraryPreservesOriginalQueryAndExactCard`
- `NativeHistoryRecordPhoneAcceptanceTests/testPhoneFilteredFavoriteRecordFromBackgroundPreservesOriginalQueryAndExactCard`

They query and cache a genuine original window before filtering through the actual History search field. Generic History entity discovery must then remain empty. The real typed system intent must resolve the window afresh through the record-specific provider, preserving the original query and revealing the actual independently identified original card. A strict canonical receipt and exact request/scene/item record receipt, unchanged source/workspace/selected Reader documents/PID, and two seconds of actual query/card/frame stability are required.

The iPad case begins the record invocation from Library; the iPhone Favorite case returns from background with the original filtered History already selected. The original query-result identifier caveat remains: the record query requires one result and execution uses the independently derived reference. Native search-field exposure, keyboard submission/dismissal, post-ACK RTL alignment, cold/warm parent publication, foregrounding and AppIntents SDK typing remain runtime requirements. These selectors have not run.

## Integration and remaining work

No PBX or localization edit is needed beyond the prior packet's two app-file registrations and eight strings. No new product file or native test file is introduced. Session, Projection, generic root discovery, public schemas, original six record selectors and all preexisting test bytes remain unchanged.

This closes the implementation of the read-only filtered-record metadata provider, not native acceptance. Remembered-position canonical `reader.open`, Saved Results folders/queries/records, explicit legacy/ambiguous-record limitations, broader accessibility/keyboard/window/RTL behavior and final production gates remain open. The original 294/51 audit is unchanged. Source controls do not close Native116, Release114+2, physical QA or distribution gates.

`SOURCE_INPUTS.json` binds the four changed files and both old prefixes. `EVIDENCE_MANIFEST.json` binds every stored artifact and losslessly compressed raw input. `BUILD_ARTIFACTS.json` identifies the preserved candidate products and exact package-source closure; no older result is claimed for the new code.
