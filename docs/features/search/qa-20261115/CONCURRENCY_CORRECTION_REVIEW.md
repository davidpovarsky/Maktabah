# Independent review of actual SDK compiler correction

Task1220546245946205; I owns evidence only. Reviewed immutable S correction **09c24e5bcc494cb8795a936ca296a8b5ddc0b6a1**, parent da186f456056fc5b9409de28fc7c989a2911cd1b. The production delta contains exactly two closure-type annotations in `GlobalSearchPresentationCoordinator.swift`: EnvironmentKey.defaultValue and EnvironmentValues.globalSearchBookChooser become `(@MainActor @Sendable () -> Void)?`. Production file SHA256 `a2f4e8bb914d14af1f253c8fe87731095ebf3717251f8eda589efdb43c7f39c7`.

This directly addresses the real non-Sendable stored-static error in manager run43744659996. The value is transferable while invocation is explicitly isolated to MainActor. Nil default, original iPad action, native header invocation, sidebar/compact chooser behavior and state ownership are unchanged. No unsafe conformance, nonisolated escape, compiler suppression, project/workflow change, new state or backend behavior appears in the production diff.

## Independent reproduction

Executed the unchanged committed S `global-search-action-swift6-tests.py` from three exact git-show input blobs in a temporary snapshot, not S's active worktree. The baseline git-show uses process-local read-only Git configuration; the runner's evidence output is retained under `swift6-action-review/`. No S source/harness was edited and no parallel production harness was introduced.

Windows Swift6.3.3 flags: `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`. Results:

- Original da186f45 key is rejected at non-Sendable static defaultValue (expected RED, exit1).
- Exact corrected key/accessor/coordinator declarations compile (exit0).
- Six assertions pass: nil/removable action, detached transfer with actual actor hop, regular Search sidebar reveal, compact chooser action and preservation of the other presentation state.
- Removing the actor hop is rejected with the actual diagnostic that the MainActor Sendable closure call is async and missing await (expected exit1).

Reviewed the probe: it copies the actual iPad action body and compiles the production coordinator unchanged except import replacement. SwiftUI EnvironmentKey/EnvironmentValues/split visibility and the host are explicit stand-ins. Observation and Swift language/concurrency are real. This **does not compile Apple's SwiftUI declarations, actual complete iPadLayout/header call sites, target settings or XCTest**, and is not Apple SDK acceptance. Manager must compile the complete integrated candidate to verify those boundaries.

## Actual call sites and public Apple declarations

Independently inspected exact09c24e5b `iPadLayout` and `GlobalSearchHeader`. Both declare their View conformance in the original struct declaration. Header reads the action through `@Environment` and invokes it from its native book Button action; nil still opens the existing chooser. iPad installs the original action that either changes the canonical session chooser flag or calls the Search-only coordinator. No background call or alternate route was added.

Apple's public documentation declares View as MainActor/preconcurrency and explains inherited isolation for conformance in the original declaration: [View](https://developer.apple.com/documentation/swiftui/view). The documented key requires a default value of its associated value type: [EnvironmentKey.defaultValue](https://developer.apple.com/documentation/swiftui/environmentkey/defaultvalue). The typed getter/setter contract preserves that associated value: [EnvironmentValues subscript](https://developer.apple.com/documentation/swiftui/environmentvalues/subscript(_:)). The documented generic property wrapper reads that value by key path: [Environment](https://developer.apple.com/documentation/swiftui/environment).

Inference from those declarations and the exact source: the installed optional MainActor/Sendable closure flows through the matching accessor to the Header without erasing its function annotations, and both complete native hosts should inherit MainActor isolation. This supports the source correction, but public documentation is not the installed Xcode27.1 swiftinterface or a compiler check of the complete captured View types. That actual SDK boundary remains pending.

`swift6-action-review/immutable-review-inputs.json` records input hashes and raw evidence hashes; RESULT.json and RED/green/run/missing-hop/driver logs retain the executed results. All16 inputs of the earlier independently executed42+18 session/paging checks match this correction commit byte-for-byte. Those passes are retained by input identity, not reported as a newly executed run. Earlier191+14 remain within their documented portable scope.

Post-commit integrity checking caught Git line-ending normalization of the emitted RESULT.json. A narrowly scoped artifact attribute preserves the concurrency result JSON bytes along with existing raw-log preservation; the committed raw evidence hashes were then reverified. This is an evidence-packaging correction, without rerunning or changing the production/test code or reclassifying any result.

## Decision and next gate

**Source correction reviewed; no additional source defect found in this two-annotation scope.** Suitable for manager's exact-source integration and real Apple compiler check. This is not native QA completion or runtime approval. Corrected-candidate Apple SDK typecheck is NOT_RUN; all18 previous selected UI cases remain NOT_RUN, as do every matrix backend/device/accessibility row and physical-device acceptance. The17 I test methods/oracles remain byte-identical to frozen packet c5379e02. No app/native run, polling, watcher, retry, cancellation or Asana mutation was performed by I for this correction. One unexpected remote toolkit API workflow dispatch occurred while attempting `apple-api --local`; it was immediately disclosed to manager and is explicitly recorded in `TOOLKIT_API_DISPATCH_EXCEPTION.json`. No result from that workflow is used as SDK evidence. Manager retains coordination and canonical task ownership.
