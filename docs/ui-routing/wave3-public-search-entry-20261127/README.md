# Public references to the original live Search

## Delivery and exact scope

Source commit: `310db9a9a887b604f422581765feb902465fef99`.
Source base: `24cd9291dbc87d799c22a41f0bc73a82c6415bfa`.
Branch: `codex/otzaria-wave3-public-search-entry-20261127`.

This packet adds typed public metadata for a loaded result and the original next page of an already submitted Search. It uses two finite destinations, `native.search.result` and `native.search.nextPage`, and the existing version-2 URL namespace. A canonical 36-character UUID in `searchReference` identifies a current catalog entry. It contains no query, scene UUID, original operation token, cursor, offset, authorization, or executable closure.

The public reference is untrusted. The native scene must find that exact entry in its existing catalog, retain the original source and window before the first await, then join the chosen record to one fresh original Search observation under the original Core preparation. Only the actual original hit/page token from that observation can reach the original executor. The original five-second request, authority, source claim, page ledger and visible-view completion remain required.

The ten-file source commit contains the portable policy/service, new App Intents, the downstream catalog, metadata reads in the existing downstream binding, and two new XCTest files. Root-owned Composition, Session and URL-handler changes are **proposals** in this documentation packet. They must be reviewed and applied with the integration agent's other changes. Until those proposals and target/resource registrations are integrated, this source commit alone is not a functioning app entry.

## Original acceptance clauses

The contract records the exact source tasks and clauses:

- UI-02 `1220542479938476`: bounded, typed, versioned contracts and discovery.
- UI-03 `1220542361203468`, G2 item 3: global Search query/filter/selected hit and the actual original visible target.
- UI-04 `1220542420331748`, G3: semantic `ShowSearchResults(query/scope/mode/result)`, live entities, actual window ownership and stale/cancellation refusal.
- UI-05 `1220542420330496`, G3: public Search filters/selected hit, privacy and strict malformed/stale/replay handling.
- UI-07 `1220542416158970`, G5: real hit/page behavior across ingress, original backends and native accessibility/layout acceptance.

This is a bounded part of those requirements. It does not close all UI-03–07 or the historical 294-row inventory. The applicable owner platform requirement remains iOS/iPadOS 27 only.

## Source ownership and preserved behavior

`PROVENANCE.json` pins actual upstream HEAD/main `4203de5fd77beb119e5826e039be1a61325f7be0`, observed with `git ls-remote`, and merge base `a0ed0df908a6cb38bc459d4baaeb400f447b2fc4`. None of the ten affected paths is tracked in that upstream tree. Their existing lineage is downstream Swift routing/integration code; no original Search view, engine, index, request controller, result model, provider or upstream UI file changes in this source commit.

The existing `PublicNavigationV2Codec` is byte-identical. Old destinations reject `searchReference`; content and component fields cannot be mixed with the new operation. Both generic discovery and generic `RouteSpec`/public binding refuse an unresolved reference destination. A generic Search-root receipt cannot complete a selected result/page request. V1, existing widgets, original first-page query/service/intents, action permission limits and Core source are unchanged.

The existing downstream Search binding adds read-only metadata capture. Its execution `readStamp` retains the original strict default; only explicitly requested metadata capture can inspect the same attached original list while its app is backgrounded. Original foreground/visible geometry remains mandatory at execution. Metadata reads do not call `claims.observe`, prepare Core, submit a query, select a row or request a page.

The catalog keeps bounded metadata, weak original source owners and one-shot source observations. A retained entry is consumed before callbacks. Reentrant selection, changed source, replacement, detachment, cancellation or expiry cannot rearm it. A completed page is allowed to change its own result rows, while the original query, configuration, model, scene, window, backend and foreign state stay bound. Public metadata never substitutes for the original executor's fresh validation.

## Actual validation

| Scope | Actual result | Evidence |
|---|---:|---|
| Candidate UIRouting and actual Host service compilation against current original Core | PASS | Portable attempt 1, compile exits 0 |
| Unmodified original PublicV2 XCTest bodies | 17 PASS | Portable attempt 2 |
| New strict schema/registry XCTest methods | 8 PASS | Portable attempt 2 |
| New actual-service XCTest methods, explicit synthetic native callback boundary | 15 PASS | Portable attempt 2 |
| Actual catalog policy, verbatim Metadata lifecycle and original Observation latch; explicit UI/window/provider substitute | 19 PASS | Catalog attempt 1 |
| Counterfactual removing only required-reference generic guards | 8 tests, 27 expected assertion failures | Portable attempt 4; never product source |
| All ten product/test files with iOS-27 branches selected | Frontend syntax exit 0 | `syntax/RESULT.json`; Linux Swift parser only |
| AppIntents metadata, actual Apple SDK/app compilation | NOT_RUN | Required integrated gate |
| Actual Intent/Shortcuts/Siri/custom URL/HTTPS delivery and UIKit behavior | NOT_RUN | Separate append-only native proposals follow |
| Production-v40/device/physical acceptance | NOT_RUN | Not established by these controls |

