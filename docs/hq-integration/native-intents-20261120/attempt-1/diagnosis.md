# First full UIRoutingHost attempt — retained failure evidence

- SentinelX job: `job_6112583dbca1`.
- Actual result: 127 executed, 125 passed, 2 failed, 0 unexpected; no source drift.
- All five new foreground-wait Intent tests passed.
- This is Windows SwiftPM host-contract evidence with synthetic native drivers, not Native/UIKit acceptance.

## Exact failures and corrective scope

1. `testVisibleWitnessCannotOutliveRevokedOrReplacedNativeAdmission` observed `unavailable(native_effect_uncertain)`, `retryable=false`, in the revoke-only case. The initial new test incorrectly required stale state. The unchanged `NativeNavigationAuthority.invalidate` removes the context, and `navigationState` explicitly throws `UIRouteError(.unavailable, "native_context_unavailable")`; the directory's live-owner validation propagates that failure. The corrected test requires **unavailable for revoked context**, **stale state for a replacement admitted lifetime**, and the same nonretryable uncertain-effect evidence in both cases. It also checks no repeated effect and that original cleanup cannot release the replacement. No success state is accepted.

2. `testBackendChangeAfterDispatchPreservesEffectUncertainty` expected the original stale-state result. Its old failure message did not print the actual result, so that log is **not evidence of an acknowledged effect**. Source review found that replacing the final asynchronous directory observation had omitted its explicit `backend == invocation.snapshot` guard. The retained receipt validation still compares that snapshot; however, its mismatch error is a different status. Root restored the exact backend equality guard before the synchronous observation, with `UIRouteError(.staleState, "backend_generation_changed")`. The existing stale-state assertion remains; its diagnostic now prints the actual result.

## Follow-up

The complete 127-test suite is rerun in `../attempt-2` with the same command and scratch cache. Do not infer that rerun's result from this diagnosis; use its raw log, source hashes and `result.json`.
