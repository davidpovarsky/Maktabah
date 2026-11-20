# Native98 History: passive failure diagnostics

## Scope and observed failure

This tranche changes only two existing UI test files, based on `f0dcb09be6c73f306d14ac2527b0c1d21a6e03b1`. It adds no test case, route, renderer, history writer, query, timeout, retry, warmup, or product lifecycle behavior.

Native run [44723902453](https://github.com/davidpovarsky/Maktabah/actions/runs/44723902453) tested immutable F `60a57972acb28739ec738565083bf17fb7503028`, application M `87b783ac3f0257e8461762e0ea9dfa5248dd06e8`. Its verified R27 Pad History case typed the unique UUID query and Return into the original field; the subsequent exact field-value assertion passed. The original 90-second settlement/persistence gate failed before termination or relaunch. Both retained observations identified one original installation but reported `original_preferences_unreadable`. That combined result did not distinguish missing file, type, read, size or parse failures. The displayed initial unavailable/packageMissing state does not prove a nil database selection.

The complete raw run evidence is preserved under `docs/hq-integration/native98-raw-supplement-20261120` at `b60eff47058a108abcb08e8d7c8cebf18df76b2f`, integrated in this baseline. This diagnostic does not establish a product root cause or a successful new execution.

## Changes

1. The existing bounded regular-file reader now returns passive diagnostic fields alongside its unchanged optional bytes: missing, nonregular, symlink, unavailable type, open/read error, oversized, and successful EOF. The original two resource keys, regular=true/non-symlink admission, byte limits, chunk size, EOF loop and close behavior remain. No reported file size is added to admission.
2. Preferences retain the same property-list/dictionary and exact query-count requirements. Failed parsing is now distinguished from a non-dictionary root or unavailable read.
3. The History helper opts in to the existing original DEBUG `GlobalSearchNativeTraceEnabled` channel for both original launches, then restores its local option. The original writer requires miniTest10 and the exact UUID test namespace. It observes provider/publication state and cannot provide a response.
4. The existing attachment points read at most 8 MiB of that same installation's trace; they attach only original event/engine, UUID identities, unsigned revisions, a Boolean, and a validated 64-character lowercase hexadecimal query digest. Request bodies, pages, result content and snippets are not copied. At most 32 records are attached. Admission, history-writer ownership and in-memory history are explicitly unobserved because this channel does not expose them. Missing trace cannot establish a missing submit.
5. Those same attachment points record the actual unique query-field value, enabled/hittable state and whether it equals the test query. These reads are outside settlement predicates.
6. R27 has its own launcher override. One existing `extraArgs` expression now appends `readerAdditionalLaunchArguments` exactly once, so the option reaches the two genuine R27 History cases. Its empty default preserves every other R27 launch argument and the original order.

The UUID query, real Return, namespace/installation pin, 90-second settlement, persisted-exactly-once requirements before and after cold relaunch, exact final row, keyboard and hittability assertions are byte-identical after removing the declared diagnostic hunks. No preferences or history data are written, seeded or synchronized by these diagnostics.

## Verification and limits

`python3 VERIFY_PACKET.py` actually verifies both source hashes, exact forward/reverse changes, every existing test declaration, the unchanged complete History admission/submission/settlement/cold assertion blocks, the one R27 append, and the bound original trace/SDK input blobs. It is source-preservation verification, not execution of Swift or the app.

The first verification attempt stopped on an ambiguous whole-file delimiter before comparing the History block. Its script and error classification are retained. The final verifier scopes the complete original History method before comparisons; Swift source was unchanged by that correction.

Independent read-only review by agent B found no concrete remaining source blocker. It prompted narrowing the digest to String64hex and confirmed the single R27 argument propagation. Root separately approved the diagnostic scope. No reviewer claimed runtime success.

- Swift parse: **NOT_RUN**. The Windows host is disconnected and local Linux has no Swift compiler.
- Apple typecheck: **NOT_RUN**.
- Native UI: **NOT_RUN**; zero new UI executions.
- Original Native98 failure/cancellation and partial execution accounting remain unchanged.

## Integration requirements

Root owns integration and must perform the exact three-way merge with the separately reviewed Groups100 edits to Faithful. This branch does not advance Root or any frozen ref.

The final canonical R27 source SHA256 is `97d33e24844ea293a004d88379b95e5f534df123b58f76df1f0b6d4de059508f`. Before a new Native freeze, Root must update the existing exact `runtime27.py` R27 source pin to this reviewed file (or the actual later merged file). This tranche deliberately does not edit that CI pin.

The original SDK-only job can codegenerate these complete source files on an immutable intermediate ref before final Native freeze. Its precise existing scope and dispatch inputs are recorded in `SDK_ROUTE.json`; it is 11 complete XCTest files, not all 18, and supplies no runtime acceptance.
