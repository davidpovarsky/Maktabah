# Early full unsigned application build — 44676269427

**PASS for the original full workspace build on the exact early source.** GitHub run [44676269427](https://github.com/davidpovarsky/Maktabah/actions/runs/44676269427), attempt 1, completed successfully. Its executed job `136088741213` built the original `Maktabah.xcworkspace` / `Maktabah-iOS` scheme for arm64 iOS Simulator, Debug, with signing disabled. The four other workflow jobs were skipped. No Native case, app launch, simulator runtime acceptance, signed archive or distribution ran here.

The tested checkout is `f7c110da7f35a1043c1ad6da777cb89fa6d07460`; application source is `34c7ab5ae026a0d3d08f02a2c97ddf4b38e1a56c`. The read-compatibility registry was **OFF**. This result does not cover the later qualified registry, App Intent/TOC fixes, full-v32 occurrence probe, or current frozen `b07f229e` source.

## Authenticated artifact and actual output

Artifact `14606375008` (`hq-stage2-focused-apple`) is 1,091,125 bytes, SHA-256 `2899854c7566fc11266ce3ddaef0e80a7421253fdf4a34c025cb6df9c3b4c4f7`. Its exact original ZIP is retained in `raw/14606375008.zip`. All 30 ZIP members passed CRC verification and have independently recorded SHA-256 digests. API run, job and artifact metadata bind the archive to the exact run/head/attempt.

The original 19.5 MB compiler log shows both XCFrameworks processed for iOS Simulator, actual linking of `Maktabah.debug.dylib` and the `Maktabah` executable, validation/touch of `Maktabah.app`, and `** BUILD SUCCEEDED **`. The build used Xcode 27.1 (27A9275), Apple Swift 6.4, iPhoneSimulator 27.1 SDK, and the original real React/CocoaPods workspace. The archived log and result, not an independent retained executable hash, are the built-app evidence: the artifact deliberately excludes DerivedData and the app executable.

The original reviewed JavaScript overlay was rebuilt through Metro and its 3,268,663-byte bundle copied into the app. The runner independently checked the copied app bundle against the rebuilt bundle: both SHA-256 `6ed1fee31285b96164acc8a17ab1d9d97cbde1394e8dcdd3a1d557fe0ce377ce`. Original Sefaria gitlink `2fd173a5a3bd32d94a9ba1222e4e32a37f6bd23c` and original resources are recorded; no book database payload was part of this build.

## Input and original source preservation

- **995 unchanged tracked Git blobs** independently match immutable `f7c110da`. The remaining one of the **996 actual inputs** is the original CocoaPods-generated `Source/PrivacyInfo.xcprivacy`. Both its exact compiled blob/SHA and original Git blob/SHA are verified. All original declarations/reasons remain; the six added reasons are traced to the five archived original dependency privacy files. This generated file is not described as byte-identical to the repository.
- The 996-path original validator check occurs after dependency setup and before xcodebuild. After the build, the original validator rechecks Hanlin SDK source, the package lock and copied app JavaScript; it does not record a second full 996-path map.
- **424/424 original Hanlin SDK files** match the previously authenticated, untruncated API tree at `e00498e33f106cc43be0476ffa2e09329c8ca300`, with identical before/after artifact bytes. This exact app artifact was compared anew. The prior original API tree is retained again for reproducibility; no SDK sources were substituted.
- All **17 pinned Swift package checkouts** are recorded at exact clean revisions. Package.resolved is unchanged across the build. Equatable macro authorization uses the exact package/target/revision fingerprint with normal Xcode validation enabled.
- Otzaria artifact `14596463166` and Zayit artifact `14595389912` match the already authenticated `99f7927e` producer ZIP digests and successful producer jobs. The producer workflow `44661774024` remains **overall FAILURE** because of its separate package-resolution job. This build correctly used the successful framework outputs, with only the exact 78 reviewed test additions excluded from compiled-input equivalence. The unchanged Zayit tree is preserved. See the sibling framework audit for the actual d5 provenance, platform slices and defined exports.
- Validator, workflow, input manifest, Xcode project, app Source/Vendor/project trees and JS overlay hashes were independently checked against immutable Git objects.

## Warnings and limits

The exact compiler log contains **1,480 `warning:` line occurrences**, representing **684 distinct full warning strings**, and no `error:` line occurrences. These are diagnostic counts, not a claim of 1,480 unique defects. Every warning is preserved in the original ZIP and in `WARNING_INVENTORY.json.gz`; frequent categories include original dependency nullability, deprecation/documentation warnings, and project duplicate-source/build-phase notices.

The original npm output reports **84 vulnerabilities (5 low, 19 moderate, 35 high, 25 critical)** and retained upstream dependency deprecation/engine warnings. This is the original install audit output, not a separate vulnerability investigation or remediation result. CocoaPods configuration/deprecation and Metro configuration warnings are also retained without filtering.

No tests were fabricated or transferred from the earlier focused SDK run. This collection only reads and authenticates existing evidence; it does not run another build, compiler, engine, or app. The first source-auditor attempt incorrectly assumed all 996 source hashes should equal Git; its preserved failure correctly identified the documented privacy-generation exception. The corrected reviewer checked that exact input and did not alter the original acceptance validator.

## Files

`RESULT.json` contains the scoped outcome; `SHA256SUMS.json` identifies every raw stored byte stream. Raw reports/scripts/API metadata are exact-byte gzip files; the original GitHub ZIP is unchanged. `BUILD_OUTPUT_WITNESSES.json.gz`, `SOURCE_BINDING_REVIEW.json.gz`, `VALIDATOR_SOURCE_EXCERPTS.json.gz`, and `WARNING_INVENTORY.json.gz` provide bounded review views of the retained originals.
