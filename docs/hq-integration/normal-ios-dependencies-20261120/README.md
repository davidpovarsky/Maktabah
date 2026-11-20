# Normal iOS: original workspace preparation and per-target SDK repair

## Actual failed Apple run

[Run 44704546258](https://github.com/davidpovarsky/Maktabah/actions/runs/44704546258), attempt 1, finished **FAILURE** on checkout `e80cd5f2c27993351533f1be9d0890dfaa82cb42`, app/test source `0f5111e8f8e379e17da558ddbe2aab5214ac0315`. All three optional heavy/corpus/live inputs were false. The single dispatch and sole finite watcher are preserved in the raw receipts.

The final job completed at **09:18:49 UTC**; GitHub updated the run at **09:18:50 UTC**. **09:19:09.577525 UTC is the watcher observation/exit time**, not the workflow execution end. The watcher closed with exit 1. There is no replacement dispatch or active watcher for this run.

| Original stage | Actual outcome |
| --- | --- |
| Swift package resolution | PASS |
| Otzaria XCFramework job | PASS |
| Zayit XCFramework job | PASS |
| Inspector backend mapping executable on Apple | PASS: six original stage completion markers |
| Simulator application build | FAIL: host Equatable macro compiled with the global iOS Simulator SDK |
| Unsigned device application build | FAIL: missing original React header in a project-only build |
| Simulator iPad acceptance / application Native acceptance | NOT_RUN after build failure |
| Optional full corpus / live Sefaria / heavy bootstrap | Not requested; no acceptance claim |
| Unsigned IPA packaging and inspection | NOT_RUN after build failure |

The simulator log's first actual compiler error is `Unable to resolve module dependency: 'SwiftSyntax'` in the original pinned Equatable macro. Its actual SwiftDriver command used `-target arm64-apple-ios15.0-simulator` and `iPhoneSimulator27.2.sdk` for the host macro. The normal workflow's global `-sdk iphonesimulator` caused the mismatch; the already working focused driver explicitly omits a global SDK for this reason.

The device log's first actual compiler error is `React/RCTBridgeModule.h file not found` at the original `ChavrusaSefariaBridgeModule.m:10`. Normal iOS built the project without the existing npm/React/Pods preparation. The shell's earlier printed `Unsigned IPA contains runtime search data` statement is **not an executed packaging failure**.

The six Inspector stage markers are LocatorAndRefTests, DecodingTests, NavigationAndPackageTests, LegacyIdentityRegistryTests, BackendCoordinatorTests, and UnifiedSearchArchitectureTests. They establish completion of the actual original standalone harness. This report does not infer an assertion count from declarations.

These are the normal iOS failures. They are separate from Native38 run 44704452479's Swift 6 XCTest capture error; that run did not execute Native cases.

## Narrow repair

Only the normal iOS workflow, a new adapter script, a portable adapter test, and this evidence are changed. Product Source, Vendor, project, SDKs, dependency locks, runtime selector, cache keys, original Inspector program, and iPad acceptance remain unchanged.

Both original app jobs now use the real `Maktabah.xcworkspace` and their original destinations without global `-sdk`. The same pinned Hanlin materialization and macro authorization remain. No macro source, headers, SDK, engine, or package is fabricated or replaced.

The new adapter imports the unchanged `hq-stage2-focused-apple.py` and reuses its existing implementations in their original order:

1. Materialize the pinned Sefaria source and run the original `npm ci --legacy-peer-deps`.
2. Restore **only** the existing pinned Embedded resource archive and its seven hash-checked metadata resources. The normal workflow's own same-run engine and SwiftPM artifacts remain in place.
3. Rebuild the one explicitly reviewed downstream JS overlay with the original Metro command.
4. Run real `pod install`, require its original React header and generated workspace, and copy the exact committed project Package.resolved to the workspace before pinned-only package resolution.
5. Verify the original locks, generated project/workspace, tracked application inputs, package checkout revisions/pristineness, and original Hanlin source.
6. Export only the six original React build environment keys to GITHUB_ENV.
7. After the actual build, verify the copied JS bundle and the same original inputs before the original app tar/unsigned IPA packaging and search-data exclusion guard.

Node 22 and Ruby 3.3 exactly match the existing successful focused/runtime27 preparation. No gem installation, package update, dependency upgrade, or new SDK is introduced. The original helper calls `pod --version` before installation; a missing executable remains an early real failure. The repository has **no tracked root Podfile.lock**. As in the original driver, pod install generates one; its exact hash is then retained and must remain unchanged through resolution/build. This is not a newly invented claim that CocoaPods had a committed lock.

A shallow checkout fetches only the exact immutable resource producer commit when needed to verify the original Sefaria tree/overlay contract. The adapter does not invoke or claim the separate focused framework preflight, and does not restore its historical framework or SwiftPM artifacts.

Preparation evidence is uploaded with existing build logs using bounded file patterns; input archives are excluded. Original unsigned signing settings, application inspection, dictionary checks, optional inputs, job dependencies, timeouts, runtime admission, and downstream acceptance remain.

## Verification actually executed

- **28/28 portable Python controls passed**, 0 failures/errors/skips, against the exact candidate adapter/workflow on Windows. They exercise actual adapter functions, real temporary file hashing/lock I/O, and explicit Apple command boundary doubles. They do **not** run npm, CocoaPods, Xcode, a Simulator, or an app.
- Controls cover exact resource-only selection; rejection of archive ambiguity, tar/destination injection, bad digest/ID, unreviewed source overlays, upstream drift, changed locks/generated workspace, stale or unprepared reports, wrong/missing copied bundles, source/SDK verification failures, pinned-only resolution ordering, safe environment export, and original workflow gates.
- The same controls first passed in local scratch and in Windows before removal of one incidental final blank line from the workflow; the final Windows run is source-bound to the final workflow hash below. Earlier receipts are retained.
- **Exact inverse source proof passed** against failed checkout F. Reversing only the listed preparation/build/log changes reconstructs every original workflow byte. Source, Vendor, project, helper, input JSON, macro authorization, Hanlin materializer, selectors, cache-key helper, original runtime script, historical toolchain fixture, and package-lock Git identities are equal.
- One preliminary invocation of the historical 29-case toolchain script omitted its required `--report` argument and exited 2 with **0 tests executed**. That attempt is retained. The historical fixture checks a specific 26-to-27-only delta against its own old baseline; it is unchanged and is not presented as a candidate PASS. Its unrelated-step preservation is now independently covered by the exact F inverse.
- Root and C reviewed the workflow/adapter and original helper contracts read-only; no blocking source issue was found. Their review is not Apple execution.

Final source SHA-256:

| File | SHA-256 |
| --- | --- |
| prepare-normal-ios-workspace.py | 0352a277567dcfa562e6e4cab02b0c2fdb614fe3df0af75971e2e532b1b18f52 |
| ios-build.yml | 5574521593c0464613a50a76a03d4b129d41ab973c6af6e4f31ad467371bb828 |
| test-normal-ios-workspace.py | 7db8686277573bbc9224b4a9f6a56cb78f686ac63d6d137f0f0293568d0c9f44 |

Reproduce the portable controls and exact preservation proof:

```sh
python3 Scripts/CI/test-normal-ios-workspace.py --report build/normal-ios-workspace-controls.json
python3 docs/hq-integration/normal-ios-dependencies-20261120/verify-preservation.py --report build/normal-ios-workflow-preservation.json
```

## Authentic evidence and remaining gate

Both small log ZIPs were fully downloaded once, bound to the exact run/head by GitHub artifact metadata, checked against GitHub SHA-256 and size, and CRC-checked for every entry:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| 14616098147 simulator-build-logs | 848,356 | c5ffd32b51f71773ac5b3c553f067a48cdbceaf7659dba401ba760098973220e |
| 14616019160 device-build-logs | 2,973,736 | 94665ac4683f8a23570f32c7389f4933fe179c56f12cb5628e7af78ce47c28eb |

All archive entries and complete authenticated job logs are preserved as raw gzip data with original-byte hashes in RAW_MANIFEST.json. The ZIP receipts retain full archive hashes/entry names. Large framework/SwiftPM artifacts were not downloaded again; their API metadata is retained without a fresh byte-validation claim.

**Candidate Apple build, original iPad acceptance, unsigned IPA inspection, and Native execution remain NOT_RUN.** A combined immutable source freeze and one real normal iOS run are still required. No source-bound portable test substitutes for these gates.
