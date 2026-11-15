# Stage2 isolated integration and actual Apple build

[תומר | INT] [MAIN_SESSION] — 2026-11-15

The five frozen repair lanes are integrated and the real unsigned arm64 `Maktabah-iOS` Debug app build passed. [Run43666438604](https://github.com/davidpovarsky/Maktabah/actions/runs/43666438604) executed exact checkout **3918864d9e4d963fa8686aab48e53c34a933c771**, completed in27m51s, and reported `** BUILD SUCCEEDED **`. Only the focused job ran; both older jobs were skipped. Runtime, device acceptance and functional completion remain OPEN.

Application source is **07d1cafa6c6bc27aaf299aa826d28a4c02090cb5**. The checked checkout and later evidence-only tip retain identical Source/Vendor/project Git trees. Five true merge commits retain all donor changed blobs, without conflicts or source overlap. STAGE2_INVENTORY.json, STAGE2_MERGE_LEDGER.md and STAGE2_OWNERSHIP.json record exact34 paths, parents and ownership. Q independently verified34/34 donor retention and three-target source registration. No newer Reader/actions package is part of this frozen batch.

## Executed Apple context

- Xcode27.1, build27A9275; Apple Swift6.4 (`swiftlang-6.4.0.34.1`, clang2100.3.34.1); iPhoneSimulator27.1 SDK. Compiler version is not a claim that every dependency uses Swift6 language mode.
- Actual `Maktabah.xcworkspace`, `Maktabah-iOS` scheme, Debug, generic iOS Simulator, arm64, jobs2. `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, empty identity. No CodeSign commands occurred.
- Exact full command, toolchain, validator/workflow/input hashes and package revisions are preserved unchanged in STAGE2_APPLE_RUN_43666438604.json.
- Real pinned Sefaria checkout2fd173a5, unchanged npm lock, Node22.23.4, Ruby3.3.13, CocoaPods1.17.0 and131 genuine pods. Authentic generated Expo provider, workspace and CocoaPods project wiring; no app mocks, dummy React headers or source exclusions.
- Four native/SPM/JS artifacts matched their configured SHA256. Native producer40566258679 source trees matched the integration; real JS/resource producer42577170165 matched unchanged Sefaria code. Seven real metadata files matched pinned hashes. No Rust rebuild, Metro regeneration, corpus/production DB download or user-data operation.
- All750 tracked Source/Vendor inputs were audited before compile. Every file stayed exact except the explicitly recorded original CocoaPods privacy aggregation. All six real SwiftPM checkout revisions were exact and clean. Committed package lock SHA256 stayed `c9959df672bb641a4a5cfb729574a6c83840dabeb067d2db79ddeee0bd8adc7e`.

## Generated configuration and privacy evidence

Generated dependency context is distinct from committed application code. The run artifact retains actual resolved Podfile.lock, generated project diff, original/generated privacy bytes and diff, ExpoModulesProvider.swift, actual-source-inputs.json and full logs. The repository had no historical committed Podfile.lock; no historical native dependency equivalence is claimed.

| Generated input | SHA256 |
| --- | --- |
| Resolved Podfile.lock | 9a7f88b1d9ebbf4d14f8b6f1efd1fb2d15ac63983bf16ffd3e9ea011f9a55ce7 |
| CocoaPods project | dfc8ca9ba3c138ab2bad986171f0d61c9a5d1b5fe9c9be1a23f54c3553815e27 |
| Workspace | d27bfdb7fb6d0dc873c287f7c4b84c161de200fec99b9a0fb11eec850896eb3f |
| ExpoModulesProvider.swift | c6ec625de1af66d390d35bfb43e4d69508597cfa246f3c939428c77295b017e1 |
| Original privacy | 39380ce07cfe093fee32ef7d99c7d1cf86d3565b8fe860ecb0f8497c23c585a1 |
| Compiled generated privacy | e6946e8876416f5a802dcad79e6c629416788175e0fa078d46accfdc73752fc5 |

All original privacy declarations and API reasons were retained; only six unique API/reason pairs evidenced by installed dependency manifests were added. This is a constrained build-context audit, not privacy compliance certification. Ten local guard checks and12 independent Q guard checks passed. Five supporting manifests were retrieved after the run from official exact versions and the integrity-verified pinned npm tarball; every SHA256 matches the installed input recorded during execution. PRIVACY_MANIFEST_SUPPLEMENT.json labels this timing explicitly. Their folder-local attributes preserve exact raw bytes without line-ending conversion or text diffs: three official files include trailing blank lines, which must remain intact for hash identity. The initial text whitespace check identified those original bytes; no manifest was reformatted. A later output-only helper/workflow addition retains these used bytes directly on future runs; that helper tip is not represented as executed391.

## Results, attempts and limits

The17,181,062-byte app log SHA256 is **6c82ed7d5a2b7de41af196652fdd3d5bde8d502313c75d54bd72e6d5a1116c8d**. It contains zero `error:` lines and1466 `warning:` occurrences, including native dependency deprecations/documentation and empty-object warnings. Build success does not mean warning-free code. Full log remains in the run artifact and ignored local `.cache/run-43666438604`; it is not committed as a large generated file.

Earlier failed attempts remain recorded, without claiming success:43663694996 exposed missing React/Pods build context;43664845739 refused absent generated-workspace package pins;43665419076 refused genuine generated privacy metadata before compiler execution. Corrections restored genuine inputs and explicit provenance. No application source correction was needed. Each run used one long-lived watcher, now ended; no healthy product rerun was added solely for evidence-file I/O.

Existing scoped registration checks, full diff whitespace checks and validator preflights passed. The final evidence/helper patch receives syntax, hash and whitespace verification only. Q's independent final reconciliation is recorded in STAGE2_QA_CLOSURE.md when received; this report alone does not assert that review completed.

Still OPEN: Search/Reader/Inspector/Sidebar device and interaction acceptance; runtime and performance evidence; Updates cross-file recovery before any native backend enablement. Current BackendID lacks native Maktabah and all existing backends intentionally remain blocked. macOS targets, x86_64, test execution, signing, archive, IPA and distribution were not validated by this arm64 simulator build.

## Handoff and rollback

Branch `codex/otzaria-integration-20261115`, worktree `C:/Users/DAVID/Code/Maktabah-hq-integration-20261115`. Ordinary isolated publication only; no main merge or PR. Original dirty worktrees remain preserved. Rollback reference `codex/otzaria-integration-pre-stage2-20261115` retains242571c9a1502d068410c82af753ba2a8a2b0bbf. Do not reset user worktrees. Validator rollback removes the new false-default manual mode/job and helper, restoring original conditions; no automatic triggers or existing defaults were changed. Shared registers and overall functional status remain Lead-owned.
