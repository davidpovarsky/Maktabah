# Whole app occurrence adapter: actual OFF-registry acceptance

**24/24 cases passed** on Windows at source `9080bc07dfb919d10aa86b40b723125f47901cc7` (the `cea3734e` owner correction plus the same reviewed `6968a3db` resource-policy commit). Compilation and runtime both returned exit 0. SentinelX job `job_7494a4cf2f0a` completed at **2026-11-20 04:12:38 UTC**. Total driver time was 179.39 seconds; the actual Swift build reported 153.94 seconds. No compile warnings were emitted. The first test attempt passed; the evidence copier's later JSON/Python literal error and recovery are recorded separately in `SUMMARY.json` and do not represent a test execution.

The driver compiled 15 complete production Swift files, the original Core package and resources, and the complete original SQLite connection. The original AccessController prefix was byte-identical; the approved same-file appendix only exposes its actual private initializer/publication method in the copied fixture. Every production file, fixture source, original Core file and official dependency checkout was checked again after execution. The actual C library remained SHA-256 `7f23e3e87aa604b410f9cd21f1b56aab2d30596c697d46c8fb19ad160e34c7a0`; the linked executable was `968131fbdc9c88c3627a23fa2123e3dda87c50e047514cca218e8d20745e7381`.

| Executed behavior | Evidence |
| --- | --- |
| Actual linked C source and original producer identity | Fork `d5d59d12…` reported by the compiled bridge; installed identity retains original producer `265a14ea…` |
| Complete mini and full manifest authentication | Both original Codable digests matched the source pins; legitimate re-encoding remained accepted |
| Manifest tampering | 20 nested changes, including resources, source DB, parts and an added semantic description, rejected |
| Scope and query contract | Canonical positive UInt64 IDs and the 200-work boundary accepted; duplicate, noncanonical, foreign and unsupported scopes/modes/units rejected |
| Original selection owner | Actual initial/publish/clear/same-pair/ABA behavior passed; 16,000 concurrent publications and 24,000 coherent observations had no torn pair or lost increment |
| Counter lifecycle and source | Unknown/external/noncanonical source, expired deadline and pre-cancelled task returned no scalar |
| Metadata limits | Each of three original metadata files tested empty, malformed, absent, oversized and nonregular; invalid inputs remained unavailable |
| Actual OFF registry | Valid authenticated metadata and an eligible actual producer/consumer pair could not enable counting; discovery/count did not open an engine |

The runner required the exact 24 unique names in `Tests/HQ/occurrence-app/CASES.json`, including their order. `runtime-result.json` contains each actual case result; `verification.json` contains commands, source inventories, dependency provenance and artifact hashes. Raw resolve/compile/runtime logs and full source snapshots are retained in compressed form. `Package.resolved` records the immutable official Crypto/ASN1 dependencies; no application dependency was added.

## Input integrity

One owned miniTest10-v6 copy was made: **15,470,592 DB bytes + 14,665,801 original index bytes = 30,136,393 bytes**. Source and copied payload hashes were checked before/after the copy. The owned DB and all seven published index payload hashes were checked before/after this run and remained equal. The pristine input was never engine-opened. The original DB SHA-256 is `d3d9bfcc2320a987a0391ad23fa72abcf6fd1fa0f3cba95adc05096e05a9edef`.

The retained independent mini SQLite oracle (`INDEPENDENT_MINI_SQL_ORACLE.json`, SHA-256 `d5879e40e597963616499fbc181eedba3c5c09745d460b03b2e57077f41c5be8`) was authenticated and decoded, but **no positive app count was executed in this OFF-registry run**. It is available for the separately qualified follow-up. The whole full-v32 manifest was authenticated as metadata; no full corpus was copied or counted here.

## Remaining gates

The production qualification registry remains **OFF**. Nine positive/qualified cases were prepared and actually typechecked, but were **not run**. Their 32-case follow-up combines 23 shared cases with nine coverage/real-count/lifetime cases; it is an alternative suite and is not added to the 24-case total. It may run only after root's separately reviewed qualification source is present.

This fixture calls the trusted app Counter directly through real Core DTOs. **Core permission admission, Apple SDK, Native UI, physical devices and full-v32 managed app counting are NOT_RUN by this tranche.** The exact app-shell boundaries and approved owner appendix are documented in the fixture README. No user index, public bookmark/defaults flow, recovery, download, reindex or user-data mutation was performed by these cases.
