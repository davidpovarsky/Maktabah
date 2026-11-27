# Explicit original immutable checkout environment

This follow-up repairs an actual launch-contract omission in the Oracle offline coordinator. It is source and local filesystem/control evidence only. It does not qualify a Mac run, original UI, either search package, network denial or physical offline behavior.

## Baseline and correction

The complete coordinator from `4cb7590d923746971c9ad53095feacfab566fa60` is retained as `baseline-4cb7590.py`, SHA `9ea6eeffd4bef89d6f4c8107bf356b9157484552c8a0744b6893423c46594244`. Its environment allowlist rejected an explicitly supplied `EXPECTED_CHECKOUT_SHA` and admitted a launch without it. The original frozen `source_context` requires this exact environment variable to equal actual Git HEAD. Relying on an inherited SSH environment could therefore prevent the original controller from reaching READY.

The coordinator now requires an explicit 40-character lowercase hexadecimal `environment.EXPECTED_CHECKOUT_SHA`. Before the original controller executes, the fixed Mac bootstrap reads actual `git rev-parse HEAD`, refuses a mismatch/read error, emits that observed checkout in its launch frame and explicitly supplies the same environment value to `execve`. The frame, original READY source context and final source join must all equal that value. This does not replace the original frozen-source, same-build, SDK, runtime or native checks.

`ORIGINAL_ENVIRONMENT_READ.json` preserves a bounded, read-only source examination at actual Oracle root `b2d00b4cb5f0aad21fe4dd9b660fbbc4e7b0f0e7`. It records exact file hashes and the relevant unmodified functions. The original runtime requires `FAITHFUL_RUNTIME27_IDENTIFIER`; the existing optional `DEVELOPER_DIR` has the `xcode-select` fallback. No additional launch environment requirements were found in the inspected `build_identity`, `verify_actual_sources`, route/after-UI distribution verification and image-inventory paths. Build/embed-only variables were not added to this runtime contract.

## Focused source controls

Thirteen controls pass against candidate SHA `7f40ce53485a56e327f6a09012066a8ee6d97dd4f0ce65363e30de8387110c9c`:

- The retained whole baseline reproduces both the missing-variable admission and the rejection of the explicit required variable.
- The original unmodified `source_context` function rejects a missing/wrong variable and accepts its matching synthetic frozen context.
- Both original offline phase launch contracts admit a valid explicit pin and reject missing/malformed pins.
- The fixed remote function reads the original bounded Git command; error, stderr or changed HEAD fails before any original exec. Stubbed exec receives the explicit value instead of an inherited different value.
- Actual coordinator launch/READY/final functions bind the pin. A mismatched READY cannot publish the owner-ready file.
- The exact retained root draft `887196e04b721491e629afba55ed239533d78b1f5e3da7004e9c6cf21a5f3755` source-context/FILES projection covers all eight coordinator dependencies for both original selectors, with the original 1800-second XCTest allowance. Removing `runtime27_interruption.py` reproduces the closure rejection. `ROOT_CLOSURE_INPUT.json` is a source projection of that reviewed draft, not a runtime admission or a future hardcoded root SHA.
- The coordinator and fixed remote programs parse without import-time execution.

The control boundaries are explicit: synthetic command returns, synthetic page/source fixtures and local temporary files. No actual SSH, Mac, native, PF, launchd, network denial or signal was invoked. Historical forty-three controls and source receipts remain at the original `4cb7590` checkpoint; they are not reattributed to this follow-up. Re-run historical controls against their historical source. The new script is the bounded current-contract follow-up.

## Remaining runtime boundary

The original owner coordination, genuine source/build freeze, retained installed packages, actual three no-denial exercises, Foundation probes and separately admitted Mac window are still required. A distinct pending lifecycle correction addresses interrupted-Popen ledgers and every-signal process ownership. No offline execution is permitted by this source receipt.
