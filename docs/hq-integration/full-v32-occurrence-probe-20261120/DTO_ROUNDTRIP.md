# Source-bound occurrence-report encoding check

Source: 2c934bf39964e82b95367352a576e5d950eba856, based on 263e6b1357c2322226bce54dc8051007b6b12285.

## Executed result

SentinelX job job_aff1ff927b4a completed on Windows at 2026-11-20T05:42:55Z. Swift 6.3.3 compiled one standalone executable with Swift 6 strict concurrency, then executed all four declared cases: **4 passed, 0 failed, 0 skipped**. Compilation exited 0 in 5.531 seconds with no warnings. Runtime exited 0. The executable is 272,896 bytes; SHA256 96c8d04d06f0405258657b8e9f60f5f1adb8ff91faa2440e5db42e5185f41812.

This fixture uses the complete original OtzariaExactOccurrenceModels.swift, the original OtzariaSearchEngineBuildInfo declaration, and byte-extracted new ExactOccurrenceCheck/ObservedOccurrence declarations and request expression from the committed runner. It supplies explicitly synthetic transport JSON to the original wire decoder, then encodes the actual report wrapper and decodes it back to the original result model. No alternate implementation of the report projection is used.

| Executed case | Required result |
| --- | --- |
| all_observed_fields_and_original_hard_bound_request | Every decoded result field survives exactly; the original request retains version, mode, query, root facets, no book restriction, timeout and all four hard bounds. |
| missing_delete_stamp_retains_semantic_nil | A missing optional delete stamp remains nil while a different segment's nonzero stamp is retained. |
| zero_delete_stamp_remains_distinct_from_nil | Zero remains a present stamp and does not become nil. |
| uint64_max_identity_and_delete_stamp_are_lossless | UInt64.max request token, generation and delete stamp survive without floating-point conversion or truncation; segment order is unchanged. |

Every case compares the full original result using its original Equatable conformance, including distinct observed counts, source strings, work counters and ordered segments. The complete generated input and exact executed launcher are retained below; the command and source hashes are in RESULT.json.gz.

## Boundaries

This is a synthetic-boundary DTO encoding test. **No C ABI, search engine, index, Apple SDK typecheck, UIKit, Native test or full-v32 count was executed by this fixture.** Its synthetic values are not corpus evidence. The real full-v32 numerical oracles remain the independently recorded SQL artifact cited in README.md, and the two real Swift/C probe calls still require the upcoming install/reopen Apple run.

The production runner and both original model files were hashed before and after execution and remained unchanged. No SwiftPM package, new package cache or second engine was created.

## Independent source review

The parent agent and github_native_audit independently reviewed the committed runner and reported no blocking source issue. Both confirmed that the DTO copies observed fields, the sequential bounded calls use the same original engine and its existing defer close, and later errors retain passed=false even if an earlier query produced a diagnostic result. The artifactProducer field is provenance of the validated original manifest; it is not a new claim that the probe read the installed producer identity. These reviews are source reviews, not execution results.

## Retained evidence

Raw source, launcher, logs and result are stored losslessly under evidence/dto/. RAW_EVIDENCE_SHA256.json binds both decompressed bytes and gzip bytes. SHA256SUMS.json covers the committed documentation/evidence files. The tested executable remains in the ignored build/v32-occurrence-dto-20261120 directory on the host.
