# Official release identity controls

Product commit: 47261ccf6b3ef5005941f03206b0563f7cf79363.
Baseline source: 29a731e273f9a757c743c49e182fece0e8047d46.
Actual Apple host: Scaleway Mac, Xcode 27.0 / Swift 6.4.
SentinelX job: job_148cc2600bb1, 2026-11-26 22:45:30–22:45:43 UTC, exit 0.
Retained host path: /Users/m1/builds/otzaria-wave2-release-identity-20261127.

The unchanged 15-case fixture compiles the four original client, model and
profile source files. Baseline Debug: 9 PASS / 6 FAIL; candidate Debug:
15 PASS / 0 FAIL. Baseline and candidate Release: 15 PASS / 0 FAIL.
Both Release binaries have identical SHA256
b5e3ffd77ef0e67947fbb0ddda18946b2e415ae43a53e64500cc98a434416048.

The candidate Debug run also used the real original client against public
GitHub: release 455390662 / v40-20261123094345, manifest asset 782942035,
two archive parts totaling 2,129,902,636 bytes, archive SHA256
39a2b52129323ea53ac3629835c4721e25acff010a8fc971bf076a666a3b9587.

This is a native source-level identity and public metadata check. It does
not execute the application UI, download the whole library, establish
Native116 or prove Settings Updates. Those acceptances remain separate.
