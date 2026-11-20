# Cloud48 Apple failure — exact source and complete retained evidence

**Run `44792622640`, attempt 1, failed before either local43 or cloud48 executed.** The independent original exchange component completed 28 cases and both abrupt-process-termination/reopen gates. The original final workflow gate correctly rejected the combined result.

| Identity | Actual value |
|---|---|
| Repository | `davidpovarsky/Maktabah` |
| Frozen checkout | `452a04c2b05150694d8120ed465afb48da190af3` |
| Canonical root tree | `29b001fbc86030179fe81c043e7c93dc57bb238e` |
| Reviewed application source | `57e4a1cb7cd0bee72e3042e2f4567972237e7e35` |
| Frozen branch | `codex/otzaria-local-annotation-cloud-apple-reviewed-20261120` |
| Job | `136483943569`, 18:25:34–18:28:51 UTC on 2026-11-20 |
| Authentic artifact | `14656519348`, 995,050 bytes, 114 ZIP members |
| Complete archive SHA-256 | `1e3fab2c767e19ef673c951e63dd05c50cf0a78bffd070b8d5be1acca9b2e116` |
| Actual toolchain | Xcode 27.2 build 27B52; Apple Swift 6.4.2; arm64 macOS SDK 27.2 |
| Captured original Core tree | `5d0ee482c8f10726fe3863792dac94c18e94d792`; this is not the later Core194 source |

The full original ZIP is retained without extraction, rewriting, filtering or recompression. The two compressed metadata files retain the complete safe canonical run/job/artifact API response, full original job log, Root's 96 Git records, and C's separate Git-tree readback. The secret download response is excluded. No simulator, Swift compiler, executable, network transport or test was rerun while preparing this packet.

## Exact compile failure

The unchanged command `/usr/bin/swift build … -j 1` returned exit 1 after 54.851877 seconds, inside its original 480-second bound. The complete compile log has one source diagnostic site:

```text
AnnotationLocalEditorCloudOwnership.swift:40:40
'inout sending' parameter '$0' is accessible to code in the current isolation context at end of function
observer.withLock { $0 = token }
```

The accompanying diagnostic note concerns the captured observer token's isolation region. The repeated highlighted diagnostic and the generic failed-frontend/build messages are retained; they are not counted as additional source defects. The failure occurred in the genuine production observer source copied into the original local executable. It is not classified as a fixture-only compile failure.

GitHub lists the local execution step's **conclusion** as success because that step uses the existing `continue-on-error` orchestration. Its actual recorded **outcome** is failure. The real compile receipt, local result, job log and final `after.json` all agree. The final gate failed with the original message requiring both whole-source drivers and the toolchain to succeed. No partial result was promoted to overall success.

The separately reviewed source correction `7af3a06d48ccbe77acef180cb99d120971c3804e` creates and stores the token inside the same mutex section. Its source and review are documented separately under `cloud48-observer-registration-20261120`. This failed run does not evaluate or qualify that correction.

## What actually ran

| Acceptance | Actual result | Scope |
|---|---|---|
| Local annotation component43 | **NOT_RUN**, 0 passed / 0 failed | Compilation stopped before execution. |
| Local separate-process cold reopen2 | **NOT_RUN**, no process receipts | No cold-persistence result is borrowed from earlier runs. |
| Owned Cloud component48 | **NOT_RUN**, 0 passed / 0 failed | No account/transport race control executed. |
| Original exchange component28 | **28 PASS**, compile 0 / execute 0 | Actual Swift, CryptoKit and original SQLite component on macOS. |
| Original exchange crash/reopen2 | **2 PASS** | Each original process exited 73 at its designated point; each independent verification process exited 0. Both retained logs report WAL with synchronous=2. |
| Original source/result rejection controls | **43 PASS**, 0 failures/errors/skips | Actual Python execution on the Apple runner. These are separate from the unexecuted local43 Swift cases. |
| SQLite pending/transaction premises | **13 PASS** | Actual Python SQLite premise checks, not production Swift or live CloudKit qualification. |

The exact 28 original case names are independently matched to the raw `RUN`/`PASS` output and source-bound declarations. All before/after source hashes in that driver match. Python's SQLite version was 3.54.1; the Swift executable reported Apple's SQLite 3.54.0. These are retained as distinct observed runtimes.

Five unique source warning sites occurred in the successful exchange compilation: three unnecessary `try` warnings in `AnnotationExchangeAcceptance.swift` (81, 316, 326) and two unreachable-code warnings in `AnnotationExchangeTestSupport.swift` (61, 219). Their complete source locations and raw compiler messages remain in `REVIEW.json` and the authentic archive. They are not suppressed or reclassified as zero warnings.

## Source and compile-input authentication

C fetched the exact canonical commit and complete 7,634-entry Git tree independently of Root's metadata. The tree was not truncated. All 96 recorded source paths match both sets of Git records, including their canonical blob IDs, lengths and actual before/after bytes. Each source tar contains exactly those 96 ordinary files; both uncompressed payload inventories are byte-identical. The tar gzip bytes differ because they were created at different times; each archive's own recorded SHA and size is separately verified.

Both local executables retain **23 complete canonical Swift source files each**, including the original Store, Repository, SQLite, ledger, editor/session and original CloudKit/Core/debouncer sources. The cloud target additionally retains the exact bounded helper prefix from the original local fixture, with no `@main`. All 47 retained files are checked against their genuine source bytes or that exact prefix. These are post-failure retained-copy checks; the missing runtime `compiled_copies_after` stage is not invented. The seven whole original exchange source copies are independently verified too.

The four original application tree pins and original Core tree also match the canonical checkout. Existing framework/App/UI source from other branches, later Core194, the separate repository-disconnect repair and the observer correction receive no credit from this run.

## Read-only replay

Run `python3 VERIFY_PACKET.py` beside this README. It checks the packet seal, the authentic complete archive digest and all 114 CRCs, both 96-file source archives against canonical Git, the 23+23 whole compile copies and exact helper prefix, the separate seven exchange inputs, the concrete compiler diagnostic, the unexecuted local/cloud/cold results, all 28 exact exchange leaves and both crash/reopen outcomes, and the 43 Python / 13 SQLite results. The printed replay **PASS** means this failed-run classification is authenticated; it does not mean the Apple workflow passed.

The first packet-verifier preparation used a lowercase-only stdout-name pattern and rejected eight genuine original case names containing `ACK`, `SHA256`, `UTF8`, `UUID` or `NUL`. That parser attempt and its error are retained. The final parser accepts case-sensitive ASCII identifier letters and still requires exact equality to all 28 original declared names and raw output. No product, driver, test declaration, assertion or Apple result was changed for that correction.

Native UI, editable Anytype mount, application relaunch, physical devices, real CloudKit account/network behavior, live exchange, remote rollback and post-retirement transport isolation remain **NOT_RUN**. The live-exchange flag stayed false.
