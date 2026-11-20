# Original iOS build 44672943654: terminal evidence

## Observed result and source

The original normal iOS workflow completed **FAILURE** at 2026-11-20T06:35:07Z. This evidence does not describe the newer Native92/Release96/full-v32 source.

- Run: https://github.com/davidpovarsky/Maktabah/actions/runs/44672943654
- Immutable checkout: 127ee9eddc2a9aea05c45ccf41420bb0cdd47705; branch codex/otzaria-ios-build-hanlin-20261120; attempt 1.
- App source in that continuation: 461de9aaee620d4275a1676ce8e1c230eb8e27ad.
- Original Hanlin SDK: e00498e33f106cc43be0476ffa2e09329c8ca300, 424 actual source files verified in both build jobs.
- Exact Equatable macro checkout/fingerprint authorization passed; global fingerprint validation remained enabled.

| Actual job | Result | Evidence boundary |
| --- | --- | --- |
| Zayit framework, 136077948353 | SUCCESS | Framework job only |
| Otzaria framework, 136077948696 | SUCCESS | Framework job only |
| Swift packages, 136077948850 | SUCCESS | Resolution only |
| Simulator, 136087824533 | CANCELLED | Original standalone Inspector mapping executable did not finish before job cancellation |
| Unsigned device, 136087824609 | FAILURE | Actual Core compilation targeted iOS12 and rejected concurrency APIs requiring iOS13 |
| Summary, 136129445060 | FAILURE | Reports preceding outcomes |
| Native bootstrap, 136129446117 | SKIPPED | No new native acceptance |

## Simulator failure, without speculative attribution

The job started 05:19:34Z. The original xcrun swiftc -D OTZARIA_INSPECTOR_MAPPING_TESTS plus standalone executable step began 05:20:43Z and was cancelled 06:34:47Z, at the 75-minute job limit. At cleanup, the real inspector-backe process (PID4486) remained and the runner terminated it. Therefore compilation had produced a runnable executable, but this log has no completed test-case or suite result. The later simulator application build and original iPad acceptance did not execute.

The authentic job log is 39,621 bytes, SHA256 4f2c21cb530051447641455832f355e3fa26696d8cb218a0ce794082c8541789. It does not locate the blocked test or identify a MainActor/runloop cause. The separate successful Inspector-owner fixture uses a different scoped owner and explicit DTO doubles; its success cannot substitute for this entire original Sefaria/Inspector harness.

Artifact 14607866287 (simulator-build-logs) is 62,691 bytes, SHA256 75246c8b6109f42dc9f7a427d50ae5e116e528e743ee1f8ce28dd407695d22c8. Authenticated metadata binds run/head, full download matches size/digest, and ZIP CRC verification passed. It contains only SDK and macro receipts, because the cancelled test step did not tee a dedicated test log.

## Device failure and separate source fix

Artifact 14603794186 is 1,379,837 bytes, SHA256 294fd8fa4e22b6b954587d151ed025698d2161d2a1c9895f512950a14930674e. Its complete original ZIP and platform diagnosis are preserved in commit 58b32dc24b480007b98027af11ce637aff37cb00, docs/hq-integration/actioncore-platform-20261120/.

That separate fix adds only .iOS(.v13) to the original ActionCore package. Actual before/after SwiftPM manifest evaluation verified the descriptor-only change and 50 unchanged source/test/resource files. It has no Apple device or native success yet. This failed run is retained as failure; no standalone retry was dispatched.

## Native orchestration budget review

Read-only review of the existing runtime27 source found one whole-matrix timeout in each UI and Release entry point; individual XCTest allowances remain 600 seconds. A proposed 16,200-second matrix allows 4.5 hours without changing an acceptance assertion.

The Release pipeline's existing maximum stages plus that proposed matrix sum to 4,200 build + 900 prototype + 16,200 matrix + 7,200 production = **28,500 seconds / 475 minutes**, excluding setup, verification and artifact upload. A 360-minute job cannot accommodate all those maxima. This arithmetic is a scheduling limit, not an observed runtime prediction or authorization to weaken a gate.

Actual successful SDK run 44668457275, job 136063413743, identifies the same xcode-27 label as **GitHub-hosted**: API runner ID1000022357, group GitHub Actions, and setup log Hosted Compute Agent, MacCloud, image xcode-27-arm64. Its exact 3,353,541-byte log SHA256 is b6c0d29ebc9d765f8286845d4d4abebba072f5997bf3be0836ba94ce34dc4e7a. The self-hosted-runner endpoint returned 404; the positive setup evidence is the basis of classification.

GitHub's current primary documentation (reviewed 2026-11-20) gives hosted jobs a six-hour execution limit, self-hosted jobs five days, and a default job timeout of 360 minutes. Merely setting Release540 on this hosted runner does not remove the six-hour limit. A longer combined validation needs a source/binary/evidence-bound division of orchestration stages, or sufficient demonstrated actual duration inside the existing limit; no test may be skipped or a partial result promoted.
- https://docs.github.com/en/actions/reference/limits
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes

## Monitor/evidence handling

One watcher at a time owned this run. Earlier finite monitor deadlines did not imply CI completion and remain recorded. The final watcher exited 1 at 06:35:35Z and independently retained actual run/jobs/artifacts metadata. No new workflow was dispatched by collection. Raw files are gzip-compressed without changing their uncompressed bytes. SHA256SUMS.json records archive and raw evidence hashes. No app source or test oracle is changed by this evidence commit.
