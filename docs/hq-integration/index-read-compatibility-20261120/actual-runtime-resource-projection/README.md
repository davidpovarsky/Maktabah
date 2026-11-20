# Actual runtime resource projection — 20 November 2026

The original producer265 and candidate d5 C binaries both report exactly two required resources: Acronyms.json and dictionary.json. The authenticated published index manifest also records the optional lexical.db, for three manifest resources. The prior candidate policy mistakenly required all three in runtime build information and producer identity.

This correction compares the runtime and retained producer identity with the exact two-resource projection actually reported by those binaries. It still requires the complete original three-resource manifest in the candidate predicate. It rejects fabricated optional-runtime-resource claims, either missing required resource, changed hashes, wrong producer/consumer revisions, and all prior provenance failures. Installation and recovery retain producer265; no consumer restamping is introduced.

qualifiedContracts remains empty. No engine pins, build scripts, workflows, published manifests, availability or activation are changed. No new callers are added. Only the two policy predicates above change; the original installer, recovery callers and writer checkpoint/seed methods are unchanged.

## Actual validation

| Same fixture and runner | Passed | Failed | Skipped |
|---|---:|---:|---:|
| Prior policy at 2ba5b080 (RED attempt 3) | 92 | 7 | 0 |
| Corrected policy (GREEN) | 99 | 0 | 0 |

These are 99 portable Swift cases, using the actual complete policy and extracted original installer/index-manager methods, real Swift Codable/filesystem/cancellation, and explicit controlled FFI/storage/profile boundaries. They do not execute native Apple UI or prove old-index runtime compatibility. The independent old-index C/runtime/SQL qualification is separate and still in progress at this commit.

The first RED preparation failed to compile because of fixture variable errors; the second timed out during compilation at 120 seconds. Both executed zero cases and their raw logs are retained. Attempt 3 and GREEN use the same corrected fixture, same runner, one compiler job, and a 300-second compilation ceiling. All seven genuine RED failures and all 99 named GREEN results are retained.

The original search/readiness regression is **not rerun yet for this correction**, pending the sole compiler slot. The earlier run belongs to the earlier policy source; it is not reassigned to this change. Apple SDK, Native and physical-device validation of this correction are **NOT_RUN**.

## Evidence integrity

VERIFICATION.json maps every retained file to its original byte count and SHA-256 and to a deterministic gzip's SHA-256. Original raw results and logs are not rewritten. The actual C build-information fixture includes the binary/consumer/log provenance; its full raw bytes are also retained. Source snapshots preserve the tested byte hashes independent of checkout line-ending conversion.
