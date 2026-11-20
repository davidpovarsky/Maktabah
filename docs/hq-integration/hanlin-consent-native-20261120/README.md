# Native Hanlin current-work consent repair

## Outcome and scope

This isolated repair makes a source-verified current Otzaria work available to the existing **default-OFF** consent control even when the original Reader loads a containing reading unit for a requested line. It also adds the existing scene-owned Study chat button to the compact Reader toolbar. The original SDK, saved conversation store, model connection, draft, one-use dismissal/consent owner and Core search permission implementation are unchanged.

Source base: c61213d9fcc8b80a8606ba00a1562215312ca2ed. The source comparison against the failed Native app 461de9aaee620d4275a1676ce8e1c230eb8e27ad found no changes in the five Hanlin consumer/transport files, the Hanlin Native tests, the original global toolbar or the reader launch toolbar. Relevant Composition changes in between belong to other integrations.

**27 source-method controls actually executed:** baseline 15 passed / 12 failed; candidate 27 passed / 0 failed. Both compiled with Swift 6.3.3, strict concurrency, zero compiler warnings. This fixture executes the original Foundation models, resolver, load coordinator and native projection methods with explicit UI/manager/Action DTO boundaries. It is not an app build, Core permission run, native UI run, provider request or physical-device acceptance.

The two original Native consent cases remain **NOT_RUN on this repair**. No source method or declaration is counted as a Native pass. Apple typechecking of the changed full app/test files is pending.

## Authentic failure evidence

Repair12 run [44673191816](https://github.com/davidpovarsky/Maktabah/actions/runs/44673191816), checkout 6030087e, app source 461de9aaee620d4275a1676ce8e1c230eb8e27ad:

- iPad actually opened the original chat. The AX hierarchy and screenshot show its original connection form and the explicit message “Search access is unavailable for the current source.” The offer was nil; the missing Toggle was not merely below the viewport.
- iPhone failed before opening a chat. Its actual hierarchy shows the pushed original Reader, Library back button and bottom native overflow, with no global-launch control. That launch button belonged to the Library root; the original compact Reader contained no Hanlin launch.

All four selected AX/PNG artifacts are already durable in e5dd2004203cf20033b24ebe5bf31ef10022a55d under ../native-repair12-44673191816-20261120/captures/entries/. This repair references their exact hashes and does not duplicate the images. The original case logs and source-method RED are preserved separately.

The original resolver preserves requested Otzaria line 523 as the requested section/focus. The original backend maps the containing unit to its first source line, 522; Reader+Content publishes that actual section while retaining the original request. Native SceneProjection.surface(.reader) intentionally requires exact requested/loaded section equality. Hanlin had reused that stricter route-receipt projection as the sole source of a work consent offer. The exact-source reproduction demonstrates its nil result for the 523→522 case. The historical iPad log does not identify which individual offer guard returned nil, so this is a proven source defect consistent with the captured state, not an assertion that an unlogged historical branch was observed.

## Changes and authority

1. ReaderContentLoadCoordinator exposes its existing immutable request token through a locked read-only getter. The existing UUID and generation, begin/invalidate behavior and lock remain original.
2. SceneProjection has a separate HanlinCurrentWorkReadSource observation. It requires the unique active original Reader, current loaded state, matching original book/backend/work/request token, actual section and original render text, and source-qualified requested/focus segments. A containing-unit mismatch is accepted only for an Otzaria line actually present in the original source and render mapping.
3. The observation retains both requested and loaded destinations, Reader object identity and the original request token. A same-work A→B→A reload has a different original token and cannot equal the captured source observation. The existing Hanlin registration recheck therefore rejects stale source before returning a result; the original consent witness still owns one-use consumption.
4. SceneSession forwards this read-only observation. Composition includes it in the existing source equality and derives the offer only when the native mapping's owner, book, work and active tab agree.
5. The original compact Reader toolbar composes OtzariaHanlinChatLaunchButton, using the same scene owner as iPad. There is no alternative chat, store, action executor, route or transport.
6. The same two Native tests use the actual reader button, or the uniquely observed native top-toolbar overflow followed by the exact original Study chat action. Their original default-OFF, grant/revoke, actual dismissal, saved conversation UUID, draft, connection, Reader locator/text and workspace assertions remain unchanged. They never invoke Send.

The strict native surface()/ACK projection is byte-identical. The metadata/navigation readerContent and existing three metadata reads are unchanged. Source matching never grants content rights: only the original explicit user consent action can issue the existing one-work search context. Unknown/mismatched sources remain unavailable.

## Executed verification

| Attempt | Actual execution | Result |
|---|---|---|
| baseline-attempt01, exact c612 | Compile 13.187s; 27 controls; runtime 0.078s | Compile exit0, zero warnings; 15 PASS / 12 FAIL; runtime exit1 |
| candidate-attempt01, source hashes in RESULT | Compile 10.890s; same 27 controls; runtime 0.063s | Compile exit0, zero warnings; 27 PASS / 0 FAIL; runtime exit0 |
| Source inverse | Six changed files; exact removal/reversal of only declared additions | Restores canonical c612 bytes for all six |
| Original source preservation | Five Hanlin files, Reader+Content, resolver and Library models | Canonical bytes unchanged; SDK gitlink e00498e33f106cc43be0476ffa2e09329c8ca300 |

The baseline's additional rejection failures are source-method controls using explicit boundary inputs. They do not demonstrate an unauthorized end-to-end Core grant in the old application. The fixture does not execute SDK registration, native mapping admission or a model.

The candidate native source method is extracted unchanged; native surface() has SHA256 cdce552f42215dd6749410b0fc8fcc74899ab25ecb30ef8bbd261d803aba5cde in both runs. Candidate executable SHA256: 349a625d333f1b713a6dd88d76c7e4eb6d4696a707ff4c46d07fcb542690a76a. Executables and generated inputs remain in the ignored evidence directory.

Commands, source hashes, exact ordered test declarations/results and original logs are in the raw reports. The source hash reports retain Windows working bytes; SOURCE_INVERSE_PROOF also records canonical LF bytes, avoiding a false claim that CRLF and Git LF hashes are interchangeable.

## Remaining acceptance

Run Apple SDK compilation and the unchanged original Native case IDs on the combined immutable source:

- HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending
- HanlinReaderConsumerAcceptanceTests/testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending

Both use the existing original-reader launch tier and canonical mini fixture. The actual sheet dismissal/reopen timing, compact toolbar/overflow behavior, original SDK connection constructor, conversation/draft preservation and post-revocation UI must pass in that run. No provider Send is performed. Network silence is not instrumented and is not claimed.

The helper review is source-only. These cases begin in their original fresh single-window layout; the helper's app-frame clipping check is not evidence of moved-window support. The unrelated original native route receipt and visibility oracles remain intact.

No additional compilation ran after the host's low-disk pause. The complete new source-fixture output occupies approximately 1.84MB. Separately, 76,184,901 bytes of conclusively owned completed Inspector intermediates were removed after process absence and SHA inventories; all 87 executable/source/resource/log/report files were verified unchanged. Shared caches, installed SDKs, original corpora and user data were not removed.

## Reproduction

python tools/hq-hanlin-current-work-source.py --source-ref c61213d9fcc8b80a8606ba00a1562215312ca2ed --artifacts-dir build/hanlin-consent-native-red-new

python tools/hq-hanlin-current-work-source.py --artifacts-dir build/hanlin-consent-native-green-new

Use a fresh evidence directory. These are standalone source-method checks, not replacements for Apple or Native acceptance.
