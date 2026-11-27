# Independent source review: two full original apps

Status: **HOLD** for source/build/product admission and production acceptance.

Reviewed the complete three-file diff from `50fca60f0a773f4e415d6729b9417ff3a27c8834` through `8c0e9b21cf7f87c18383aa4fc329c65bf974d441`, including `87dfd8d0aa1cb06b418823a0c01587b9907be14d`. Exact Git blobs, byte counts and SHA256 values are in REVIEW.json. Source-only review: no controller, app, SDK or native test was executed; no credential file was opened.

## Required corrections

1. **B1 - Preserve original qualification.** The new controller only hashes caller-selected files. It does not evaluate the original source/build/SDK receipt, permits an empty product closure, and never proves that the app it installs is the app/runner named by the xctestrun it executes. Reuse `production-annotation-native.py`'s unchanged `source_context()` and `qualified_build_context()` before mutation and after execution, bind the final decoded xctestrun and actual installed image closure, and fail on mismatch. Existing ordinary controller calls these original gates.
2. **B2 - Make the new production route actually production.** The fixture helper defaults to miniTest10, and the new selector inherits `.realUI`, which explicitly launches miniTest10. Fix both the original installer invocation and the new selector's tier, then require each actual production release receipt. Keep the existing four ordinary selectors and their original realUI assertions unchanged. Add a defaulted tier argument only where the new paired creation helper needs it; cold reopens must retain the actual production arguments.
3. **C1 - Preserve cleanup as a real gate.** The new controller can report PASS after simctl delete returns nonzero. Attempt exact bounded cleanup for both owned devices, retain errors, verify absence, and publish non-PASS/nonzero if cleanup fails. Preserve the original test failure and never touch another simulator.

The exact affected lines, concrete source counterexample, original callable boundaries and proposed controls are in REVIEW.json. None of the proposed controls was executed during this review.

## What remains intact

The original edit/discard/save/update/receive and cold-reopen assertions remain. The new controller requires exactly one passing, zero-skipped test per phase, two distinct fresh simulator IDs, unchanged JSON transfer, stable note/native identity, and read-only SQLite inspection. It does not claim a local SDK response acknowledges a remote device. Raw authentication artifacts remain private and the controller does not open the recovery key.

These facts support retaining the source packet for correction. They do not qualify a native run, production v40, the full Native116/Release114 gates, or physical-device acceptance.

## Scope and reproduction

Read only the pinned Git objects for the reviewed files and original helper contracts. `SOURCE_EXCERPTS.json` retains small exact line ranges for the three findings. `REVIEW.json` identifies every full source pin. No peer source files were modified.
