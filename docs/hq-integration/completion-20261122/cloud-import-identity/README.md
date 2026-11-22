# Original CloudKit import identity correction — 2026-11-22

Application source: 5d0a11f6a799bee9deb23dc91b29e832bec14335.
Base: 5ccd0c318f0900c41302a6a27a7ab359930e424b.
Root reviewed the minimal protected SQL hook and downstream identity policy before integration. The cross-app product task remains open; this is not Stage B–F acceptance.

## Actual defects and change

The existing original Repository CloudKit update returned an Annotation with the remote source context/locator while its SQL UPDATE omitted those existing columns. The returned model and durable row diverged. Its UUID-less positional fallback also adopted rows from another backend, work or text position if their book/content/range numbers matched.

The UPDATE now persists context and backendLocator using the same encoding as the existing INSERT. The existing legacy query supplies raw locator JSON to the 21-line downstream AnnotationCloudImportIdentity helper and scans for the first compatible candidate instead of limiting before identity verification. Native TextLocator equality includes backend/work/position. Malformed or one-sided missing locators fail closed; original nonnegative catalog IDs with both locators absent retain their prior positional adoption behavior.

No schema, UUID, same-UUID timestamp conflict rule, pending queue, owner/account state, rich body, 64KB limit, original editor/runtime or startup path changed. The same helper is registered in the existing three app targets and in the existing lower-level original Repository driver source closure.

## Executed Windows original Repository/SQLite proof

Baseline job_0e4f705b8680 compiled and ran on real Windows SQLite 3.53.4 with Swift 6.3.3. Write PID 18948 and fresh reopen PID 21940 both reproduced exactly six failures and three passing controls.

Candidate job_c9510f3d31e0 compiled the corrected whole checked-out original Repository/Annotation/SQLiteDatabase/SyncPendingStore. Write PID 34116 passed 9/9 and separate reopen PID 8284 passed 9/9; zero failures. Exact compiled inputs remained unchanged during execution.

Six reproduced failures now pass: same UUID locator/context persistence; legacy mismatch by backend, work or position; missing negative-ID locator; malformed stored locator. The unchanged positive controls also pass: reordered equivalent JSON retains original identity; original positive-ID legacy adoption; older same-UUID remote data cannot overwrite newer local data. Assertions also verify row identity/count, tags, note/timestamp, unchanged schema and unrelated original pending-upload/delete rows. This is not a byte comparison of the whole SQLite file.

The test compiles the full original production Repository, Annotation, SQLiteDatabase and SyncPendingStore, plus exact extracted original TextLocator and connection/lifetime declarations. Explicit boundaries cover Windows-only OSLog, unrelated catalog/title/UI helpers, and an unused compressed-blob decoder. No AnnotationStore cache, CloudKit transport, native app or original Anytype SDK executes here. The old runner wording 'Repository source untouched' means the compiler driver does not rewrite the checked-out source; the candidate contains the reviewed product fix.

The candidate manifest recorded HEAD 5ccd while compiling then-uncommitted candidate bytes; APPLICATION_SOURCE.json and SHA256 matching bind those exact bytes to later application commit 5d0a. The baseline exact-source-before.tar.gz preserves all 13 original compile/provenance inputs, including the original driver version, with full hashes. No passing old suite was rerun.

## Apple continuation

The existing cloud acceptance driver gains optional --cloud-only. Its default still compiles/runs original local43/cold2 and Cloud48. The unchanged Cloud48 assertion bodies, name validator, result validator, fixture prefix and source inventory function were checked; this source review is not a runtime pass.

A narrow source-bound branch codex/otzaria-cloud-import-identity-apple-20261122 runs the same Cloud48 executable and original nine import plus separate-process reopen cases using the actual Apple SDK/OSLog/SQLite. It records committed input blobs and SHA256 before/after, exact compiled copies, real process IDs, raw cases and failure logs. It does not repeat Core194 or local43/cold2, use live credentials, or infer a full app/Native result. Apple results remain NOT_RUN until the actual workflow completes.

## Ordinary app build and original-editor admission

The ordinary HQ build uses its existing source-bound inputs and optional --original-editor-admission composition. No UNFINALIZED producer is required for an ordinary guarded build. Dedicated original-editor StageB prepare/distribution admission remains locked until the real original producer is qualified. No SDK prerequisite or canImport guard was weakened or enabled.

## Preserved attempts and protected-source review

The initial edit script job_a1cd21e7b7f7 timed out after retaining the complete baseline source archive and before any product edits. A fresh exact-state/process audit validated all 13 archived hashes and no product change before guarded continuation job_173e87409928 applied the patch. No duplicate candidate run was spawned.

PRE_EDIT_REVIEW.json records current authorization and scope. The original Repository SQL hook and Xcode target registration are protected upstream files and must be included in the final unsigned full-index review package. Authentic attestation/signature, final Native/Release/TestFlight and two-device cross-app acceptance remain separate gates.

## Source publication preflight

Bound checkout 385fffafb5b014f0777b3100151b5b6d0e75eed9 passed the actual ordinary HQ source preflight, all 93 reviewed Apple input hashes, and the original editor source context with 270 exact execution inputs (job_7f127a427db8). The earlier stale Project build-exclusion pin rejection on d7a988f3 is retained, together with the exact eight-line registration delta and corrected existing manifest digest. No test exclusion rule was weakened. The single dedicated Apple run is frozen at 385fffaf; later evidence-only commits preserve the same application and compiled inputs.

## Actual Apple result — verified

Run 44977823319 completed SUCCESS on exact frozen checkout 385fffaf / application 5d0a. Apple Swift 6.4.2 with MacOSX27.2 SDK executed all unchanged Cloud48 assertions: 48 passed, 0 failed. Original Repository import cases passed 9/9, then reopened actual Apple SQLite 3.54.0 in a separate process: 9/9 passed, PIDs 19651 and 19652.

Artifact 14736950047 is 656371 bytes, SHA256 57d265b96541376c07c683a099b3888518d23163a508d604facf7b18a65c8844, exactly matching the GitHub digest and size; ZIP CRC verified. Its complete raw archive is retained under apple-44977823319, together with GitHub run/jobs/metadata, source inventories, raw Actions logs and readable result/case reports. All 93 reviewed source hashes match before/after; compiled copies are exact. No Core194/local43/cold2 rerun, live network/CloudKit, Anytype runtime, full app or Native credit is claimed.
