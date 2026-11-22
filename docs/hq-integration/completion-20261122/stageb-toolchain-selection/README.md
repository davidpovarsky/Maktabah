# StageB exact producer toolchain selection

Prepared against Maktabah a2c960b3cafa02be9cec8f01aebba893ad67cd47. This changes only the shared selector and the separate original-editor StageB workflow. It does not alter application, vendor, Xcode project or UI test trees, admit an SDK, activate a workflow branch, install a toolchain or change global xcode-select state.

## Why the selection must be constrained

The existing selector chooses the newest installed complete Xcode/SDK/runtime matrix pair. The original-editor SDK consumer also requires exact producer and consumer Swift and SDK versions. Observed SDK run 45034016674 used Xcode 27.0 / Swift 6.4 / SDK 27.0, while the unrestricted selector could choose a newer installed pair. The new optional `--original-editor-admission` constraint selects only an existing complete pair whose complete observed Xcode, Swift and SDK tuple matches a committed, finalized admission file. No matching tuple fails closed. Other consumers retain the existing selection path.

The StageB workflow alone supplies the option. Its actual admission file remains UNFINALIZED until a genuine qualified producer artifact is available. The later original SDK distribution gate still verifies the artifact, qualification and actual runtime; this selector does not replace that gate.

The producer records stripped stdout from `xcrun swiftc --version`. Its real successful command also wrote 30 bytes of driver diagnostics to stderr. The optional inspection therefore uses the same command, preserves separate streams and compares only stripped stdout; stderr length and SHA256 remain recorded.

## Verified controls and preservation

- Six new pure selection/source-binding controls passed at 2026-11-22 15:25:43 UTC. They cover default selection, exact older producer selection, absence of fallback, complete tuple drift, real temporary Git source binding and rejection of an unfinalized input. Their original selector, test source, receipts and streams are retained under `retained-six-controls/` and `evidence/RESULT.json`.
- A peer review identified the stdout/stderr mismatch. The final selector adds the separate-stream inspection, and one new controlled subprocess case passed at 15:33:48 UTC. It uses preserved actual producer streams and a clearly isolated xcrun fixture, checks exact argv and scoped environment, and does not execute an Apple compiler. Its raw receipt and streams are in `evidence/version-stream-control/`.
- The six earlier controls were not rerun. Their exact recorded input and output hashes were rechecked, and AST comparison confirmed that both functions they exercise and all six test bodies remain unchanged. The retained historical selector file is named `retained-six-controls/selector.py`; it is the exact bytes recorded as `candidate/Scripts/CI/select-runtime27-toolchain.py` in the original receipt. The workflow bytes also remain identical to that receipt. No historical receipt was rewritten.
- Final independent peer review by the SDK workstream confirmed the exact producer command and stream behavior, unchanged default path, scoped environment and absence of fallback. No remaining source-review issue was found; genuine SDK binding and Apple execution remain outstanding.

These are seven new controlled Python checks across two executions, not Apple/native or SDK acceptance. No passing application suite was replayed.
