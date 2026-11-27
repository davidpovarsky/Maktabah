# UI-04 actual Siri delivery selectors

Two focused native selectors now exercise the existing registered App Shortcut through Apple's public Siri UI testing service:

| Device | Selector | Entry |
| --- | --- | --- |
| iPad | NativeRoutingAcceptanceTests/testSiriHistoryFromOriginalIPadReaderPreservesWorkspace | Original Reader foreground |
| iPhone | NativeRoutingPhoneAcceptanceTests/testPhoneSiriHistoryFromBackgroundPreservesOriginalReader | Original Reader background |

The recognized text is `Open History in ChavrusaText`. Its grammar comes from the actual existing `MaktabahNativeShortcuts` destination phrase; History is the original registered root name and ChavrusaText is the current iOS CFBundleDisplayName. No new product route or App Shortcut is introduced.

## Required original result

Each case boots the existing canonical original Reader using the normal realUI bootstrap, verifies its sealed source locator/text, and retains its scene, profile, group, selected tab and ordered document identities. It then invokes only `XCUIDevice.shared.siriService.activate(voiceRecognitionText:)` for navigation.

Acceptance requires the original History & Favorites navigation surface to be visible and hittable, the application to return foreground, and exactly one fresh strict native navigation receipt. The receipt must name this exact original scene, backend Otzaria, destination native.history, currentTab presentation, a valid request UUID and an advancing original revision. Existing receipt lines must remain intact.

Original workspace identities and all retained documents' persisted source, book, location, page/part, search and highlight semantics must be unchanged. Geometry checkpoints and the workspace's persistence revision are outside that semantic comparison. Both actual document snapshots are attached. The existing receipt validator is reused unchanged.

The recognized text, actual Siri-root hierarchy, application/SpringBoard hierarchy and full display screenshots are retained. A Siri setup, recognition, disambiguation or delivery failure remains a failure. No direct Intent run/perform, URL delivery, private decoder, app activation fallback, synthetic receipt or skip substitutes for Siri.

## Evidence and limits

The actual installed iPhoneSimulator27.0 SDK typechecked the public Siri activation and Siri debugDescription expressions with Apple Swift 6.4, exit 0. That 253-byte public API probe is recorded with its exact command, header hashes, source/log hashes and resource measurements. It is not a complete application or UI test target compile.

The two changed test sources passed syntax parsing, including the sealed helper. No native Siri selector has executed yet. Both remain NOT_RUN in FOCUSED_CASES.json. These cases use Siri recognized-text delivery, not a physical microphone or an assertion about human speech recognition.

The entire previous 180406-byte NativeRoutingAcceptanceTests.swift prefix remains byte-identical. The helper is appended and the two selectors are in the new original UI-target source file NativeSiriAcceptanceTests.swift. Historical Native116 and Release114 manifest files, counts, selection lists and deadlines are unchanged. Final native execution belongs to the original integrated acceptance driver.

## Source references

- Apple public Siri testing API: https://developer.apple.com/documentation/xcuiautomation/xcuisiriservice
- Apple recognized-text activation: https://developer.apple.com/documentation/xcuiautomation/xcuisiriservice/activate(voicerecognitiontext:)
- Installed SDK headers and their exact digests: PUBLIC_API_SDK_RESULT.json.
- Existing product phrase, display name, entity execution and original reading-state schema: source hashes in SOURCE_AND_ACCEPTANCE.json.

The installed SDK and source references were read on 2026-11-27. No private Siri API or platform availability override is used.

## Independent source review

The independent TOC/release reviewer verified the unchanged original file prefix, exact existing phrase, sole public Siri delivery, strict receipt/scene and owner checks, and absence of navigation fallbacks. No blocking source defect was found. The persisted semantic projection deliberately does not include selectedRange, TOC expansion, layout or full viewport restoration; those remain separate native acceptance requirements. A future native failure caused by checkpoint timing must be diagnosed against actual source/timestamps, not hidden by weakening state equality.
