# Original editor Stage B: frozen CI integration draft

Status: reviewable source-only implementation. The new editable original SDK export is not yet available, so artifact inputs deliberately remain unfinalized and the workflow must reject them before downloading or building. No Ruby execution, exported-SPI typecheck, Apple app build, XCTest, import/reopen or production acceptance is claimed by this package.

## Frozen implementation

Apply `original-editor-stageb-native.patch` after the published Maktabah consumer source `3566e9d09939583e8ddc4d489d44add01238d8c0`. The patch SHA256 is `b23847ae9fd7b34eca44966455042b52b7c42e895ddb303a6756d0e73b64c5bf`. Exact per-file preimages, output blobs, lengths and SHA256 values are in `CANDIDATE_INPUTS.json`.

The only changed existing driver is `Scripts/CI/hq-stage2-focused-apple.py`, based on exact blob `b62897bd94ba50b21dbb3e1cc73a41ffbde472c1` at `fb6a88f4e6ac3b0bfe0adb0a8992e2b0c3af4b5d`. Its optional 14-line integration keeps the ordinary path unchanged. The original native matrix, simulator lifecycle, 600-second case timeout, strict XCTest verifier and full Native116/Release114 catalogs are not edited. Two untouched base references are included solely for reproducible review.

| File | Purpose |
| --- | --- |
| `hq-stage2-focused-apple.py` | Optional SDK admission immediately before the original single Debug Simulator build-for-testing, followed by exact built-product verification. |
| `restore-original-editor-distribution.py` | Fresh read-only GitHub run/job/artifact metadata, exact archive identities, original evidence-envelope closure and safe owned extraction. |
| `hq-original-editor-distribution.py` | Original producer prerequisites, actual product inventory, shared-runtime source closure, same-toolchain SPI compiler admission and byte-preserving app embedding. |
| `hq-original-editor-app-target.rb` | CocoaPods' existing Xcodeproj dependency; changes only Maktabah-iOS Debug search/link settings and one appended embed phase, preserving every unrelated project object. |
| `OriginalEditorDistributionAPICheck.swift` | Actual exported module/SPI typecheck, bounded to 600 seconds; never executes an account or editor operation. |
| `runtime27-original-editor-native.py` | Early Python import preflight, source freeze, one separate original annotation test, existing matrix callback, named evidence collection and original final verifiers. |
| `runtime27-original-editor.inputs.json` | Fail-closed producer/run/artifact template, not a qualified binary identity. |
| `otzaria-original-editor-stageb-native.yml` | Dedicated xcode-27 push route, one build and one original UI case, bounded evidence and cache admission. |
| Two `tools/verify-original-editor-*.py` scripts | Reproducible portable source controls; no native substitutes or fabricated Apple results. |

## Shared runtime admission

All overlapping materialized runtime package revisions must match. Hanlin is additionally checked using complete `Package.swift` plus `Sources`/resource membership and actual SHA256 bytes for HanlinAgentSDK, HanlinPlatform and HanlinPresentationSDK. Package-name or swift-ai-sdk revision equality alone is insufficient.

The old Anytype Hanlin snapshot `116cc6be0654a5d11bc56ba00e0310031107ee36` differs materially from Maktabah `e00498e33f106cc43be0476ffa2e09329c8ca300`: 17 changed compiled/resource inputs and 13 additions. `dependency-review/HANLIN_SHARED_COMPILED_INPUTS.json` preserves complete immutable Git membership/blob/mode/length evidence. That old snapshot must not be admitted as equivalent.

The coordinated new runtime alignment is Hanlin `e00498e33f106cc43be0476ffa2e09329c8ca300`, FloatingPanel `3db567a19ff81d2d3ce00399021ee87a4fccf7e0` and ZIPFoundation `22787ffb59de99e5dc1fbfe80b19c97a904ad48d`. The integration agent has published common Inspector candidate `23db0f84e88d9ee9c7053c49de86903fc7bb5785`; its affected Apple validation is run `44968013856` and was still in progress when this package was frozen. Root must review that result and align the consumer pin before finalizing the Stage B source. Current consumer `19d1b35397af4f10ae70cfb3f444c9de87383b53` is not silently treated as the new pin.

Only the observed SwiftSyntax pair is conditionally eligible: Maktabah `79e4b74a295b6eb74a8b585e3a39d29e70c1dbd1`, SDK `0687f71944021d616d34d922343dcef086855920`. The two official manifests, exact Git blob/SHA256 identities and their full union of 51 product/target names are retained under `dependency-review`. Any other mismatch fails. The original complete locks and exact macro authorization remain unchanged and bound in the receipt.

That conditional pair requires actual producer distribution and Maktabah Simulator product, symbol, load-command and import evidence. Every real Mach-O/static archive is hashed before and after. Successful full `nm -a`, `otool -L` and `otool -l` outputs are retained losslessly as gzip, with successful exit, nonempty output and actual symbol evidence. All associated product/module names must be absent. Exact embedded SDK images reuse their existing proof; other actual app images are inspected independently. After UI, the same complete image and evidence hashes are rechecked rather than repeating these commands. Missing/unreadable/changed evidence rejects admission. No runtime absence has been asserted from an old filename inventory alone.

For each app framework/resource collision, the installer compares full materialized membership, bytes and modes. An identical existing product is reused without rewriting it; any differing member or alias fails without overwriting. New products preserve original signatures and bytes. There is no CodeSignOnCopy, stripping or RemoveHeadersOnCopy. Matching source inputs are necessary admission checks; actual Apple linking and runtime behavior remain required.

