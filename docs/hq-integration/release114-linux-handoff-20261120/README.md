# Actual Linux verification of the unchanged Release handoff

## Verified result

The original Scripts/CI/test-runtime27-release-handoff.py ran unchanged on Linux: **29/29 exact unique cases PASS, zero failures, errors, or skips**. Runtime was 2026-11-20 13:33:59.314861–13:33:59.680128 UTC (0.365327296 seconds), with the original 90-second outer bound and exit0. Interpreter: Python3.12.14, Linux6.18.57/glibc2.41.

This run is bound to exact source commit c10ce8af00fbc1fc62910c1ac06ec7a0f3d79494. It uses the same complete canonical Git files as the prior Windows projection. The source archive is388072bytes with SHA256 0c98cac2c5a94a62309c46829fbca2e1283b67f541780b19f20bf986f9724959. All87 ZIP entries passed CRC;86 are whole source/configuration files and the last is their source manifest. Every source file matched its committed Git blob before transfer and matched its recorded hash both before and after the Linux execution. No test, guard, mode assertion, framework alias, source prefix, or expected hash was changed.

The newly available Linux environment was used directly. No OS changes, runtime installation, package installation, production data access, or original Mac/simulator artifact substitution occurred. The fixture creates its original synthetic products inside temporary owned directories.

## Relationship to the preserved Windows result

The preceding source commit retains the actual Windows handoff outcome:29 executed,26 passed,2 failed,1 errored. Those results are unchanged. The same three cases now pass on the compatible POSIX host:

- test_changed_extra_or_permission_modified_products_are_rejected;
- test_roundtrip_retains_every_byte_mode_and_original_plist;
- test_internal_versioned_framework_aliases_roundtrip.

All other26 handoff cases also pass, including hostile archive/provenance/path cases. Exact expected and observed case inventories are in raw/RESULT.json.gz; the raw unittest log contains every29 leaf. There were no skips, mocks added to accommodate Windows, or passing results inferred from a total alone.

The separate original Producer13, Stages24 and Gate23 controls already passed on the Windows canonical projection in the preceding evidence. They were not rerun or credited as Linux execution here. This follow-up resolves the concrete POSIX failures by actual compatible-host execution; it does not rewrite historical failures or claim a single combined cross-platform run.

## Scope and limits

This is Python handoff/source-provenance contract verification. It is not an Apple SDK build, Native UI execution, actual simulator/macOS product transfer, production Release acceptance, or physical-device test. Those original workflow gates remain required. The prepared Release selection remains114 UI executions plus2 separate prototype oracles, with final application M assigned by the coordinator after integration.

Only this evidence directory changes in this follow-up. Production source, CI scripts, test fixtures, manifests, selected IDs, guards, pinned refs and timeouts remain identical to c10ce8af.

## Retained proof

ARTIFACTS.json binds seven deterministic gzip files to exact compressed and uncompressed SHA-256 and sizes. They include the unchanged whole-source ZIP, actual validation driver, complete stdout/stderr, exact29-case result, and both86-input inventories. For the inner source ZIP, also verify its CRC and compare every listed source member with git show c10ce8af:<path>. The before/after inventories are identical.

The initial transfer tool response was truncated before reconstruction, so the same owned source ZIP was reread in nine individually SHA-verified chunks. The final complete archive hash and CRC were verified before any execution; no truncated source was executed.
