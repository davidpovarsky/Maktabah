# Apple SDK run 44648487731: failure retained

Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44648487731

Checkout 83bc48f7b27e41d5580124a974d78bfad6ace50c; application source
ca314e7cc5d5cdde2bb15a54a79c92541296349f. Finished failure at 00:59 UTC
on 20 November 2026. The original artifact ZIP was downloaded by artifact ID
and its complete SHA256 matched GitHub's digest before extraction.

The iPad SDK XCTest compilation/code generation passed on Xcode 27.2,
including the 88 selected declarations. This is zero Native executions.
The aggregate SDK gate correctly failed because the actual SQLite test fixture
did not compile: Apple Swift 6.4 marks five DispatchSemaphore.wait calls as
unavailable in async contexts. The five diagnostics point to the fixture,
not the production SQLite wrapper. SQLite runtime assertions were NOT_RUN
in this attempt. The prior Windows 26-case execution remains separate evidence.

The original artifact and compressed compile log preserve the failure.
VERIFIED.json records the exact partial results: 15 Hebrew matcher,
17 Inspector owner, 8 legacy Hanlin contract, 11 original filesystem-store,
and 28 API1.2 host contract assertions/tests passed at their documented boundaries.
The Hanlin tests preserve actual SDK modules with explicit authority/native
doubles; none is original-chat/provider/Native acceptance. The UI compiler
reported 2,504 warnings; no warning-free aggregate is claimed.

A bounded nonblocking async fixture repair is in progress, preserving all
original assertions and deadlines. The gate requires another genuine Apple
run on a new immutable checkout. This failure is not overwritten by that run.
No full-app, Native88, Release, physical-device or TestFlight acceptance follows.
