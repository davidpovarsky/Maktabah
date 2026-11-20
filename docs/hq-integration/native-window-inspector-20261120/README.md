# Native Window/HID: use the original compact toolbar action

## Result and acceptance boundary

Two verified Native88 iPad cases failed when the tests required `reader-study-toggle` to be a direct toolbar button in a real 375pt window. This change resolves the original action through either its directly visible button or the actual native top overflow. It changes two test files only. There is **no product, routing, state, window-size, HID, or acceptance-oracle change**.

**Candidate Native execution: NOT_RUN (0).** Windows syntax parsing succeeded; it is not Apple SDK typechecking or runtime evidence. Root must run the focused current-source Native diagnostic to establish that opening the original overflow exposes the action and that the existing Inspector/locator/restoration checks pass.

## Actual failure evidence

Run [44657116407](https://github.com/davidpovarsky/Maktabah/actions/runs/44657116407) checked out `fe4df7c39aec242d00046bc454c81963ba4285a0` and tested app/test source `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`.

| Original case | Narrow actual state | Same process after wide restoration |
| --- | --- | --- |
| `testNormalBootstrapNativeWindowResizePaletteAndInspector` | PID 79692; window (418,117,375,486); original reader locator `otzaria\|book:3891\|line:522`; native `TopOverflowBarButtonItem`; no direct `reader-study-toggle` | Window (0,0,1210,834); same reader locator; `reader-study-toggle` with original Hebrew label |
| `testNormalBootstrapPaletteHIDComparison` | PID 92508; same actual narrow bounds and locator; native top overflow; no direct Study button | Same PID/locator; wide window; original Study button visible |

`ACTUAL_NATIVE88_OBSERVATIONS.json` records exact attachment names, hashes, source region, localized catalog entry and the inference boundary. The four original AX attachments are preserved losslessly in `original-ax/`. The full source-bound run evidence and selected capture ranges are committed separately in [982793cbdc14aa910a8b164ab1a4956b7d8e775f](https://github.com/davidpovarsky/Maktabah/tree/982793cbdc14aa910a8b164ab1a4956b7d8e775f/docs/hq-integration/native88-44657116407-20261120).

The old run did **not** open the top overflow. Its AX/screenshot proves the direct-selector assumption is wrong in the compact toolbar; actual menu action discovery and activation remain the next Native gate.

## Test change

`FaithfulReaderUIBase.originalStudyToolsActionInWindow()` waits up to the existing 15 seconds for either a visible direct action or native top overflow, then takes a fresh snapshot. It requires a unique element, hittability, containment in the current actual window, and the exact source-owned Open Study Tools label. If needed, it opens the unique navigation-bar `TopOverflowBarButtonItem` exactly once, then waits for the original action by its exact identifier/localized title. It records the resulting real hierarchy.

The two R27 cases call this helper and still use their unchanged `tapInWindow` ownership/bounds checks. The compact-window Release flow uses the same original action. It closes the actual Inspector through its original `torah-inspector-close` control, with added existence, hittability and window-containment checks, because a dismissed overflow item is not a persistent close button.

No retry, coordinate fallback, generic button selection, synthetic command, product priority change, or window widening is introduced. All existing real HID input, palette removal, panel/tools, text/locator, selection, and restoration assertions remain.

## Verification and review

- `SOURCE_PRESERVATION.json`: the exact inverse of the helper and approved call-site changes restores both complete baseline files byte-for-byte in Git LF form. Baseline is `f064b5517f560e2b52838bf321214baa3fb09e2c`. All production files remain unchanged.
- `git diff --check`: passed.
- `SYNTAX_PARSE.json`: initial syntax-only parses of both files exited 0; two cross-target warnings per file are retained.
- `SYNTAX_PARSE_REVIEW_CORRECTION.json`: the corrected shared helper was parsed again, exit 0; its two warnings are retained. The R27 source did not change after its first successful parse.
- Independent source review identified a direct-button delayed-appearance gap in the first draft. The candidate now waits for direct OR overflow together before choosing. The reviewer found no other blocking source issue. This is source review, not Native execution.

The R27 Git-LF SHA-256 for Root's strict `runtime27.py` source pin is:

`53f9db5b97784b9003eacf1bafc69e51bb64dd0580e426f0d8a17d32f4d9de9b`

Root owns the pin update and integration. This branch does not alter it. The Faithful helper/compact-window hunks are independent of Root's Profile editor and Global History changes.
