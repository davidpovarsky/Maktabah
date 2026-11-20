# Existing Escape calibration: trace opt-in only

This packet changes one existing XCTest file from exact Root source `0ccfa719b301aec5bbb9bd50caec4357dc0576d5`. It gives `R27NativePadTests` a private Boolean initially false, preserves `super.readerAdditionalLaunchArguments`, and appends the existing `-CommandPaletteEscapeTraceEnabled YES` only when that Boolean is true. Only `testNormalBootstrapPaletteKeyboardDispatchCalibration` sets it, immediately before its existing launch.

The original calibration remains the same real UI sequence: open the original palette, close it with its original Close button, reopen, use XCTest Down and Up to verify actual result selection, then XCTest Escape on empty and filtered input. Every original statement, assertion and 15-second wait remains byte-identical after removing this one assignment. The whole-file inverse also proves all other methods unchanged. The original R27 launch already forwards the inherited additional arguments; its `realUI` tier, UUID namespace, miniTest10 bootstrap and scenario are unchanged.

No production handler, keyboard phase, control, observer, SDK, fixture, HID transport or test oracle changes. The existing product trace remains gated by DEBUG, its explicit argument/default, the actual miniTest10 database and valid UUID namespace, with its existing bounded metadata-only log.

## Why this measurement is needed

Original Release [44723918854](https://github.com/davidpovarsky/Maktabah/actions/runs/44723918854), F60/M87, still failed. Its Pointer/Keyboard case synthesized Escape to the actual application but the original 15-second disappearance assertion failed. Authenticated late video frames retain the palette/input. The existing log observed a foreground key-window first responder with the callback present, but no logged Escape handler/dismiss entry; its limit was not reached. This establishes an unobserved delivery boundary, not a proven UIKit phase or product-handler defect.

The private event archive's keyPhase/keyCode numbers are not interpreted as UIKit phases. Apple's public [XCTest typeKey API](https://developer.apple.com/documentation/xcuiautomation/xcuielement/typekey(_:modifierflags:)-6gaoi) describes typing a key but does not specify which UIKit callback must receive it. Async log write timestamps do not prove input latency.

In another case from the same binary, the original authenticated HID Escape was followed by both actual palette/input disappearance assertions and the dismissed attachment. That case subsequently failed its StudyTools overflow assertion, so its whole-case result remains FAIL. This narrower stage observation does not establish that the XCTest transport delivered Escape, nor identical window/query conditions. The retained [Release evidence](../release96-44723918854-20261120/README.md) and [authenticated captures](../release96-capture-result-44783201113-20261120/README.md) remain authoritative and are not duplicated.

The existing keyboard calibration was not observed in the bounded search of 325 retained log/testnode/summary files (171,106,900 uncompressed bytes). Its exact inventory is retained compressed. It is absent from both current full selection catalogs. A declaration or a source-integrity check is not an executed calibration.

## Prepared selections, not an activation

`SELECTION_PROPOSAL.json` contains two separate options for a future immutable full-app run:

| Prepared scope | Exact cases | Existing native-log collection |
| --- | --- | --- |
| Single calibration | `R27NativePadTests/testNormalBootstrapPaletteKeyboardDispatchCalibration` | Currently false; its exact collector allowlist addition must be reviewed/frozen first |
| Paired diagnostic | The calibration plus `FaithfulReaderUIAcceptanceTests/testPointerHoverClickAndHardwareKeyboardDismissal` | True through the unchanged Pointer/Keyboard collector condition |

The original Pointer/Keyboard case remains selected in both iPad 11 and iPad 13 Release114 configurations. Neither case is selected in Native116 or active Focused4. A future focused run must report its actual one or two selected cases, retain the unchanged full Native116 and Release114 plus two oracle scopes, build the actual complete app, and preserve the original 600-second per-case allowance and all 15-second case waits.

The current `runtime27.py` helper hash is already stale on Root's unfrozen integration source. A later freeze must update that original guard to the final actual R27 file, without removing it. This candidate's exact SHA is recorded in the selection metadata. No workflow, manifest, collector or pin is edited here. Active Focused4 run 44786439788 / head d5d7928 remains untouched.

## Verification boundary

Canonical source bytes are bound to Git blob IDs at the exact base commit. The read-only verifier checks every packet hash, all six retained inputs, whole-file inverse, preserved calibration body, original collector behavior and the existing selection crosswalk. It executes only the original pure Python collector predicate; it does not compile Swift or execute UI.

```sh
python3 docs/hq-integration/escape-keyboard-calibration-20261120/verify_packet.py --root .
```

**Swift parse, Apple typecheck and Native execution are NOT_RUN.** Root owns source review, integration, final pins and any later activation. No historical failed case is reclassified.
