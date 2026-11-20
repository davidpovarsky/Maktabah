# Executed verification of current-work Hanlin consent

## Current exact source

The production/test source is `e6ef4da1c2067061daa8f1f66e55e1e423a91cd5`, based on `7e777509d486a17bec5b4bd437a9ac7f51d3a43a`. The original SDK remains `e00498e33f106cc43be0476ffa2e09329c8ca300`.

The source sequence is:

1. `bbd3605ac4b501e442fdfa6dfdc3ca2dd0f4ad16`: explicit native consent, original owner/session/draft lifecycle and scoped read adapter.
2. `842639540d7212f45cbd873f3038f9784401cc49`: preserved actual RED, initial zero-execution attempts and focused authority review.
3. `e6ef4da1c2067061daa8f1f66e55e1e423a91cd5`: retain existing discovery alongside contentRead in the separate scoped context, required by the actual Core advertisement path.

The final evidence commit changes documentation/evidence only. The eight Swift sources are verified against the immutable e6ef4da1 Git blobs in `evidence/source-e6ef4da1-verification.json`. The earlier `SOURCE_INPUTS.json` is retained as the initial bbd3605 source snapshot.

## Actual passing executions

SentinelX job `job_0a28ae7c4f1d`, Windows Swift 6.3.3:

| Suite | Actual passed | Failed / missing | Process exit | Elapsed |
| --- | ---: | ---: | ---: | ---: |
| OtzariaHanlinHostAdapterTests | 48 | 0 / 0 | 0 | 94.297 s |
| OtzariaHanlinConversationStoreTests | 11 | 0 / 0 | 0 | 113.328 s |
| Total | 59 | 0 / 0 | — | — |

The unchanged original strict XCTest verifier `Scripts/CI/verify-faithful-xctest.py` has SHA-256 `5a1d173f73db80bddcef2a3253577f9309911910066832bd2f5a4ddb91f9505e`. Its expected names come from the actual fixture declarations, and every required name appears as an executed passing XCTest case. Zero missing/failed cases and process exit zero are required together.

The host package contains 62 verified inputs: actual original Core, actual adapter, unchanged original SDK contracts and complete original HostDispatcher, plus the actual fixture. All 28 original case names passed; 20 additions exercise the new consent/scope/rights/cancellation boundaries. Backend contents, native source observations and authority receipts are explicit doubles. The app owner/UIKit/AgentSession/provider are outside this portable target.

The store package contains 36 verified inputs: the complete production filesystem store, original SDK value/presentation modules and unchanged message DTO, plus the fixture. All 11 original names remain. The existing reopen case now also executes actual same-conversation lease rotation, rich history/draft/SDK metadata reads, byte-identical saved file observation and refusal of a write through the revoked old lease. The production store source is unchanged.

Source bytes are compared with the current original source before and after each execution. The code was committed before these runs, and both reports identify e6ef4da1. No generated substitute Core, store, successful connection, provider or native scene is used.

## Commands and invocation boundary

Both passing commands use the prepared packages from the unchanged original drivers. Exact absolute command arrays and working directories are in each `inputs.json` and `RESULT.json`.

The host invocation was:

```text
C:\Users\DAVID\AppData\Local\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin\swift.EXE test --scratch-path C:\Users\DAVID\Code\Maktabah-hanlin-read-actions-20261120\build\hh -j 1 --disable-swift-testing -Xswiftc -strict-concurrency=complete
```

Its working directory was `C:\Users\DAVID\Code\Maktabah-hanlin-read-actions-20261120\build\hanlin-read-actions-20261120\host-initial\package`. The store uses the same command options with scratch path `build\hcs` and working directory `build\hanlin-read-actions-20261120\store\package`.

The invocation adds `--disable-swift-testing` for fixtures that contain only XCTest cases; none contains `import Testing` or `@Test`. It does not remove a test or alter its assertion. The original driver files and Apple CI scripts are unchanged. The original strict verifier still demands every one of the 48/11 names.

The passing run reused the existing package paths/build caches after the old runs had finished their source comparisons. Only the adapter and its test file were refreshed from the committed source; the other 60 host inputs remained byte-identical. The old two files and previous input manifest are retained in `evidence/host-green-input-preparation`.

The host run recorded zero warning occurrences. The store log records 66 warning occurrences; their actual paths/messages are retained, rather than describing this as a warning-free build. These do not change the actual zero exit/11 executed-case result or establish Apple compilation.

## Preserved failures and timeouts

