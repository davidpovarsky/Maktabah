# Native Intent lifecycle and final visible acknowledgement — 2026-11-20

The original Native75 run44559352638 failed background Search/book App Intents before foreground scene readiness. A separate Inspector case rendered its original visible panel but failed its final acknowledgement during asynchronous layout publication.

## Changes

- Resolve only the user-selected mounted system entity, await that exact existing scene activation within the original bounded lifecycle mechanism, then perform fresh execution discovery. No first-window fallback, scene creation, grant, route or receipt is issued during this wait. Cached book intents apply the same exact-window barrier.
- Observe the actual visible scene and the retained synchronous backend in one MainActor turn after native visibility. Explicitly preserve the original backend/generation/RPC snapshot equality check and every original Core completion, source binding, authority revision/lifetime, driver/token, cancellation/deadline and exact-route check. An uncertain UI effect remains nonretryable.
- Five new Intent regressions exercise exact identity, fresh authority, replacement-window refusal, missing entity refusal and cancellation.
- Four new final-observation tests exercise ordinary layout publication, changed/missing witness, revoked/remounted admission and cancellation. Six existing adversarial injections now run at the actual synchronous boundary with explicit assertions that each injection occurred.

## Executed evidence

Windows Swift6.3.3, strict concurrency, full original UIRoutingHost package. Attempt1:125 passed,2 failed,0 skips. Preserve its raw report: one original backend-status guard needed to be retained explicitly; the new revocation test needed separate exact unavailable/replaced-lifetime status oracles. Neither failure was a Native UI test.

Attempt2:127 passed,0 failed,0 skipped,0 compiler warnings/errors; tests23.039s, incremental command58.75s. Input hashes show no source drift. Exact command and full raw logs are in attempt-2. These are portable contract tests with explicit native boundary doubles, not Apple SDK compilation or Native UIKit acceptance. The existing background/Inspector Native cases remain required in the78-case integrated matrix.
