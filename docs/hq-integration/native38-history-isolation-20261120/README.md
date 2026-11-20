# Native38 compile barrier and History capture isolation repair

## Actual immutable run

[Native38 run 44704452479](https://github.com/davidpovarsky/Maktabah/actions/runs/44704452479) completed with **FAILURE during Apple build-for-testing**, before any UI case executed. This source-specific result is preserved without borrowing results from older runs.

| Identity or outcome | Verified value |
| --- | --- |
| Checkout D | `f0bbf9f06b3609d68c72626e5a4dd2c4aee2f99e` |
| App and XCTest source M | `0f5111e8f8e379e17da558ddbe2aab5214ac0315` |
| XCTest tree | `56c8aa08b7296940869d57904e634178287dfc48` |
| Case manifest SHA256 | `866afcdb0fe3e0c770b99a2673931404c0b3360eb23383ca813412be7cd9c8c8` |
| Selection | 38: 28 iPad and 10 iPhone; 25 canonical and 13 existing Release smoke cases |
| Executed UI PASS / FAIL / SKIP | 0 / 0 / 0 |
| Selected UI NOT_RUN | 38 |
| Actual XCTest result bundles | None retained or produced by this build-failure path |
| UI screenshots/video/captures artifact | Absent |
| Runtime job completed | 2026-11-20 09:16:04 UTC |
| GitHub run updated | 09:16:05 UTC |
| Finite watcher observed completion | 09:16:28.436170 UTC; separate from execution finish |

The generated JUnit wrapper has 38 `<error>` entries for NOT_RUN. These are build-blocked reporting records, not 38 failed XCTest executions. The native zero-skip acceptance gate was not exercised. The original 92-case matrix and Release 96+2 remain separate; 67 original canonical cases were not selected in this diagnostic run.

The only published artifact, `runtime27-evidence` 14615913957, is retained here verbatim: 1,502,571bytes, SHA256 `a3198ef3647bea46864fcb69d4b4656ac23596f36bd498dc5b703a01da1ecbfe`. All 66 ZIP entries passed CRC verification. The complete original build log, generated results, declaration preflight, project/dependency records and toolchain records remain inside it. No multi-gigabyte capture archive was downloaded.

## First actual Apple compiler failure

Xcode 27.2, Apple Swift 6.4.2 reported at `Maktabah-iOSUITests/FaithfulReaderUIAcceptanceTests.swift:991:67`:

> sending 'self' risks causing data races

The diagnostic explains that the local `historyObservation` function captures `self` through `workspaceNamespace`, then is used from the `NSPredicate` / `MainActor.assumeIsolated` closure. The exact first diagnostic is log line 108355 in `hq-stage2/simulator-build-for-testing.log`; its complete local context is retained in `FIRST_APPLE_ERROR.txt.gz`. The remaining compiler error line repeats the same diagnostic, followed by TEST BUILD FAILED. This failure is distinct from dependency diagnostics observed in the separate normal iOS workflow.

## Narrow repair

Only the existing History helper in FaithfulReaderUIAcceptanceTests changes:

1. Copy `workspaceNamespace` into immutable `historyNamespace` before the initial observation.
2. Use that same value for the initial observation and every later persistence observation.
3. Replace the local function with an explicitly `@Sendable` file-only closure. It retains only the existing immutable URL, String and Data values, not the XCTest instance or UI objects.

There is no new actor hop, UI operation, polling loop, fixture seed, preference write or changed timeout. The original query, Return, 90-second waiter, same installation/metadata requirement, exact-once query check, relaunch, visible row, keyboard geometry and all attachments remain byte-identical. No caller change is required because the invocation shape remains `historyObservation()`.

`SOURCE_INVERSE.json` records the two exact substitutions. Reversing them reconstructs the **entire** original XCTest file byte for byte:

- Before LF SHA256: `387879fcc00f2d90f8bb03319c59faf392f093062fcd0d1551a6c34009f9bb11`.
- Candidate LF SHA256: `397099a55c6da0d3d9e0f2e8b8a13e4bf9e0f0e3a8114ac8d59a42eb3a7fb899`.

The complete before/after files and proposed patch are retained compressed. Production Source, packages, project, workflows, manifests and all other XCTest files are unchanged by this repair.

## Executed focused host verification

A small Windows Swift 6.3.3 fixture compiles the **complete original Foundation observation helpers** and the exact original/candidate closure blocks. Its explicit test-only boundary is a non-Sendable owner and disposable UUID-named metadata/property lists. It is not a UIKit/XCTest scheduler or Apple SDK substitute.

The legacy capture control was rejected by strict concurrency when required to transfer as a Sendable function. That host diagnostic is retained separately from the real Apple failure above; it is not presented as an Apple reproduction. The candidate compiled with `-swift-version 6`, `-strict-concurrency=complete`, and one compiler job, then executed four controls successfully:

| Control | Actual result |
| --- | --- |
| Original pinned installation/query observation | PASS |
| Captured namespace stays independent of later owner mutation | PASS |
| Duplicate query still fails the exact-once oracle | PASS |
| Changed original metadata still fails the pinned-installation oracle | PASS |

The whole candidate XCTest file also passed Windows frontend syntax parsing. The compiler and runtime finished at 09:32:58 UTC. Raw outputs, command lines, hashes, exact fixture inputs and boundaries are retained. **Candidate Apple typecheck and Native execution are NOT_RUN.** A future immutable Apple run must establish them; the old Native38 outcome remains 0 executed / 38 NOT_RUN.

## Source binding and collection boundary

The retained result matches the exact 38 unique selected IDs, the declared 28/10 device distribution, the frozen case manifest and test tree. All 32 recorded XCTest/helper SHA256 inputs were checked against their exact M or D Git source. Of 996 actual application input objects, 995 match M exactly. The sole differing object is the already declared CocoaPods privacy aggregation for `Source/PrivacyInfo.xcprivacy`; its original bytes match M, its generated bytes match the recorded compiled object, and every retained dependency privacy input matches its stated hash. No other source mismatch is allowed.

An initial collection check that assumed every application object would equal M stopped on that explicitly recorded generated privacy file. The corrected collection verifies the original/generated/dependency chain instead of hiding it. `VERIFIED_OUTCOME.json` retains this distinction. No test or source condition was relaxed.

The sole finite watcher terminated normally after observing the completed workflow. No watcher was renewed, and this tranche dispatched or cancelled no workflow. All historical observations remain dated and source-specific.
