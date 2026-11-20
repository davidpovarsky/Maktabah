# Actual Focused4 v2 failure, 2026-11-20

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44807261790

The actual run at F `8bb0ab7e87895a85265132188ede021cef3a08ae`, application/test M `409519a6972783990a276ade0dbdc4703bb36ae4`, attempt1 finished FAILURE. The original full application build passed. All four selected Native cases completed: three passed and Reduce Motion failed, with zero skips and zero unexecuted cases. No full Native116, Release114 or release approval is granted.

## Actual leaves

- Inspector landscape: PASS,64.42490100860596 seconds.
- Inspector portrait: PASS,53.39760196208954 seconds.
- Reduce Motion: FAIL,241.51282906532288 seconds. Original selected test reports line595: the open palette, search input and real result did not settle inside the native window.
- Original Core commentary/source preservation: PASS,107.97477900981903 seconds.

The native run had a600-second per-case bound; this failure was an assertion, not that bound. The actual20-second palette settlement assertion remains a failure. The prior v1 failure remains independently retained. The v2 outcome is not relabeled after a later test correction.

## Evidence and verification

`ORIGINAL_EVIDENCE.zip` is the complete authentic artifact14670442656,11,255,807bytes,SHA256 `d0c4805b46ae132b3007388ba590947f95624a68bf3c264d3be1381cc5be2cfe`; all150 ZIP entries passed CRC. Run/jobs/artifact API metadata, actual terminal job log and exact canonical F tree are retained here.

The complete capture artifact14670143892 is retained on GitHub and was downloaded locally:125,174,360bytes,SHA256 `c842d4706b51fa22efb1a72e74d9bde798b26be267aa6e74f333b97a6e62886e`; all1507 ZIP entries passed CRC. It is not duplicated inside this source-control packet. Matched raw Motion AX/screenshot evidence is separately retained with its source correction.

Run `python -B verify_evidence.py VERIFY_CONFIG.json` for a read-only replay. It checks actual raw XCTest leaves/logs and preserved pass/fail counts;232 before/after execution inputs and1244 distinct original product/execution entries against exact Git blobs/sizes;1004 actual product inputs; original CocoaPods privacy aggregation and every added reason against its retained dependency input; original package checkout cleanliness. This replays evidence only and executes zero new Apple/Swift/Native tests.

The initial local review assumed one post-UI privacy audit entry; the unchanged original helper actually appends a second byte-identical audit entry. The verifier now explicitly requires exactly those two identical entries, validates the full generated privacy bytes and dependency reasons, and does not suppress a distinct change. No product or CI evidence was modified.
