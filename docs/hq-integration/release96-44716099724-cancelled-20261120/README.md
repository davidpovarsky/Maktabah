# Release44716099724 — explicit cancellation of known invalid source

Run44716099724, attempt1, checked out e9050ad8998a070c92c73a881b0d7deb6e216e88 on codex/otzaria-release96-reviewed-20261120; application/test source was c6542e412fb5b052d182aacbea685c62bdf8440c.

The independent Native98 run44716092729 had already reported three actual Apple Foundation argument-label errors in GlobalSearchNativeAcceptanceTests.swift and no UI execution. Root verified every retained source excerpt/hash proving that Release mode builds the same complete original XCTest target before the matrix. Runtime selection cannot remove these calls from compilation.

Root sent one ordinary cancellation request at10:47:14UTC. GitHub completed the original build job136219795730 and workflow as CANCELLED at10:47:47UTC. No force cancel or retry was sent. The original finite watcher observed termination at10:48:15.750585 and completed its post-run capture at10:48:17.991583. Its workflow_cancelled=false field means that the watcher itself did not cancel; Root's separately retained explicit cancellation request did.

The original artifact14622172381 runtime27-release-build-evidence is retained unmodified:1243137 bytes, SHA25698ece3597c7d1a1c3607a4f13e1826f5fc12bb5473c7685cc4914c85c12ca20b. All62 ZIP members passed CRC. The checkout.txt source is exact. The18.66MB compiler log ends during app compilation; it contains no final build-success/failure marker and no compiler error. This is distinct from the actual Native98 error log: the Release build was stopped before that known test-source diagnostic was reached.

There is no runtime result.json, xcresult, prototype execution report, capture or UI execution evidence in this artifact. No Release UI success or failure is fabricated from the cancellation or from absence of a report. The original96UI+2-oracle contract remains unqualified. Subsequent exact-source rerun44723918854 uses corrected freeze60a57972acb28739ec738565083bf17fb7503028 / app87b783ac3f0257e8461762e0ea9dfa5248dd06e8.

RAW_FILES.json retains original byte hashes for API records, both cancellation and watcher receipts, the source-closure proof, logs and Root's independent artifact review. No raw record was silently rewritten.
