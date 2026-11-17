# Standalone SDK scope correction

Run [44201962404](https://github.com/davidpovarsky/Maktabah/actions/runs/44201962404)
at c59a00a1 failed its aggregate SDK check. Actual XCTest source compilation
passed (2,298 existing actor-isolation warnings; no UI execution).
The standalone toolbar list still included two entire sidebar files after
those files acquired real app workspace/lifecycle dependencies. Those
dependencies were absent from that standalone module. The script also still
targeted iOS 18.6 while this continuation's product minimum is iOS 27.

The correction uses the iOS 27 target for all SDK compiler invocations.
It compiles every original self-contained toolbar/tab source unchanged,
plus the exact native split configuration and sidebar search/title adapters.
The two app-composed full sidebar files are explicitly recorded with their
hashes as REQUIRES_FULL_APP_BUILD. They are not replaced by model stubs.
The existing app-membership, full app/build-for-testing, and Native acceptance
gates remain required. An isolated SDK pass cannot certify those full files
or the app. No UI assertion, original test method, or runtime timeout changed.

The prior real app build at 837497a0 / application9a3e498 passed independently;
that is historical evidence and is not transferred to a newer source SHA.
See REVIEW.json and retained canonical SDK logs/artifact for exact boundaries.
