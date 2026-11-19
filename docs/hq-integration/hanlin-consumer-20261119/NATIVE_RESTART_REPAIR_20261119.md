# Original chat cold-restart readiness repair — 2026-11-19

## Observed failure, not a storage failure claim

[Native run 44480833870](https://github.com/davidpovarsky/Maktabah/actions/runs/44480833870) built the actual app at `7be3af6b977823fb02e64859ab10e79c4eef410f` with the original SDK `6d62957852ffcb428810b065b4252e5384f1374b`. Two original UI cases executed on iPad Pro 11-inch (M5), iOS Simulator 27.2 (24B8117): one passed and one failed. The reader chat presentation/return case passed its original exact book/locator/text/workspace checks.

The global draft case entered the actual Hebrew/English multiline text and restored the identical draft after native dismissal. The saved-history list contained exactly one conversation; reconnect was required and Send was disabled. After the process changed from PID 54619 to 56758, tapping the actual global launcher reached the app's `Study chat unavailable` alert, not the chat. The failure is at `HanlinConsumerAcceptanceTests.swift:29`, before the test could inspect cold-restored history. Thus this run does not prove loss of the saved draft or successful process-restored history.

The exported failure hierarchy `FFE778CE-D89B-4F5A-BCDA-615D45D7387D.txt` contains the real alert and message `The original study window is not ready. Try again from the reader.` The raw xcresult, recording, hierarchy and logs were downloaded from the run's `runtime27-evidence` and `runtime27-native-captures` artifacts. The latter completed download successfully after the first transfer timed out; partial output was preserved separately.

## Cause addressed and ownership

The existing workspace lifecycle publishes the original adapter before its asynchronous `attach`/`switchGroup` restore completes. `attached` becomes true before that restore. Routing can therefore mount while the original live native mapping is unavailable. Its binding installation correctly refuses the unavailable mapping. The routing host previously retried installation only on selection or visible navigation changes; a cold restoration of the same empty group need not change either. The actual producer nevertheless publishes its `.available` mapping event.

The downstream routing host now refreshes its existing projection/binding when that original event becomes available. All original scene, foreground, workspace owner, native-setter coverage, source identity, namespace and epoch checks remain in the existing composition. This adds no alternate mapping, permission model, timer, automatic navigation, synthetic receipt or storage migration. The causal attribution is a source-based diagnosis pending the unchanged native regression.

| File | Ownership and provenance | Change | Validation |
|---|---|---|---|
| `Source/ChavrusaText/UIRoutingHost/Integration/MaktabahNativeRoutingHost.swift` | Downstream app composition; absent from actual upstream `d46af139b3a265399c16d87f5923acd8e3444024` (remote HEAD rechecked before edit) | Observe original producer publication and call the existing refresh path | Swift syntax parse; same two actual Native cases required |
| This report and source-freeze metadata | Downstream evidence | Record original failure and new immutable candidate | Hash/tree comparison; exact selected case identities |

No upstream application source, SDK source/pin, test function, assertion, timeout, launch bootstrap, fixture data or SwiftPM lock changes in this repair. The original 77-case catalog and parent 75-case affected selection remain preserved; the bounded two-case execution does not certify them.

## Acceptance

Current source repair: NOT_YET_NATIVE_VERIFIED. The next run must preserve both original UI test methods byte-for-byte, execute both, and pass the process-PID, exact multiline draft, same conversation, no empty duplicate, no restored credential, disabled Send and reader return checks. Provider/source opening, three real model/Core/UI journeys, full corpus, physical device and release remain open. Tasks stay OPEN; release remains NO_GO.
