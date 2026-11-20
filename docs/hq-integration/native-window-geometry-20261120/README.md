# Correct actual moved-window geometry

The retained Release run 44665679661 exposes application snapshot (0,0,375,486) while the actual native window is (418,117,375,486). Its original toolbar actions are inside that window and toolbar, but outside the application snapshot. This is an observed coordinate-space defect in the acceptance harness.

Only FaithfulReaderUIAcceptanceTests.swift changes. The common action/palette/bottom-toolbar/capture bounds and actual window gesture/resize/restoration use app.windows.firstMatch, the same actual native window already used by R27. Restoration taps the exact public SpringBoard window-controls identifier present in the retained failure hierarchy. No guessed application-relative point remains.

All 386 XCTest assertion calls, original viewport and source/pixel anchor checks, locator/text/selection checks, unique/hittable toolbar actions, real resize delta80pt, restore tolerance2pt and original native timeouts remain. Exact inverse review proves all other source bytes unchanged. R27, application source, SDK, manifests and original acceptance scope are unchanged.

Actual verification: retained AX rectangles were decoded from their committed lossless originals; both toolbar buttons fail the old coordinate bound and satisfy the actual native window and toolbar bound. This arithmetic is evidence analysis, not a new Native test. Cross-target Swift syntax parsing returned0 with2 expected Windows SDK warnings; Apple SDK typechecking and Native execution remain NOT_RUN. An independent source review found no blocking type/lifetime issue; the original main-actor restoration wrapper is retained.

The old cleanup actually ran and reported its native control unavailable. It was not skipped by XCTest. Its failed restoration left the following R27 case starting in a compact window. Existing R27's strict wide-start assertion is preserved; no expected viewport or test oracle was weakened.

Original evidence: docs/hq-integration/release96-44665679661-20261120 at f2a4eef9004710be8040e183d8713dc28f73c2c7. Exact paths, raw hashes, frames and the public system control are recorded in ACTUAL_AX_GEOMETRY.json.

New full-source freeze and real Apple/Native rerun are required before any acceptance credit.