The portable run reuses the integration owner's read-only original Core module/library. All 31 Core source files were byte-joined to the base Git commit. The only additional compiled source in those Core products is the original generated resource-bundle accessor. The new candidate UIRouting and Host services were actually compiled; historic Core results were not relabelled as new tests. Original resources were verified when copied next to the new executable. `CORE_REUSE_PROVENANCE.json` and the raw result manifests preserve the exact closure.

The catalog harness compiles the actual general catalog bodies and exact `Metadata` implementation. It omits only the iOS conditional wrapper and app-specific `captureOriginal` factory, and supplies an explicitly named original-UI boundary. A single test-only same-file accessor sets the revision at its overflow boundary. This is not an app, provider, UIKit, native-window, or source-factory runtime test.

All initial failures are retained. Portable attempt 1 failed the test compile because two original helper files were missing from the runner's input list; adding those files, without editing any original test body or product source, produced attempt 2's 40/0. The first counterfactual attempt was interrupted by the connector's 25-second task ceiling after two successful product compile phases; its incomplete result is preserved, not converted into a successful compile or test. Attempt 4 reused only its verified completed module phases, recompiled the tests with a sufficient task ceiling, and recorded the expected failures. The raw failed push and absent-ref readback are also retained. The first documentation diff check flagged required blank context lines in textual unified patches; its raw failure is retained, and those exact patch bytes are now stored losslessly as gzip rather than rewritten.

`EVIDENCE_INDEX.json` describes five lossless JSON/gzip capsules. Every capsule includes exact input bodies, commands, raw stdout/stderr, source/product pins and result data. `ARTIFACTS.json` binds the delivered documentation files. No binary, cache or prior result was discarded.

## Root integration contract

`root-proposals/INPUTS.json` pins each base and candidate. The three exact patches are stored as lossless .patch.gz files (decompress before review/application) and are scoped to:

1. The exact scene's metadata catalog and retained selection, plus synchronous original source/window/Notes invalidation.
2. Two reference-required descriptors, service dependency registration and typed original Search continuation entry. The existing in-app continuation delegates to the same retained original executor body; public entry retains metadata before foreground activation and keeps the same absolute deadline.
3. The existing URL handler. It recognizes the two finite paths before decoding; recognized malformed references fail and cannot fall back to a generic root route. Unrelated old paths remain in the existing handler.

The root must keep the proposal's actual `Execution(command,outcome)` through reporting failures. A partial, refused or unqualified original return stays inspectable; no success is reconstructed from an unrelated receipt. Metadata is not promoted to an authority merely because a URL decodes.

`REGISTRATION_AND_LOCALIZATION.json` specifies one new app Sources member, package auto-membership, fifteen English/Hebrew catalog entries and two AppShortcut additions (six existing entries become eight). The shortcut patch preserves all six original entries. Catalog order and prior translations must be preserved during root integration. No PBX, catalog or shortcut product file is changed by this source commit.

## Independent review and current limits

Navigation's independent read covered the finite portable policy and generic isolation, then the actual Catalog/Metadata/service lifetime chain. It found no demonstrated blocker in those reviewed source seams. Its review was read-only and did not run tests or review root's forthcoming integrated scene/URL wiring. The final catalog adds explicit nested MainActor annotations and uses the original Foundation localization API; those exact final bytes are bound to the 19-case run.

Still open:

- Cold/restored/missing-source reference behavior is intentionally a truthful refusal. A new query plus selected result, cross-root original Search restoration and persistent public result references require their own original-source contract.
- Revealing a loaded hit does not open Reader at a remembered position. That is a separate canonical Reader operation.
- Actual app/Apple compilation, system metadata extraction, original global-window activation, real source-factory observation and UIKit completion need the integrated candidate.
- Native AppIntent and actual URL/Universal Link selectors must exercise these production callers, not the previous DEBUG probe. New proposal helpers will preserve the exact existing native-test prefix.
- All original backend, production, accessibility, keyboard, resize, window and restoration criteria remain independently required. Existing VoiceOver speech checks prove title/snippet reachability only; unique expanded-row/full-context traversal remains open.

No final UI, ownership, release, TestFlight or physical acceptance is claimed here.
