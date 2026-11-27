# Proposed actual-system hidden-phone Reader-tab acceptance

Status: **proposal only; no test file/helper edit, build or native execution**.

Source under test is the paired original Manager/Reader-tab binding change in `81ea1a360f027993362a9fa690e15fd2b38a4c52`, combined with the integrated Viewer continuation and final qualified app. Keep the original Native116 and Release selectors/assertions unchanged. The shared `NativeRoutingAcceptanceTests.swift` tail currently belongs to the UI acceptance lane; root must coordinate any later append-only helper there.

## Original setup and independent oracles

Use the existing `launchCurrentCanonicalReader(expectedPad: false)`, sealed original SQL reader oracle and original workspace reader. Obtain the real `NativeReaderTabEntity` through `IntentDefinitions(...).entities[...]` while the original Reader is visible, and retain that exact returned entity. Demonstrate its successful real `OpenReaderTabIntent.run()` invocation before each stale-entity refusal case.

Hide the actual Reader through its original unique Library Back button: the existing `prepareOriginalPhoneLibrary` source identifies `app.navigationBars.buttons` with identifier `BackButton` and label `Library`, and first requires a visible `reader-current-locator`. This original UI action must preserve the same persisted active tab/profile/group/scene and document identities. Wait for the real Library and the absence of the visible Reader. Do not write selectedBook, preferences, database paths, workspace JSON, synthetic entity identifiers or source generations.

For a successful hidden-tab invocation, use only the cached real entity's system `makeIntent(tab: cachedEntity).run()`. Require the same process and scene, exact original tab UUID/order/count/profile/group, original document source and location, sealed SQL locator and real TextKit text. Require exactly one new `native.reader.tab` / `currentTab` receipt for this measured invocation using the existing receipt parser/helper. Discovery and a model-only projection do not establish success.

## Separate proposed selectors

1. **Phone, already-active hidden Reader from original Library.** Start with a live original Reader, cache its entity, use Back, verify the same active workspace tab and continued real discovery, then invoke that cached entity. Require the exact original Reader to become visible without opening another tab or publishing another mode through an adapter.

2. **Phone, already-active hidden Reader from background.** Use the same original Back setup, then Home and a witnessed background state. Invoke the same cached entity through the system. Require the same process, foregrounded owned scene and original Reader. Preserve the original five-second Core deadline; XCTest setup/observation bounds must not renew it.

3. **Phone, hidden active Reader through a foreign global page.** After Back, navigate to the original History page through the existing validated public root transport or original UI control. Capture the receipt baseline after this setup. The same cached entity must use the one-use Viewer-parent continuation and original mode publication, then present the exact Reader under the same request. Require final Reader/TextKit evidence and exactly one measured final receipt; a Viewer/Library parent alone fails.

4. **Phone stale cached entity after original closure or group departure.** First prove the same entity succeeds. Invalidate it through the original tab-close or original profile/group UI, verify removal from real discovery and persist the new original workspace. Reuse the same cached entity and require a real refusal, no new receipt and no workspace/document mutation throughout the existing five-second inverted observation. Use an actually available original phone control; do not invent a close action or bypass the UI if that control is unavailable.

Add a duplicate-book variant only where the existing original UI can establish two distinct live tab UUIDs. Select the retained exact tab, compare document UUID/source/location and assert that the other Reader/document remains unchanged. A title match or numeric book ID cannot choose the target.

## Required limits

The current source controls cannot establish actual phone Back behavior, active AppEntity discovery while hidden, UIKit restoration timing, system invocation delivery, real persistence or final TextKit attachment. All proposed native results remain pending the qualified final Debug/Release app and original acceptance route. No physical Safari/Siri/device result is inferred from Simulator execution.