## Validation already performed

| Receipt | Actual scope and outcome |
| --- | --- |
| `validation/source-controls.json` | Historical 22/22 portable controls passed for default-driver preservation, exact copy/reuse, collision and alias rejection, owned evidence, ZIP membership, unfinalized admission and exact callback selection. The distribution helper and runner subsequently received the bounded policy/preflight additions described here; this is not relabeled as a new 22-case execution. |
| `validation/unfinalized-control-followup.json` | One targeted follow-up passed after making the negative-control input independent of future finalized pins. Other unchanged controls were not repeated. |
| `validation/runtime-closure-controls.json` | Current 13/13 changed-source controls passed: runtime revision rejection, exact conditional pair, complete manifest-name derivation, full-output/nonempty-symbol admission, lossless actual subprocess retention, command failure, image identity/alias rejection, and early import preflight that never executes fixture scripts. No nm/otool or Apple execution occurred in these portable controls. |
| `validation/final-source-checks.json` | Six current Python files parsed; the 16-step workflow parsed; exactly one build and one case execution found; full 10-file patch applied with whitespace errors forbidden and all output hashes matching. Both untouched base references remained byte-identical. |

The native agent independently read the app-target/Ruby preservation, original callback cleanup, original verifier requirements and named capture/import collection. No concrete blocker was found in that read. Actual Ruby/Xcodeproj and Apple behavior remain unexecuted.

The selected Stage B path uses the original fixture installer and fixture oracle and does not invoke Hanlin's mini-parity zstandard decoder. Its early preflight checks Python 3.11+, statically follows the selected original local import closure, and actually imports each declared standard-library dependency without executing top-level fixture actions. A missing dependency fails before the app build. No speculative pip install was added.

## Finalization required before publication

1. Finish and review the genuine new original Host producer export. The old inspect-only v9/v10 artifact does not provide this API. Keep all original producer source/package/resource/signature/external-consumer gates.
2. Merge root's two actual Apple compile corrections before any Stage B build: `@MainActor` on the original pointer test that calls `sendNativeHID`, and explicit `self.add` in the escaping Settings restoration closure. Root verified that Native6 run `44962008465` failed at those compiler errors before any Native case; consumer `3566e9d` inherits that source. Root owns the precise fixes and new real-SDK typecheck preflight. Align the consumer's canonical shared Inspector pin after its affected validation; keep the other agreed shared runtime inputs exact. Freeze that reviewed descendant of `3566e9d` once. Advance the dedicated runner's `SOURCE` constant and `hq-stage2-focused-apple.inputs.json` application source plus exact Source/Vendor/project tree pins coherently. Update only the actual project blob in `hq-stage2-otzaria-test-additions.json` and its full LF SHA256 if that project proof changed. The original exclusion/producer contracts remain intact. If root's new preflight changes the stage2 driver, retain its new default logic and reapply only this optional 14-line integration against the newly recorded preimage; do not replace the current driver wholesale with the older fb6 file.
3. Populate `runtime27-original-editor.inputs.json` from the actual new successful producer: repository/run/attempt/job identities; exact successful workflow and steps; framework/evidence artifact IDs, names, sizes, digests and upload intervals; exact source; original export manifest, QUALIFICATION, OriginalSource and Hanlin receipt digests. Preserve the original raw distribution format and same Swift/Xcode/Simulator version requirement. Review any real producer schema change explicitly; do not weaken admission.
4. Run the original stage2 source preflight and exact single-case declaration selection at that final source. Review the final CI diff and commit identity. Root owns the single publication to `codex/otzaria-original-editor-stageb-native-20261122`; this draft has not been pushed or dispatched.

The dedicated workflow runs these original routes in order after source/toolchain preparation:

```text
python3 Scripts/CI/runtime27-original-editor-native.py prepare
python3 Scripts/CI/restore-original-editor-distribution.py --admission Scripts/CI/runtime27-original-editor.inputs.json
python3 Scripts/CI/hq-stage2-focused-apple.py --build-for-testing --derived-data build/DerivedData --original-editor-admission Scripts/CI/runtime27-original-editor.inputs.json
python3 Scripts/CI/runtime27-original-editor-native.py run
python3 Scripts/CI/runtime27-original-editor-native.py collect
```

`collect` is always attempted and preserves the original matrix failure phase before examining possibly absent strict XCTest results. It still fails without exactly one executed/passed case, zero failed/skipped cases and complete original owned-simulator cleanup.

The exact case is `OriginalEditorAnnotationAcceptanceTests/testSavedBlankAnnotationUsesOriginalEditorAndDurablyReopensTwoBlocks`. It must use the real original saved blank note, type two independently identified native block text views, explicitly capture/save through the existing CAS path, retain the same annotation UUID/revision receipt, perform real SDK import/reopen and observe both rendered blocks. The accepted production body is not synthesized; blank preview preservation is explicitly reported as unqualified preview semantics.

The callback collects only named qualification/export/import reports and bounded actual XCTest attachments before original simulator deletion. It does not collect wallet, account repository, broad ApplicationSupport, raw simulator container or a replacement renderer. Failure of callback capture cannot prevent the original independent shutdown/delete attempts. Full Native116, Release114, device acceptance, production rich-note editing and production preview remain separate open gates.
