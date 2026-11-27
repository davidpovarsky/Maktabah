# Original Annotation expansion: retain the source inside callbacks

This is one narrow follow-up to source commit `8f7142bba6efb8f4a93c4e325ee6cdb835041bb5`. That commit and all of its evidence remain unchanged. Only `iOSAnnotationViewController.setOriginalGroupExpanded` and its existing `nativeRoutingReveal` call change.

## Source defect and correction

The original helper calls `dataSource.apply`, then looks up the original group cell and updates its `ListContentConfiguration`. Diffable application can synchronously invoke UIKit layout/configuration. The existing controller publishes actual layout through `nativeRoutingPublishLayout` → the binding's `hostLayoutChanged` → the installed Session change callback. The old caller checked retained source ownership only after the entire helper returned. A source retirement or replacement inside a callback could therefore be followed by an old configuration write.

The helper now accepts optional validation, defaulting to nil. The canonical caller supplies its existing exact request/source/host validator. The helper checks that same retained source after snapshot/application and before animation/configuration writes, including inside the retained animation closure and after reading the cell configuration. Validation never captures a replacement source or grants another effect. The caller's existing throwing checks before and after the helper remain intact.

Ordinary user calls still pass the same node, expansion flag and animation flag, with nil validation. Removing the two exact edits reconstructs all 31,823 original file bytes and SHA `bf7bc1ea1bb559e02a7904dad3508fab1c265ecd07e1592365cab045aecbc714`. No other controller, Store, model, editor, Session, Core, backend, View or project operation changes.

## Actual verification and its boundary

Oracle job `job_2ffef32024b2` ran on 2026-11-27 from 18:50:57 to 18:51:02 UTC, exit 0. The exact original and candidate helper bodies were compiled with Swift 6.4.3 over explicit UIKit/domain doubles. Only the private access modifier was removed from the extracted methods so the standalone capsule could invoke them. The doubles expose the synchronous callback and retained-animation boundaries; they are not UIKit execution or an application simulator.

| Evidence | Actual result |
|---|---|
| Unchanged original helper | 3 passed, 8 failed |
| Corrected helper | 11 passed, 0 failed |
| Whole candidate iOS frontend syntax parse | Exit 0 |
| Exact ordinary-route whole-file inverse | Passed |
| Apple SDK typecheck, application build, UIKit/native tests | Not run |

The preserved failures cover retirement/replacement/ABA during diffable application, retirement during lookup/animation/configuration access, and retirement before a held animation closure executes. Positive controls retain the original ordinary nil-validation order and the current-source native expansion. No original assertion or existing native test was changed.

Actual result: SHA `1e23d72f21802c9a12e2b35d07586dec71c70cdec420e6e157e8e67f3e8e73f0`. Raw archive: 32,067 bytes, SHA `19a02a8e13ae2877e75336b19414bbf2e33e7ee58d07196f0e72147b1e2d4b60`; all 13 raw members and the manifest were verified. Full argv, PID, timestamps, original/candidate outputs, original failure exit 1, source pins, capacity checks and inputs are retained.

This source result does not change the outstanding requirement for the final original Annotation system-Intent/visible-cell acceptance on the qualified app. The separate native selectors remain pending. The first packet's editor, filters, body, tags, style, per-book and production/device obligations also remain open.

## Integration

Apply the one-file source commit after the original Annotation source packet. The documentation commit is separate. There are no new source files, Xcode membership entries, localization keys, App Shortcuts or shared wiring hunks in this follow-up. The original file's upstream header/provenance remains; the new code is the downstream retained-source boundary only. No dependency pins, upstream snapshot, owner signature, gate or validator changes.
