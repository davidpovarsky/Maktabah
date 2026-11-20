# Authenticated Apple framework evidence — run 44661774024

This records the original artifacts from producer commit 99f7927e4da72f2463417f5c2de2c4d20c6aa168. It does not activate index read compatibility, change framework pins, or claim the complete workflow passed.

## Actual producer outcome

The Otzaria framework job **136041463727** and Zayit framework job **136041463406** completed successfully. The original Otzaria build, semantic host verification, framework upload, and pinned/pristine upstream confirmation steps are preserved in raw/producer-jobs.json.gz. The Swift package resolve job **136041463763** failed; the workflow summary job failed and device/simulator/native bootstrap jobs were skipped. The complete workflow therefore remains **FAILURE**.

- Original run: https://github.com/davidpovarsky/Maktabah/actions/runs/44661774024
- Original producer: https://github.com/davidpovarsky/Maktabah/commit/99f7927e4da72f2463417f5c2de2c4d20c6aa168

## Authenticated archives

Both archives were downloaded once via the authenticated GitHub connector, then checked for the exact byte count and full ZIP SHA-256 reported by the artifact API. They were retained in the owned scratch evidence directory, not committed to Git.

| Artifact | ZIP bytes | Full ZIP SHA-256 |
| --- | ---: | --- |
| Otzaria 14596463166 | 201,330,360 | efc73de90d74fdd380ffecfa334fe9dcece38519832b89cf3fb2a5741dcc25ad |
| Zayit 14595389912 | 123,727,544 | 64f4ba7b8d6cfced525732699fd1958ca0cc5ec836369dcf839d91df855914d7 |

The parsers stream each ZIP member and tar member. No library or framework was extracted to another full copy. The retained raw proof hashes both the tar and static libraries, parses the actual BSD archive symbol table, resolves each required defined symbol to a Mach-O object, and records the platform load command of that object.

## Binary findings

All **28 declared Otzaria C exports** are defined in each of the three architecture slices: device arm64, simulator arm64, and simulator x86_64. This includes all four new request/count exports. Each slice contains the exact d5d59d1269bdf87fb0a6901cf31941726a0c699b engine identity, original upstream base 265a14ea54f959a3e266d6e8acfa3a3b98101d68, fork repository, and branch strings. Actual object load commands identify platform 2 for device and platform 7 for both simulator architectures.

The two Otzaria public headers are identical, 4,474 bytes each, SHA-256 e18b589a0dbd616edb8908ed68c8fbcbb847b6501c8a879ecddcde0b6d2871de.

All **5 Zayit C exports** are defined in each of the three architecture slices. Device arm64 and simulator x86_64 use the older LC_VERSION_MIN_IPHONEOS command (0x25, minimum iOS 10); the x86_64 simulator interpretation combines the real CPU architecture with the original XCFramework Info.plist. Simulator arm64 uses LC_BUILD_VERSION platform 7, minimum iOS 14. No modern platform command is invented for the legacy objects. The legacy Intel+iOS simulator interpretation is consistent with LLVM's Mach-O reader: https://llvm.org/docs/doxygen/DylibReader_8cpp_source.html .

The first parser attempt completed the Otzaria proof but rejected Zayit's older platform-command format. Its log is retained unchanged. A narrow separate wrapper subsequently inspected the same verified ZIP and recorded the real legacy commands. Neither parser executes Apple machine code.

## Exact source relationship

SOURCE_PARITY_SUMMARY.json and the complete original raw/99f-to-52e-source-parity.json.gz compare the producer against candidate 52e530a0a0adc85bfa5ff1e59e20b4ddf618135f:

- Every preexisting entry of the complete Otzaria vendor tree has the same Git mode/blob.
- The only Otzaria vendor differences are exactly **78 added test/evidence entries** under Vendor/OtzariaSearchEngine/Tests/OccurrenceSwift/.
- The complete Zayit vendor tree is identical.
- The actual workflow, checkout verifier, framework verifier, and both framework build scripts are byte-identical.
- The original Cargo framework build does not compile the added Swift test directory.

The first documentation-packaging attempt stopped on an incorrectly assumed script filename. ARCHIVING_ATTEMPT1.json preserves that failure. The real semantic host command is inside the original ios-build.yml verification step and is recorded explicitly in the corrected summary. This was a documentation-path error; it did not rebuild, modify, or restamp an artifact.

## Scope and reproduction

SHA256SUMS.json covers each deterministic gzip member by both its stored SHA-256 and original uncompressed SHA-256/length. Decompress the parser scripts to inspect or reproduce their static archive checks against the exact original ZIPs.

These are authenticated binary/source/job observations. Apple runtime occurrence execution, the new complete app build, Simulator acceptance, and the independent full-index count qualification are **not established by this report**. The original producer identity is retained. Compatibility registry and production capability remain disabled pending the separately owned qualification and acceptance gates.
