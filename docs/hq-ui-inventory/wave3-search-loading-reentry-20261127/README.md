# Search rejection stability and independent Wave2 test review

The new post-Books-Updates Search test first waited for loading to disappear, then checked three seconds of stable rejection. Its inverted predicate omitted loading, and its final assertions omitted loading too. The expected error could stay visible while loading returned and the new gate could pass.

This follow-up changes only that new test's inverted predicate and final assertion block in `Maktabah-iOSUITests/GlobalSearchNativeAcceptanceTests.swift`: it adds `global-search-loading.exists` to the rejection predicate and a final `XCTAssertFalse` for the same original control. Every prior assertion remains. There is no application Source, engine, index, driver, expectation duration or fixture modification.

Base: `e60a54127f8201e2bd980774b8c73b7345066b9e`.

Before SHA256: `fa4cbfc31a73d0265efc572923b756d7e39aa092c70fbdee36e06f0804a66de9`.

After SHA256: `2efbdc09aed91c9c2ed2dea67a9ed85f7a4070cb7eb501ee2537375a87680d17`.

## Actual focused control

The control compiles the verbatim baseline and candidate inverted predicate, unchanged three-second `XCTWaiter` call and final assertion block with actual XCTest/Corelibs and Foundation on Oracle (Swift 6.4.3, aarch64 Linux). Explicit mutable UI-state doubles supply only the observation boundary. No application or native element is replaced in the product. This is not an Apple SDK compile, simulator run or native UI result.

| Controlled state | Baseline | Candidate |
| --- | --- | --- |
| Stable rejection, no loading | Accepts | Accepts |
| Loading returns and remains | Incorrectly accepts | Rejects |
| Loading returns, then recovers during the original three-second wait | Incorrectly accepts | Rejects |
| Existing negative: result rows return | Rejects | Rejects |

The negative cases intentionally produce real XCTest failures and nonzero exits. The enclosing control checks those expected outcomes; their raw failure output is preserved. In attempt2, the explicit loading transition occurs after nine initial predicate evaluations; the baseline transient interval is about 0.220 seconds. The candidate records `invertedFulfillment`. The source predicate is sampled; this does not claim detection of every arbitrarily brief transition between observations.

Final control: `validation/attempt-2/RESULT.json`, SHA256 `565493bbbff2b13edc957b2246c0dea66f02bc5d486e49acec22f1bd3fc79e1b`.

### Preserved first attempt

`validation/attempt-1` is retained unchanged, including its unsuccessful aggregate result (`5e1475a11e2a4980c3cc888abacc70f8865db22e79d395e371b5459baa198d7f`). That harness constructed one-shot timers without explicit absolute fire dates. Its recorded reentry and recovery both happened on the first run-loop tick, roughly 19 microseconds apart, so the intended transient interval was not produced. Persistent loading already failed correctly in the candidate. The second driver changes only the control's timer scheduling and adds a timing assertion. Product/test source and extracted assertion-block hashes are identical across both attempts. Both drivers, both generated harnesses, actual compiler logs and every result remain available.

Both controls reuse the existing owned Reader-identity module cache. No SDK or application build was run, and no new module-cache directory was created.

## Independent intake review

The complete review and exact receipt/source/hash bindings are in `INDEPENDENT_INTAKE_REVIEW.json`.

- `661e37935ee3740c717f0459f4e4271446821026` republishes `e60a54127f8201e2bd980774b8c73b7345066b9e`: all six changed file blobs are identical. Select one, then this follow-up.
- `991526228533d6689c4ad9da8dbd3e9f82a7bea1` republishes `422c21b0eebbe45a1d3b1c8beea0113ecb0c53c4`: all 17 changed file blobs are identical. Select one.
- The original Search file's 153,728 bytes remain exact after removing only the donor's Darwin import; its new R08 test is appended. The follow-up's inverse replacements recover the entire 184,397-byte donor exactly.
- The continuous-pull donor preserves the entire 90,630-byte `a1e12fd` Reader file as its prefix. A small isolated `git merge-file -p` against actual root `068fb6b9c8f1f49f1eaf78e3fcec74c46efb84cd` returned 0 and preserved both existing `ebd10f` integer-unwrapping/equality sites. All 10 prior selectors remain, with one added selector. Expected combined file: 102,598 bytes, SHA256 `ca66d554b22f340366f0a68a7d3e43a4210eb143cbe2550fcdbabbead768b53c`.

### Existing Apple evidence

Live read-only verification on the Mac matched all eight compiler/control source inputs and payloads and all 10 recorded stdout/stderr streams. The Search archive also preserves exact input bytes, driver, launch record and compile journal. Its extracted classes differ from the full file only by two explicit deletion ranges; no new stub implementation was inserted. The continuous helper's four declarations are byte-identical to the accepted root's original Search source.

The Search receipt records whole-file parsing and a focused actual XCTest/iPhoneSimulator 27 typecheck. The older FaithfulReaderUIBase-dependent classes are outside that focused typecheck. Its README's phrase “116 existing base-class warnings” is imprecise: 116 is the count of repeated warning text, corresponding to 58 primary diagnostics (56 original-base, two retained context-helper, zero new R08).

The continuous-pull receipt records whole donor Reader-file typechecking against actual XCTest/iPhoneSimulator 27 and 19 actual installed-codec/protobuf component controls with explicit synthetic client/probe doubles. Its 153 primary warnings all belong to the retained base/old Reader prefix; none belongs to the new extension. Current five codec/client/protobuf sources, two original assets and two companion binaries still match the pinned receipt. No simulator connection or touch was made by those controls.

These Apple receipts bind their original donor hashes. They do not compile this new loading follow-up or the Reader file combined with `ebd10f`.

## Native acceptance still required

The post-update case is cold-only. It requires the real original Settings update to v41, retained v40 packages, exact source-bound positive trace prefix and separate actual current-process log validation. UI XCTest success alone cannot satisfy that external host gate, and no warm same-process acceptance is claimed.

The continuous-pull case requires both the dedicated host and the exact original native XCTest to pass with the final qualified app/test/SDK/source/corpus bindings. Its current observable contract is portrait, one original HID stream, held native overscroll above then below 80, one release, exact original source/document/TOC. The original probe does not directly expose the private state-machine enum; the preserved positive commit/two-way navigation test remains required.

No native UI, physical device, Native116, Release114, Groups100 or performance acceptance is claimed by this packet. Original raw failure whitespace is evidence and must remain unchanged.
