# Host macro SDK and actual XCTest result correction

Original app gate: https://github.com/davidpovarsky/Maktabah/actions/runs/44465725912
Source: b4477a9e4fc69fe7f3c85b7a65b736feeb3e2041. Actual source and all dependency pins matched.

The exact EquatableMacros/equatable/597c2bb34af0c51331eb3b5e705f942d8ee20daa authorization was accepted with normal Xcode validation. The next failure is visible in the real compiler command: the macro tool targeted arm64-apple-ios15.0-simulator with the iPhoneSimulator SDK while its SwiftSyntax prebuilt modules were for macOS. The original driver supplied a global -sdk iphonesimulator. Removing that one global override retains the explicit generic/platform=iOS Simulator destination, original scheme, arm64, pinned packages, normal macro validation, original data/source preparation and signing boundary. Each target can now select its own SDK. Actual replacement compilation is required before calling this app build successful.

Primary supporting guidance: https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle.md explains that -destination selects architectures/SDK through build settings and advises using it instead of global -sdk/-arch. The observed macro mismatch and proposed fix are an inference from our retained actual compiler command, not proof from another project's successful build. No Xcode-wide validation or prebuilt setting was changed.

## Native store result

Original SDK/compiler gate: https://github.com/davidpovarsky/Maktabah/actions/runs/44459541882
Source: f423a0d51c5a2d9bd87a533c48b57f9e395ac168; SDK873607e45e021b40fe5b940c836d398c329f95c8.
Full artifact14501647526 SHA25621be497c05b7ba5b108aa4f7f612efdccfe631d8d936cc04b9f896a7c129b624,165693bytes, all member CRCs verified.

All11 original OtzariaHanlinConversationStoreTests actually passed on Apple Swift6.4.2/macOS. The app store and exact original SDK value modules were compiled, with real Foundation files, separate host/SDK revisions, scope rejection, actual filesystem write failure, corruption preservation, tombstones and restart. Raw test log SHA256cffd363c85e1076e4709197b60d46167063cde29195e3a41b9e360a712356c54. No new runtime execution is inferred from a replay.

The driver missed Apple's Objective-C XCTest display names, recorded zero matching methods, and made the aggregate fail. It now reuses Scripts/CI/verify-faithful-xctest.py: original Swift frontend declarations, exact suite/method matching and rejection of any failed or missing case. It also records the Swift process exit separately from verification. The retained old report did not separate those exit codes; its overall failure remains preserved.

Authenticated log replay: exact11PASS. Three negative replays (a missing pass, a later failure, and an unrelated suite) all reject. Replay receipt SHA256aca86b3afc414119f122dccc61bf79327e3853d8e0d3f7ecf1af26b7be9e9f50.

The original selected iOS UI source compilation/code generation passed in the same older gate, with2306 retained warnings and0 UI cases executed. The original8 navigation-contract cases passed with their explicit host/effect double and reproduced current contract limitation; this is not production navigation acceptance.

## Remaining acceptance

Actual current app compilation, original native history/reader routes, live provider/model, actual source opening, physical protection and signing remain open. Source, Vendor, package locks, Xcode project and original tests are unchanged by these driver corrections.
