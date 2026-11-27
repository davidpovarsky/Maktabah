# Original hidden-active phone Reader-tab native selectors

## Delivery and current status

This packet adds five **unexecuted actual-system XCTest selectors** for the phone Reader-tab fix in `81ea1a360f027993362a9fa690e15fd2b38a4c52`, now integrated in root `7fbe04c6eef8c072d6a9ff9c0e6c78791b3db97b` (Source tree `1e36b8942c4f43e551f5b1eb814139fac651e56b`). It delivers one new synchronized-target test file and a separate append-only helper proposal. Root must combine that exact suffix with its shared helper before compiling the tests. The branch deliberately does not modify the shared live `NativeRoutingAcceptanceTests.swift`.

The measured action is the real cached `NativeReaderTabEntity` passed to Apple's out-of-process `OpenReaderTabIntent` through `IntentDefinitions(...).makeIntent(...).run()`. Each positive case requires the original Reader, sealed SQL locator, actual TextKit text, the original process/scene/profile/group/tab and document semantics, and exactly one new `native.reader.tab` / `currentTab` receipt. A Library/Viewer parent or an entity query is insufficient.

| New selector in `NativeRoutingPhoneAcceptanceTests` | Original setup and measured outcome | Runtime status |
|---|---|---|
| `testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromLibrary` | Cache the real entity while its Reader is visible; use the unique original Library Back button; prove the same tab remains active; restore the exact Reader through the cached entity. | NOT_RUN |
| `testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromBackground` | Same Back setup, then Home and a witnessed background state; the cached system action must foreground the same process and restore the original Reader. | NOT_RUN |
| `testPhoneSystemReaderTabIntentRestoresAlreadyActiveHiddenReaderFromHistory` | Same Back setup, then the original dedicated History URL/receipt contract; one measured Reader-tab invocation must complete the Viewer continuation and the original Reader presentation. | NOT_RUN |
| `testPhoneSystemReaderTabIntentRejectsCachedHiddenReaderAfterOriginalGroupDeparture` | First prove the same cached entity successfully restores its hidden Reader; use the original overview/New empty group/Done controls; require withdrawal from real discovery and actual refusal with no receipt or workspace effect. | NOT_RUN |
| `testPhoneSystemReaderTabIntentRejectsCachedHiddenReaderAfterOriginalGroupDepartureFromBackground` | The same successful-then-foreign-group setup, followed by a witnessed background state before reusing that cached entity; preserve the original workspace and receipt log through the full five-second observation. | NOT_RUN |

## Original controls and independent evidence

The Back query is the existing phone contract: `app.navigationBars.buttons` with identifier `BackButton` and label `Library`. The new helper requires an actual visible Reader first, then a visible/hittable original `library-contents-list` and no Reader locator. It verifies that Back did not close or replace the original active workspace tab. A new real entity query while hidden must still return the one original tab; the measured action continues to use the original cached entity.

The foreign-page setup calls the existing dedicated `historyURL("otzaria", request:)`, then validates that exact setup request with `requireRootReceipt`. The measured receipt baseline is taken afterward. The older `publicRootURL` has an original search/annotations-only assertion, so this packet does not route History through it or change its guard. Root separately owns the four historical incompatible callsite corrections and the other agent's Search suffix.

The stale cases use the actual original phone toolbar to open `StudyGroupsOverview`, its original New empty group action and Save prompt, and its original Done control. They independently read the persisted scene, profile, new empty group, and retained old group's tab UUIDs. The exact old entity must disappear from the actual query. Both cases then reuse the **same entity that already succeeded**. There is no fabricated identity, direct service call, state injection, preference write, database update, or app activation fallback.

Successful navigation compares original document UUID, backend, book, backend locator, locator, content identity, page/part, and search/highlight fields using the existing `actualSiriReaderDocuments` oracle. That helper deliberately excludes viewport/selection/TOC bookkeeping; this packet does not claim the full Reader restoration matrix. Refusals compare the complete persisted workspace JSON with only the monotonically increasing top-level `revision` removed. The five-second inverted observation also compares the full native receipt set; failed reads count as an unwanted effect. This is the original Core deadline, not an extended product timeout or a new grant.

