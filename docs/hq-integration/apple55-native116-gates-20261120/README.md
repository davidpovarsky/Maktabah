# Apple Foundation transport55 gate and Native116 preparation

## Current result and boundaries

This tranche prepares a real Apple Foundation gate; it does not report Apple55 or Native116 as passed. The final Windows source/CI run completed at 2026-11-20T13:07:35Z: 25 Python controls passed, 34 source/preservation checks passed, and 3,584 old-mode job-admission comparisons were identical. These controls use explicit synthetic receipts and two owned Python subprocesses. They invoke no Swift compiler, SDK, Hermes, network provider, or Native UI.

The historical Windows transport attempt in source13a07 remains 29/52 PASS/FAIL accounting, with 23 actual property-roundtrip failures, and its final three lifecycle controls remain separately 3/3. Nothing in this gate converts those failures into Apple acceptance. The unchanged 55 named fixture cases must now run with the observed real Apple compiler and Foundation.

The current branch starts at Root a15d3cf893cd2d4224a131154aad15ebda74f1ac, merges Sefaria13a07c8bcabc008b6c25fecc84ce13de63cea3da, and contains the separate English Rashi row correction f3401ec1597e1d882d2e2c6db9492ed211058712. Existing frozen Native60a refs were not edited. No workflow was dispatched or cancelled by this preparation.

## One strict gate, two execution routes

Scripts/CI/sefaria-toc-apple55.py verifies the requested full checkout SHA against actual Git HEAD and binds the complete eight production files, the test-only appendix, both original drivers, the wrapper, and its actual interruption helper to their immutable Git bytes before and after execution. It records actual Xcode27, selected swiftc path/version/default macOS target, macOS SDK path/version, and the selected iOS/simulator27 pair. The child driver receives the exact selected compiler through PATH and the observed macOS SDK through SDKROOT.

It runs the original full driver once, with the unchanged strict Swift6 configuration and original180s compile/20s-per-mode bounds. All three exact mode inventories are required: failure-retry26, cancel-held26, and lifetime3. A nonzero exit, missing/duplicated/failed leaf, partial mode, source override, altered input, or unverified summary fails the gate. The successful gate status is APPLE_FOUNDATION_55_PASS. The portable driver's appleSDK=NOT_RUN describes the absence of iPad SDK/app/runtime acceptance; it does not deny host macOS Foundation execution. Native, real-network, Embedded Hermes, and physical-offline acceptance remain NOT_RUN.

The driver now streams compile/runtime stdout and stderr directly to files, including before a timeout, and records each command before starting it. If a mode is interrupted, only fully verified earlier mode inventories count toward executed/passed; unverifiedPartialMode names the current mode. The new controls prove that a second-mode timeout preserves the first26 verified leaves rather than incorrectly reporting zero or55. The wrapper retains the raw copied sources, commands, case leaves, proof files and partial logs, with a hash index, including on failure. It excludes the compiler cache and executable from upload.

In the existing Sefaria workflow, the gate runs after the original toolchain selector and before the Native/Release runtime executor. The lightweight value runtime27_mode=toc-transport uses the same existing runtime27 job, executes the same full55, and skips Native/app preparation, caches, Node/Ruby and the runtime executor. The concurrency group distinguishes this lightweight run from Native. All pre-existing mode admissions, timeouts, jobs, artifact paths and Release stages are preserved.

In the normal iOS workflow, the identical gate is added to the existing otzaria-framework job immediately after toolchain selection. Both original simulator/device app jobs already require that job, so a gate failure prevents both app builds. An always-running artifact step preserves the gate evidence. Every pre-existing normal job, dependency, original framework/Pods/SwiftPM build stage and verification remains byte-identical after removing these two added steps.

## Coordinator-only lightweight dispatch

Use the existing workflow sefaria-embedded-validation.yml with a newly reviewed immutable branch and its exact full commit SHA:

- runtime27_mode: toc-transport
- hq_stage2_expected_sha: the exact immutable checkout SHA
- run_simulator_tests: false
- validation_runner: xcode-27
- ui_sdk_check_only, books_updates_check_only, hq_stage2_focused, run_production_release: false
- source_ref and ui_diagnostic_cases: empty

The artifact is sefaria-toc-apple55-evidence. Its build/artifacts/sefaria-toc-apple55/ directory contains RESULT.json, SOURCE_INPUTS.json, GATE_COMMANDS.json, real toolchain outputs, driver stdout/stderr, RAW_INDEX.json and raw/. Normal iOS uses artifact ios-build-sefaria-toc-apple55. This preparation performs no dispatch.

## Native116 selection, final source still pending

R27_CASES.json appends exactly six Core compound journeys and twelve Hebrew/English Sefaria cases. The original98 selection is an exact prefix, every original catalog row/oracle and nested metadata field reconstructs exactly, and the original per-group order is preserved. The declaration validator and original execution_groups function accept all116 unique methods:87iPad/29iPhone.

The existing seven groups now contain12,22,5,41,5,2,29 cases respectively. Only11-window retains HID comparison. All original600s per-XCTest budgets, the Release96+2 manifest and its three stages, runtime executor, matrix driver, source guards and existing source-pinned input file remain unchanged.

This is selection preparation only. The old87b application/source pin fields are deliberately preserved, and a new metadata block explicitly marks the final application freeze pending the Coordinator's AppIntent integration. This branch must not be submitted as a full Native116 acceptance before the final source pins are refreshed by the Coordinator. The lightweight host55 gate binds its own actual checkout and does not claim full app-source acceptance.

The new Core cases retain source-bound counts, canonical commentary/draft continuation and an authoritative no-commentary refusal. The new Sefaria cases retain actual Embedded mobile TOC/canonical navigation plus separately scoped Remote transport failure/retry. Their full oracles and prerequisites are in the appended catalog rows. Physical offline, VoiceOver speech, physical performance and external providers are not substituted by these cases.

## Evidence and review

ARTIFACTS.json binds every compressed raw artifact by compressed/raw SHA256 and size, plus current source inputs with separate raw and canonical-LF hashes. The final receipts are raw/final-controls-after-review/. Earlier successful control attempts and the exact source/driver inverses remain alongside them.

Peer review by Agent C found one local executable-input closure gap: runtime27_interruption.py had not initially been hashed. The final wrapper adds it to the immutable pre/post source closure, and the same25 controls plus all34 preservation checks were rerun on that exact final source. The review is source-only, not Apple/Native execution.

The actual Native98 run44723902453 continues on frozen60a/app87b under one finite watcher owned by Agent A. It contributes no result to this new gate or selection.
