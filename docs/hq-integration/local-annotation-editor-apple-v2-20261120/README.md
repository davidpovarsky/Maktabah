# Local annotation Apple v2: complete original model closure

The first Apple run **44774181751** on exact source **1bde04bfbabbf1b1df714668785b580c9141a3b8** failed before executing the local component cases. Its local result is **0 executed, 43 NOT_RUN**, with neither local cold reopen executed. The unchanged original exchange suite independently passed **28/28** and both original process-termination/reopen checks. The final workflow gate correctly failed; the local step's `continue-on-error` summary is not acceptance evidence.

The authentic artifact is **14650065379**, 815,530 bytes, SHA-256 **55036c390406f18a1c82a49b5537b7d73885aba695fc41ad0a9b235e83423976**. All 81 ZIP entries passed CRC verification. The entire original ZIP is retained in this packet, together with the run, artifact metadata, job log, Root's independent Git proof for all 83 before/after source inputs, and its independent source review. The signed download-URL receipt is deliberately excluded.

## Exact failure and correction

The complete compiler log contains five semantic diagnostics, all `cannot find type 'AnnotationNode' in scope`, at `AnnotationChangeTypes.swift` lines 12, 13, 19, 20 and 26. The harness copied the complete original change-types source without its real model dependency. Module compilation stopped there; this first run establishes no local Swift result and does not prove that no further diagnostics can surface.

The v2 source commit is **5b0f8ef7875a373918d1e2e32f45651e1a15a11f**, parent exact 1bde04b, tree **ff685eaa3d66badca85c17411aa194fdd62e33a8**. Six files change:

- The original local driver adds exactly one `SOURCES` entry for the whole, unchanged `AnnotationNode.swift` (Git blob **aefdacf6d13ea0c13d6fde3ed0b160421006290a**).
- The existing explicit UI/catalog boundary fixture adds five synthetic `LocalizedStringResource` accessors for the original Node's generated localization names. Their English keys are checked against the unchanged original `Annotation.xcstrings` (Git blob **238e8bb2a3e2a676fb59e2af888a96e8c93553ff**). The Node itself is never doubled or edited. These accessors provide **no localization or UI qualification**.
- The Apple wrapper requires the unique original whole model, the explicit boundary and its exact original catalog dependency before compilation, and again before accepting results.
- Four source-closure controls are appended to the existing Python suite. All 28 original test methods, and all 34 original methods including fixture helpers, are unchanged.
- Source pins and bootstrap hashes bind the corrected closure. There are 28 pinned non-Core inputs, 53 unchanged whole-Core inputs and four CI inputs: 85 before/after inputs in the next Apple run.
- The workflow is bound to the new exact activation branch `codex/otzaria-local-annotation-editor-apple-reviewed-v2-20261120`. Its runner, permissions, concurrency, original toolchain selector, commands, outcomes, timeouts and artifact collection remain unchanged.

The source was published only on authoring branch `codex/otzaria-local-annotation-editor-apple-ci-v2-20261120`. Its readback and six-file Git comparison were verified; the activation ref was still absent after that publication. This packet does not activate, rerun or replace the first frozen run.

## Preserved acceptance and actual local verification

The complete original 43-case Swift file is byte-identical, as are the original exchange 28-case source and driver. The local driver is byte-identical after removing its single new source-list row. The existing boundary file is an unchanged prefix. Applying the complete six-file inverse restores every original source file exactly. In particular, no product, SQLite, ledger, editor, Core, SDK or engine code changes in v2.

Actual Linux Python execution: **32/32 passed, 0 failures, 0 errors, 0 skips**, with all 32 local verification inputs unchanged before/after. This includes the original 28 controls and four new controls that reject the observed omitted model, a substitute model, and mismatched generated localization keys, plus the corrected closure's positive check. Three Python files parsed and the workflow YAML parsed. This is source/validator evidence, **not Swift compilation**.

The local Apple limits remain 480 seconds for compilation, 30 for binary-path lookup, 180 for the 43 cases and 45 for each of three distinct executable processes. Original exchange limits and both process-termination checks are unchanged. The job remains 50 minutes, with the same 16-minute local step, 14-minute exchange step and strict final gate requiring both actual step outcomes to be successful.

The fixed original Core tree is **5d0ee482c8f10726fe3863792dac94c18e94d792**, from the reviewed b19d local-body source. It is **not** the separately corrected Core194 integration. The product source and application-source attribution remain unchanged; only the isolated harness closure and its reviewed route are corrected here.

One preparation attempt was caught before any test or publication: local file creation added a final LF to the original string catalog, which has no final newline. The full Git-blob check rejected it. Removing only that extra LF restored the exact authenticated original bytes. The failed preparation receipt is retained separately; it is not a Swift test result.

## Replay and scope

Run `python verify-evidence.py` to verify all seals, the authentic failed artifact, original source Git blobs, model/catalog identity, all candidate blobs, and the complete inverse. `--replay-python` reconstructs the exact source closure in an owned temporary directory and reruns the 32 Python controls. No network access, compiler, SDK or original user database is needed.

Candidate Swift/Apple execution is **NOT_RUN** in this packet. There is no app launch, native UI, Anytype mount, live CloudKit/account operation, cross-app delivery or physical-device claim. The separate CloudKit ownership proposal remains unmodified and outside this frozen source.
