# Global Search Dynamic Type: passive diagnostic candidate

## Finding and scope

The original Native accessibility audit still has an unresolved failure. In run `44723902453`, attempt 1, checkout `60a57972acb28739ec738565083bf17fb7503028` and application source `87b783ac3f0257e8461762e0ea9dfa5248dd06e8`, `GlobalSearchNativeAcceptanceTests/testHeaderAndHistoryNativeAccessibilityAudit` failed after 68.593 seconds. The authentic retained issue says that a UILabel partially lacks Dynamic Type support, but its element is **unavailable**. The original log shows the failed element lookup and the unfiltered issue attachment. It does not identify that UILabel as the search field, its placeholder, the history heading, or another visible component.

The old application and base `e603d8182a1c10c4b37b14c92b5f0bc3829edea8` have the same native search field blob, `5f5f22eeea9e04889f2bd278d32d819b313380c2`. The existing control already applies preferred body typography, enables content-size adjustment, observes the actual trait, and updates the native placeholder label. The history heading already uses preferred headline typography with adjustment enabled. This review did **not** establish a product font defect and makes no speculative font replacement.

This candidate adds passive observations for the next original Native audit. It does not repair or suppress the accessibility issue. Swift parsing/typechecking, UIKit execution, the candidate audit and actual collection of its new records are **NOT_RUN**.

## Source changes

Only these three existing files change:

| File | Change | Preserved boundary |
| --- | --- | --- |
| `Source/ChavrusaText/Search/UI/NativeGlobalSearchField.swift` | DEBUG-only optional observation closures and a bounded UIKit font metadata recorder | Every original statement, font update, callback, guard and return remains. Removing the new complete DEBUG blocks restores the original file byte-for-byte. |
| `Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift` | Default-false launch argument, enabled only by the original accessibility-audit case | Reversing the three explicit launch edits restores the entire original file. All 29 declarations, the complete unfiltered audit callback, assertions, waits and failure behavior remain. |
| `Scripts/CI/run-faithful-ipad-matrix.py` | Include that exact case, or its whole suite, in the original persistent-log collection selector | The original copy/report/error logic and every other matrix statement, budget and verification guard remain byte-identical. |

The new pure-Python selector controls live in `Tests/HQ/global-search-font-diagnostics/test_collection_contract.py`. No project membership, source pin, SDK, package, engine, registry, account, entitlement or workflow trigger is changed here. Root owns integration and the final frozen source.

## Activation and observations

Production observation code exists only under `#if DEBUG`. The existing representable supplies optional closures only when all three conditions are true: the process has the explicit `-GlobalSearchFontDiagnosticsEnabled YES` argument and corresponding defaults value; the actual active profile is `miniTest10`; and `studyWorkspaceTestingNamespace` is a valid UUID. Each observation rechecks that authority. The optional closures default to nil and are cleared when the original view is dismantled. The UIKit-only control does not import or substitute an app owner; the actual app representable supplies the original logger.

The recorder observes the search field's actual UIWindow after the original mount, trait and pending-layout work. It does not call layout, schedule tasks or timers, change fonts, call accessibility lookup APIs, or alter the responder. A reentrancy flag excludes nested traversal. A pending flag allows one layout observation after a mount or trait event, rather than scanning on each layout. Duplicate metadata snapshots are omitted.

Each recorder is bounded to 768 visited views, depth 24, 64 recorded UILabel rows and 32 distinct snapshots, plus one explicit snapshot-limit notice. Each JSON record is at most 65,536 bytes before the existing logger prefix/timestamp; strings are limited to 160 characters. These are per-control/per-namespace limits, not a process-wide log quota. Node, label, byte and snapshot truncation are reported. A recreated control can have its own bounded recorder.

Recorded fields are phase, actual content-size categories, window/scene presence and foreground flags, view-tree path and class, an allowlisted known scope, hidden/alpha/geometry metadata, and the live font name, point size, line height, text-style metadata and `adjustsFontForContentSizeCategory`. The recorder reads no label text, query text, attributed text, accessibility label, accessibility value or accessibility hint. It reads accessibility identifiers only to reduce them to a closed list of existing scope names; arbitrary identifiers are not serialized.

This is a bounded UIKit observation, not an accessibility auditor. It does not decide whether a font or label passes Dynamic Type, does not assign an unavailable audit element to a row, and cannot cover separate system windows or views outside the visited subtree. A missing or truncated observation remains missing or truncated evidence.

## Actual persistence and collection path

The sink is the original serial `OtzariaFileLogger.shared.log`, which writes `Documents/OtzariaLogs/otzaria-reader.log`. Records have the fixed `[GlobalSearchFontDiagnostics]` prefix. The existing matrix obtains the actual app data container with `simctl get_app_container`, then copies that original file to `artifacts/native-routing-logs-<label>/otzaria-reader.log` and records its bytes and SHA-256 in `collection.json`.

That collection occurs after the original XCTest and strict xcresult verification even when the audit has failed. The selector is the only changed collection logic. `MISSING` and `COLLECTION_ERROR` remain explicit; no substitute log, successful audit, or record delivery is fabricated. The existing asynchronous logger has no newly added flush guarantee. A missing final log after a process/container failure must be reported as missing. This candidate does not add a container scan or change the existing failure path.

The original SDK checker extracts the exact source from `private final class GlobalSearchTextField: UISearchTextField {` through end-of-file with `import UIKit`. The new recorder stays within that self-contained UIKit boundary. The original representable/coordinator still require actual app compilation. The driver itself is unchanged and is included among the eight Git-bound reference inputs for source review; no Apple compile is claimed from inspecting this closure.

## Verification actually performed

The pure original Python selector executed **12/12 controls**, exit 0, with distinct named results retained in `raw/collection.stderr.log`. They cover existing routing/phone/Escape collection, the exact audit and whole suite, unrelated and lookalike cases, empty selection and a mixed selection. They do not execute Swift, UIKit, a simulator, the logger or the copy operation.

The reproducible verifier independently binds eight baseline files to their Git blob IDs and SHA-256, checks all three whole-file inverses, checks the original collector and SDK extraction boundary, and validates those retained 12 leaves and the authentic 131-byte issue attachment. It performs source checks and Python syntax compilation only. Its recorded result is `SOURCE_PRESERVATION.json`.

From the repository root:

```sh
python3 Tests/HQ/global-search-font-diagnostics/test_collection_contract.py
python3 docs/hq-integration/global-search-font-diagnostics-20261120/verify.py --repo .
```

`BASE_PROOF.json` and `raw/baseline/**/*.gz` preserve the exact source authority. `HISTORICAL_EVIDENCE_REVIEW.json`, the original issue text, retained search log and case excerpt preserve the actual old failure. The small original search log is reused from the previously verified Native98 evidence; the selected attachment is reused from the exact prior Sentinel read. No new capture archive was downloaded and no whole capture-archive hash is asserted.

The remaining gate is the original Apple compile and original unfiltered Native accessibility audit on the final integrated source, followed by actual collection and analysis of these records. An audit PASS or an identified font defect requires that execution; neither follows from this diagnostic patch or its Python controls.
