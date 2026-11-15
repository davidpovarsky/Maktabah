# Public read/navigation v2 — shared contract for manager + N

P owner: primary `01a1df8a-23b0-77a0-bd90-c1dbfac06c2a`, worktree `C:/Users/DAVID/Code/Maktabah-hq-actions-core-20261115`, branch `codex/otzaria-ui-registry-20261115`, base `945b483f0b01fe6722c0bd0dd864d8fe249cd973`.

This is an additive future surface contract. It does not activate a native URL handler, register installed app destinations, publish a URL or expand N's current History-v1/Settings-intent tranche. All new live registrations in the tests are explicitly synthetic; the shipped default registry remains empty.

## Explicit public shape and opt-in

`PublicNavigationSpecV2: Codable, Sendable, Equatable` has only `version=2`, `destination`, optional qualified `backend`/`content`, `presentation` and optional static `component`. Its presentation enum is currentTab/newTab/sheet/inspector. `content` reuses Core's public canonical reader-destination/ref schema with no catalog/data revisions. `component` is one exact semantic UIDestinationID, not a FocusSpec/range/selector or a dynamic row/session identity.

Example, navigation to a named control (show/focus only, never activate/change its value):

```json
{"version":2,"destination":"test.settings","presentation":"sheet","component":"test.settings.fontSize"}
```

The two golden files are `public-settings-v2.json` and `public-inspector-v2.json` under the existing test Fixtures directory. They are synthetic examples, not app capabilities.

There is no requestId, scene/tab/workspace/profile/session ID, expected snapshot/generation/epoch, whole RouteSpec/UIStateSpec, selected item, draft/note/selected/search text, arbitrary parameter dictionary, control value, selector/class/JS/RPC method or path. Unknown fields are refused, not ignored. Focus is limited to revealing/focusing the named static component; setting values, activating controls, saving notes/preferences, updating packages or other persistent mutations cannot be represented. A native GET handler must not turn component focus into activation or persistence; actual before/after control/data acceptance remains N's responsibility.

The existing `UIDestinationDescriptor` gains optional `publicNavigationV2: UIPublicNavigationPolicyV2? = nil`. It is INDEPENDENT of `allowsPublicRoute`, which keeps its frozen v1 meaning. Thus future Settings may opt into v2 without enabling its currently refused v1 URL. Existing descriptor JSON without this optional field decodes normally; encoding nil adds no field.

A policy contains at most4 unique presentation rules. Each rule explicitly declares `allowsRoot` and up to16 exact components drawn from the descriptor's registered static anchors. Empty/duplicate rules, unknown components, unsupported presentation, fixture/inventory stages, mutations and non-navigation semantic action requirements are rejected. Only implemented risk2 read/navigation surfaces with `requiredCoreActions=[]` (no required content) or exactly `["reader.open"]` (required content) can opt in. The registry caps the TOTAL v2 combinations (including roots/components) at128; it fails closed rather than silently truncating.

## Codec/schema/version boundaries

- `UIRouteSchemas.publicNavigationV2() throws -> ActionJSON` projects a strict closed schema using the same Core ref definitions. It does not duplicate the parser/identity/permissions.
- `UIRouteCodec.decodePublicV2(_:registry:) throws -> PublicNavigationSpecV2` uses the sole bounded Core original-byte parser, then the v2 schema, typed refs and exact registry policy. Input cap4096 bytes; duplicate/escaped duplicate keys, fractional versions, malformed/unknown versions and unsupported combinations fail closed.
- `encodePublicV2(_:registry:) throws -> Data` takes only an explicit public DTO, validates via the same codec and checks the normalized output cap as well. It never projects private state or grants publication/shareability permission.
- `migratePublicV1ToV2(_:registry:) throws -> PublicNavigationSpecV2` explicitly validates v1 first, then requires independent v2 opt-in and equivalent allowed presentation/root. It drops the old wire request UUID because v2 imports a reusable intent; a new local correlation is issued at execution. It never guesses a component or copies private state.

