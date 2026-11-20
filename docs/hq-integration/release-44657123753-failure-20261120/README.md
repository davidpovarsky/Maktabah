# Release preparation failure and preserved actual app build

Run [44657123753](https://github.com/davidpovarsky/Maktabah/actions/runs/44657123753) failed at exact checkoutfe4df7c/application7e777509. Artifact14596960766 (39,831,942 bytes) independently matched GitHub SHA256cd78d3553d5149c2b94c3ccb97ec16f0ef50351e1e3f09c7fb2a794ebde77689. Original result, source inputs, pinned SDK inventory, xctestrun and complete compressed build log are retained. The complete ZIP stays in the owned build directory; every extracted entry hash is recorded.

The original integrated app, original XCTest runner and XCTest bundle built successfully with Xcode27.2/Apple Swift6.4.2. The original build report verified888 source inputs and retained Hanlin e004. These are build/source checks, not888 tests. The report's88 declaration preflight concerns the separate phase matrix. Actual full-release UI executions and reference oracles in this failed run are both zero.

## Exact cause and review

The prepared-source row still expected Sidebar11201AcceptanceTests.swift SHA3fa01d75 from commit2c5af4e9. The actual already-integrated file is SHA69163531 at source606a48df. That reviewed change fixes category expansion through the original rendered disclosure chevron: a virtualized offscreen child no longer incorrectly implies a collapsed category; the test requires exactly one real chevron and waits for the expanded state. No sidebar paging case was removed or weakened.

The manifest now binds the actual exact Git blob. Runtime27 validates the same full manifest before restoring/building the app and retains the final producer check as well. Error diagnostics identify the specific path and expected/observed hashes. Application/XCTest/SDK code and the independent signing/release gate were not changed.

The original producer control suite actually reproduced11PASS,1FAIL,1ERROR: stale prepared-source hash plus obsolete94-case totals. After updating only the historical expected totals to the already-frozen96-case contract,13/13 producer controls passed. All23 independent release-gate controls also passed. These are synthetic evidence controls/declaration checks, not Native results.

All five configurations remain unchanged: iPad11 has54 UI+1 separate oracle, iPad13 has34 UI+1 oracle, largest-text iPad13 has1 UI, iPhone has6 UI, and full-production Release iPad13 has1 UI. Total96 UI plus2 separate oracles, with the original device sizes, data profiles, orientations, locale and exact case identities preserved. Corrected Apple execution remains required.
