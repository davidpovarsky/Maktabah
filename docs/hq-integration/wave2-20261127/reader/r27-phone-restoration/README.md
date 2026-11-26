# Native116 phone restoration: original capture obstruction

## Observed failure and scope

The retained original `R27NativePhoneTests/testNormalBootstrapOtzariaBackgroundAndColdRestoration` failed at 2026-11-26 20:38:35 UTC while `capture("r27-phone-background-restored")` queried the original parent `reader-text` UITextView's hittability. XCTest reported an invalid activation point. The test had already passed its initial source/title/locator checks and advanced past the post-background checks. The capture failed before the scenario argument was removed and the cold-relaunch branch began. This receipt does not establish the cold-restoration product outcome.

`original-case.log` is extracted from the retained actual phone run log, SHA256 `837279325be7f483a67cd0427bc4b07af3645b38f6ac5cc79b56505e33c3a985`. `original-evidence.json` binds the exact attachment manifest entry, original app/control source attribution, paths, full-file hashes and screenshot identity. The parent Native116 run was 82 pass / 34 fail / 0 skipped and remains a failed baseline.

The actual same-case hierarchy `8896907D-7463-4150-9DD8-DDB83F84A003.txt`, SHA256 `45981d45bfe32372b0baff0af4da8804a00eab2dcd10b7d10c9f8a5114232677`, shows:

- Native window and original parent TextView at `(0,0,402,874)`.
- Actual rendered Hebrew source children, including the long visible paragraph between the real native bars.
- Canonical title `ספר החינוך` and locator `otzaria|book:3891|line:522`.
- Original compact bottom control `ToolbarOverflowBarButtonItem` at `(33,803,38,38)`.

The generic capture observer searched `reader-more-menu` and `BottomOverflowBarButtonItem`, neither of which was the actual compact phone control in this hierarchy. Its query of the passive parent TextView then threw. This diagnosis is separate from the Sefaria TOC collection snapshot failure and Wave3's cold-history scene-mount case.

## Narrow change

Only `Maktabah-iOSUITests/R27NativeInteractionAcceptanceTests.swift` changes. The same original test selector, default fixture, real bootstrap, backend/work/title locator checks and removal of `-smokeScenario` before cold launch remain.

A phone-only capture observer requires the actual current portrait window, unique original TextView, exact unchanged source text and canonical locator. It requires a unique visible, genuinely hittable original bottom button from the established More/overflow identities, including the observed `ToolbarOverflowBarButtonItem`. It verifies live/snapshot geometry agrees and that actual source TextView children remain visible between the measured original navigation bar and bottom action. It does not request an activation point for the passive parent TextView.

The original source text is additionally compared exactly after backgrounding and cold launch. Actual termination is now awaited before the cold launch. Full-screen screenshots and fresh AX/geometry evidence are retained even if settlement fails. A failed observer remains a failed assertion. The shared Faithful capture implementation and other phone/pad cases are unchanged.

## Verification and remaining acceptance

Candidate R27 source SHA256: `7f1816d21f8933e675beab48df1d23a6115178fc685245417b0d19a448d7f786`.

Actual Xcode 27 / iPhoneSimulator 27 checks on Scaleway:

- Full R27 file syntax parse: exit 0.
- Exact new observer and capture method typechecked against actual UIKit/XCTest SDK types, Swift 6 strict concurrency: exit 0 after including Xcode's real `Developer/usr/lib/XCTest.swiftmodule` overlay path.

The initial standalone typecheck lacked that Swift overlay and could not resolve `XCTAssertEqual`; its failure log is retained. No production or assertion code was changed to bypass it. The corrected invocation adds the observed actual Xcode overlay search path. `apple-source-controls` retains both attempts and the compile-only host containing the exact observer/method source.

There has been no native UI rerun of this candidate here. The integration owner must execute the unchanged test selector on the qualified combined app/test build. In particular, cold restoration without the setup route still requires its first completed native assertion sequence and source/canonical-identity evidence.
