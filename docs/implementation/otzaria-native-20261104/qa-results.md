# Verification evidence

- Portable production Swift component contracts: 497/497 assertions passed, including 87 key/hash assertions for all 43 pinned RefKey fixtures and actual total/group-count pagination rules. These are not Apple SDK or Hermes evidence.
- Production JavaScript dispatcher fixtures: 23 passed. These exercise production dispatch/mapping and explicit offline/remote fixture transports, not a Hermes runtime.
- Real native SQLite/zstd production-repository fixtures: 51 assertions passed against minimal fixtures and the authenticated v36 mini database, including all seven original footnote lines, Hebrew edition metadata and true edition IDs. The line_alt_toc coverage assertion also passes against canonical rows and rejects a foreign book.
- Rust locked native tests: existing stress test over 1024 bounded engine lifetimes passed; schema10 SQLite source and snapshot/memory ABI tests passed (2/2); corrected schema10 compatibility/grouping test passed (1/1). No production semantic mock enabled.
- All 15 focused Rust bridge tests pass (the already-passed 1024-lifetime stress test was not repeated). New native Rust cancellation test passed: cancellation completes with the engine mutex held; exact/fuzzy/advanced search and counts honor the cancelled ID; a different ID is unaffected; the registry survives engine close safely.
- C header/Swift declarations/Rust exports: all 32 symbols match.
- Upstream checkout exact pin and committed resource hashes: passed; checkout pristine.
- Strict unchanged boundary checker against base 59b01fa2: FAIL (18 findings at b55fc1fc). Chat authorization is recorded separately; no signed approval is fabricated and no guard is weakened. See owner-approval-proposals.md for exact origins and protected scope. This check is not claimed green.
- Initial iPad CI 42449700127 built app/test binaries and launched app; cancelled during UI tests to replace shared simulator selection with a run-owned simulator. UI acceptance is NOT VERIFIED by that run.
- Native CI 42454286791 built all three Apple Rust slices; the fixture compile then failed because ZSTDContextWrapper.swift was missing from the harness input (corrected).
- Native CI 42456093752 passed the native SQLite fixture stage, then failed app compilation on BackendComposition OptionSet inference (corrected). Its run_simulator_tests=false dispatch cannot establish UI acceptance.
- Mini database preparation [42456560269](https://github.com/davidpovarsky/Maktabah/actions/runs/42456560269) passed: authenticated v36 download, identical raw/compressed subset built twice, foreign-key/integrity and table parity checks.
- Current app/SDK diagnostic: [42458201624](https://github.com/davidpovarsky/Maktabah/actions/runs/42458201624), source 23d98a7d, not yet complete and not final-candidate coverage.
- Current full schema10 artifact generation: [42458333213](https://github.com/davidpovarsky/Maktabah/actions/runs/42458333213), source 99474b5c, not yet complete.
- Final combined branch, production archive, upload and App Store Connect processing: pending. Physical-device QA: not verified.

Local logs are ignored under build/integration-verification. CI evidence must be linked after the final run; this file must not label a cancelled run as passed.

The original 115 acceptance cases are tracked individually in acceptance-matrix.json. Unexecuted UI/device/performance/legal cases remain NOT_RUN; original religious substitution and the explicitly deferred delta phase are marked BLOCKED rather than counted as passed.
