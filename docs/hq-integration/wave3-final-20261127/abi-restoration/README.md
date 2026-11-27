# Original ABI dependency restoration ? 27 November 2026

The unchanged original e973 verifier passed all three actual pinned wrappers after the exact retained inputs were restored. The subsequent original Wave1 donor preparation on clean source 1be970356c655bcef3688ddf1d129d5029bbc533 verified all 17 existing Lib members and copied zero files.

This packet establishes dependency restoration and an ABI input for the next SDK build. It does not establish a new SDK/framework build, composed application, native UI acceptance, production-library acceptance or TestFlight readiness. No owner signature, source pin, verifier, assertion or historical receipt was changed.

## Source and ownership

| Item | Exact identity |
|---|---|
| Maktabah documentation base | 460a098912d6b9ebd29e99330a76644937d2b570 |
| Isolated branch | codex/otzaria-wave3-abi-restoration-evidence-20261127 |
| Original ABI verifier source | e973cc7432419778f0342624a3b7052055fd270d |
| Original native Heart source | b18e6733605deb4086ee95aa4cf755404746cf51 |
| Actual donor checkout HEAD | 75a98ba98d6455eefc2c98113fa744b0f3c2e7bf in the retained 9bc6420f directory |
| Wave1 consumer source | 1be970356c655bcef3688ddf1d129d5029bbc533 |
| Existing genuine execution | local-0d90c236-6ddf-4872-af7b-e8001b97675e |

Every repository change in this packet is new downstream documentation. No upstream application, SDK, cache policy, lockfile, build setting or source-admission file is edited.

## Observed sequence

| Stage | Actual result | Raw receipt |
|---|---|---|
| Restore three c-archives | 3 exact files, 807,997,648 logical bytes; original size, SHA-256 and Git blob checked before and after atomic publication | THREE_ARCHIVES_RESULT.json |
| Restore final compiler inputs | 69 files, 2,708,358 bytes, matching the original final compiler manifest across all three targets | SIXTY_NINE_COMPILER_INPUTS_RESULT.json |
| Original verifier after those 72 files | FAIL: declared module cache inputs were still absent; failure and stderr preserved | ORIGINAL_VERIFIER_BEFORE_MODULE_HYDRATION_FAIL.json |
| Exact module hydration | 198 exact module@version pairs, both original h1 checks, 4,444 declared files and 89,114,545 bytes restored | MODULE_HYDRATION_RESULT.json |
| Same original verifier after hydration | Exit 0, THREE_ACTUAL_PINNED_WRAPPERS_PASS; original go.sum preserved and gomobile unchanged | ORIGINAL_VERIFIER_AFTER_MODULE_HYDRATION_PASS.json |
| Original Wave1 donor preparation | Exit 0, PASS_EXACT_NATIVE_ABI_REUSE_ONLY_NEW_SDK_NOT_YET_ACCEPTED; 17 Lib members verified, zero copied | ORIGINAL_DONOR_PREPARE_RESULT.json |

The original failed Wave1 preparation remains verbatim in ORIGINAL_WAVE1_FAILED_PREPARATION.json. It has not been relabeled following the later success.

The c-archives came from the already preserved exact archive recovery, not from framework slices. The 69 files came from the original final compiler-root archive. The historical pre-tidy go.mod/go.sum receipts remain unchanged; the restored files match the final compiler inputs required by the unmodified verifier.

The module operation used the original Go 1.26.5 executable, SHA-256 3925fc3221ac440ebf7c35361ff663bed0c7bdb2e0a157b75fe993607ffe0a19, in a newly owned staging workspace with unchanged original final go.mod/go.sum. GOTOOLCHAIN=local, GOWORK=off and GOFLAGS=-mod=readonly were retained. Every exact module was downloaded and verified separately. Only missing/identical declared original destinations could be published, through temporary files and exclusive atomic publication. A differing target would stop the operation. Size, SHA-256 and Git blob were checked for all 4,444 files. Only newly owned per-module staging was recycled after its raw receipt was sealed. No foreign cache or simulator was removed.

## Terminal bindings

| Evidence | SHA-256 |
|---|---|
| Original verifier file | 178262cdfd5d8b07fb0d8915bb394150ef8988de5fe2115f02bac735f6c65289 |
| Original pinned result input | d7fca002ef2e7984ef6ada7bc23ac3f055cce10f8e079b24166aa0c39fea692f |
| Module hydration result | ba74c565bedddfb819ece0e90b6958ec14386f27a4d937c6042935492cd433e2 |
| Original verifier after hydration result | 656f9a2e588042d20112b6d6abe4e4cb617b8a6d2ed9b43c5105584b6721be3d |
| New ABI_DONOR_INPUT.json | adab56b1ad2c6fc06d7b154b4df0112a9a3dfdde4230a576e5064bd15bd04496 |
| Original donor preparation result | a7420d2de274685f6b23a50a9bcbfaa42bec0336b05a4fba6a78143c712b279e |

The final verifier ran from 03:50:34.691 to 03:50:39.104 UTC. Original donor preparation ran as PID 93947 from 03:56:08.869 to 03:56:39.279 UTC, with Python 3.12 and the existing source-bound identity. Its exact argv, exit, output hashes, source afterimage and free-space observations are in DONOR_PREPARE_COMMAND_RESULT.json.

## Complete raw evidence and transport

RESTORATION_RAW_EVIDENCE.tar.gz is 2,071,721 bytes with SHA-256 004002315135a4f182caf4e1da5009fe4c7b6ca74a960508a60bd26dd7a67c6f. It contains 2,024 original evidence files, totaling 12,669,277 uncompressed bytes, plus its member manifest. All 198 module completion receipts are included.

MEMBER_MANIFEST.json binds every member to its original absolute Mac path, byte count and SHA-256. Every raw archived member was read back and checked on Mac and again on Oracle. The archive and three companion files were verified after Mac-to-Windows transfer through the existing pinned scaleway-mac SSH alias, then after Windows-to-Oracle transfer through torah-social. The actual per-hop hashes and timestamps are in TRANSFER_MAC_TO_WINDOWS.json and TRANSFER_WINDOWS_TO_ORACLE.json.

The archive includes metadata, original command logs, the recovery driver and receipts. It excludes module payloads, native archives, SDK/app binaries and credentials. All original payloads and evidence remain on Mac. The verified Windows preservation directory is C:\Users\DAVID\.codex\artifacts\otzaria-wave3-abi-restoration-20261127.

## SDK continuation boundary

SDK_CONTINUATION_READINESS.json records the original controller argv, existing local-execution environment, reviewed-macro prepare/restore commands and fresh work/evidence paths as observed before framework invocation. Both originally allowed compiler-cache seed directories were absent; no cache reuse was claimed. The previous immutable Debug distribution inventory was 1,307,281,591 bytes, which is not a fresh build peak measurement. All required producer, retained producer, distribution and independent consumer scopes are named. No numerical fresh peak is invented.

Any subsequent framework attempt and its consumer/import/resource results require separate source-bound evidence. The new donor receipt's new_sdk_acceptance_granted remains false. Native, app and physical-device acceptance remains required on the eventual integrated candidate.
