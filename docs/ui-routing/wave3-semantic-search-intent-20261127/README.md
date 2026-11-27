# Semantic Search system intent — source packet

This packet adds a foreground ShowSearchResultsIntent to the existing local App Intents package and a fixed app shortcut. It sends the exact phrase, optional qualified Otzaria book filters, supported mode/sort and explicitly chosen original window into the existing search.openResults Core action. It does not implement selected-hit or cursor/paging navigation.

## Source and ownership

Base commit: 1a4d64dca46b61ea3d9dbcab5d152dc618f2be39.

The new portable service and iOS metadata adapter live in the existing ChavrusaUIRoutingHost package. They reuse NativeReaderIntentService for original Core catalog metadata and its strict, canonical work identifiers. The app composition has two scoped edits: dependency registration after the existing reader service, and factoring its original search entry so the system caller supplies .appIntent, one request ID and the exact selected scene. The app-bundle shortcut file adds one entry; both existing shortcuts remain verbatim.

The original foreground preflight runs before a Core grant exists. It retains the exact original registration across the bounded mount wait and rejects another/replaced scene or backend snapshot. Once foreground is ready, the existing original source observation, pending search owner, resolver, Core admission, native query submission and visible receipt are used unchanged. A final original validateSearchResultsCompletion occurs while the same retained binding remains alive. No second provider, search model, scene chooser, permission store or synthetic UI receipt is introduced.

PROVENANCE.json records upstream 4203de5fd77beb119e5826e039be1a61325f7be0, the original source owners, allowed hunks and unchanged gates. The composition/intent files are downstream integration paths absent from that live upstream tree. No upstream pin, original package contract, original selector/assertion, owner signature, library engine or data is changed.

## Supported semantics

| Original backend | Phrase/match | Book filters | Sort |
|---|---|---|---|
| Otzaria | Phrase, exact, distance 0 | Canonical current-backend work entities without unsupported catalog revision; original Core resolves each again | Relevance or canonical book order |
| Legacy Sefaria | Phrase, exact, distance 0 | Original native results UI rejects supplied work scopes | Relevance, canonical or chronological, as the original contract permits |
| Sefaria Embedded | Phrase, exact, distance 0 | Original native results UI rejects supplied work scopes | Relevance only; original snapshot retains RPC epoch |

The system enum advertises only the common exact-phrase mode. Unsupported mode, match, distance, scope revision and sort combinations fail explicitly through the original query contract. Any selected-hit or cursor argument, including an empty value, is rejected before native navigation. These requirements remain open; see RESULT_SELECTION_AND_PAGING_PROPOSAL.md.

The required window parameter is resolved from the original mounted native.search metadata. No default/first window or backend switch is chosen. Optional book entities are discoverable only for the supported original Otzaria scope. Metadata queries do not navigate or submit searches.

Query UTF-8 bytes are retained through the adapter and original Core query projection. Nothing adds private query text to URLs or diagnostic logs. The original engine keeps its own existing text processing.

## Completion and refusal

A successful system return requires the same Core request/action/backend/generation, the original completed search effect and the actual matching native results receipt for the selected scene, with an advanced scene revision. A queued request, foreground request, refusal, cancellation, stale snapshot, missing receipt or mismatched route cannot become success.

NativeSearchIntentService.Failure retains the actual original ActionResult and any observed native receipt, including uncertain effects after cancellation or failed final verification. It does not relabel those effects as completed. The original source owner still performs authoritative visibility and query-completion checks; the service validates their returned projection.

## Verification

- **68/68 source tests passed** on Swift 6.4.3/Linux: 23 new Search service tests and 45 existing feature/destination/reader intent tests.
- The original Core, UIRouting and portable Host package targets actually compiled. The test transports are explicitly injected catalog/native doubles; this is not an original UIKit or live-provider acceptance result.
- The run finished at 2026-11-27T07:31:51.799297+00:00, exit 0, input inventory unchanged during execution. Compiler log reports 44.57 seconds.
- Minimum observed Oracle free space was 409,190,400 bytes, above the 256 MiB reserve.
- **Three Apple-target syntax parses passed** for the new iOS intent adapter, changed composition and new shortcut entry. Parsing does not typecheck Apple SDK APIs or extract App Intents metadata.
- The shortcut entry was added after the portable run under a separate root lease. It is outside the portable package target. PORTABLE_INPUT_CLOSURE.json independently verifies all actual package source/test/resource inputs stayed byte-identical; its separate syntax receipt binds the new shortcut.
- Historical 35-test evidence and 30 retained product files (49,175,365 bytes) were preserved and byte-verified before the existing SwiftPM cache was reused. PRESERVATION.json records the exact paths/hashes. No historical result was retagged.
- No Mac SDK/app build, simulator run, device test, runtime search or Siri invocation occurred for this packet.

Do not add these 68 source tests to Native116 or Release114+2.

## Integration and remaining acceptance

The new files are automatically members of the existing local Swift package target. No new PBX source registration is needed for them. The existing app-bundle AppIntentsPackage includes that package; MaktabahNativeIntents.swift adds the fixed phrase that lets the system collect the required query and window.

Root must integrate the independently owned RN/record composition hunks, regenerate original source admission and owner verification for the final source, add/reconcile the exact English/Hebrew strings in LOCALIZATION_ADDITIONS.json, and use the original Apple app build to validate metadata extraction. The final original iPad/iPhone cold/warm, selected-window, unsupported backend/scope/sort, cancellation and actual Shortcuts/Siri journeys remain **NOT_RUN**. Query field routing is owned by the separate original Search component packet; this intent submits actual results and must not be counted as selected-hit/paging completion.

Original requirements: [UI-03](https://app.asana.com/0/1219602719070493/1220542361203468), [UI-04](https://app.asana.com/0/1219602719070493/1220542420331748), [UI-05](https://app.asana.com/0/1219602719070493/1220542420330496), [UI-06](https://app.asana.com/0/1219602719070493/1220542467495722), [UI-07](https://app.asana.com/0/1219602719070493/1220542416158970).

API design references checked against primary Apple documentation: [Adding parameters to an app intent](https://developer.apple.com/documentation/appintents/adding-parameters-to-an-app-intent), [App entity parameters](https://developer.apple.com/documentation/appintents/intentparameter-app-entity). Required window/query parameters, optional compatible entity collections, finite AppEnum values, foreground execution and shared process dependencies follow the existing package pattern. Apple SDK compilation remains the actual compatibility gate.