A background parameter-resolution refusal may leave the app in the background. The test records the actual post-refusal state and does not activate the app to manufacture a journey. If it is foreground, the original empty Library must be visible; otherwise the app must retain a running background state and the same actual PID. No successful Reader ACK is expected in either refusal. The actual system error is attached, but the test does not assert a specific typed error or claim the intent's `perform()` was reached when the system rejects during parameter resolution.

## Exact source preservation and integration

The frozen shared helper prefix is **259,080 bytes**, SHA-256 `7f735919df764571929bb858dd21e082c7a52b68d01b9e15b65aa738284ee4ad`. The 13,144-byte suffix is SHA-256 `25e48b7aec434f0e279ba03dcccaa3171310209d5da03ab0706bca1e6a66fc9a`. Their independently retained syntax candidate is **272,224 bytes**, SHA-256 `20ff79f690d4ebf203f9596095f09ebb0c14148e21f243b50885f217da75bd61`.

The new test file is **1,511 bytes**, SHA-256 `df2a74beaee99eadd112613a7eca19f75eb68280660d802bb58b24e25fb1871b`. `APPEND_ONLY_HELPER.patch` is an exact additive patch against the frozen prefix. Root must preserve its separate reviewed four-callsite correction and the Search helper addition when composing these independent changes. No automatic replacement of the whole shared helper is authorized by this packet.

All 67 test-function occurrences inside that original helper prefix remain byte-exact. This number is a source occurrence count, not a Native116 or Release test result. The original six Reader-tab selectors, Profile/Group selectors, Native116 and Release114 assertions are unchanged. No selectors are deleted, renamed, skipped or counted as passed.

The new file inherits target membership from `PBXFileSystemSynchronizedRootGroup` `F30578032FA46222005732C6`, path `Maktabah-iOSUITests`, attached to UI-test target `F30578012FA46222005732C6`. The exact base PBX SHA is `909679eccc56d8ac8ec5be5947fd7f99fc855d62390a330836f28d9deee770bc`; the relevant original blocks are retained in `evidence/MEMBERSHIP_READ.json`. **Do not add manual PBX membership.** Actual Apple discovery remains pending.

## Validation and limits

One actual Oracle Swift 6.4.3 frontend invocation parsed the exact combined candidate and new selector file with target `arm64-apple-ios27.0`. It exited **0**, with empty stdout and stderr. `evidence/attempt-1/RESULT.json` records the full argv, exact input hashes and duration; its SHA-256 is `07055f566ef84d10a1182773b8f6eedd5261524e0605921649291249f5c77f7b`.

That is syntax evidence only. No Apple SDK import/typecheck, AppIntentsTesting metadata discovery, app compile/link, simulator, native XCTest, physical device, Siri or TestFlight execution occurred. The existing native family's sealed **miniTest10-v6** setup is reused unchanged; this is not production-v40 acceptance. The separate production and full original release gates remain required.

The Windows-hop preflight returned `agent_offline` before any command ran. The established direct Oracle link then completed the isolated checkout and parse. A read-only PBX lookup initially matched both a target attribute and the target definition; its error is preserved, and the corrected read required the exact `PBXNativeTarget` type. Neither tooling attempt is a product/native result.

## Ownership and rollback

| Path | Ownership and delta |
|---|---|
| `Maktabah-iOSUITests/NativeHiddenActivePhoneReaderTabAcceptanceTests.swift` | New downstream XCTest selectors only. |
| `NATIVE_HELPER_ADDITION.swift` / `APPEND_ONLY_HELPER.patch` | Downstream test helper proposal, appended by root to the existing downstream native acceptance file. |
| Evidence and intake documentation | Downstream source-bound documentation; original app inputs are read-only. |

No upstream app source, Manager, Reader binding, Session, Core, interface, vendor pin, dependency, acceptance gate or project file changes. `evidence/PROVENANCE.json` pins the original controls, owner and intent files used in this review. Rollback removes this new test file and this exact additive suffix, preserving every prior helper byte and the independently owned Search/History changes.
