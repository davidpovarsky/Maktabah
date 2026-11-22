# Apple native creation-fence route preparation

This packet prepares execution of the existing 24 persistence controls on the actual Apple toolchain. It does not contain an Apple result and dispatches no CI.

The published Windows component remains frozen at source e78ddef1 / evidence 0cdb968f. Only the existing acceptance executable's switch gains a three-line all-controls entry; every existing control body, helper and crash/reopen assertion is unchanged. The Python runner retains its original default 18-control selection and 19-control affected selection. The new explicit all-controls mode executes the existing 18 controls followed by all six UUID cases and the original three abrupt termination/reopen pairs. compiler_inputs exposes the same existing dependency selection to the narrow CI source gate.

The existing Darwin branch uses the Apple SDK SQLite3 module and links sqlite3 without a replacement module map. The unchanged original AnnotationExchangeTestSupport aliases AcceptanceDigest to the production AnnotationExchangePlatformDigest / CryptoKit, and uses the original _exit(73) abrupt terminator. No Source, Tests fixture, schema, digest, assertion or native SDK code changes are needed.

## Review paths

- docs/hq-integration/completion-20261122/native-creation-fence/NativeCreationFenceAcceptance.swift — three-line entry selection only.
- docs/hq-integration/completion-20261122/native-creation-fence/run-native-creation-controls.py — explicit all-controls selection and reusable exact input list.
- Scripts/CI/native-creation-fence-apple.py — prepare/source-check/collect, using the existing exact_working_inputs helper.
- Scripts/CI/native-creation-fence-apple.inputs.json — fail-closed until the canonical composition and all execution inputs are sealed.
- .github/workflows/otzaria-native-creation-fence-apple.yml — one dedicated xcode-27 push route; original Xcode selection is reused.

The neutral preparation branch does not match the gate branch codex/otzaria-native-creation-fence-apple-20261122. No existing workflow is changed or re-dispatched.

## Required source composition

Root's new canonical application source is 67518e8df6975c976e8f1cd9e622328dc45985fc, containing the reviewed ledger and the current application/UI work. The verified published parent 5b2e63cedf54fb839d07304526c4b2dcb97bb1b1 was composed in a true two-parent merge 80e997759adb784fa417bf5e820a834ccdfaee6f. All four resulting Source/Vendor/project/UI-test trees equal application67518. The final route closure is committed at 2f8a8b978bf331fc0d8754b44da986aacc40d4d0. Its 47 execution inputs (42 compiler inputs plus five route/toolchain/helper inputs) are sealed from committed Git blobs using a single batch read. The source gate refuses unsealed input, dirty bytes, missing/extra dependencies, tree drift or unreviewed helpers. No early full source admission is claimed for the older isolated application composition.

## Actual execution contract

The future Apple job must admit the exact repository, gate branch, workflow checkout, run ID and attempt; use a fresh owned package; execute all 24 exact case names; and retain actual compile/control/exit73/reopen process records. Run/attempt-specific evidence directories preserve earlier attempts.

Collection requires the real Apple Swift target and system SQLite, the seven unchanged-or-explicitly-bound copied compiler inputs, current original Core dependency, exact process commands and executed binary hash, all 24 raw PASS rows, and three distinct-process reopen pairs. It verifies no source/copy drift and no SDK/RPC/identity writer/ACK execution. Every raw writer/reopen receipt must match the aggregated result. A metadata-only workflow success is insufficient.

The same existing Core194, exchange28, Cloud48, Native UI and live suites are not part of this route. Only the new creation-fence component and its real persistence semantics are selected. Windows evidence is retained for its original exact inputs; it is not relabeled as Apple evidence.

Current status: canonical composition and committed input sealing completed; one local source-only admission is next; actual Apple execution NOT_RUN. No CI dispatch is authorized by the existence of this packet.
