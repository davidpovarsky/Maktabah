# Verification evidence

- Portable production Swift component contracts: 493/493 assertions passed, including 87 key/hash assertions for all 43 pinned RefKey fixtures. These are not Apple SDK or Hermes evidence.
- Production JavaScript dispatcher fixtures: 11 passed. These use explicit fixture transports, not a Hermes runtime.
- Real native SQLite/zstd production-repository fixture: initial 16 passed; expanded cases pending at this checkpoint.
- Rust locked native tests: existing stress test over 1024 bounded engine lifetimes passed; schema10 SQLite source and snapshot/memory ABI tests passed (2/2); corrected schema10 compatibility/grouping test passed (1/1). No production semantic mock enabled.
- C header/Swift declarations/Rust exports: all 29 symbols match.
- Upstream checkout exact pin and committed resource hashes: passed; checkout pristine.
- Initial iPad CI 42449700127 built app/test binaries and launched app; cancelled during UI tests to replace shared simulator selection with a run-owned simulator. UI acceptance is NOT VERIFIED by that run.
- Final combined branch, production archive, upload and App Store Connect processing: pending. Physical-device QA: not verified.

Local logs are ignored under build/integration-verification. CI evidence must be linked after the final run; this file must not label a cancelled run as passed.
