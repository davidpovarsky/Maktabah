# Original regression on the corrected policy

Source commit: 6968a3db1bf31d5aef387fea5014892a8fc31e9b.

The original tools/hq-search-tests.py completed at 2026-11-20 04:07:44 UTC with exit 0 in 48.188 seconds. It reported **191 portable search assertions** and **14 real-repository cached readiness assertions**, both PASS. These are assertion counts, not 205 test cases.

The original driver, fixtures and production sources were not edited. The owned execution wrapper injected only swiftc -j 1 to serialize compiler work under the host memory budget. Every original/actual command, source digest, unchanged driver/policy digest and raw output is retained. The existing redundant Sendable conformance warning is preserved.

The search fixture uses real models/wrapper/session with FFI and Combine doubles; the cached-readiness fixture compiles the real repository with explicit FFI/storage doubles. This does not claim Apple SDK, Native UI or actual index qualification. The compatibility registry remains empty.

VERIFICATION.json contains the observed result and original/gzip SHA-256 ledger. The earlier README's pending regression status describes the earlier source commit moment; this follow-up resolves that specific pending check on the exact corrected source.