| Attempt | Input / invocation | Actual outcome |
| --- | --- | --- |
| Host initial | Earlier 46 declarations; unchanged driver, 240 s bound | Compilation timeout, exit 124, 0 executed |
| Host second | Current 48 declarations; unchanged driver, 240 s bound | Compilation timeout, exit 124, 0 executed |
| Host preflight `job_88bd2c6b000f` | Source identity check before Swift | Assertion stopped execution; 0 tests. A subsequent all 62 byte comparison matched current source and original SDK. |
| Host actual RED | bbd3605 source, original command, 600 s bound | Executed 48: 38 PASS / 10 FAIL, exit 1, 455.344 s; all original 28 passed |
| Store initial | 11 declarations; original driver,300 s bound | Compilation timeout, exit 124,0 executed |
| Store default continuation | Same11 source,600 s bound | Compilation timeout, exit 124,0 executed,602.610 s |
| Cold-cache XCTest-only host diagnostic | Same bbd3605 source,600 s bound | Compilation timeout, exit 124,0 executed,601.719 s |
| Cold-cache XCTest-only store diagnostic | Same unchanged store/test source,600 s bound | Compilation timeout, exit 124,0 executed,601.219 s |
| Corrected host | e6ef4da1, incremental package/cache, XCTest-only option | Actual48/48 PASS |
| Store exact-source continuation | e6ef4da1, same store/test bytes, incremental cache, XCTest-only option | Actual11/11 PASS |

The RED is a real product integration finding. The original Core's `advertisedActions` executes `system.listBackends` before filtering eligible descriptors. That requires the existing discovery scope; omitting it from the separate read context hid the permitted search tool. The fix preserves discovery plus explicit contentRead, exact one-work rights and no navigation scope. The positive test requires all four real catalog tools, and the missing-content-rights test still requires the exact `content_rights_required` error and zero backend reads.

No timeout is counted as a pass. A small optional-Testing importer diagnostic timed out at 15 s with the normal import and completed with a module alias, but that does not prove the underlying cause of the long build. The default host subsequently completed within its 600 s bound. The cold-cache XCTest-only runs still timed out. No compiler deadlock, orphan-induced cache lock or device-performance conclusion is claimed. The bounded process observations found no proven old owned orphan to terminate; active runs were left intact.

## Evidence files

`RAW_EXECUTION_EVIDENCE.zip` preserves the observed file bytes, including Windows line endings. Readable Git copies may normalize line endings. The archive and its per-entry SHA-256 manifest therefore own byte-accurate raw-log verification; `RAW_EXECUTION_EVIDENCE_MANIFEST.json` records the archive hash.

- `evidence/ACTUAL_EXECUTION_SUMMARY.json`: checked aggregate, exact counts, command arrays, hashes and boundaries.
- `evidence/host-green-executed/{RESULT.json,inputs.json,swift-test.log}`: all 48 current-source executions.
- `evidence/store-green-executed/{RESULT.json,inputs.json,swift-test.log}`: all 11 actual filesystem-store executions.
- `evidence/host-attempt03-actual-red` and `evidence/ORIGINAL_CASE_COMPARISON.json`: RED and immutable original 28 comparison.
- Other named attempt directories retain the initial/current declarations, byte manifests, raw logs and zero-execution outcomes.
- `AUTHORITY_REVIEW.md`: independent source review of pending consent, A→B→A invalidation, old callbacks and the no-Send call path.
- `evidence/source-e6ef4da1-verification.json`: all8 current Swift source identities and syntax-only parse commands.

## Apple/Native/provider gates

The Windows frontend parses are syntax-only and do not typecheck UIKit or SwiftUI. Full Apple app compilation and combined current-source regressions remain pending. The existing Apple typecheck pipeline already includes the entire Native test file with source hashes and invokes both unchanged host/store drivers; this branch changes no workflow selection or pin.

Two prepared Native cases, both NOT_RUN and using the original `.realUI` tier:

- `HanlinReaderConsumerAcceptanceTests/testOriginalIPadCurrentWorkReadConsentReopensAndRevokesWithoutSending`
- `HanlinReaderConsumerAcceptanceTests/testOriginalPhoneCurrentWorkReadConsentReopensAndRevokesWithoutSending`

They must be selected on their respective original iPad/phone destinations after the root freezes the merged source. They never tap Send and do not instrument network silence. Actual SwiftUI onDismiss identity/timing, scene background/account changes on device, a real configured-provider request, the real live backend search and physical performance are not established by the portable suites.

The current immutable older Native88/Release runs remain separate evidence and cannot validate this later source. No Asana task completion or Native/provider acceptance follows from these 59 component tests alone.