Existing `decodePublic`/`encodePublic` and their v1 DTO/schema retain version1 and currentTab/newTab only. They reject v2. V2 rejects v1 unless the caller expressly invokes migration; private v0/v1 migrations and legacy URL handling stay unchanged. There is no fallback parser or implicit version promotion. All untrusted bytes MUST use the strict matching codec, not a permissive direct JSONDecoder followed by binding.

V2 additionally refuses private revisions, path/control/URI-like strings in its public references; arbitrary precision or original numeric provenance is not inferred. These stricter v2 privacy filters do not change frozen v1 acceptance. A structurally valid opaque ref is still not proof it exists, is licensed/shareable or is accessible to a caller; the canonical resolver and actual trusted host/corpus checks remain mandatory.

## Truthful live variants

`UIPublicNavigationEligibilityPort: UIDestinationEligibilityPort` requires BOTH methods, with no broad-descriptor/default fallback:

```swift
func assessPublicVariant(_ variant: UIPublicNavigationVariantV2,
    scene: UISceneSnapshot, context: ActionExecutionContext,
    invocation: ActionPortInvocation) async throws -> UIRouteEligibility
func assessPublicNavigation(_ intent: PublicNavigationSpecV2,
    scene: UISceneSnapshot, context: ActionExecutionContext,
    invocation: ActionPortInvocation) async throws -> UIRouteEligibility
```

The first checks an exact registered presentation/component combination for live installed host support/readiness/permission. The second checks the actual imported request, including real content/corpus/shareability/rights and native lifetime. They supplement canonical Core policy, not replace it. A static registration cannot fabricate either assessment; an available descriptor is not proof every presentation/anchor works.

`UIDestinationRegistry.discoverPublicV2(scene:context:invocation:core:host:clock:)` returns only exact `UIPublicNavigationVariantV2` values that passed canonical discovery/navigation permission, normal semantic availability and the exact host check under fresh scene/backend authority. Generic `discover` strips the v2 opt-in rules from returned rows instead of advertising unassessed public combinations. Trusted `descriptor(for:)` remains a static declaration lookup, not an availability/grant API. Default/unregistered/fixture destinations cannot become live variants.

All waits stay inside the original cooperative deadline scope, with mandatory exact-scene/SAME-Core authority rechecks and cleanup. Context/generation/epoch changes, deadline/cancellation and stale echoed assessments do not yield successful bindings. This retains DISC01/02's cooperative limitation: no hard interruption or new executor/admission bound is claimed. N owns finite admission and real native observer cleanup.

## Bind only at actual local execution

`bindPublicV2(_:scene:localTabID:context:invocation:core:host:clock:) async throws -> UIPublicNavigationPlanV2` validates the explicit public intent, exact host variant and fresh native/Core authority, then binds a newly host-issued local request UUID, selected authorized scene/revision, actual backend snapshot and (for content) locally prepared tab. A link cannot supply these fields. Backend nil uses the actual local backend; an explicit different backend returns requiresBackendSwitch without switching/substituting. A missing native tab for content fails unprepared; no invented ID or global/first-scene fallback exists.

The non-Codable plan distinguishes:

1. `.surface(UIAuthorizedSceneCommand)` for genuinely UI-only navigation. Call its one-use synchronous `authorizeCommit(current:)` immediately before the exact native mutation, with no await; after actual observation/layout waits call `validateCompletion(receipt:observed:)`. The URL did not mint the preparation, and parsing/binding alone invokes no control/value/persistence mutation.
2. `.reader(UIValidatedRoute)` is ONLY a structural route, not a content grant. Execute canonical Core reader.open with its fresh local request UUID and qualified destination. In the actual Core-delivered sink, construct UISceneCommand from this retained route plus Core's ACTUAL reader invocation/deadline and a fresh local scene. Then use `prepareNavigation(readerCommand:)`, the synchronous guard and full observed completion/receipt checks. The binding-time invocation must NOT be mistaken for the independently issued Core reader invocation. Route expectations still reject a changed scene/backend/tab; no semantic resolver/sink/receipt step is bypassed. N keeps the context admitted through the full Core result and carries the remaining overall task budget into that execution.

N must validate actual workspace/item/control existence and content rights, not derive authority from DTOs or availability metadata. Publishers need separate actual shareability approval before exposing even a structurally public reference. Failure after an effect remains uncertain/noncompleted, never automatic rollback/retry. Cross-actor atomicity, actual native support and persistence-free native callbacks are not proved by portable fixtures.

## Safe cases and refusals tested

| Case | Portable expectation |
| --- | --- |
| Explicit settings sheet + registered font/appearance component | Valid public intent; fresh guarded UI-only local plan; no setter invoked during binding |
| Reader inspector + registered links component, all3 backends | Public refs preserved; structural reader plan; actual Core resolver/sink/receipt path required |
| Content current/newTab/sheet/inspector | Only exact rule + Core-compatible presentation mode accepted |
| History v1 root to independently opted-in v2 root | Explicit migration preserves navigation, drops wire correlation |
| Settings v1 when only v2 opted in | Still refused; no widening of current v1 handling |
| Unknown/mismatched presentation/component, missing required sheet component | Refused; no guessed/fallback target |
| Host unsupported/unready/denied or different active backend | Structured non-success; no fake supported variant/backend switch |
| Private state/IDs/text, value/setter, context/authority, selectors/JS/paths | Closed schema/registry refusal |
| Duplicate/escaped duplicate, fractional/malformed/future version, oversize | Single-parser bounded rejection |
| Revocation, generation drift, deadline/cancel across bind AND variant-discovery waits | Refused with cooperative continuation cleanup before finite safety release |
| Missing local tab or host-denied content rights | No prepared reader plan or resolver/effect invocation |

Ownership: only downstream UIRouting contracts/codecs/registry, tests/fixtures and docs. Core/Resolver/Bridge/Reader/upstream/project/manifest/workflow/release-gate files are unchanged from945b483f. Existing Core frozen resources and old v1/legacy goldens remain unchanged. Exact executed test counts, source/Git/fixture/log hashes and retained failed compile attempt are in `results/public-v2-summary.json`. Apple/native/physical/current app URL support is NOT_RUN by P; manager/N review and real read-only host acceptance remain open.

## Executed verification and exact source packet

Final strict Swift6.3.3 Windows run of the complete affected UIRouting package: **72 distinct XCTest methods / 0 failures / 0 compiler warnings**, including **14 new public-v2 methods**, old codec/golden/private-v0/v1 tests,19 DISC methods,20 navigation-authority methods (including the final-await race) and5 scene/receipt methods. These are portable synthetic-authority/host cases, not native UI. The old v1 public schema method body and original3 golden Git blobs were verified unchanged; all Core package inputs match945b483f.

All3 backends x4 public presentation forms round-trip; guarded UI-only binding and canonical actual Core reader sink execution run for all3 synthetic backends. Both public bind and exact variant-discovery awaits are tested for context/rights/generation revocation, deadline and caller cancellation with finite cleanup gates. Initial v2 compile hit a contextual type-inference error and executed0tests; that log is retained. Intermediate47/0 and earlier72/0 runs are not added to the final72. Final raw log and exact50 package input working SHA256/Git blobs, old fixture identities and all retained log hashes: `results/public-v2-summary.json`, `results/public-v2-final.log`.

No app target, current N handler, S/I/R source, Core package, deployment/signing or workflow/gate is edited. This packet is ready for manager/N contract review; actual v2 public read-only surfaces, real URL import/publishing, Apple compiler/runtime and physical acceptance remain NOT_RUN/open.

## Separate post-packet budget follow-up

The original 72-method packet and its hashes above remain immutable. [PUBLIC_V2_BUDGET_FOLLOWUP_20261115.md](PUBLIC_V2_BUDGET_FOLLOWUP_20261115.md) records a reproduced decode/encode byte-budget mismatch and the v2-only normalized-output check. Its final 75-method run also verifies canonical denied-work enforcement and stale retained reader-plan rejection at the actual Core sink. No new native/public-v2 handler is activated.
